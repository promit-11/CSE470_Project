import EvaluationRequest from "../../models/v1/EvaluationRequest.js";
import mongoose from "mongoose";
import MockSession from "../../models/v1/MockSession.js";
import Question from "../../models/v1/Question.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import TestHistory from "../../models/v1/TestHistory.js";
import { OWNER_TYPES } from "../../../constants/ownership.js";
import { APPROVAL_STATUSES, EVALUATION_REQUEST_STATUSES } from "../../../constants/workflow-statuses.js";
import { ROLES } from "../../../constants/roles.js";
import User from "../../models/v1/User.js";
import { HttpError } from "../../../utils/http-error.js";
import { calculateOverallBand } from "../../../utils/score-utils.js";
import {
  createTeacherPayoutRequest,
  listTeacherPayoutRequests,
} from "./finance-service.js";

const WRITING_CRITERIA_KEYS = [
  "taskResponse",
  "coherenceAndCohesion",
  "lexicalResource",
  "grammaticalRangeAndAccuracy",
];

const SPEAKING_TEXT_CRITERIA_KEYS = [
  "fluencyAndCoherence",
  "lexicalResource",
  "grammaticalRangeAndAccuracy",
];

function isBandValue(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= 9;
}

function normalizeTextArray(value, fieldName) {
  if (!Array.isArray(value)) {
    throw new HttpError(422, `${fieldName} must be an array of strings`);
  }
  return value
    .map((item) => (typeof item === "string" ? item.trim() : ""))
    .filter(Boolean);
}

function validateCriteriaScores(section, criterionScores) {
  if (!criterionScores || typeof criterionScores !== "object" || Array.isArray(criterionScores)) {
    throw new HttpError(422, "criterionScores must be an object");
  }

  const keys = section === "writing" ? WRITING_CRITERIA_KEYS : SPEAKING_TEXT_CRITERIA_KEYS;
  const normalized = {};

  for (const key of keys) {
    const value = criterionScores[key];
    if (!isBandValue(value)) {
      throw new HttpError(422, `criterionScores.${key} must be a number between 0 and 9`);
    }
    normalized[key] = value;
  }

  return normalized;
}

function normalizeReviewPayload(section, payload = {}) {
  const overallBand = payload.overallBand;
  if (!isBandValue(overallBand)) {
    throw new HttpError(422, "overallBand must be a number between 0 and 9");
  }

  const comments = typeof payload.comments === "string" ? payload.comments.trim() : "";
  const strengths = normalizeTextArray(payload.strengths, "strengths");
  const weaknesses = normalizeTextArray(payload.weaknesses, "weaknesses");
  const criteriaScores = validateCriteriaScores(section, payload.criterionScores);

  return {
    overallBand,
    comments,
    strengths,
    weaknesses,
    criteriaScores,
  };
}

function toRubric(section, criteriaScores) {
  if (section === "writing") {
    return {
      taskResponse: criteriaScores.taskResponse,
      coherenceAndCohesion: criteriaScores.coherenceAndCohesion,
      lexicalResource: criteriaScores.lexicalResource,
      grammaticalRangeAndAccuracy: criteriaScores.grammaticalRangeAndAccuracy,
      fluencyAndCoherence: null,
      pronunciation: null,
    };
  }

  // Speaking review is text-based in current implementation, so pronunciation is not scored.
  return {
    taskResponse: null,
    coherenceAndCohesion: null,
    lexicalResource: criteriaScores.lexicalResource,
    grammaticalRangeAndAccuracy: criteriaScores.grammaticalRangeAndAccuracy,
    fluencyAndCoherence: criteriaScores.fluencyAndCoherence,
    pronunciation: null,
  };
}

function buildSectionReviewSnapshot(row) {
  if (!row) {
    return null;
  }

  return {
    status: row.status,
    evaluationRequestId: String(row._id),
    reviewedBand: row.reviewedBandScore,
    reviewedAt: row.reviewedAt,
    criterionScores: row.criteriaScores || {},
    comments: row.reviewComments || row.reviewFeedback || "",
    strengths: Array.isArray(row.reviewStrengths) ? row.reviewStrengths : [],
    weaknesses: Array.isArray(row.reviewWeaknesses) ? row.reviewWeaknesses : [],
  };
}

function buildSectionFeedbackEntry(sectionState, evalRow) {
  const base = {
    rawScore: sectionState?.rawScore || 0,
    status: sectionState?.status || "submitted",
    evaluationRequestId: evalRow ? String(evalRow._id) : null,
  };

  if (!evalRow || evalRow.status === EVALUATION_REQUEST_STATUSES.PENDING) {
    return {
      ...base,
      bandScore: null,
      reviewStatus: "pending",
      note: "Pending teacher review.",
    };
  }

  if (evalRow.status === EVALUATION_REQUEST_STATUSES.CLAIMED) {
    return {
      ...base,
      bandScore: null,
      reviewStatus: "claimed",
      note: "Claimed by a teacher and currently under review.",
    };
  }

  return {
    ...base,
    bandScore: evalRow.reviewedBandScore,
    reviewStatus: "reviewed",
    criterionScores: evalRow.criteriaScores || {},
    comments: evalRow.reviewComments || evalRow.reviewFeedback || "",
    strengths: Array.isArray(evalRow.reviewStrengths) ? evalRow.reviewStrengths : [],
    weaknesses: Array.isArray(evalRow.reviewWeaknesses) ? evalRow.reviewWeaknesses : [],
    note: "Reviewed by teacher.",
  };
}

function dedupeTextList(values = []) {
  return [...new Set(values.filter((item) => typeof item === "string" && item.trim()).map((item) => item.trim()))];
}

async function getTeacherProfileOrThrow(teacherUserId) {
  const [profile, teacherUser] = await Promise.all([
    TeacherProfile.findOne({ userId: teacherUserId }).lean(),
    User.findById(teacherUserId).select({ role: 1, status: 1, approvalStatus: 1 }).lean(),
  ]);

  if (!profile) {
    throw new HttpError(404, "Teacher profile not found");
  }

  if (
    !teacherUser ||
    teacherUser.role !== ROLES.TEACHER ||
    teacherUser.status !== "active" ||
    teacherUser.approvalStatus !== APPROVAL_STATUSES.APPROVED
  ) {
    throw new HttpError(403, "Only approved active teachers can access evaluation requests");
  }

  return profile;
}

function buildEligibilityFilter(teacherProfile) {
  return teacherProfile.coachingId
    ? {
        sourceType: OWNER_TYPES.COACHING,
        coachingId: teacherProfile.coachingId,
      }
    : {
        sourceType: OWNER_TYPES.APP,
        coachingId: null,
      };
}

function normalizeMediaMetadata(media) {
  if (!media || typeof media !== "object") {
    return null;
  }

  return {
    mediaId: media.mediaId || "",
    fileName: media.fileName || "",
    mimeType: media.mimeType || "",
    sizeBytes: media.sizeBytes || 0,
    publicUrl: media.publicUrl || "",
    uploadedAt: media.uploadedAt || null,
    pageOrder: typeof media.pageOrder === "number" ? media.pageOrder : null,
  };
}

async function buildReviewDetailPayload(request) {
  const session = await MockSession.findById(request.testSessionId).lean();
  if (!session) {
    throw new HttpError(404, "Mock session not found for this evaluation request");
  }

  const sectionState = Array.isArray(session.sections)
    ? session.sections.find((sectionRow) => sectionRow.section === request.section)
    : null;
  const questionIds = Array.isArray(sectionState?.questionIds) ? sectionState.questionIds : [];

  const questionRows = await Question.find({ _id: { $in: questionIds } })
    .select({
      section: 1,
      questionType: 1,
      category: 1,
      difficulty: 1,
      title: 1,
      content: 1,
      instruction: 1,
      tags: 1,
      mediaUrl: 1,
      listeningAudio: 1,
    })
    .lean();
  const questionById = new Map(questionRows.map((question) => [String(question._id), question]));

  const orderedQuestions = questionIds
    .map((questionId) => questionById.get(String(questionId)))
    .filter(Boolean)
    .map((question) => ({
      id: String(question._id),
      section: question.section,
      questionType: question.questionType,
      category: question.category,
      difficulty: question.difficulty,
      title: question.title,
      content: question.content,
      instruction: question.instruction || "",
      tags: Array.isArray(question.tags) ? question.tags : [],
      mediaUrl: question.mediaUrl || "",
      listeningAudioUrl: question?.listeningAudio?.publicUrl || question.mediaUrl || "",
    }));

  const normalizedAnswers = Array.isArray(sectionState?.answers)
    ? sectionState.answers.map((answer) => ({
        questionId: String(answer.questionId),
        value: answer.value,
      }))
    : [];

  const writingImages = Array.isArray(sectionState?.writingSubmission?.images)
    ? sectionState.writingSubmission.images
        .map(normalizeMediaMetadata)
        .filter(Boolean)
        .sort((left, right) => (left.pageOrder || 0) - (right.pageOrder || 0))
    : [];

  const writingTypedAnswer = sectionState?.writingSubmission?.typedAnswer || "";
  const writingLegacyResponse = sectionState?.writingResponse || "";
  const writingHasContent = Boolean(writingTypedAnswer.trim() || writingImages.length > 0 || writingLegacyResponse.trim());

  const speakingRecording = normalizeMediaMetadata(sectionState?.speakingSubmission?.recording || null);

  return {
    session: {
      id: String(session._id),
      sourceType: session.sourceType,
      coachingId: session.coachingId ? String(session.coachingId) : null,
      sectionOrder: Array.isArray(session.sectionOrder) ? session.sectionOrder : [],
      currentSection: session.currentSection,
      status: session.status,
    },
    sectionContext: {
      section: request.section,
      sectionStatus: sectionState?.status || "submitted",
      startedAt: sectionState?.startedAt || null,
      submittedAt: sectionState?.submittedAt || null,
      durationSeconds: sectionState?.durationSeconds || 0,
      answers: normalizedAnswers,
      questions: orderedQuestions,
    },
    writingSubmission:
      request.section === "writing"
        ? {
            mode: sectionState?.writingSubmission?.mode || "none",
            typedAnswer: writingTypedAnswer,
            images: writingImages,
            hasContent: writingHasContent,
            legacyWritingResponse: writingLegacyResponse,
          }
        : null,
    speakingSubmission:
      request.section === "speaking"
        ? {
            recording: speakingRecording,
            hasRecording: Boolean(
              speakingRecording?.mediaId ||
                speakingRecording?.publicUrl ||
                speakingRecording?.fileName
            ),
            legacySpeakingResponse: sectionState?.speakingResponse || "",
          }
        : null,
  };
}

function buildUnavailableSectionFeedback(sectionState) {
  return {
    bandScore: null,
    rawScore: sectionState?.rawScore || 0,
    status: sectionState?.status || "submitted",
    evaluationRequestId: null,
    reviewStatus: "not_submitted",
    note: "No submission found for this section.",
  };
}

function buildSubjectiveEvaluationSnapshot(row) {
  if (!row) {
    return {
      status: "not_submitted",
      evaluationRequestId: null,
      reviewedBand: null,
      reviewedAt: null,
      criterionScores: {},
      comments: "",
      strengths: [],
      weaknesses: [],
    };
  }

  if (row.status === EVALUATION_REQUEST_STATUSES.PENDING) {
    return {
      status: "pending",
      evaluationRequestId: String(row._id),
      reviewedBand: null,
      reviewedAt: null,
      criterionScores: {},
      comments: "",
      strengths: [],
      weaknesses: [],
    };
  }

  if (row.status === EVALUATION_REQUEST_STATUSES.CLAIMED) {
    return {
      status: "claimed",
      evaluationRequestId: String(row._id),
      reviewedBand: null,
      reviewedAt: null,
      criterionScores: {},
      comments: "",
      strengths: [],
      weaknesses: [],
    };
  }

  return buildSectionReviewSnapshot(row);
}

function buildResultSummary({
  sectionBands,
  subjectivePending,
  subjectiveReviewed,
  subjectiveUnavailable,
  objectiveOverallBand,
  overallBand,
}) {
  const isFullyReviewed = subjectivePending.length === 0 && subjectiveUnavailable.length === 0;
  const hasUnavailable = subjectiveUnavailable.length > 0;
  const partialOverallBand = hasUnavailable
    ? calculateOverallBand({
        listening: sectionBands.listening,
        reading: sectionBands.reading,
        writing: sectionBands.writing,
        speaking: sectionBands.speaking,
      })
    : null;

  const writingStatus = subjectiveReviewed.includes("writing")
    ? "reviewed"
    : subjectivePending.includes("writing")
      ? "pending_review"
      : "not_submitted";
  const speakingStatus = subjectiveReviewed.includes("speaking")
    ? "reviewed"
    : subjectivePending.includes("speaking")
      ? "pending_review"
      : "not_submitted";

  return {
    sections: {
      listening: { status: "completed", band: sectionBands.listening ?? null },
      reading: { status: "completed", band: sectionBands.reading ?? null },
      writing: {
        status: writingStatus,
        band: writingStatus === "reviewed" ? sectionBands.writing ?? null : null,
      },
      speaking: {
        status: speakingStatus,
        band: speakingStatus === "reviewed" ? sectionBands.speaking ?? null : null,
      },
    },
    objectiveCompletedSections: ["listening", "reading"],
    pendingSubjectiveSections: subjectivePending,
    reviewedSubjectiveSections: subjectiveReviewed,
    unavailableSubjectiveSections: subjectiveUnavailable,
    overall: {
      rule: "partial_until_all_sections_available",
      status: isFullyReviewed
        ? "finalized"
        : hasUnavailable
          ? "partial_unavailable_sections"
          : "pending_full_review",
      overallEstimatedBand: isFullyReviewed ? overallBand : hasUnavailable ? partialOverallBand : null,
      objectiveOverallBand,
      finalOverallBand: isFullyReviewed ? overallBand : null,
      isPartial: !isFullyReviewed && hasUnavailable,
    },
  };
}

export async function listPendingEligibleRequests(teacherUserId) {
  const teacherProfile = await getTeacherProfileOrThrow(teacherUserId);
  const eligibilityFilter = buildEligibilityFilter(teacherProfile);

  return EvaluationRequest.find({
    status: EVALUATION_REQUEST_STATUSES.PENDING,
    ...eligibilityFilter,
  })
    .sort({ createdAt: 1 })
    .lean();
}

export async function claimEvaluationRequest(teacherUserId, requestId) {
  const teacherProfile = await getTeacherProfileOrThrow(teacherUserId);
  const eligibilityFilter = buildEligibilityFilter(teacherProfile);

  const now = new Date();
  const claimed = await EvaluationRequest.findOneAndUpdate(
    {
      _id: requestId,
      status: EVALUATION_REQUEST_STATUSES.PENDING,
      ...eligibilityFilter,
    },
    {
      $set: {
        teacherId: teacherUserId,
        status: EVALUATION_REQUEST_STATUSES.CLAIMED,
        claimedAt: now,
      },
    },
    { new: true }
  ).lean();

  if (claimed) {
    return {
      request: claimed,
      claimed: true,
    };
  }

  const existing = await EvaluationRequest.findById(requestId).lean();
  if (!existing) {
    throw new HttpError(404, "Evaluation request not found");
  }

  if (existing.status !== EVALUATION_REQUEST_STATUSES.PENDING) {
    throw new HttpError(409, "Evaluation request was already claimed or is no longer pending");
  }

  const eligible = await EvaluationRequest.findOne({
    _id: requestId,
    ...eligibilityFilter,
  }).lean();

  if (!eligible) {
    throw new HttpError(403, "You are not eligible to claim this evaluation request");
  }

  throw new HttpError(409, "Evaluation request was claimed by another teacher");
}

export async function listMyClaimedRequests(teacherUserId) {
  await getTeacherProfileOrThrow(teacherUserId);

  return EvaluationRequest.find({
    teacherId: teacherUserId,
    status: EVALUATION_REQUEST_STATUSES.CLAIMED,
  })
    .sort({ claimedAt: -1, createdAt: -1 })
    .lean();
}

export async function listMyReviewedRequests(teacherUserId) {
  await getTeacherProfileOrThrow(teacherUserId);

  return EvaluationRequest.find({
    teacherId: teacherUserId,
    status: EVALUATION_REQUEST_STATUSES.REVIEWED,
  })
    .sort({ reviewedAt: -1, createdAt: -1 })
    .lean();
}

export async function getMyTeacherProfile(teacherUserId) {
  const profile = await getTeacherProfileOrThrow(teacherUserId);
  return {
    id: String(profile._id),
    userId: String(profile.userId),
    coachingId: profile.coachingId ? String(profile.coachingId) : null,
    rewardCredits: profile.rewardCredits || 0,
    bio: profile.bio || "",
    expertiseTags: Array.isArray(profile.expertiseTags) ? profile.expertiseTags : [],
  };
}

export async function getMyEvaluationRequestDetails(teacherUserId, requestId) {
  await getTeacherProfileOrThrow(teacherUserId);

  const request = await EvaluationRequest.findOne({
    _id: requestId,
    teacherId: teacherUserId,
    status: {
      $in: [EVALUATION_REQUEST_STATUSES.CLAIMED, EVALUATION_REQUEST_STATUSES.REVIEWED],
    },
  }).lean();

  if (request) {
    const reviewDetail = await buildReviewDetailPayload(request);
    return {
      ...request,
      reviewDetail,
    };
  }

  const existing = await EvaluationRequest.findById(requestId).lean();
  if (!existing) {
    throw new HttpError(404, "Evaluation request not found");
  }
  if (String(existing.teacherId || "") !== String(teacherUserId)) {
    throw new HttpError(403, "You do not have access to this evaluation request");
  }

  throw new HttpError(409, "Evaluation request is not in a viewable teacher state");
}

async function submitEvaluationReviewCore(teacherUserId, requestId, payload, dbSession = null) {
  const claimQuery = EvaluationRequest.findOne({ _id: requestId });
  if (dbSession) claimQuery.session(dbSession);
  const claimRow = await claimQuery.lean();

  if (!claimRow) {
    throw new HttpError(404, "Evaluation request not found");
  }
  if (String(claimRow.teacherId || "") !== String(teacherUserId)) {
    throw new HttpError(403, "You can only review requests claimed by you");
  }

  const review = normalizeReviewPayload(claimRow.section, payload);
  const now = new Date();

  const reviewedUpdateOptions = { new: true };
  if (dbSession) reviewedUpdateOptions.session = dbSession;

  const reviewedRow = await EvaluationRequest.findOneAndUpdate(
    {
      _id: requestId,
      teacherId: teacherUserId,
      status: EVALUATION_REQUEST_STATUSES.CLAIMED,
    },
    {
      $set: {
        status: EVALUATION_REQUEST_STATUSES.REVIEWED,
        reviewedAt: now,
        reviewedBandScore: review.overallBand,
        criteriaScores: review.criteriaScores,
        reviewComments: review.comments,
        reviewStrengths: review.strengths,
        reviewWeaknesses: review.weaknesses,
        reviewSummary: review.comments,
        reviewFeedback: review.comments,
        recommendations: review.strengths,
        correctionNotes: review.weaknesses,
        rubric: toRubric(claimRow.section, review.criteriaScores),
      },
    },
    reviewedUpdateOptions
  ).lean();

  if (!reviewedRow) {
    const latestQuery = EvaluationRequest.findById(requestId);
    if (dbSession) latestQuery.session(dbSession);
    const latest = await latestQuery.lean();

    if (!latest) {
      throw new HttpError(404, "Evaluation request not found");
    }
    if (latest.status === EVALUATION_REQUEST_STATUSES.REVIEWED) {
      throw new HttpError(409, "Evaluation request was already reviewed");
    }
    throw new HttpError(409, "Evaluation request is no longer in claimed status");
  }

  const mockSessionQuery = MockSession.findById(reviewedRow.testSessionId);
  if (dbSession) mockSessionQuery.session(dbSession);
  const mockSession = await mockSessionQuery;

  if (!mockSession) {
    throw new HttpError(404, "Mock session not found for this evaluation request");
  }

  const subjectiveRowsQuery = EvaluationRequest.find({
    testSessionId: reviewedRow.testSessionId,
    section: { $in: ["writing", "speaking"] },
  });
  if (dbSession) subjectiveRowsQuery.session(dbSession);
  const subjectiveRows = await subjectiveRowsQuery.lean();

  const bySection = new Map(subjectiveRows.map((row) => [row.section, row]));
  const writingRow = bySection.get("writing") || null;
  const speakingRow = bySection.get("speaking") || null;

  const writingBand = writingRow?.status === EVALUATION_REQUEST_STATUSES.REVIEWED
    ? writingRow.reviewedBandScore
    : null;
  const speakingBand = speakingRow?.status === EVALUATION_REQUEST_STATUSES.REVIEWED
    ? speakingRow.reviewedBandScore
    : null;
  const subjectiveUnavailable = ["writing", "speaking"].filter(
    (section) => !subjectiveRows.some((row) => row.section === section)
  );

  mockSession.sectionBands = {
    listening: mockSession.sectionBands?.listening ?? 0,
    reading: mockSession.sectionBands?.reading ?? 0,
    writing: writingBand,
    speaking: speakingBand,
  };

  const subjectivePending = subjectiveRows
    .filter((row) => row.status !== EVALUATION_REQUEST_STATUSES.REVIEWED)
    .map((row) => row.section);
  const subjectiveReviewed = subjectiveRows
    .filter((row) => row.status === EVALUATION_REQUEST_STATUSES.REVIEWED)
    .map((row) => row.section);

  const allSubjectiveReviewed =
    subjectivePending.length === 0 && subjectiveUnavailable.length === 0;
  mockSession.overallBand = allSubjectiveReviewed
    ? calculateOverallBand({
        listening: mockSession.sectionBands.listening,
        reading: mockSession.sectionBands.reading,
        writing: mockSession.sectionBands.writing,
        speaking: mockSession.sectionBands.speaking,
      })
    : null;
  mockSession.overallEstimatedBand = allSubjectiveReviewed
    ? mockSession.overallBand
    : subjectiveUnavailable.length > 0
      ? calculateOverallBand({
          listening: mockSession.sectionBands.listening,
          reading: mockSession.sectionBands.reading,
          writing: mockSession.sectionBands.writing,
          speaking: mockSession.sectionBands.speaking,
        })
      : null;
  mockSession.overallBandStatus = allSubjectiveReviewed ? "finalized" : "pending_full_review";

  const sectionByName = new Map((mockSession.sections || []).map((s) => [s.section, s]));
  const sectionFeedback = {
    ...(mockSession.feedbackSummary?.sectionFeedback || {}),
    writing: writingRow
      ? buildSectionFeedbackEntry(sectionByName.get("writing"), writingRow)
      : buildUnavailableSectionFeedback(sectionByName.get("writing")),
    speaking: speakingRow
      ? buildSectionFeedbackEntry(sectionByName.get("speaking"), speakingRow)
      : buildUnavailableSectionFeedback(sectionByName.get("speaking")),
  };

  const strengthPool = [
    ...(Array.isArray(mockSession.feedbackSummary?.strengths) ? mockSession.feedbackSummary.strengths : []),
    ...(Array.isArray(writingRow?.reviewStrengths) ? writingRow.reviewStrengths : []),
    ...(Array.isArray(speakingRow?.reviewStrengths) ? speakingRow.reviewStrengths : []),
  ];
  const weaknessPool = [
    ...(Array.isArray(mockSession.feedbackSummary?.weaknesses) ? mockSession.feedbackSummary.weaknesses : []),
    ...(Array.isArray(writingRow?.reviewWeaknesses) ? writingRow.reviewWeaknesses : []),
    ...(Array.isArray(speakingRow?.reviewWeaknesses) ? speakingRow.reviewWeaknesses : []),
  ];

  mockSession.feedbackSummary = {
    strengths: dedupeTextList(strengthPool),
    weaknesses: dedupeTextList(weaknessPool),
    sectionFeedback,
    notes: allSubjectiveReviewed
      ? "All sections have been scored, including teacher-reviewed writing and speaking."
      : subjectiveUnavailable.length > 0
        ? "Listening/reading are auto-scored. Overall band is partial because one or more subjective submissions are missing."
        : "Listening/reading are auto-scored. Writing/speaking review is partially complete.",
  };

  mockSession.resultStatus = {
    ...(mockSession.resultStatus || {}),
    objectiveSectionsScored: ["listening", "reading"],
    subjectiveSectionsPending: subjectivePending,
    subjectiveSectionsReviewed: subjectiveReviewed,
    subjectiveSectionsUnavailable: subjectiveUnavailable,
    overallStatus: allSubjectiveReviewed
      ? "completed"
      : subjectiveUnavailable.length > 0
        ? "partial_unavailable_sections"
        : "pending_subjective_review",
  };

  const resultSummary = buildResultSummary({
    sectionBands: mockSession.sectionBands,
    subjectivePending,
    subjectiveReviewed,
    subjectiveUnavailable,
    objectiveOverallBand: mockSession.resultStatus?.objectiveOverallBand ?? null,
    overallBand: mockSession.overallBand,
  });

  mockSession.subjectiveEvaluation = {
    writing: buildSubjectiveEvaluationSnapshot(writingRow),
    speaking: buildSubjectiveEvaluationSnapshot(speakingRow),
  };

  const saveOptions = dbSession ? { session: dbSession } : undefined;
  await mockSession.save(saveOptions);

  const historyOptions = { upsert: true, new: true };
  if (dbSession) historyOptions.session = dbSession;

  await TestHistory.findOneAndUpdate(
    { mockSessionId: mockSession._id },
    {
      studentProfileId: mockSession.studentProfileId,
      mockSessionId: mockSession._id,
      listeningBand: mockSession.sectionBands.listening,
      readingBand: mockSession.sectionBands.reading,
      writingBand,
      speakingBand,
      overallBand: mockSession.overallBand,
      overallEstimatedBand: mockSession.overallEstimatedBand,
      overallBandStatus: mockSession.overallBandStatus,
      strengths: mockSession.feedbackSummary.strengths,
      weaknesses: mockSession.feedbackSummary.weaknesses,
      feedbackNotes: mockSession.feedbackSummary.notes,
      sectionFeedback: mockSession.feedbackSummary.sectionFeedback,
      resultSummary,
      resultStatus: mockSession.resultStatus,
      subjectiveEvaluation: mockSession.subjectiveEvaluation,
      completedAt: new Date(),
    },
    historyOptions
  );

  let rewardCreditsAdded = 0;
  if (reviewedRow.sourceType === OWNER_TYPES.APP) {
    rewardCreditsAdded = 3;
    const teacherUpdateOptions = {};
    if (dbSession) teacherUpdateOptions.session = dbSession;
    await TeacherProfile.updateOne(
      { userId: teacherUserId },
      { $inc: { rewardCredits: rewardCreditsAdded } },
      teacherUpdateOptions
    );
  }

  return {
    request: reviewedRow,
    rewardCreditsAdded,
    resultSummary,
    resultStatus: mockSession.resultStatus,
    subjectiveEvaluation: mockSession.subjectiveEvaluation,
    // Include the updated mock session so clients can immediately consume fresh session data
    updatedSession: mockSession.toObject ? mockSession.toObject() : mockSession,
  };
}

export async function submitEvaluationReview(teacherUserId, requestId, payload) {
  await getTeacherProfileOrThrow(teacherUserId);

  const dbSession = await mongoose.startSession();
  try {
    try {
      let result;
      await dbSession.withTransaction(async () => {
        result = await submitEvaluationReviewCore(teacherUserId, requestId, payload, dbSession);
      });
      return result;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return submitEvaluationReviewCore(teacherUserId, requestId, payload, null);
    }
  } finally {
    await dbSession.endSession();
  }
}

export async function requestPayout(teacherUserId, payload = {}) {
  await getTeacherProfileOrThrow(teacherUserId);
  return createTeacherPayoutRequest(
    teacherUserId,
    payload.requestedRewardCredits,
    payload.note || ""
  );
}

export async function listMyPayoutRequests(teacherUserId) {
  await getTeacherProfileOrThrow(teacherUserId);
  return listTeacherPayoutRequests(teacherUserId);
}
