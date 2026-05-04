import Exam from "../../models/v1/Exam.js";
import bcrypt from "bcryptjs";
import mongoose from "mongoose";
import Question from "../../models/v1/Question.js";
import MockTemplate from "../../models/v1/MockTemplate.js";
import MockSession from "../../models/v1/MockSession.js";
import User from "../../models/v1/User.js";
import Institute from "../../models/v1/Institute.js";
import StudentProfile from "../../models/v1/StudentProfile.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import EvaluationRequest from "../../models/v1/EvaluationRequest.js";
import PaymentTransaction from "../../models/v1/PaymentTransaction.js";
import PayoutRequest from "../../models/v1/PayoutRequest.js";
import CoachingAssignmentRequest from "../../models/v1/CoachingAssignmentRequest.js";
import DiscountCode from "../../models/v1/DiscountCode.js";
import TestHistory from "../../models/v1/TestHistory.js";
import RefreshToken from "../../models/v1/RefreshToken.js";
import { ROLES } from "../../../constants/roles.js";
import { APPROVAL_STATUSES, EVALUATION_REQUEST_STATUSES } from "../../../constants/workflow-statuses.js";
import { OWNER_TYPES } from "../../../constants/ownership.js";
import { HttpError } from "../../../utils/http-error.js";
import { mediaStorageService } from "./media-storage-service.js";
import {
  approveSimulatedPayoutByAdmin,
  rejectPayoutByAdmin,
} from "./finance-service.js";

function toPositiveInt(value, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    return fallback;
  }
  return Math.floor(number);
}

function paginationFromQuery(query = {}) {
  const page = toPositiveInt(query.page, 1);
  const limit = Math.min(toPositiveInt(query.limit, 20), 100);
  const skip = (page - 1) * limit;
  return { page, limit, skip };
}

const DATABASE_COLLECTION_MODELS = {
  users: User,
  student_profiles: StudentProfile,
  teacher_profiles: TeacherProfile,
  institutes: Institute,
  questions: Question,
  exams: Exam,
  mock_templates: MockTemplate,
  mock_sessions: MockSession,
  test_histories: TestHistory,
  evaluation_requests: EvaluationRequest,
  payment_transactions: PaymentTransaction,
  payout_requests: PayoutRequest,
  coaching_assignment_requests: CoachingAssignmentRequest,
  discount_codes: DiscountCode,
  refresh_tokens: RefreshToken,
};

function resolveDatabaseCollectionModel(collectionName) {
  const key = String(collectionName || "").trim().toLowerCase();
  const model = DATABASE_COLLECTION_MODELS[key];
  if (!model) {
    throw new HttpError(404, "Unsupported collection");
  }
  return { key, model };
}

function buildDatabaseSearchFilter(model, search) {
  const term = String(search || "").trim();
  if (!term) {
    return {};
  }

  const preferredFields = [
    "name",
    "email",
    "title",
    "status",
    "role",
    "approvalStatus",
    "examType",
    "section",
    "category",
  ];
  const searchableFields = preferredFields.filter((field) => {
    const path = model.schema.path(field);
    return path && path.instance === "String";
  });

  if (!searchableFields.length) {
    return {};
  }

  const regex = new RegExp(term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
  return {
    $or: searchableFields.map((field) => ({ [field]: regex })),
  };
}

function sanitizeUser(user) {
  if (!user) {
    return null;
  }
  return {
    id: String(user._id),
    name: user.name,
    email: user.email,
    role: user.role,
    status: user.status,
    approvalStatus: user.approvalStatus,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

function buildTeacherFilterFromState(state) {
  if (state === "pending_approval") {
    return { approvalStatus: APPROVAL_STATUSES.PENDING_APPROVAL };
  }
  if (state === "approved") {
    return {
      approvalStatus: APPROVAL_STATUSES.APPROVED,
      status: "active",
    };
  }
  if (state === "deactivated") {
    return {
      $or: [
        { status: { $in: ["inactive", "blocked"] } },
        { approvalStatus: APPROVAL_STATUSES.REJECTED },
      ],
    };
  }
  return {};
}

function appOwnershipFilter() {
  return {
    ownerType: OWNER_TYPES.APP,
    ownerId: null,
  };
}

function questionWithMediaUrls(question) {
  return {
    ...question,
    listeningAudioUrl: question?.listeningAudio?.publicUrl || question?.mediaUrl || "",
  };
}

function validateObjectiveQuestionPayload(section, options, answerKey) {
  const normalizedSection = String(section || "").toLowerCase();
  const isObjectiveSection = normalizedSection === "listening" || normalizedSection === "reading";
  if (!isObjectiveSection) {
    return;
  }

  const hasOptions = Array.isArray(options) && options.length > 0;
  const hasAnswerKey = Array.isArray(answerKey) && answerKey.length > 0;
  if (!hasOptions && !hasAnswerKey) {
    return;
  }

  const normalizedOptions = Array.isArray(options) ? options.filter((item) => item && item.key && item.text) : [];
  const normalizedAnswerKey = Array.isArray(answerKey)
    ? answerKey.map((value) => String(value || "").trim().toUpperCase()).filter(Boolean)
    : [];

  if (normalizedOptions.length < 2 || normalizedAnswerKey.length < 1) {
    throw new HttpError(
      422,
      "Listening and reading questions require at least 2 options and at least 1 answer key"
    );
  }

  const optionKeys = new Set(normalizedOptions.map((item) => String(item.key).trim().toUpperCase()));
  for (const key of normalizedAnswerKey) {
    if (!optionKeys.has(key)) {
      throw new HttpError(422, "answerKey must reference existing option keys");
    }
  }
}

function withAppOwnership(payload = {}) {
  const next = { ...payload };
  delete next.ownerType;
  delete next.ownerId;
  return {
    ...next,
    ownerType: OWNER_TYPES.APP,
    ownerId: null,
  };
}

export async function listExams() {
  return Exam.find(appOwnershipFilter()).sort({ createdAt: -1 }).lean();
}

export async function createExam(payload) {
  const exam = await Exam.create(withAppOwnership(payload));
  return exam.toObject();
}

export async function updateExam(id, payload) {
  const updated = await Exam.findOneAndUpdate(
    { _id: id, ...appOwnershipFilter() },
    withAppOwnership(payload),
    { new: true }
  ).lean();
  if (!updated) {
    throw new HttpError(404, "App-owned exam not found");
  }
  return updated;
}

export async function deleteExam(id) {
  const deleted = await Exam.findOneAndDelete({ _id: id, ...appOwnershipFilter() }).lean();
  if (!deleted) {
    throw new HttpError(404, "App-owned exam not found");
  }
}

export async function listQuestions(query = {}) {
  const filter = { ...appOwnershipFilter() };
  if (query.section) filter.section = query.section;
  if (query.difficulty) filter.difficulty = query.difficulty;
  if (query.category) filter.category = query.category;
  if (query.examId) filter.examId = query.examId;
  const rows = await Question.find(filter).sort({ createdAt: -1 }).lean();
  return rows.map(questionWithMediaUrls);
}

export async function createQuestion(payload, listeningAudioFile = null) {
  const examId = payload.examId || null;
  if (examId) {
    const examExists = await Exam.exists({ _id: examId, ...appOwnershipFilter() });
    if (!examExists) {
      throw new HttpError(404, "Exam not found");
    }
  }

  const nextPayload = withAppOwnership(payload);
  nextPayload.examId = examId;
  validateObjectiveQuestionPayload(nextPayload.section, nextPayload.options, nextPayload.answerKey);

  // Normalize answerKey to uppercase for objective sections
  const normalizedSection = String(nextPayload.section || "").toLowerCase();
  if (normalizedSection === "listening" || normalizedSection === "reading") {
    nextPayload.answerKey = Array.isArray(nextPayload.answerKey)
      ? nextPayload.answerKey.map((value) => String(value || "").trim().toUpperCase()).filter(Boolean)
      : [];
  }

  if (listeningAudioFile) {
    if (nextPayload.section !== "listening") {
      throw new HttpError(422, "Listening audio can only be uploaded for listening questions");
    }
    nextPayload.listeningAudio = await mediaStorageService.saveUploadedFile({
      file: listeningAudioFile,
      targetFolder: "questions/app/listening",
    });
  }

  const question = await Question.create(nextPayload);
  return questionWithMediaUrls(question.toObject());
}

export async function updateQuestion(id, payload, listeningAudioFile = null) {
  const question = await Question.findOne({ _id: id, ...appOwnershipFilter() });
  if (!question) {
    throw new HttpError(404, "App-owned question not found");
  }

  const updates = withAppOwnership(payload);
  const nextSection = updates.section || question.section;
  const nextOptions = updates.options ?? question.options;
  const nextAnswerKey = updates.answerKey ?? question.answerKey;
  validateObjectiveQuestionPayload(nextSection, nextOptions, nextAnswerKey);

  // Normalize answerKey to uppercase for objective sections if it was provided in updates
  const normalizedSection = String(nextSection || "").toLowerCase();
  if ((normalizedSection === "listening" || normalizedSection === "reading") && updates.answerKey) {
    updates.answerKey = Array.isArray(updates.answerKey)
      ? updates.answerKey.map((value) => String(value || "").trim().toUpperCase()).filter(Boolean)
      : [];
  }

  if (listeningAudioFile) {
    if (nextSection !== "listening") {
      throw new HttpError(422, "Listening audio can only be uploaded for listening questions");
    }
    if (question.listeningAudio?.storagePath) {
      await mediaStorageService.deleteByStoragePath(question.listeningAudio.storagePath);
    }
    updates.listeningAudio = await mediaStorageService.saveUploadedFile({
      file: listeningAudioFile,
      targetFolder: "questions/app/listening",
    });
  }

  Object.assign(question, updates);
  await question.save();
  return questionWithMediaUrls(question.toObject());
}

export async function deleteQuestion(id) {
  const deleted = await Question.findOneAndDelete({ _id: id, ...appOwnershipFilter() }).lean();
  if (!deleted) {
    throw new HttpError(404, "App-owned question not found");
  }
}

export async function listTemplates(query = {}) {
  const filter = { ...appOwnershipFilter() };
  if (query.examId) {
    filter.examId = query.examId;
  }
  return MockTemplate.find(filter).sort({ createdAt: -1 }).lean();
}

export async function createTemplate(payload) {
  const examId = payload.examId || null;
  if (examId) {
    const examExists = await Exam.exists({ _id: examId, ...appOwnershipFilter() });
    if (!examExists) {
      throw new HttpError(404, "Exam not found");
    }
  }

  const nextPayload = withAppOwnership(payload);
  nextPayload.examId = examId;
  const template = await MockTemplate.create(nextPayload);
  return template.toObject();
}

export async function updateTemplate(id, payload) {
  const updated = await MockTemplate.findOneAndUpdate(
    { _id: id, ...appOwnershipFilter() },
    withAppOwnership(payload),
    { new: true }
  ).lean();
  if (!updated) {
    throw new HttpError(404, "App-owned mock template not found");
  }
  return updated;
}

export async function getAdminOverview() {
  const [studentCount, teacherCount, coachingCount, completedSessions, pendingEvaluationRequests] =
    await Promise.all([
      User.countDocuments({ role: ROLES.STUDENT }),
      User.countDocuments({ role: ROLES.TEACHER }),
      Institute.countDocuments(),
      MockSession.countDocuments({ status: "completed" }),
      EvaluationRequest.countDocuments({
        sourceType: OWNER_TYPES.APP,
        status: EVALUATION_REQUEST_STATUSES.PENDING,
      }),
    ]);

  return {
    students: studentCount,
    teachers: teacherCount,
    coachings: coachingCount,
    completedSessions,
    pendingEvaluationRequests,
  };
}

export async function listTeachers(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = {
    role: ROLES.TEACHER,
    ...buildTeacherFilterFromState(query.state),
  };

  const [users, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    User.countDocuments(filter),
  ]);

  const teacherProfiles = await TeacherProfile.find({
    userId: { $in: users.map((u) => u._id) },
  }).lean();
  const instituteIds = teacherProfiles.map((p) => p.coachingId).filter(Boolean);
  const institutes = await Institute.find({ _id: { $in: instituteIds } })
    .select({ name: 1, contactEmail: 1, contactPhone: 1 })
    .lean();

  const profileByUserId = new Map(teacherProfiles.map((profile) => [String(profile.userId), profile]));
  const instituteById = new Map(institutes.map((institute) => [String(institute._id), institute]));

  return {
    page,
    limit,
    total,
    items: users.map((user) => {
      const profile = profileByUserId.get(String(user._id)) || null;
      const coaching = profile?.coachingId
        ? instituteById.get(String(profile.coachingId)) || null
        : null;
      return {
        user: sanitizeUser(user),
        teacherProfile: profile
          ? {
              id: String(profile._id),
              coachingId: profile.coachingId ? String(profile.coachingId) : null,
              rewardCredits: profile.rewardCredits,
              bio: profile.bio,
              expertiseTags: profile.expertiseTags,
            }
          : null,
        coaching,
      };
    }),
  };
}

export async function approveTeacher(teacherUserId) {
  const user = await User.findOne({ _id: teacherUserId, role: ROLES.TEACHER });
  if (!user) {
    throw new HttpError(404, "Teacher not found");
  }

  user.approvalStatus = APPROVAL_STATUSES.APPROVED;
  user.status = "active";
  await user.save();

  return {
    user: sanitizeUser(user.toObject()),
    action: "approved",
  };
}

export async function rejectOrDeactivateTeacher(teacherUserId, action, reason = "") {
  const user = await User.findOne({ _id: teacherUserId, role: ROLES.TEACHER });
  if (!user) {
    throw new HttpError(404, "Teacher not found");
  }

  if (action === "reject") {
    user.approvalStatus = APPROVAL_STATUSES.REJECTED;
    user.status = "inactive";
  } else if (action === "deactivate") {
    user.status = "inactive";
  } else {
    throw new HttpError(400, "Unsupported action");
  }

  await user.save();

  return {
    user: sanitizeUser(user.toObject()),
    action,
    reason: reason || null,
  };
}

export async function listStudents(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = { role: ROLES.STUDENT };

  if (query.status) {
    filter.status = query.status;
  }

  const [items, total] = await Promise.all([
    User.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    User.countDocuments(filter),
  ]);

  return {
    page,
    limit,
    total,
    items: items.map((item) => ({ user: sanitizeUser(item) })),
  };
}

export async function listCoachings(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);

  const [items, total] = await Promise.all([
    Institute.find().sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    Institute.countDocuments(),
  ]);

  const adminUsers = await User.find({ _id: { $in: items.map((item) => item.adminUserId) } })
    .select({ name: 1, email: 1, status: 1 })
    .lean();
  const adminById = new Map(adminUsers.map((user) => [String(user._id), user]));

  return {
    page,
    limit,
    total,
    items: items.map((item) => ({
      ...item,
      adminUser: adminById.get(String(item.adminUserId)) || null,
    })),
  };
}

export async function suspendUser(userId, reason = "") {
  const user = await User.findById(userId);
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  if (user.role === ROLES.PLATFORM_ADMIN) {
    throw new HttpError(400, "Platform admin cannot be suspended from this endpoint");
  }

  user.status = "blocked";
  await user.save();

  return {
    user: sanitizeUser(user.toObject()),
    action: "suspended",
    reason: reason || null,
  };
}

export async function safeRemoveUser(userId, reason = "") {
  const user = await User.findById(userId);
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  if (user.role === ROLES.PLATFORM_ADMIN) {
    throw new HttpError(400, "Platform admin cannot be deactivated from this endpoint");
  }

  user.status = "inactive";
  await user.save();

  return {
    user: sanitizeUser(user.toObject()),
    action: "safe_removed",
    reason: reason || null,
  };
}

async function ensureEmailAvailable(email) {
  const normalizedEmail = String(email || "").trim().toLowerCase();
  if (!normalizedEmail) {
    throw new HttpError(422, "Email is required");
  }
  const existing = await User.findOne({ email: normalizedEmail }).lean();
  if (existing) {
    throw new HttpError(409, "Email already in use");
  }
  return normalizedEmail;
}

async function buildPasswordHash(password) {
  const value = String(password || "").trim();
  if (value.length < 6) {
    throw new HttpError(422, "Password must be at least 6 characters");
  }
  return bcrypt.hash(value, 12);
}

export async function createStudentByAdmin(payload = {}) {
  const email = await ensureEmailAvailable(payload.email);
  const passwordHash = await buildPasswordHash(payload.password);
  const name = String(payload.name || "").trim();
  if (!name) {
    throw new HttpError(422, "Name is required");
  }

  const user = await User.create({
    name,
    email,
    passwordHash,
    role: ROLES.STUDENT,
    status: "active",
    approvalStatus: APPROVAL_STATUSES.NOT_REQUIRED,
  });

  await StudentProfile.create({
    userId: user._id,
    testCredits: Number(payload.testCredits) > 0 ? Number(payload.testCredits) : 20,
  });

  return {
    created: true,
    role: ROLES.STUDENT,
    user: sanitizeUser(user.toObject()),
  };
}

export async function createTeacherByAdmin(payload = {}) {
  const email = await ensureEmailAvailable(payload.email);
  const passwordHash = await buildPasswordHash(payload.password);
  const name = String(payload.name || "").trim();
  if (!name) {
    throw new HttpError(422, "Name is required");
  }

  const user = await User.create({
    name,
    email,
    passwordHash,
    role: ROLES.TEACHER,
    status: "active",
    approvalStatus: APPROVAL_STATUSES.APPROVED,
  });

  await TeacherProfile.create({
    userId: user._id,
    rewardCredits: 0,
    bio: "",
    expertiseTags: [],
  });

  return {
    created: true,
    role: ROLES.TEACHER,
    user: sanitizeUser(user.toObject()),
  };
}

export async function createCoachingByAdmin(payload = {}) {
  const email = await ensureEmailAvailable(payload.email);
  const passwordHash = await buildPasswordHash(payload.password);
  const adminName = String(payload.name || "").trim();
  const instituteName = String(payload.instituteName || "").trim();
  if (!adminName) {
    throw new HttpError(422, "Admin name is required");
  }
  if (!instituteName) {
    throw new HttpError(422, "Institute name is required");
  }

  const user = await User.create({
    name: adminName,
    email,
    passwordHash,
    role: ROLES.COACHING_ADMIN,
    status: "active",
    approvalStatus: APPROVAL_STATUSES.NOT_REQUIRED,
  });

  const institute = await Institute.create({
    name: instituteName,
    description: String(payload.description || "").trim(),
    address: String(payload.address || "").trim(),
    contactEmail: email,
    contactPhone: String(payload.contactPhone || "").trim(),
    adminUserId: user._id,
  });

  return {
    created: true,
    role: ROLES.COACHING_ADMIN,
    user: sanitizeUser(user.toObject()),
    coaching: {
      id: String(institute._id),
      name: institute.name,
      contactEmail: institute.contactEmail,
    },
  };
}

export async function deleteStudentByAdmin(userId) {
  const user = await User.findOne({ _id: userId, role: ROLES.STUDENT });
  if (!user) {
    throw new HttpError(404, "Student not found");
  }

  // Get StudentProfile before deletion to access studentProfileId for references
  const studentProfile = await StudentProfile.findOne({ userId: user._id });

  // Delete all MockSession records
  await MockSession.deleteMany({ studentProfileId: studentProfile?._id });

  // Delete all TestHistory records
  await TestHistory.deleteMany({ studentProfileId: studentProfile?._id });

  // Delete all PaymentTransaction records
  await PaymentTransaction.deleteMany({ studentId: user._id });

  // Delete all EvaluationRequest where studentId matches
  await EvaluationRequest.deleteMany({ studentId: user._id });

  // Delete all CoachingAssignmentRequest where studentId matches
  await CoachingAssignmentRequest.deleteMany({ studentId: user._id });

  // Remove studentProfileId from DiscountCode eligibleStudentIds arrays
  if (studentProfile?._id) {
    await DiscountCode.updateMany(
      { eligibleStudentIds: studentProfile._id },
      { $pull: { eligibleStudentIds: studentProfile._id } }
    );
  }

  // Delete all RefreshToken records for this user
  await RefreshToken.deleteMany({ userId: user._id });

  // Finally delete StudentProfile and User
  await StudentProfile.deleteOne({ _id: studentProfile?._id });
  await User.deleteOne({ _id: user._id });

  return { deleted: true, role: ROLES.STUDENT, userId: String(userId) };
}

export async function deleteTeacherByAdmin(userId) {
  const user = await User.findOne({ _id: userId, role: ROLES.TEACHER });
  if (!user) {
    throw new HttpError(404, "Teacher not found");
  }

  // Delete all PayoutRequest records where this teacher is the requester
  await PayoutRequest.deleteMany({ teacherId: user._id });

  // Update PayoutRequest records where this teacher is the processor (set to null)
  await PayoutRequest.updateMany(
    { processedByUserId: user._id },
    { $set: { processedByUserId: null } }
  );

  // Update EvaluationRequest where this teacher is the assigned reviewer (set to null)
  await EvaluationRequest.updateMany(
    { teacherId: user._id },
    { $set: { teacherId: null } }
  );

  // Remove this teacher from EvaluationRequest eligibleTeacherIds arrays
  await EvaluationRequest.updateMany(
    { eligibleTeacherIds: user._id },
    { $pull: { eligibleTeacherIds: user._id } }
  );

  // Update CoachingAssignmentRequest where this teacher made the decision (set to null)
  await CoachingAssignmentRequest.updateMany(
    { decidedByUserId: user._id },
    { $set: { decidedByUserId: null } }
  );

  // Delete all RefreshToken records for this user
  await RefreshToken.deleteMany({ userId: user._id });

  // Finally delete TeacherProfile and User
  await TeacherProfile.deleteOne({ userId: user._id });
  await User.deleteOne({ _id: user._id });

  return { deleted: true, role: ROLES.TEACHER, userId: String(userId) };
}

export async function deleteCoachingByAdmin(coachingId) {
  const institute = await Institute.findById(coachingId);
  if (!institute) {
    throw new HttpError(404, "Coaching not found");
  }

  await TeacherProfile.updateMany(
    { coachingId: institute._id },
    { $set: { coachingId: null } }
  );

  await StudentProfile.updateMany(
    { coachingId: institute._id },
    {
      $set: {
        coachingId: null,
        assignmentStatus: "independent",
        studentMode: "independent",
      },
    }
  );

  await User.deleteOne({ _id: institute.adminUserId, role: ROLES.COACHING_ADMIN });
  await Institute.deleteOne({ _id: institute._id });

  return { deleted: true, role: ROLES.COACHING_ADMIN, coachingId: String(coachingId) };
}

export async function listAppEvaluationRequests(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = { sourceType: OWNER_TYPES.APP };

  if (query.status) {
    filter.status = query.status;
  }
  if (query.section) {
    filter.section = query.section;
  }

  const [items, total] = await Promise.all([
    EvaluationRequest.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    EvaluationRequest.countDocuments(filter),
  ]);

  return {
    page,
    limit,
    total,
    items,
  };
}

export async function listPaymentTransactions(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = {};

  if (query.status) {
    filter.status = query.status;
  }

  const [items, total] = await Promise.all([
    PaymentTransaction.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    PaymentTransaction.countDocuments(filter),
  ]);

  return {
    page,
    limit,
    total,
    items,
  };
}

export async function listPayoutRequests(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = {};

  if (query.status) {
    filter.status = query.status;
  }

  const [items, total] = await Promise.all([
    PayoutRequest.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    PayoutRequest.countDocuments(filter),
  ]);

  return {
    page,
    limit,
    total,
    items,
  };
}

export async function approvePayoutRequest(adminUserId, payoutRequestId, note = "") {
  return approveSimulatedPayoutByAdmin(adminUserId, payoutRequestId, note);
}

export async function rejectPayoutRequest(adminUserId, payoutRequestId, reason = "") {
  return rejectPayoutByAdmin(adminUserId, payoutRequestId, reason);
}

export async function listDatabaseCollectionsSummary() {
  const entries = await Promise.all(
    Object.entries(DATABASE_COLLECTION_MODELS).map(async ([name, model]) => {
      const count = await model.countDocuments({});
      return {
        collection: name,
        count,
      };
    })
  );

  return entries.sort((a, b) => a.collection.localeCompare(b.collection));
}

export async function listDatabaseDocuments(collectionName, query = {}) {
  const { model } = resolveDatabaseCollectionModel(collectionName);
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = buildDatabaseSearchFilter(model, query.search);

  const [items, total] = await Promise.all([
    model.find(filter).sort({ createdAt: -1, _id: -1 }).skip(skip).limit(limit).lean(),
    model.countDocuments(filter),
  ]);

  return {
    collection: collectionName,
    page,
    limit,
    total,
    items,
  };
}

export async function deleteDatabaseDocument(collectionName, documentId, actorUserId = null) {
  const { key, model } = resolveDatabaseCollectionModel(collectionName);
  if (!mongoose.Types.ObjectId.isValid(documentId)) {
    throw new HttpError(422, "document id must be a valid id");
  }

  if (key === "users") {
    const user = await User.findById(documentId).lean();
    if (!user) {
      throw new HttpError(404, "Document not found");
    }
    if (user.role === ROLES.PLATFORM_ADMIN) {
      throw new HttpError(403, "Platform admin users cannot be deleted from database manager");
    }
    if (actorUserId && String(user._id) === String(actorUserId)) {
      throw new HttpError(403, "You cannot delete your own user account");
    }
  }

  const deleted = await model.findByIdAndDelete(documentId).lean();
  if (!deleted) {
    throw new HttpError(404, "Document not found");
  }

  return {
    deleted: true,
    collection: key,
    documentId: String(documentId),
  };
}

export async function createDiscountCode(payload) {
  // Implementation for creating a discount code
  const discountCode = await DiscountCode.create(payload);
  return discountCode.toObject();
}

export async function listDiscountCodes(query = {}) {
  const { page, limit, skip } = paginationFromQuery(query);
  const filter = {};

  if (query.status) {
    filter.status = query.status;
  }

  const [items, total] = await Promise.all([
    DiscountCode.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
    DiscountCode.countDocuments(filter),
  ]);

  return {
    page,
    limit,
    total,
    items,
  };
}

export async function deleteTemplate(templateId) {
  if (!mongoose.Types.ObjectId.isValid(templateId)) {
    throw new HttpError(422, "Template id must be a valid id");
  }

  const deleted = await MockTemplate.findByIdAndDelete(templateId).lean();
  if (!deleted) {
    throw new HttpError(404, "Template not found");
  }

  return {
    deleted: true,
    templateId: String(templateId),
  };
}
