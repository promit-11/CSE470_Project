import StudentProfile from "../../models/v1/StudentProfile.js";
import TestHistory from "../../models/v1/TestHistory.js";
import User from "../../models/v1/User.js";
import MockSession from "../../models/v1/MockSession.js";
import Question from "../../models/v1/Question.js";
import DiscountCode from "../../models/v1/DiscountCode.js";
import Institute from "../../models/v1/Institute.js";
import CoachingAssignmentRequest from "../../models/v1/CoachingAssignmentRequest.js";
import { COACHING_ASSIGNMENT_REQUEST_STATUSES } from "../../../constants/workflow-statuses.js";
import { HttpError } from "../../../utils/http-error.js";
import { normalizeResultSummaryFromHistory } from "./student-result-serializer.js";
import {
  createSimulatedCreditPurchase,
  listSimulatedCreditPackages,
  listStudentPaymentTransactions,
} from "./finance-service.js";

const BASE_PRICE_PER_MOCK = 500;

function toBandNumber(value) {
  const band = Number(value);
  if (!Number.isFinite(band)) {
    return null;
  }
  return Math.max(0, Math.min(9, band));
}

function normalizeHistoryRow(row) {
  const resultSummary = normalizeResultSummaryFromHistory(row);
  const overallBand = resultSummary.overall.status === "finalized"
    ? toBandNumber(row?.overallBand)
    : null;

  return {
    ...row,
    writingBand: resultSummary.sections.writing.bandScore,
    speakingBand: resultSummary.sections.speaking.bandScore,
    overallBand,
    overallEstimatedBand: resultSummary.overall.overallEstimatedBand ?? resultSummary.overall.objectiveBandScore,
    overallBandStatus: resultSummary.overall.status,
    resultSummary,
  };
}

function computeSectionAverages(history) {
  if (!Array.isArray(history) || history.length === 0) {
    return {
      listening: 0,
      reading: 0,
      writing: 0,
      speaking: 0,
      overall: 0,
      counts: {
        listening: 0,
        reading: 0,
        writing: 0,
        speaking: 0,
        overall: 0,
      },
    };
  }

  const totals = {
    listening: 0,
    reading: 0,
    writing: 0,
    speaking: 0,
    overall: 0,
  };
  const counts = {
    listening: 0,
    reading: 0,
    writing: 0,
    speaking: 0,
    overall: 0,
  };

  history.forEach((h) => {
    const listening = toBandNumber(h?.resultSummary?.sections?.listening?.bandScore);
    const reading = toBandNumber(h?.resultSummary?.sections?.reading?.bandScore);
    const writing = toBandNumber(h?.resultSummary?.sections?.writing?.bandScore);
    const speaking = toBandNumber(h?.resultSummary?.sections?.speaking?.bandScore);
    const overall =
      h?.resultSummary?.overall?.status === "finalized"
        ? toBandNumber(h?.resultSummary?.overall?.bandScore)
        : null;

    if (listening !== null) {
      totals.listening += listening;
      counts.listening += 1;
    }
    if (reading !== null) {
      totals.reading += reading;
      counts.reading += 1;
    }
    if (writing !== null) {
      totals.writing += writing;
      counts.writing += 1;
    }
    if (speaking !== null) {
      totals.speaking += speaking;
      counts.speaking += 1;
    }
    if (overall !== null) {
      totals.overall += overall;
      counts.overall += 1;
    }
  });

  const avgOrZero = (total, count) => (count > 0 ? Number((total / count).toFixed(2)) : 0);
  return {
    listening: avgOrZero(totals.listening, counts.listening),
    reading: avgOrZero(totals.reading, counts.reading),
    writing: avgOrZero(totals.writing, counts.writing),
    speaking: avgOrZero(totals.speaking, counts.speaking),
    overall: avgOrZero(totals.overall, counts.overall),
    counts,
  };
}

function calculateDiscountAmount(code, subtotal) {
  if (!code || subtotal <= 0) {
    return 0;
  }
  if (code.discountType === "fixed") {
    return Math.max(0, Math.min(subtotal, Number(code.discountValue) || 0));
  }
  const percent = Number(code.discountValue) || 0;
  return Math.max(0, Math.min(subtotal, (subtotal * percent) / 100));
}

async function findResumableSessionForAnalytics(studentProfileId) {
  const activeSessions = await MockSession.find({
    studentProfileId,
    status: "active",
  })
    .sort({ updatedAt: -1, createdAt: -1 })
    .limit(10)
    .lean();

  for (const session of activeSessions) {
    const currentSectionState = Array.isArray(session.sections)
      ? session.sections.find((section) => section.section === session.currentSection)
      : null;
    const questionIds = Array.isArray(currentSectionState?.questionIds)
      ? currentSectionState.questionIds
      : [];

    if (!currentSectionState || currentSectionState.submittedAt || questionIds.length === 0) {
      continue;
    }

    const existingQuestionCount = await Question.countDocuments({
      _id: { $in: questionIds },
    });
    if (existingQuestionCount > 0) {
      return session;
    }
  }

  return null;
}

async function findBestApplicableInstituteDiscount(profile, completedMocks, subtotal) {
  if (!profile.instituteId || !profile.verifiedByInstitute) {
    return null;
  }

  const now = new Date();
  const codes = await DiscountCode.find({
    instituteId: profile.instituteId,
    active: true,
    validFrom: { $lte: now },
    validTo: { $gte: now },
  }).lean();

  let best = null;
  let bestAmount = 0;

  for (const code of codes) {
    if ((code.minMocks || 0) > completedMocks) {
      continue;
    }

    const eligible = Array.isArray(code.eligibleStudentIds) ? code.eligibleStudentIds : [];
    if (eligible.length && !eligible.some((id) => String(id) === String(profile._id))) {
      continue;
    }

    if ((code.usedCount || 0) >= (code.usageLimit || 0)) {
      continue;
    }

    const amount = calculateDiscountAmount(code, subtotal);
    if (amount > bestAmount) {
      bestAmount = amount;
      best = code;
    }
  }

  if (!best) {
    return null;
  }

  return { code: best, amount: bestAmount };
}

export async function getMyProfile(userId) {
  const user = await User.findById(userId).lean();
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  const profile = await StudentProfile.findOne({ userId }).lean();
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  return {
    user: {
      id: String(user._id),
      name: user.name,
      email: user.email,
      role: user.role,
    },
    profile,
  };
}

export async function updateMyProfile(userId, payload) {
  const profile = await StudentProfile.findOne({ userId });
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  if (Array.isArray(payload.strengths)) {
    profile.strengths = payload.strengths;
  }
  if (Array.isArray(payload.weaknesses)) {
    profile.weaknesses = payload.weaknesses;
  }
  if (typeof payload.targetBand === "number") {
    profile.targetBand = payload.targetBand;
  }

  await profile.save();
  return profile.toObject();
}

export async function getMyHistory(userId) {
  const profile = await StudentProfile.findOne({ userId }).lean();
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const rows = await TestHistory.find({ studentProfileId: profile._id })
    .sort({ completedAt: -1 })
    .lean();

  return rows.map((row) => {
    const normalized = normalizeHistoryRow(row);
    return {
      ...normalized,
      archiveState: {
        objectiveFinalized: true,
        subjectivePending: normalized.resultSummary.pendingSubjectiveSections,
        subjectiveReviewed: normalized.resultSummary.reviewedSubjectiveSections,
        subjectiveMissing: normalized.resultSummary.unavailableSubjectiveSections,
      },
    };
  });
}

export async function getMyAnalytics(userId) {
  const profile = await StudentProfile.findOne({ userId }).lean();
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const history = await TestHistory.find({ studentProfileId: profile._id })
    .sort({ completedAt: 1 })
    .lean();

  const normalizedHistory = history.map(normalizeHistoryRow);

  const trend = normalizedHistory.map((h) => ({
    completedAt: h.completedAt,
    overallBand: h.resultSummary.overall.status === "finalized" ? h.resultSummary.overall.bandScore : null,
    // Backward compatibility alias for clients expecting `overall`.
    overall: h.resultSummary.overall.status === "finalized" ? h.resultSummary.overall.bandScore : null,
    overallBandStatus: h.resultSummary.overall.status,
    overallEstimatedBand: h.resultSummary.overall.overallEstimatedBand,
    listeningBand: h.resultSummary.sections.listening.bandScore,
    readingBand: h.resultSummary.sections.reading.bandScore,
    writingBand: h.resultSummary.sections.writing.bandScore,
    speakingBand: h.resultSummary.sections.speaking.bandScore,
    isFinalized: h.resultSummary.overall.status === "finalized",
    resultSummary: h.resultSummary,
  }));

  const latest = normalizedHistory[normalizedHistory.length - 1] || null;
  const latestFinalized = [...normalizedHistory]
    .reverse()
    .find((row) => row.resultSummary?.overall?.status === "finalized") || null;
  const weaknesses =
    Array.isArray(latestFinalized?.weaknesses) && latestFinalized.weaknesses.length > 0
      ? latestFinalized.weaknesses
      : profile.weaknesses;
  const strengths =
    Array.isArray(latestFinalized?.strengths) && latestFinalized.strengths.length > 0
      ? latestFinalized.strengths
      : profile.strengths;

  const activeSession = await findResumableSessionForAnalytics(profile._id);

  return {
    totalMocks: normalizedHistory.length,
    finalizedOverallCount: normalizedHistory.filter(
      (row) => row.resultSummary?.overall?.status === "finalized"
    ).length,
    latest,
    latestFinalized,
    trend,
    sectionAverages: computeSectionAverages(normalizedHistory),
    latestSectionFeedback: latest?.sectionFeedback || {},
    pendingReviewCounts: {
      writing: normalizedHistory.filter((row) => row.resultSummary?.sections?.writing?.status === "pending_review").length,
      speaking: normalizedHistory.filter((row) => row.resultSummary?.sections?.speaking?.status === "pending_review").length,
    },
    analyticsRule: {
      overallTrend: "exclude_incomplete_subjective_results",
      overallAverages: "exclude_incomplete_subjective_results",
      note:
        "Overall metrics include only finalized attempts. Objective section averages always include completed listening/reading; subjective section averages include only reviewed sections.",
    },
    strengths,
    weaknesses,
    mockAccess: (() => {
      const credits = profile.mockAccess?.remainingCredits ?? -1;
      const testCredits = profile.testCredits ?? 20;
      
      return {
        ...profile.mockAccess?.toObject?.() || profile.mockAccess || {},
        // If no purchase credits (-1), show testCredits (initial free credits)
        remainingCredits: credits < 0 ? testCredits : credits,
      };
    })(),
    hasResumableSession: Boolean(activeSession),
    activeSessionId: activeSession ? String(activeSession._id) : null,
  };
}

export async function purchaseMockAccess(userId, payload = {}) {
  const profile = await StudentProfile.findOne({ userId });
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const directPackSize = Number(payload);
  const payloadPackSize = Number(payload?.packSize);
  const packSize = Number.isFinite(payloadPackSize) && payloadPackSize > 0
    ? payloadPackSize
    : Number.isFinite(directPackSize) && directPackSize > 0
      ? directPackSize
      : 1;
  const subtotal = packSize * BASE_PRICE_PER_MOCK;
  const completedMocks = await TestHistory.countDocuments({ studentProfileId: profile._id });
  const discount = await findBestApplicableInstituteDiscount(profile, completedMocks, subtotal);
  const discountAmount = discount?.amount || 0;
  const finalAmount = Math.max(0, subtotal - discountAmount);

  if (discount?.code?._id) {
    await DiscountCode.updateOne(
      { _id: discount.code._id },
      { $inc: { usedCount: 1 } }
    );
  }

  const rawStoredCredits = Number(profile.mockAccess?.remainingCredits);
  const rawTestCredits = Number(profile.testCredits);
  const fallbackTestCredits = Number.isFinite(rawTestCredits)
    ? rawTestCredits
    : 20;
  const effectivePreviousCredits =
    Number.isFinite(rawStoredCredits) && rawStoredCredits >= 0
      ? rawStoredCredits
      : Math.max(0, fallbackTestCredits);
  const nextCredits = effectivePreviousCredits + packSize;

  profile.mockAccess = {
    ...(profile.mockAccess?.toObject?.() || profile.mockAccess || {}),
    allowed: true,
    plan: "credit_pack",
    remainingCredits: nextCredits,
    lastPurchasedAt: new Date(),
  };
  await profile.save();

  return {
    packSize,
    basePricePerMock: BASE_PRICE_PER_MOCK,
    subtotal,
    discountApplied: Boolean(discount),
    appliedDiscount: discount
      ? {
          code: discount.code.code,
          amount: discountAmount,
        }
      : null,
    discountCode: discount ? discount.code.code : undefined,
    discountAmount,
    finalAmount,
    creditsAfterPurchase: nextCredits,
  };
}

export async function getCreditPackages() {
  return listSimulatedCreditPackages();
}

export async function purchaseTestCredits(userId, payload = {}) {
  const packageId = typeof payload.packageId === "string" ? payload.packageId.trim() : "";
  if (!packageId) {
    throw new HttpError(422, "packageId is required for simulated payment");
  }
  return createSimulatedCreditPurchase(userId, packageId);
}

export async function getMyPayments(userId) {
  return listStudentPaymentTransactions(userId);
}

export async function getCoachingAssignmentForm(userId) {
  const [user, profile] = await Promise.all([
    User.findById(userId).lean(),
    StudentProfile.findOne({ userId }).lean(),
  ]);

  if (!user) {
    throw new HttpError(404, "User not found");
  }
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const [pendingRequest, latestRequest, assignedCoaching, allCoachings] = await Promise.all([
    CoachingAssignmentRequest.findOne({
      studentId: user._id,
      status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
    }).lean(),
    CoachingAssignmentRequest.findOne({ studentId: user._id })
      .sort({ createdAt: -1 })
      .lean(),
    profile.coachingId
      ? Institute.findById(profile.coachingId)
          .select({ name: 1, description: 1, address: 1, contactEmail: 1, contactPhone: 1 })
          .lean()
      : Promise.resolve(null),
    Institute.find()
      .select({ name: 1, description: 1, address: 1, contactEmail: 1, contactPhone: 1 })
      .sort({ name: 1 })
      .lean(),
  ]);

  return {
    prefilled: {
      user: {
        id: String(user._id),
        name: user.name,
        email: user.email,
      },
      profile: {
        id: String(profile._id),
        coachingId: profile.coachingId ? String(profile.coachingId) : null,
        studentMode: profile.studentMode || (profile.coachingId ? "coaching_assigned" : "independent"),
      },
    },
    assignment: {
      hasActiveAssignment: Boolean(profile.coachingId),
      activeCoachingId: profile.coachingId ? String(profile.coachingId) : null,
      pendingRequestId: pendingRequest ? String(pendingRequest._id) : null,
      requestStatus: latestRequest ? latestRequest.status : null,
      currentRequest: latestRequest
        ? {
            id: String(latestRequest._id),
            status: latestRequest.status,
            coachingId: String(latestRequest.coachingId),
            admissionCode: latestRequest.admissionCode,
            createdAt: latestRequest.createdAt,
            resolvedAt: latestRequest.resolvedAt,
            decisionNote: latestRequest.decisionNote || "",
          }
        : null,
      activeCoaching: assignedCoaching
        ? {
            id: String(assignedCoaching._id),
            name: assignedCoaching.name,
            description: assignedCoaching.description,
            address: assignedCoaching.address,
            contactEmail: assignedCoaching.contactEmail,
            contactPhone: assignedCoaching.contactPhone,
          }
        : null,
    },
    coachings: allCoachings.map((coaching) => ({
      id: String(coaching._id),
      name: coaching.name,
      description: coaching.description,
      address: coaching.address,
      contactEmail: coaching.contactEmail,
      contactPhone: coaching.contactPhone,
    })),
  };
}

export async function submitCoachingAssignmentRequest(userId, payload = {}) {
  const coachingId = String(payload.coachingId || "").trim();
  const admissionCode = String(payload.admissionCode || "").trim();

  if (!coachingId) {
    throw new HttpError(400, "coachingId is required");
  }
  if (admissionCode.length < 2) {
    throw new HttpError(400, "admissionCode must be at least 2 characters");
  }

  const [user, profile, coaching] = await Promise.all([
    User.findById(userId).lean(),
    StudentProfile.findOne({ userId }),
    Institute.findById(coachingId).lean(),
  ]);

  if (!user || user.role !== "student") {
    throw new HttpError(404, "Student account not found");
  }
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }
  if (!coaching) {
    throw new HttpError(404, "Coaching center not found");
  }

  if (profile.coachingId) {
    throw new HttpError(409, "Student already has an active coaching assignment");
  }

  const existingPending = await CoachingAssignmentRequest.findOne({
    studentId: user._id,
    status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
  }).lean();
  if (existingPending) {
    throw new HttpError(409, "Student already has a pending coaching assignment request");
  }

  let request;
  try {
    request = await CoachingAssignmentRequest.create({
      studentId: user._id,
      coachingId: coaching._id,
      admissionCode,
      status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
    });
  } catch (error) {
    if (error?.code === 11000) {
      throw new HttpError(409, "Student already has a pending coaching assignment request");
    }
    throw error;
  }

  profile.pendingAssignmentRequestId = request._id;
  await profile.save();

  return {
    request: request.toObject(),
    prefilled: {
      user: {
        id: String(user._id),
        name: user.name,
        email: user.email,
      },
      profile: {
        id: String(profile._id),
        studentMode: profile.studentMode || "independent",
      },
    },
    coaching: {
      id: String(coaching._id),
      name: coaching.name,
    },
  };
}
