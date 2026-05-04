import DiscountCode from "../../models/v1/DiscountCode.js";
import Exam from "../../models/v1/Exam.js";
import mongoose from "mongoose";
import Institute from "../../models/v1/Institute.js";
import CoachingAssignmentRequest from "../../models/v1/CoachingAssignmentRequest.js";
import MockTemplate from "../../models/v1/MockTemplate.js";
import Question from "../../models/v1/Question.js";
import StudentProfile from "../../models/v1/StudentProfile.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import User from "../../models/v1/User.js";
import EvaluationRequest from "../../models/v1/EvaluationRequest.js";
import { ROLES } from "../../../constants/roles.js";
import {
  APPROVAL_STATUSES,
  COACHING_ASSIGNMENT_REQUEST_STATUSES,
  EVALUATION_REQUEST_STATUSES,
} from "../../../constants/workflow-statuses.js";
import { OWNER_TYPES } from "../../../constants/ownership.js";
import { HttpError } from "../../../utils/http-error.js";
import { mediaStorageService } from "./media-storage-service.js";

export async function getInstituteByAdmin(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  return institute;
}

function coachingOwnershipFilter(coachingId) {
  return {
    ownerType: OWNER_TYPES.COACHING,
    ownerId: coachingId,
  };
}

function withCoachingOwnership(payload = {}, coachingId) {
  const next = { ...payload };
  delete next.ownerType;
  delete next.ownerId;
  return {
    ...next,
    ownerType: OWNER_TYPES.COACHING,
    ownerId: coachingId,
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

export async function listCoachingExams(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  return Exam.find(coachingOwnershipFilter(institute._id)).sort({ createdAt: -1 }).lean();
}

export async function createCoachingExam(adminUserId, payload) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const exam = await Exam.create(withCoachingOwnership(payload, institute._id));
  return exam.toObject();
}

export async function updateCoachingExam(adminUserId, examId, payload) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const updated = await Exam.findOneAndUpdate(
    { _id: examId, ...coachingOwnershipFilter(institute._id) },
    withCoachingOwnership(payload, institute._id),
    { new: true }
  ).lean();
  if (!updated) {
    throw new HttpError(404, "Coaching-owned exam not found");
  }
  return updated;
}

export async function deleteCoachingExam(adminUserId, examId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const deleted = await Exam.findOneAndDelete({
    _id: examId,
    ...coachingOwnershipFilter(institute._id),
  }).lean();
  if (!deleted) {
    throw new HttpError(404, "Coaching-owned exam not found");
  }
}

export async function listCoachingQuestions(adminUserId, query = {}) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const filter = { ...coachingOwnershipFilter(institute._id) };
  if (query.section) filter.section = query.section;
  if (query.difficulty) filter.difficulty = query.difficulty;
  if (query.category) filter.category = query.category;

  const rows = await Question.find(filter).sort({ createdAt: -1 }).lean();
  return rows.map(questionWithMediaUrls);
}

export async function createCoachingQuestion(adminUserId, payload, listeningAudioFile = null) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const nextPayload = withCoachingOwnership(payload, institute._id);
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
      targetFolder: `questions/coaching/${String(institute._id)}/listening`,
    });
  }

  const question = await Question.create(nextPayload);
  return questionWithMediaUrls(question.toObject());
}

export async function updateCoachingQuestion(adminUserId, questionId, payload, listeningAudioFile = null) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const question = await Question.findOne({
    _id: questionId,
    ...coachingOwnershipFilter(institute._id),
  });
  if (!question) {
    throw new HttpError(404, "Coaching-owned question not found");
  }

  const updates = withCoachingOwnership(payload, institute._id);
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
      targetFolder: `questions/coaching/${String(institute._id)}/listening`,
    });
  }

  Object.assign(question, updates);
  await question.save();
  return questionWithMediaUrls(question.toObject());
}

export async function deleteCoachingQuestion(adminUserId, questionId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const deleted = await Question.findOneAndDelete({
    _id: questionId,
    ...coachingOwnershipFilter(institute._id),
  }).lean();
  if (!deleted) {
    throw new HttpError(404, "Coaching-owned question not found");
  }
}

export async function listCoachingTemplates(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  return MockTemplate.find(coachingOwnershipFilter(institute._id)).sort({ createdAt: -1 }).lean();
}

export async function createCoachingTemplate(adminUserId, payload) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const template = await MockTemplate.create(withCoachingOwnership(payload, institute._id));
  return template.toObject();
}

export async function updateCoachingTemplate(adminUserId, templateId, payload) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const updated = await MockTemplate.findOneAndUpdate(
    { _id: templateId, ...coachingOwnershipFilter(institute._id) },
    withCoachingOwnership(payload, institute._id),
    { new: true }
  ).lean();
  if (!updated) {
    throw new HttpError(404, "Coaching-owned mock template not found");
  }
  return updated;
}

export async function deleteCoachingTemplate(adminUserId, templateId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  const deleted = await MockTemplate.findOneAndDelete({
    _id: templateId,
    ...coachingOwnershipFilter(institute._id),
  }).lean();
  if (!deleted) {
    throw new HttpError(404, "Coaching-owned mock template not found");
  }
}

export async function updateInstitute(adminUserId, payload) {
  const institute = await Institute.findOne({ adminUserId });
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  if (typeof payload.name === "string") institute.name = payload.name;
  if (typeof payload.description === "string") institute.description = payload.description;
  if (typeof payload.address === "string") institute.address = payload.address;
  if (typeof payload.contactPhone === "string") institute.contactPhone = payload.contactPhone;

  await institute.save();
  return institute.toObject();
}

export async function verifyStudent(adminUserId, studentEmail) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const user = await User.findOne({ email: studentEmail.toLowerCase(), role: "student" }).lean();
  if (!user) {
    throw new HttpError(404, "Student account not found");
  }

  const profile = await StudentProfile.findOne({ userId: user._id });
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  if (
    profile.verifiedByInstitute &&
    profile.instituteId &&
    String(profile.instituteId) !== String(institute._id)
  ) {
    throw new HttpError(409, "Student is already verified under another institute");
  }

  profile.instituteId = institute._id;
  profile.verifiedByInstitute = true;
  await profile.save();
  return profile.toObject();
}

export async function listInstituteStudents(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const profiles = await StudentProfile.find({ instituteId: institute._id, verifiedByInstitute: true }).lean();
  const userIds = profiles.map((p) => p.userId);
  const users = await User.find({ _id: { $in: userIds } }).lean();
  const userById = new Map(users.map((u) => [String(u._id), u]));

  return profiles.map((p) => ({
    ...p,
    user: userById.get(String(p.userId)) || null,
  }));
}

export async function listCoachingTeachers(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const profiles = await TeacherProfile.find({ coachingId: institute._id }).lean();
  const userIds = profiles.map((profile) => profile.userId);
  const users = await User.find({ _id: { $in: userIds }, role: ROLES.TEACHER }).lean();
  const userById = new Map(users.map((user) => [String(user._id), user]));

  return profiles.map((profile) => ({
    ...profile,
    user: userById.get(String(profile.userId)) || null,
  }));
}

export async function listAvailableTeachersForCoaching(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const eligibleUsers = await User.find({
    role: ROLES.TEACHER,
    status: "active",
    approvalStatus: APPROVAL_STATUSES.APPROVED,
  })
    .select({ name: 1, email: 1, approvalStatus: 1, status: 1 })
    .lean();

  const profiles = await TeacherProfile.find({
    userId: { $in: eligibleUsers.map((user) => user._id) },
  })
    .select({ userId: 1, coachingId: 1, rewardCredits: 1, expertiseTags: 1 })
    .lean();

  const profileByUserId = new Map(profiles.map((profile) => [String(profile.userId), profile]));

  return eligibleUsers
    .map((user) => {
      const profile = profileByUserId.get(String(user._id)) || null;
      const coachingId = profile?.coachingId ? String(profile.coachingId) : null;
      const isAssignable = !coachingId || coachingId === String(institute._id);
      return {
        id: String(user._id),
        name: user.name,
        email: user.email,
        approvalStatus: user.approvalStatus,
        status: user.status,
        currentCoachingId: coachingId,
        isAssignable,
        teacherProfile: profile
          ? {
              id: String(profile._id),
              rewardCredits: profile.rewardCredits || 0,
              expertiseTags: Array.isArray(profile.expertiseTags) ? profile.expertiseTags : [],
            }
          : null,
      };
    })
    .filter((teacher) => teacher.isAssignable);
}

export async function listCoachingEvaluationRequests(adminUserId, query = {}) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const filter = {
    sourceType: OWNER_TYPES.COACHING,
    coachingId: institute._id,
  };
  if (query.status) {
    filter.status = query.status;
  }
  if (query.section) {
    filter.section = query.section;
  }

  const requests = await EvaluationRequest.find(filter).sort({ createdAt: -1 }).lean();

  const studentIds = requests.map((request) => request.studentId).filter(Boolean);
  const teacherIds = requests.map((request) => request.teacherId).filter(Boolean);

  const [students, teachers] = await Promise.all([
    User.find({ _id: { $in: studentIds } }).select({ name: 1, email: 1 }).lean(),
    User.find({ _id: { $in: teacherIds } }).select({ name: 1, email: 1 }).lean(),
  ]);

  const studentById = new Map(students.map((student) => [String(student._id), student]));
  const teacherById = new Map(teachers.map((teacher) => [String(teacher._id), teacher]));

  const statusCounts = {
    pending: 0,
    claimed: 0,
    reviewed: 0,
  };

  requests.forEach((request) => {
    if (request.status === EVALUATION_REQUEST_STATUSES.PENDING) statusCounts.pending += 1;
    if (request.status === EVALUATION_REQUEST_STATUSES.CLAIMED) statusCounts.claimed += 1;
    if (request.status === EVALUATION_REQUEST_STATUSES.REVIEWED) statusCounts.reviewed += 1;
  });

  return {
    statusCounts,
    items: requests.map((request) => ({
      ...request,
      student: studentById.get(String(request.studentId)) || null,
      teacher: request.teacherId ? teacherById.get(String(request.teacherId)) || null : null,
    })),
  };
}

export async function assignTeacherToCoaching(adminUserId, teacherUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const teacherUser = await User.findOne({ _id: teacherUserId, role: ROLES.TEACHER });
  if (!teacherUser) {
    throw new HttpError(404, "Teacher account not found");
  }

  if (teacherUser.approvalStatus !== APPROVAL_STATUSES.APPROVED) {
    throw new HttpError(409, "Only approved teachers can be assigned to a coaching");
  }

  if (teacherUser.status !== "active") {
    throw new HttpError(409, "Teacher account must be active before assignment");
  }

  let profile = await TeacherProfile.findOne({ userId: teacherUser._id });
  if (!profile) {
    profile = await TeacherProfile.create({ userId: teacherUser._id, rewardCredits: 0 });
  }

  if (profile.coachingId && String(profile.coachingId) !== String(institute._id)) {
    throw new HttpError(409, "Teacher is already assigned to another coaching");
  }

  profile.coachingId = institute._id;
  await profile.save();

  return {
    teacher: {
      id: String(teacherUser._id),
      name: teacherUser.name,
      email: teacherUser.email,
      approvalStatus: teacherUser.approvalStatus,
      status: teacherUser.status,
    },
    teacherProfile: profile.toObject(),
    coaching: {
      id: String(institute._id),
      name: institute.name,
    },
  };
}

export async function removeTeacherFromCoaching(adminUserId, teacherUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const teacherUser = await User.findOne({ _id: teacherUserId, role: ROLES.TEACHER }).lean();
  if (!teacherUser) {
    throw new HttpError(404, "Teacher account not found");
  }

  const profile = await TeacherProfile.findOne({ userId: teacherUser._id });
  if (!profile) {
    throw new HttpError(404, "Teacher profile not found");
  }

  if (!profile.coachingId) {
    return {
      teacher: {
        id: String(teacherUser._id),
        name: teacherUser.name,
        email: teacherUser.email,
      },
      teacherProfile: profile.toObject(),
      message: "Teacher is already independent",
    };
  }

  if (String(profile.coachingId) !== String(institute._id)) {
    throw new HttpError(403, "Teacher is not assigned to your coaching");
  }

  profile.coachingId = null;
  await profile.save();

  return {
    teacher: {
      id: String(teacherUser._id),
      name: teacherUser.name,
      email: teacherUser.email,
    },
    teacherProfile: profile.toObject(),
    message: "Teacher removed from coaching and set to independent",
  };
}

export async function removeStudentFromCoaching(adminUserId, studentUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const studentUser = await User.findOne({
    _id: studentUserId,
    role: ROLES.STUDENT,
  }).lean();
  if (!studentUser) {
    throw new HttpError(404, "Student account not found");
  }

  const profile = await StudentProfile.findOne({ userId: studentUser._id });
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const belongsToInstitute =
    (profile.coachingId &&
      String(profile.coachingId) === String(institute._id)) ||
    (profile.instituteId &&
      String(profile.instituteId) === String(institute._id));

  if (!belongsToInstitute) {
    throw new HttpError(403, "Student is not assigned to your coaching");
  }

  await CoachingAssignmentRequest.updateMany(
    {
      studentId: studentUser._id,
      coachingId: institute._id,
      status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
    },
    {
      $set: {
        status: COACHING_ASSIGNMENT_REQUEST_STATUSES.CANCELLED,
        decidedByUserId: adminUserId,
        decisionNote: "Cancelled after student removal from coaching",
        resolvedAt: new Date(),
      },
    }
  );

  profile.coachingId = null;
  profile.instituteId = null;
  profile.verifiedByInstitute = false;
  profile.assignmentStatus = "independent";
  profile.studentMode = "independent";
  profile.pendingAssignmentRequestId = null;
  await profile.save();

  return {
    student: {
      id: String(studentUser._id),
      name: studentUser.name,
      email: studentUser.email,
    },
    studentProfile: profile.toObject(),
    message:
      "Student removed from coaching. Student can still access app-owned exams with available credits.",
  };
}

export async function createDiscountCode(adminUserId, payload) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const codeValue = String(payload.code || "").trim().toUpperCase();
  const validFrom = new Date(payload.validFrom);
  const validTo = new Date(payload.validTo);
  const discountType = payload.discountType;
  const discountValue = Number(payload.discountValue);
  const usageLimit = Number(payload.usageLimit);
  const minMocks = Number(payload.minMocks || 0);

  if (!codeValue) {
    throw new HttpError(400, "Discount code is required");
  }
  if (Number.isNaN(validFrom.getTime()) || Number.isNaN(validTo.getTime())) {
    throw new HttpError(400, "validFrom and validTo must be valid ISO dates");
  }
  if (validTo <= validFrom) {
    throw new HttpError(400, "validTo must be later than validFrom");
  }
  if (!Number.isFinite(discountValue) || discountValue <= 0) {
    throw new HttpError(400, "discountValue must be a positive number");
  }
  if (discountType === "percentage" && discountValue > 100) {
    throw new HttpError(400, "percentage discount cannot exceed 100");
  }
  if (!Number.isInteger(usageLimit) || usageLimit < 1) {
    throw new HttpError(400, "usageLimit must be at least 1");
  }
  if (!Number.isInteger(minMocks) || minMocks < 0) {
    throw new HttpError(400, "minMocks must be 0 or greater");
  }

  const requestedEligible = Array.isArray(payload.eligibleStudentIds)
    ? payload.eligibleStudentIds.map(String)
    : [];
  let eligibleStudentIds = [];
  if (requestedEligible.length) {
    const verifiedProfiles = await StudentProfile.find({
      _id: { $in: requestedEligible },
      instituteId: institute._id,
      verifiedByInstitute: true,
    })
      .select({ _id: 1 })
      .lean();

    if (verifiedProfiles.length !== requestedEligible.length) {
      throw new HttpError(400, "eligibleStudentIds contains invalid or unverified students");
    }

    eligibleStudentIds = verifiedProfiles.map((p) => p._id);
  }

  let code;
  try {
    code = await DiscountCode.create({
      instituteId: institute._id,
      code: codeValue,
      discountType,
      discountValue,
      validFrom,
      validTo,
      usageLimit,
      minMocks,
      active: payload.active ?? true,
      eligibleStudentIds,
    });
  } catch (error) {
    if (error?.code === 11000) {
      throw new HttpError(409, "Discount code already exists for this institute");
    }
    throw error;
  }

  return code.toObject();
}

export async function listDiscountCodes(adminUserId) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }
  return DiscountCode.find({ instituteId: institute._id }).sort({ createdAt: -1 }).lean();
}

export async function listIncomingAssignmentRequests(adminUserId, query = {}) {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const filter = { coachingId: institute._id };
  if (query.status) {
    filter.status = query.status;
  }

  const requests = await CoachingAssignmentRequest.find(filter)
    .sort({ createdAt: -1 })
    .lean();

  const studentIds = requests.map((request) => request.studentId);
  const [users, profiles] = await Promise.all([
    User.find({ _id: { $in: studentIds } })
      .select({ name: 1, email: 1, status: 1 })
      .lean(),
    StudentProfile.find({ userId: { $in: studentIds } })
      .select({ targetBand: 1, strengths: 1, weaknesses: 1, coachingId: 1, studentMode: 1 })
      .lean(),
  ]);

  const userById = new Map(users.map((user) => [String(user._id), user]));
  const profileByUserId = new Map(profiles.map((profile) => [String(profile.userId), profile]));

  return requests.map((request) => ({
    ...request,
    student: userById.get(String(request.studentId)) || null,
    studentProfile: profileByUserId.get(String(request.studentId)) || null,
  }));
}

async function acceptAssignmentRequestCore(adminUserId, requestId, institute, note = "", dbSession = null) {
  const request = await CoachingAssignmentRequest.findOne({
    _id: requestId,
    coachingId: institute._id,
  }).session(dbSession);

  if (!request) {
    throw new HttpError(404, "Assignment request not found for this coaching");
  }
  if (request.status !== COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING) {
    throw new HttpError(409, "Only pending assignment requests can be accepted");
  }

  const profile = await StudentProfile.findOne({ userId: request.studentId }).session(dbSession);
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  if (profile.coachingId && String(profile.coachingId) !== String(institute._id)) {
    throw new HttpError(409, "Student already has an active coaching assignment");
  }

  request.status = COACHING_ASSIGNMENT_REQUEST_STATUSES.ACCEPTED;
  request.decidedByUserId = adminUserId;
  request.decisionNote = String(note || "").trim();
  request.resolvedAt = new Date();
  await request.save(dbSession ? { session: dbSession } : undefined);

  await CoachingAssignmentRequest.updateMany(
    {
      studentId: request.studentId,
      _id: { $ne: request._id },
      status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
    },
    {
      $set: {
        status: COACHING_ASSIGNMENT_REQUEST_STATUSES.CANCELLED,
        decidedByUserId: adminUserId,
        decisionNote: "Cancelled automatically after acceptance by another coaching",
        resolvedAt: new Date(),
      },
    },
    dbSession ? { session: dbSession } : undefined
  );

  profile.coachingId = institute._id;
  profile.instituteId = institute._id;
  profile.verifiedByInstitute = true;
  profile.assignmentStatus = "assigned";
  profile.studentMode = "coaching_assigned";
  profile.pendingAssignmentRequestId = null;
  await profile.save(dbSession ? { session: dbSession } : undefined);

  return {
    request: request.toObject(),
    studentProfile: profile.toObject(),
  };
}

async function rejectAssignmentRequestCore(adminUserId, requestId, institute, note = "", dbSession = null) {
  const request = await CoachingAssignmentRequest.findOne({
    _id: requestId,
    coachingId: institute._id,
  }).session(dbSession);

  if (!request) {
    throw new HttpError(404, "Assignment request not found for this coaching");
  }
  if (request.status !== COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING) {
    throw new HttpError(409, "Only pending assignment requests can be rejected");
  }

  request.status = COACHING_ASSIGNMENT_REQUEST_STATUSES.REJECTED;
  request.decidedByUserId = adminUserId;
  request.decisionNote = String(note || "").trim();
  request.resolvedAt = new Date();
  await request.save(dbSession ? { session: dbSession } : undefined);

  await StudentProfile.updateOne(
    {
      userId: request.studentId,
      pendingAssignmentRequestId: request._id,
    },
    {
      $set: { pendingAssignmentRequestId: null },
    },
    dbSession ? { session: dbSession } : undefined
  );

  return {
    request: request.toObject(),
  };
}

export async function acceptAssignmentRequest(adminUserId, requestId, note = "") {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const dbSession = await mongoose.startSession();
  try {
    try {
      let responsePayload;
      await dbSession.withTransaction(async () => {
        responsePayload = await acceptAssignmentRequestCore(
          adminUserId,
          requestId,
          institute,
          note,
          dbSession
        );
      });
      return responsePayload;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return acceptAssignmentRequestCore(adminUserId, requestId, institute, note, null);
    }
  } finally {
    await dbSession.endSession();
  }
}

export async function rejectAssignmentRequest(adminUserId, requestId, note = "") {
  const institute = await Institute.findOne({ adminUserId }).lean();
  if (!institute) {
    throw new HttpError(404, "Institute profile not found");
  }

  const dbSession = await mongoose.startSession();
  try {
    try {
      let responsePayload;
      await dbSession.withTransaction(async () => {
        responsePayload = await rejectAssignmentRequestCore(
          adminUserId,
          requestId,
          institute,
          note,
          dbSession
        );
      });
      return responsePayload;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return rejectAssignmentRequestCore(adminUserId, requestId, institute, note, null);
    }
  } finally {
    await dbSession.endSession();
  }
}
