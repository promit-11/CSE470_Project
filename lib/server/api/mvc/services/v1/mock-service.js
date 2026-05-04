import MockSession from "../../models/v1/MockSession.js";
import MockTemplate from "../../models/v1/MockTemplate.js";
import Question from "../../models/v1/Question.js";
import StudentProfile from "../../models/v1/StudentProfile.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import TestHistory from "../../models/v1/TestHistory.js";
import User from "../../models/v1/User.js";
import { SECTION_DURATIONS_SECONDS, SECTION_ORDER } from "../../../constants/sections.js";
import { OWNER_TYPES } from "../../../constants/ownership.js";
import { APPROVAL_STATUSES, EVALUATION_REQUEST_STATUSES } from "../../../constants/workflow-statuses.js";
import { ROLES } from "../../../constants/roles.js";
import EvaluationRequest from "../../models/v1/EvaluationRequest.js";
import { HttpError } from "../../../utils/http-error.js";
import { buildMockQuestions } from "../../../utils/mock-generator.js";
import { calculateOverallBand, rawToBand } from "../../../utils/score-utils.js";
import { mediaStorageService } from "./media-storage-service.js";
import { buildResultSummaryContract } from "./student-result-serializer.js";

function getSectionState(session, section) {
  const state = session.sections.find((s) => s.section === section);
  if (!state) {
    throw new HttpError(404, `Section ${section} not found`);
  }
  return state;
}

function normalizeSectionOrder(template) {
  const order = Array.isArray(template?.sectionOrder) ? template.sectionOrder : SECTION_ORDER;
  const valid = order.filter((s) => SECTION_ORDER.includes(s));
  if (valid.length !== SECTION_ORDER.length) {
    return SECTION_ORDER;
  }
  return valid;
}

function ensureCurrentSection(session, section) {
  if (session.currentSection !== section) {
    throw new HttpError(409, "Only the current IELTS section can be modified");
  }
}

function normalizeWritingMode(typedAnswer, images = []) {
  const hasTyped = typeof typedAnswer === "string" && typedAnswer.trim().length > 0;
  const hasImages = Array.isArray(images) && images.length > 0;
  if (hasTyped && hasImages) return "typed_and_images";
  if (hasTyped) return "typed";
  if (hasImages) return "images";
  return "none";
}

function collectLegacyTextResponses(sectionState) {
  if (!sectionState || !Array.isArray(sectionState.answers)) {
    return [];
  }
  return sectionState.answers
    .map((answer) => (typeof answer?.value === "string" ? answer.value.trim() : ""))
    .filter(Boolean);
}

function hasMeaningfulWritingContent(sectionState) {
  const typedAnswer = sectionState?.writingSubmission?.typedAnswer || "";
  const images = Array.isArray(sectionState?.writingSubmission?.images)
    ? sectionState.writingSubmission.images
    : [];
  const writingResponse = typeof sectionState?.writingResponse === "string"
    ? sectionState.writingResponse.trim()
    : "";
  const legacyAnswers = collectLegacyTextResponses(sectionState);

  return Boolean(
    typedAnswer.trim() ||
      images.length > 0 ||
      writingResponse ||
      legacyAnswers.length > 0
  );
}

function hasSpeakingRecording(sectionState) {
  const recording = sectionState?.speakingSubmission?.recording;
  if (!recording || typeof recording !== "object") {
    return false;
  }

  return Boolean(recording.mediaId || recording.publicUrl || recording.storagePath);
}

function summarizeSubjectiveSection(section, requestRow, hasSubmission) {
  if (!hasSubmission) {
    return {
      status: "not_submitted",
      band: null,
      evaluationRequestId: null,
      reviewStatus: "not_submitted",
      note: "No submission found for this section.",
    };
  }

  if (!requestRow) {
    return {
      status: "not_submitted",
      band: null,
      evaluationRequestId: null,
      reviewStatus: "not_submitted",
      note: "No review request was created for this section.",
    };
  }

  return {
    status: requestRow.status === EVALUATION_REQUEST_STATUSES.REVIEWED ? "reviewed" : "pending_review",
    band: requestRow.status === EVALUATION_REQUEST_STATUSES.REVIEWED ? requestRow.reviewedBandScore : null,
    evaluationRequestId: String(requestRow._id),
    reviewStatus: requestRow.status,
    note: section === "writing" || section === "speaking"
      ? "Pending teacher review."
      : "Section submitted.",
  };
}

function listeningAudioUrl(question = {}) {
  return question?.listeningAudio?.publicUrl || question?.mediaUrl || "";
}

function formatQuestionForClient(question = {}) {
  return {
    ...question,
    listeningAudioUrl: listeningAudioUrl(question),
  };
}

function touchSectionInProgress(sectionState) {
  if (!sectionState.startedAt) {
    sectionState.startedAt = new Date();
    sectionState.status = "in_progress";
  }
}

async function loadActiveSessionForStudent(userId, sessionId) {
  const profile = await StudentProfile.findOne({ userId }).lean();
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const session = await MockSession.findOne({ _id: sessionId, studentProfileId: profile._id });
  if (!session || session.status !== "active") {
    throw new HttpError(404, "Active mock session not found");
  }

  return { session };
}

async function ensureEditableSectionForMedia(session, section) {
  ensureCurrentSection(session, section);
  const expired = await autoSubmitIfExpired(session, section);
  if (expired) {
    throw new HttpError(409, "Section time expired and was auto-submitted");
  }

  const sectionState = getSectionState(session, section);
  if (sectionState.submittedAt) {
    throw new HttpError(409, `${section} section is already submitted and locked`);
  }

  return sectionState;
}

function isExpired(sectionState) {
  if (!sectionState.startedAt || sectionState.submittedAt) {
    return false;
  }
  const deadline = sectionState.startedAt.getTime() + sectionState.durationSeconds * 1000;
  return Date.now() >= deadline;
}

function getRemainingSeconds(sectionState) {
  if (sectionState.submittedAt) {
    return 0;
  }
  if (!sectionState.startedAt) {
    return sectionState.durationSeconds;
  }
  const elapsed = Math.floor((Date.now() - sectionState.startedAt.getTime()) / 1000);
  return Math.max(0, sectionState.durationSeconds - elapsed);
}

async function scoreAndSubmitSection(session, section, autoSubmitted = false) {
  const sectionState = getSectionState(session, section);
  if (sectionState.submittedAt) {
    return;
  }

  const questions = await Question.find({ _id: { $in: sectionState.questionIds } }).lean();
  const questionById = new Map(questions.map((q) => [String(q._id), q]));

  if (section === "listening" || section === "reading") {
    // Check if student actually answered any questions
    const hasAnswers = sectionState.answers && sectionState.answers.length > 0;
    
    if (hasAnswers) {
      sectionState.rawScore = calculateObjectiveSection(sectionState, questionById);
      sectionState.bandScore = rawToBand(section, sectionState.rawScore);
    } else {
      // No answers submitted - don't calculate band score
      sectionState.rawScore = null;
      sectionState.bandScore = null;
    }
  } else {
    const responseKey = section === "writing" ? "writingResponse" : "speakingResponse";
    const responses = sectionState.answers
      .map((a) => (typeof a.value === "string" ? a.value.trim() : ""))
      .filter(Boolean);
    if (section === "writing") {
      const typed = sectionState.writingSubmission?.typedAnswer || "";
      if (!sectionState.writingSubmission) {
        sectionState.writingSubmission = {};
      }
      sectionState.writingSubmission.mode = normalizeWritingMode(
        typed,
        sectionState.writingSubmission?.images || []
      );
      sectionState.writingSubmission.updatedAt = new Date();
      sectionState[responseKey] = typed.trim() || responses.join("\n\n");
    } else {
      sectionState[responseKey] = responses.join("\n\n");
      if (!sectionState.speakingSubmission) {
        sectionState.speakingSubmission = {};
      }
      sectionState.speakingSubmission.updatedAt = new Date();
    }
    sectionState.bandScore = 0;
  }

  sectionState.submittedAt = new Date();
  sectionState.status = autoSubmitted ? "auto_submitted" : "submitted";

  const currentIdx = session.sectionOrder.indexOf(section);
  if (currentIdx >= 0 && currentIdx < session.sectionOrder.length - 1) {
    session.currentSection = session.sectionOrder[currentIdx + 1];
  }
}

async function autoSubmitIfExpired(session, section) {
  const sectionState = getSectionState(session, section);
  if (!isExpired(sectionState)) {
    return false;
  }
  await scoreAndSubmitSection(session, section, true);
  await session.save();
  return true;
}

function resolveGenerationScope(profile, sourceTypeRaw) {
  const requested = sourceTypeRaw === OWNER_TYPES.COACHING
    ? OWNER_TYPES.COACHING
    : OWNER_TYPES.APP;

  if (requested === OWNER_TYPES.COACHING) {
    if (!profile.coachingId) {
      throw new HttpError(403, "Coaching-based tests are available only for coaching-assigned students");
    }
    const isApprovedCoachingAssignment =
      profile.assignmentStatus === "assigned" &&
      profile.studentMode === "coaching_assigned";
    if (!isApprovedCoachingAssignment) {
      throw new HttpError(
        403,
        "Coaching-based tests require an approved coaching assignment"
      );
    }
    return {
      ownerType: OWNER_TYPES.COACHING,
      ownerId: profile.coachingId,
    };
  }

  return {
    ownerType: OWNER_TYPES.APP,
    ownerId: null,
  };
}

function ownershipFilter(scope) {
  return {
    ownerType: scope.ownerType,
    ownerId: scope.ownerId,
  };
}

async function findResumableActiveSession(studentProfileId) {
  const activeSessions = await MockSession.find({
    studentProfileId,
    status: "active",
  })
    .sort({ updatedAt: -1, createdAt: -1 })
    .limit(10);

  for (const session of activeSessions) {
    const currentSectionState = Array.isArray(session.sections)
      ? session.sections.find((section) => section.section === session.currentSection)
      : null;

    const questionIds = Array.isArray(currentSectionState?.questionIds)
      ? currentSectionState.questionIds
      : [];

    const invalidCurrentSection =
      !currentSectionState ||
      Boolean(currentSectionState.submittedAt) ||
      questionIds.length === 0;

    if (invalidCurrentSection) {
      session.status = "abandoned";
      await session.save();
      continue;
    }

    const existingQuestionCount = await Question.countDocuments({
      _id: { $in: questionIds },
    });
    if (existingQuestionCount === 0) {
      session.status = "abandoned";
      await session.save();
      continue;
    }

    return session;
  }

  return null;
}

function getGenerationScopeCandidates(profile, preferredScope) {
  const candidates = [preferredScope];

  const appScope = {
    ownerType: OWNER_TYPES.APP,
    ownerId: null,
  };

  if (preferredScope.ownerType === OWNER_TYPES.COACHING) {
    candidates.push(appScope);
  } else if (profile.coachingId) {
    candidates.push({
      ownerType: OWNER_TYPES.COACHING,
      ownerId: profile.coachingId,
    });
  }

  return candidates;
}

async function findTemplateForGeneration({ templateId, scope }) {
  const templateFilter = {
    ...ownershipFilter(scope),
    active: true,
  };

  if (templateId) {
    return MockTemplate.findOne({ _id: templateId, ...templateFilter }).lean();
  }

  return MockTemplate.findOne(templateFilter).sort({ createdAt: -1 }).lean();
}

export async function generateMockSession(userId, templateId = null, sourceType = OWNER_TYPES.APP) {
  const profile = await StudentProfile.findOne({ userId });
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const existingActiveSession = await findResumableActiveSession(profile._id);
  if (existingActiveSession) {
    return getSessionDetails(userId, String(existingActiveSession._id));
  }

  const scope = resolveGenerationScope(profile, sourceType);

  if (!profile.mockAccess?.allowed) {
    throw new HttpError(403, "Mock access is locked. Purchase a mock package first.");
  }

  if (typeof profile.mockAccess?.remainingCredits === "number" && profile.mockAccess.remainingCredits == 0) {
    throw new HttpError(403, "No mock credits left. Purchase additional credits.");
  }

  const recentSessions = await MockSession.find({ studentProfileId: profile._id, status: "completed" })
    .sort({ createdAt: -1 })
    .limit(20)
    .lean();
  const recentQuestionIds = new Set();
  recentSessions.forEach((session) => {
    session.sections.forEach((sectionState) => {
      sectionState.questionIds.forEach((qid) => recentQuestionIds.add(String(qid)));
    });
  });

  let resolvedScope = scope;
  let template = null;
  let listening = [];
  let reading = [];
  let writing = [];
  let speaking = [];

  const scopeCandidates = templateId
    ? [scope]
    : getGenerationScopeCandidates(profile, scope);

  for (const candidateScope of scopeCandidates) {
    const questionScopeFilter = {
      ...ownershipFilter(candidateScope),
      active: true,
    };

    const [candidateTemplate, candidateListening, candidateReading, candidateWriting, candidateSpeaking] = await Promise.all([
      findTemplateForGeneration({
        templateId,
        scope: candidateScope,
      }),
      Question.find({ section: "listening", ...questionScopeFilter }).lean(),
      Question.find({ section: "reading", ...questionScopeFilter }).lean(),
      Question.find({ section: "writing", ...questionScopeFilter }).lean(),
      Question.find({ section: "speaking", ...questionScopeFilter }).lean(),
    ]);

    const hasSectionCoverage =
      candidateListening.length > 0 &&
      candidateReading.length > 0 &&
      candidateWriting.length > 0 &&
      candidateSpeaking.length > 0;

    if (!hasSectionCoverage) {
      continue;
    }

    resolvedScope = candidateScope;
    template = candidateTemplate;
    listening = candidateListening;
    reading = candidateReading;
    writing = candidateWriting;
    speaking = candidateSpeaking;
    break;
  }

  if (
    listening.length === 0 ||
    reading.length === 0 ||
    writing.length === 0 ||
    speaking.length === 0
  ) {
    throw new HttpError(404, "No active questions found to generate a mock session");
  }

  const selected = buildMockQuestions(
    {
      listening,
      reading,
      writing,
      speaking,
    },
    recentQuestionIds,
    template
  );

  const sectionOrder = normalizeSectionOrder(template);

  const session = await MockSession.create({
    studentProfileId: profile._id,
    templateId: template?._id || null,
    sourceType: resolvedScope.ownerType,
    coachingId: resolvedScope.ownerId,
    sectionOrder,
    currentSection: sectionOrder[0],
    sections: sectionOrder.map((section) => {
      const questionIds = selected[section].map((q) => q._id);
      return {
        section,
        durationSeconds: SECTION_DURATIONS_SECONDS[section],
        questionIds,
        answers: questionIds.map((questionId) => ({
          questionId,
          value: null,
          flagged: false,
        })),
      };
    }),
  });

  if (typeof profile.mockAccess?.remainingCredits === "number" && profile.mockAccess.remainingCredits > 0) {
    profile.mockAccess.remainingCredits -= 5; // Full-length test costs 5 credits
    if (profile.mockAccess.remainingCredits <= 0) {
      profile.mockAccess.remainingCredits = Math.max(0, profile.mockAccess.remainingCredits);
      profile.mockAccess.allowed = false;
    }
    await profile.save();
  }

  return getSessionDetails(userId, String(session._id));
}

export async function getSessionDetails(userId, sessionId) {
  const profile = await StudentProfile.findOne({ userId }).lean();
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const session = await MockSession.findOne({ _id: sessionId, studentProfileId: profile._id });
  if (!session) {
    throw new HttpError(404, "Mock session not found");
  }

  if (session.status === "active") {
    // Ensure persisted state reflects elapsed time before sending session snapshot.
    const current = getSectionState(session, session.currentSection);
    if (!current.submittedAt && isExpired(current)) {
      await scoreAndSubmitSection(session, session.currentSection, true);
      await session.save();
    }
  }

  const sessionObj = session.toObject();

  const questionIds = sessionObj.sections.flatMap((section) => section.questionIds);
  const questions = await Question.find({ _id: { $in: questionIds } }).lean();
  const includeAnswers = sessionObj.status === "completed";
  const questionById = new Map(
    questions.map((q) => {
      const fq = formatQuestionForClient(q);
      if (!includeAnswers) {
        delete fq.answerKey;
      }
      return [String(q._id), fq];
    })
  );

  const hydratedSections = sessionObj.sections.map((sectionState) => ({
    ...sectionState,
    remainingSeconds: getRemainingSeconds(sectionState),
    questions: sectionState.questionIds.map((id) => questionById.get(String(id))).filter(Boolean),
  }));

  // If the session is completed, attach per-question review answers for listening/reading
  if (sessionObj.status === "completed") {
    for (const sec of hydratedSections) {
      if (sec.section === "listening" || sec.section === "reading") {
        const qids = Array.isArray(sec.questionIds) ? sec.questionIds : [];
        const qs = await Question.find({ _id: { $in: qids } }).lean();
        const qmap = new Map(qs.map((q) => [String(q._id), formatQuestionForClient(q)]));
        const review = (sec.answers || []).map((a) => {
          const q = qmap.get(String(a.questionId)) || {};
          const studentValue = a.value;
          const correctVals = Array.isArray(q.answerKey) ? q.answerKey : (q.answerKey ? [q.answerKey] : []);
          const expected = [...correctVals.map(String)].map((v) => v.trim().toUpperCase()).sort().join("|");
          const actualVals = Array.isArray(studentValue) ? studentValue : [studentValue].filter(Boolean);
          const actual = [...actualVals.map(String)].map((v) => v.trim().toUpperCase()).sort().join("|");
          const isCorrect = expected && expected === actual;
          const questionText = q.title || q.content || (Array.isArray(q.options) ? q.options.map((o) => o.text).join(" / ") : "");
          return {
            questionId: String(a.questionId),
            questionText,
            studentAnswer: studentValue,
            correctAnswer: correctVals,
            isCorrect,
          };
        });
        sec.reviewAnswers = review;
      }
    }
  }

  const currentSectionState = hydratedSections.find((s) => s.section === sessionObj.currentSection) || null;

  return {
    ...sessionObj,
    currentRemainingSeconds: currentSectionState ? currentSectionState.remainingSeconds : 0,
    sections: hydratedSections,
  };
}

export async function saveAnswer(userId, sessionId, section, questionId, value) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);

  ensureCurrentSection(session, section);
  const expired = await autoSubmitIfExpired(session, section);
  if (expired) {
    throw new HttpError(409, "Section time expired and was auto-submitted");
  }

  const sectionState = getSectionState(session, section);
  touchSectionInProgress(sectionState);

  const answer = sectionState.answers.find((a) => String(a.questionId) === String(questionId));
  if (!answer) {
    throw new HttpError(404, "Question not found in this section");
  }
  answer.value = value;

  await session.save();
  return { ok: true };
}

export async function markQuestion(userId, sessionId, section, questionId, flagged) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);

  ensureCurrentSection(session, section);
  const expired = await autoSubmitIfExpired(session, section);
  if (expired) {
    throw new HttpError(409, "Section time expired and was auto-submitted");
  }

  const sectionState = getSectionState(session, section);
  const answer = sectionState.answers.find((a) => String(a.questionId) === String(questionId));
  if (!answer) {
    throw new HttpError(404, "Question not found in this section");
  }
  answer.flagged = Boolean(flagged);
  await session.save();
  return { ok: true };
}

function calculateObjectiveSection(sectionState, questionById) {
  let raw = 0;
  for (const ans of sectionState.answers) {
    const q = questionById.get(String(ans.questionId));
    if (!q) continue;
    const value = Array.isArray(ans.value) ? ans.value : [ans.value].filter(Boolean);
    if (!q.answerKey.length) continue;
    // Normalize both expected and actual to uppercase for consistent comparison
    const expected = [...q.answerKey.map(String)].map(v => v.trim().toUpperCase()).sort().join("|");
    const actual = [...value.map(String)].map(v => v.trim().toUpperCase()).sort().join("|");
    if (expected === actual) {
      raw += 1;
    }
  }
  return raw;
}

export async function submitSection(userId, sessionId, section, autoSubmitted = false) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);

  ensureCurrentSection(session, section);

  const sectionState = getSectionState(session, section);
  if (sectionState.submittedAt) {
    return session.toObject();
  }

  const expiredNow = isExpired(sectionState);
  await scoreAndSubmitSection(session, section, autoSubmitted || expiredNow);

  await session.save();
  return getSessionDetails(userId, String(session._id));
}

export async function finalSubmit(userId, sessionId) {
  const profile = await StudentProfile.findOne({ userId });
  if (!profile) throw new HttpError(404, "Student profile not found");

  const session = await MockSession.findOne({ _id: sessionId, studentProfileId: profile._id });
  if (!session) {
    throw new HttpError(404, "Mock session not found");
  }

  if (session.status === "completed") {
    const existingRows = await EvaluationRequest.find({
      testSessionId: session._id,
      section: { $in: ["writing", "speaking"] },
    })
      .sort({ createdAt: 1 })
      .lean();
    const existingHistory = await TestHistory.findOne({ mockSessionId: session._id }).lean();
    const existingSummary = existingHistory?.resultSummary || {};
    const writingSection = session.sections?.find((section) => section.section === "writing") || null;
    const speakingSection = session.sections?.find((section) => section.section === "speaking") || null;

    const writingRow = existingRows.find((row) => row.section === "writing") || null;
    const speakingRow = existingRows.find((row) => row.section === "speaking") || null;
    const writingHasSubmission = hasMeaningfulWritingContent(writingSection);
    const speakingHasSubmission = hasSpeakingRecording(speakingSection);

    const writingStatus = writingRow
      ? (writingRow.status === EVALUATION_REQUEST_STATUSES.REVIEWED ? "reviewed" : "pending_review")
      : (writingHasSubmission ? "pending_review" : "not_submitted");
    const speakingStatus = speakingRow
      ? (speakingRow.status === EVALUATION_REQUEST_STATUSES.REVIEWED ? "reviewed" : "pending_review")
      : (speakingHasSubmission ? "pending_review" : "not_submitted");

    const normalizedSummary = existingSummary?.contractVersion
      ? existingSummary
      : buildResultSummaryContract({
          listeningBand: session.sectionBands?.listening,
          readingBand: session.sectionBands?.reading,
          writingBand: writingStatus === "reviewed" ? session.sectionBands?.writing : null,
          speakingBand: speakingStatus === "reviewed" ? session.sectionBands?.speaking : null,
          listeningRawScore: session.sections?.find((section) => section.section === "listening")?.rawScore,
          readingRawScore: session.sections?.find((section) => section.section === "reading")?.rawScore,
          writingRawScore: writingSection?.rawScore,
          speakingRawScore: speakingSection?.rawScore,
          objectiveOverallBand: session.resultStatus?.objectiveOverallBand,
          finalOverallBand: session.overallBandStatus === "finalized" ? session.overallBand : null,
          writingStatus,
          speakingStatus,
          writingHasSubmission,
          writingSubmissionMode: writingSection?.writingSubmission?.mode || "none",
          writingHasTypedAnswer: Boolean(writingSection?.writingSubmission?.typedAnswer?.trim()),
          writingHasImages: Boolean(writingSection?.writingSubmission?.images?.length),
          writingImageCount: Array.isArray(writingSection?.writingSubmission?.images)
            ? writingSection.writingSubmission.images.length
            : 0,
          speakingHasSubmission,
          speakingHasRecording: hasSpeakingRecording(speakingSection),
          sectionFeedback: existingHistory?.sectionFeedback || session.feedbackSummary?.sectionFeedback || {},
        });

    if (existingHistory) {
      const existingWritingStatus = existingSummary?.sections?.writing?.status || "not_submitted";
      const existingSpeakingStatus = existingSummary?.sections?.speaking?.status || "not_submitted";
      if (existingWritingStatus !== writingStatus || existingSpeakingStatus !== speakingStatus) {
        await TestHistory.findByIdAndUpdate(existingHistory._id, {
          resultSummary: normalizedSummary,
        });
      }
    }

    return {
      ...session.toObject(),
      evaluationRequests: existingRows.map((row) => ({
        id: String(row._id),
        section: row.section,
        status: row.status,
        sourceType: row.sourceType,
        coachingId: row.coachingId ? String(row.coachingId) : null,
        eligibleTeacherCount: row.eligibleTeacherCount || 0,
      })),
      resultState: {
        objective: {
          listeningBand: session.sectionBands?.listening ?? null,
          readingBand: session.sectionBands?.reading ?? null,
          objectiveOverallBand: session.resultStatus?.objectiveOverallBand ?? null,
        },
        subjective: {
          writing: writingStatus,
          speaking: speakingStatus,
        },
        overall: normalizedSummary.overall,
        sections: normalizedSummary.sections,
        overallStatus: normalizedSummary.overall.status,
      },
      resultSummary: normalizedSummary,
    };
  }

  if (session.status !== "active") {
    throw new HttpError(409, "Session is not active and cannot be final-submitted");
  }

  for (const section of session.sectionOrder) {
    const sectionState = getSectionState(session, section);
    if (!sectionState.submittedAt) {
      await submitSection(userId, sessionId, section, true);
    }
  }

  const refreshed = await MockSession.findById(session._id);
  const listeningBand = getSectionState(refreshed, "listening").bandScore;
  const readingBand = getSectionState(refreshed, "reading").bandScore;
  const objectiveOverallBand = calculateOverallBand({
    listening: listeningBand,
    reading: readingBand,
  });

  const writingSectionState = getSectionState(refreshed, "writing");
  const speakingSectionState = getSectionState(refreshed, "speaking");
  const listeningSectionState = getSectionState(refreshed, "listening");
  const readingSectionState = getSectionState(refreshed, "reading");
  const writingHasSubmission = hasMeaningfulWritingContent(writingSectionState);
  const speakingHasSubmission = hasSpeakingRecording(speakingSectionState);
  const subjectiveSectionsNeedingReview = [];
  if (writingHasSubmission) {
    subjectiveSectionsNeedingReview.push("writing");
  }
  if (speakingHasSubmission) {
    subjectiveSectionsNeedingReview.push("speaking");
  }
  const subjectiveSectionsUnavailable = ["writing", "speaking"].filter(
    (section) => !subjectiveSectionsNeedingReview.includes(section)
  );

  refreshed.sectionBands = {
    listening: listeningBand,
    reading: readingBand,
    writing: null,
    speaking: null,
  };
  refreshed.overallBand = null;
  refreshed.overallEstimatedBand = null;
  refreshed.overallBandStatus = "pending_full_review";
  refreshed.status = "completed";

  const teacherFilter = {
    role: ROLES.TEACHER,
    status: "active",
    approvalStatus: APPROVAL_STATUSES.APPROVED,
  };
  const teacherProfiles = await TeacherProfile.find(
    refreshed.sourceType === OWNER_TYPES.APP
      ? { coachingId: null }
      : { coachingId: refreshed.coachingId }
  )
    .select({ userId: 1 })
    .lean();
  const eligibleTeacherIds = teacherProfiles.map((profileRow) => profileRow.userId);
  const eligibleTeachers = await User.find({
    ...teacherFilter,
    _id: { $in: eligibleTeacherIds },
  })
    .select({ _id: 1 })
    .lean();
  const routedTeacherIds = eligibleTeachers.map((teacher) => teacher._id);

  const evaluationRows = await Promise.all(
    subjectiveSectionsNeedingReview.map((section) =>
      EvaluationRequest.findOneAndUpdate(
        { testSessionId: refreshed._id, section },
        {
          studentId: userId,
          teacherId: null,
          coachingId: refreshed.sourceType === OWNER_TYPES.COACHING ? refreshed.coachingId : null,
          testSessionId: refreshed._id,
          section,
          sourceType: refreshed.sourceType,
          status: EVALUATION_REQUEST_STATUSES.PENDING,
          claimedAt: null,
          reviewedAt: null,
          eligibleTeacherIds: routedTeacherIds,
          eligibleTeacherCount: routedTeacherIds.length,
          reviewedBandScore: null,
          reviewSummary: "",
          reviewFeedback: "",
          correctionNotes: [],
          recommendations: [],
          rubric: {},
        },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      ).lean()
    )
  );

  const evaluationBySection = Object.fromEntries(
    evaluationRows.map((row) => [row.section, row])
  );

  const completedSections = refreshed.sections;
  const strengths = [];
  const weaknesses = [];
  const sectionFeedback = {};
  completedSections.forEach((s) => {
    const isObjective = s.section === "listening" || s.section === "reading";
    if (isObjective && s.bandScore >= 7) strengths.push(s.section);
    if (isObjective && s.bandScore > 0 && s.bandScore < 6) weaknesses.push(s.section);
    if (isObjective) {
      sectionFeedback[s.section] = {
        bandScore: s.bandScore,
        rawScore: s.rawScore,
        status: s.status,
        reviewStatus: "scored",
        evaluationRequestId: null,
        note:
          s.bandScore >= 7
            ? "Strong performance in this section."
            : s.bandScore > 0 && s.bandScore < 6
              ? "Needs improvement in this section."
              : "Section submitted.",
      };
      return;
    }

    const subjective = summarizeSubjectiveSection(
      s.section,
      evaluationBySection[s.section] || null,
      s.section === "writing" ? writingHasSubmission : speakingHasSubmission
    );
    sectionFeedback[s.section] = {
      bandScore: subjective.band,
      rawScore: s.rawScore,
      status: s.status,
      reviewStatus: subjective.reviewStatus,
      evaluationRequestId: subjective.evaluationRequestId,
      note: subjective.note,
    };
  });
  refreshed.feedbackSummary = {
    strengths,
    weaknesses,
    sectionFeedback,
    notes:
      subjectiveSectionsNeedingReview.length > 0
        ? "Listening and reading are auto-scored. Submitted subjective sections are pending teacher review."
        : "Listening and reading are auto-scored. Subjective sections were not submitted.",
  };

  const overallStatus = subjectiveSectionsNeedingReview.length > 0
    ? "pending_subjective_review"
    : "partial_unavailable_sections";

  refreshed.resultStatus = {
    objectiveSectionsScored: ["listening", "reading"],
    subjectiveSectionsPending: subjectiveSectionsNeedingReview,
    subjectiveSectionsReviewed: [],
    subjectiveSectionsUnavailable,
    overallStatus,
    objectiveOverallBand,
  };
  refreshed.subjectiveEvaluation = {
    writing: {
      status: writingHasSubmission ? "pending" : "not_submitted",
      evaluationRequestId: writingHasSubmission
        ? String(evaluationBySection.writing?._id || "")
        : null,
    },
    speaking: {
      status: speakingHasSubmission ? "pending" : "not_submitted",
      evaluationRequestId: speakingHasSubmission
        ? String(evaluationBySection.speaking?._id || "")
        : null,
    },
  };

  const hasPendingSubjective = subjectiveSectionsNeedingReview.length > 0;
  const writingImages = Array.isArray(writingSectionState?.writingSubmission?.images)
    ? writingSectionState.writingSubmission.images
    : [];
  const writingTypedAnswer = writingSectionState?.writingSubmission?.typedAnswer || "";
  const writingSubmissionMode = writingSectionState?.writingSubmission?.mode || "none";

  // Build per-question review answers for listening and reading (only for completed session)
  const reviewAnswers = { listening: [], reading: [] };
  try {
    for (const secName of ["listening", "reading"]) {
      const sec = refreshed.sections.find((s) => s.section === secName) || null;
      if (!sec) continue;
      const qids = Array.isArray(sec.questionIds) ? sec.questionIds : [];
      const qs = await Question.find({ _id: { $in: qids } }).lean();
      const qmap = new Map(qs.map((q) => [String(q._id), formatQuestionForClient(q)]));
      const arr = (sec.answers || []).map((a) => {
        const q = qmap.get(String(a.questionId)) || {};
        const studentValue = a.value;
        const correctVals = Array.isArray(q.answerKey) ? q.answerKey : (q.answerKey ? [q.answerKey] : []);
        const expected = [...correctVals.map(String)].map((v) => v.trim().toUpperCase()).sort().join("|");
        const actualVals = Array.isArray(studentValue) ? studentValue : [studentValue].filter(Boolean);
        const actual = [...actualVals.map(String)].map((v) => v.trim().toUpperCase()).sort().join("|");
        const isCorrect = expected && expected === actual;
        const questionText = q.title || q.content || (Array.isArray(q.options) ? q.options.map((o) => o.text).join(" / ") : "");
        return {
          questionId: String(a.questionId),
          questionText,
          studentAnswer: studentValue,
          correctAnswer: correctVals,
          isCorrect,
        };
      });
      reviewAnswers[secName] = arr;
    }
  } catch (e) {
    // ignore errors - best-effort
  }

  const resultSummary = buildResultSummaryContract({
    listeningBand,
    readingBand,
    writingBand: null,
    speakingBand: null,
    listeningRawScore: listeningSectionState?.rawScore,
    readingRawScore: readingSectionState?.rawScore,
    writingRawScore: writingSectionState?.rawScore,
    speakingRawScore: speakingSectionState?.rawScore,
    objectiveOverallBand,
    finalOverallBand: null,
    writingStatus: writingHasSubmission ? "pending_review" : "not_submitted",
    speakingStatus: speakingHasSubmission ? "pending_review" : "not_submitted",
    writingHasSubmission,
    writingSubmissionMode,
    writingHasTypedAnswer: writingTypedAnswer.trim().length > 0,
    writingHasImages: writingImages.length > 0,
    writingImageCount: writingImages.length,
    speakingHasSubmission,
    speakingHasRecording: speakingHasSubmission,
    sectionFeedback,
    reviewAnswers: (function buildReviewAnswers() {
      const out = { listening: [], reading: [] };
      try {
        const buildFor = (secName) => {
          const sec = refreshed.sections.find((s) => s.section === secName) || null;
          if (!sec) return [];
          const qids = Array.isArray(sec.questionIds) ? sec.questionIds : [];
          return qids.map((qid) => {
            const answerObj = (sec.answers || []).find((a) => String(a.questionId) === String(qid)) || { value: null };
            return { qid, answer: answerObj.value };
          }).map((entry) => {
            return entry; // placeholder, will be replaced below by actual values after DB fetch
          });
        };
        out.listening = buildFor("listening");
        out.reading = buildFor("reading");
      } catch (e) {
        // ignore
      }
      return out;
    })(),
  });

  await refreshed.save();

  await TestHistory.findOneAndUpdate(
    { mockSessionId: refreshed._id },
    {
      studentProfileId: profile._id,
      mockSessionId: refreshed._id,
      listeningBand: refreshed.sectionBands.listening,
      readingBand: refreshed.sectionBands.reading,
      writingBand: null,
      speakingBand: null,
      overallBand: null,
      overallEstimatedBand: null,
      overallBandStatus: "pending_full_review",
      strengths: refreshed.feedbackSummary.strengths,
      weaknesses: refreshed.feedbackSummary.weaknesses,
      feedbackNotes: refreshed.feedbackSummary.notes,
      sectionFeedback: refreshed.feedbackSummary.sectionFeedback,
      resultSummary,
      resultStatus: refreshed.resultStatus,
      subjectiveEvaluation: refreshed.subjectiveEvaluation,
      completedAt: new Date(),
    },
    { upsert: true, new: true }
  );

  profile.strengths = refreshed.feedbackSummary.strengths;
  profile.weaknesses = refreshed.feedbackSummary.weaknesses;
  await profile.save();

  return {
    ...refreshed.toObject(),
    evaluationRequests: evaluationRows.map((row) => ({
      id: String(row._id),
      section: row.section,
      status: row.status,
      sourceType: row.sourceType,
      coachingId: row.coachingId ? String(row.coachingId) : null,
      eligibleTeacherCount: row.eligibleTeacherCount || 0,
    })),
    resultState: {
      objective: {
        listeningBand,
        readingBand,
        objectiveOverallBand,
      },
      subjective: {
        writing: writingHasSubmission ? "pending_review" : "not_submitted",
        speaking: speakingHasSubmission ? "pending_review" : "not_submitted",
      },
      overall: resultSummary.overall,
      sections: resultSummary.sections,
      overallStatus: resultSummary.overall.status,
    },
    resultSummary,
  };
}

export async function saveWritingTypedResponse(userId, sessionId, typedAnswer) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);
  const sectionState = await ensureEditableSectionForMedia(session, "writing");
  touchSectionInProgress(sectionState);

  const typed = typeof typedAnswer === "string" ? typedAnswer : "";
  const existingImages = Array.isArray(sectionState.writingSubmission?.images)
    ? sectionState.writingSubmission.images
    : [];

  if (!sectionState.writingSubmission) {
    sectionState.writingSubmission = {};
  }
  sectionState.writingSubmission.typedAnswer = typed;
  sectionState.writingSubmission.images = existingImages;
  sectionState.writingSubmission.mode = normalizeWritingMode(typed, existingImages);
  sectionState.writingSubmission.updatedAt = new Date();
  sectionState.writingResponse = typed.trim();

  session.markModified("sections");
  await session.save();
  return getSessionDetails(userId, String(session._id));
}

export async function uploadWritingImages(userId, sessionId, files = []) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);
  const sectionState = await ensureEditableSectionForMedia(session, "writing");
  touchSectionInProgress(sectionState);

  const incomingFiles = Array.isArray(files) ? files : [];
  if (!incomingFiles.length) {
    throw new HttpError(422, "At least one writing image file is required");
  }

  const existingImages = Array.isArray(sectionState.writingSubmission?.images)
    ? [...sectionState.writingSubmission.images]
    : [];
  const nextOrderStart = existingImages.length + 1;

  const uploaded = [];
  for (let i = 0; i < incomingFiles.length; i += 1) {
    const metadata = await mediaStorageService.saveUploadedFile({
      file: incomingFiles[i],
      targetFolder: `sessions/${sessionId}/writing`,
    });
    uploaded.push({
      ...metadata,
      pageOrder: nextOrderStart + i,
    });
  }

  const images = [...existingImages, ...uploaded];
  const typedAnswer = sectionState.writingSubmission?.typedAnswer || "";
  if (!sectionState.writingSubmission) {
    sectionState.writingSubmission = {};
  }
  sectionState.writingSubmission.typedAnswer = typedAnswer;
  sectionState.writingSubmission.images = images;
  sectionState.writingSubmission.mode = normalizeWritingMode(typedAnswer, images);
  sectionState.writingSubmission.updatedAt = new Date();

  session.markModified("sections");
  await session.save();
  return getSessionDetails(userId, String(session._id));
}

export async function deleteWritingImage(userId, sessionId, mediaId) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);
  const sectionState = await ensureEditableSectionForMedia(session, "writing");

  const existingImages = Array.isArray(sectionState.writingSubmission?.images)
    ? [...sectionState.writingSubmission.images]
    : [];
  const index = existingImages.findIndex((image) => String(image.mediaId) === String(mediaId));
  if (index < 0) {
    return getSessionDetails(userId, String(session._id));
  }

  const [removed] = existingImages.splice(index, 1);
  if (removed?.storagePath) {
    await mediaStorageService.deleteByStoragePath(removed.storagePath);
  }

  const normalizedImages = existingImages.map((image, idx) => ({
    ...image,
    pageOrder: idx + 1,
  }));
  const typedAnswer = sectionState.writingSubmission?.typedAnswer || "";
  if (!sectionState.writingSubmission) {
    sectionState.writingSubmission = {};
  }
  sectionState.writingSubmission.typedAnswer = typedAnswer;
  sectionState.writingSubmission.images = normalizedImages;
  sectionState.writingSubmission.mode = normalizeWritingMode(typedAnswer, normalizedImages);
  sectionState.writingSubmission.updatedAt = new Date();

  session.markModified("sections");
  await session.save();
  return getSessionDetails(userId, String(session._id));
}

export async function reorderWritingImages(userId, sessionId, orderedMediaIds = []) {
  const { session } = await loadActiveSessionForStudent(userId, sessionId);
  const sectionState = await ensureEditableSectionForMedia(session, "writing");

  const ids = Array.isArray(orderedMediaIds) ? orderedMediaIds.map(String) : [];
  const existingImages = Array.isArray(sectionState.writingSubmission?.images)
    ? [...sectionState.writingSubmission.images]
    : [];

  if (ids.length !== existingImages.length) {
    throw new HttpError(422, "orderedMediaIds must include every existing writing image exactly once");
  }

  const existingById = new Map(existingImages.map((image) => [String(image.mediaId), image]));
  if (new Set(ids).size !== ids.length || !ids.every((id) => existingById.has(id))) {
    throw new HttpError(422, "orderedMediaIds contains invalid or duplicate media ids");
  }

  const reordered = ids.map((id, idx) => ({
    ...existingById.get(id),
    pageOrder: idx + 1,
  }));
  const typedAnswer = sectionState.writingSubmission?.typedAnswer || "";
  if (!sectionState.writingSubmission) {
    sectionState.writingSubmission = {};
  }
  sectionState.writingSubmission.typedAnswer = typedAnswer;
  sectionState.writingSubmission.images = reordered;
  sectionState.writingSubmission.mode = normalizeWritingMode(typedAnswer, reordered);
  sectionState.writingSubmission.updatedAt = new Date();

  session.markModified("sections");
  await session.save();
  return getSessionDetails(userId, String(session._id));
}

export async function uploadSpeakingRecording(userId, sessionId, file) {
  if (!file) {
    throw new HttpError(422, "speakingRecording file is required");
  }

  const { session } = await loadActiveSessionForStudent(userId, sessionId);
  const sectionState = await ensureEditableSectionForMedia(session, "speaking");
  touchSectionInProgress(sectionState);

  const previous = sectionState.speakingSubmission?.recording || null;
  if (previous?.storagePath) {
    await mediaStorageService.deleteByStoragePath(previous.storagePath);
  }

  const recording = await mediaStorageService.saveUploadedFile({
    file,
    targetFolder: `sessions/${sessionId}/speaking`,
  });

  if (!sectionState.speakingSubmission) {
    sectionState.speakingSubmission = {};
  }
  sectionState.speakingSubmission.recording = recording;
  sectionState.speakingSubmission.updatedAt = new Date();

  session.markModified("sections");
  await session.save();
  return getSessionDetails(userId, String(session._id));
}
