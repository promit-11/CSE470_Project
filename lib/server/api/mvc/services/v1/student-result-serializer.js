function clampBand(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) {
    return null;
  }
  return Math.max(0, Math.min(9, numeric));
}

function hasBand(value) {
  return typeof clampBand(value) === "number";
}

function normalizeFeedbackEntry(value) {
  if (!value) {
    return {
      summary: "",
      comments: "",
      strengths: [],
      weaknesses: [],
    };
  }

  if (typeof value === "string") {
    return {
      summary: value,
      comments: value,
      strengths: [],
      weaknesses: [],
    };
  }

  return {
    summary: typeof value.note === "string" ? value.note : "",
    comments: typeof value.comments === "string" ? value.comments : "",
    strengths: Array.isArray(value.strengths) ? value.strengths : [],
    weaknesses: Array.isArray(value.weaknesses) ? value.weaknesses : [],
  };
}

function normalizeSectionShape({
  section,
  status,
  bandScore,
  rawScore,
  reviewPending,
  feedback,
  submission,
  reviewAnswers,
}) {
  const normalizedBand = clampBand(bandScore);
  return {
    section,
    status,
    bandScore: normalizedBand,
    // Legacy compatibility alias.
    band: normalizedBand,
    rawScore: typeof rawScore === "number" ? rawScore : null,
    reviewPending: Boolean(reviewPending),
    feedback: normalizeFeedbackEntry(feedback),
    submission: submission || null,
    reviewAnswers: Array.isArray(reviewAnswers) ? reviewAnswers : [],
  };
}

function normalizeSectionStatusFromLegacy(summarySection, fallbackStatus = "not_submitted") {
  const rawStatus = summarySection?.status;
  if (
    rawStatus === "completed" ||
    rawStatus === "pending_review" ||
    rawStatus === "reviewed" ||
    rawStatus === "not_submitted"
  ) {
    return rawStatus;
  }
  return fallbackStatus;
}

function buildOverall({
  status,
  rule,
  ruleLabel,
  isPartial,
  objectiveBandScore,
  finalBandScore,
  pendingSections,
  reviewedSections,
  unavailableSections,
}) {
  return {
    status,
    rule,
    ruleLabel,
    isPartial: Boolean(isPartial),
    bandScore: hasBand(finalBandScore) ? clampBand(finalBandScore) : null,
    objectiveBandScore: clampBand(objectiveBandScore),
    pendingSections,
    reviewedSections,
    unavailableSections,
    // Legacy compatibility fields.
    objectiveOverallBand: clampBand(objectiveBandScore),
    finalOverallBand: hasBand(finalBandScore) ? clampBand(finalBandScore) : null,
    overallEstimatedBand: hasBand(finalBandScore)
      ? clampBand(finalBandScore)
      : unavailableSections.length > 0
        ? clampBand(objectiveBandScore)
        : null,
  };
}

export function buildResultSummaryContract(payload = {}) {
  // Determine listening/reading status based on whether band scores exist
  // If no band score, section was not submitted (empty submission)
  const listeningStatus = hasBand(payload.listeningBand) ? "completed" : "not_submitted";
  const readingStatus = hasBand(payload.readingBand) ? "completed" : "not_submitted";
  const writingStatus = payload.writingStatus || "not_submitted";
  const speakingStatus = payload.speakingStatus || "not_submitted";

  const pendingSubjectiveSections = ["writing", "speaking"].filter(
    (section) => (section === "writing" ? writingStatus : speakingStatus) === "pending_review"
  );
  const reviewedSubjectiveSections = ["writing", "speaking"].filter(
    (section) => (section === "writing" ? writingStatus : speakingStatus) === "reviewed"
  );
  const unavailableSubjectiveSections = ["writing", "speaking"].filter(
    (section) => (section === "writing" ? writingStatus : speakingStatus) === "not_submitted"
  );

  const isFinalized =
    pendingSubjectiveSections.length === 0 && unavailableSubjectiveSections.length === 0;
  const overallStatus = isFinalized
    ? "finalized"
    : unavailableSubjectiveSections.length > 0
      ? "partial_unavailable_sections"
      : "pending_full_review";

  const overall = buildOverall({
    status: overallStatus,
    rule: "partial_until_all_sections_available",
    ruleLabel:
      "Overall band is final only after both subjective sections are reviewed; missing subjective submissions keep a partial objective-only result.",
    isPartial: overallStatus === "partial_unavailable_sections",
    objectiveBandScore: payload.objectiveOverallBand,
    finalBandScore: isFinalized ? payload.finalOverallBand : null,
    pendingSections: pendingSubjectiveSections,
    reviewedSections: reviewedSubjectiveSections,
    unavailableSections: unavailableSubjectiveSections,
  });

  const sections = {
    listening: normalizeSectionShape({
      section: "listening",
      status: listeningStatus,
      bandScore: payload.listeningBand,
      rawScore: payload.listeningRawScore,
      reviewPending: false,
      feedback: payload.sectionFeedback?.listening,
      submission: {
        mode: "objective",
        hasSubmission: hasBand(payload.listeningBand),
      },
      reviewAnswers: payload.reviewAnswers?.listening,
    }),
    reading: normalizeSectionShape({
      section: "reading",
      status: readingStatus,
      bandScore: payload.readingBand,
      rawScore: payload.readingRawScore,
      reviewPending: false,
      feedback: payload.sectionFeedback?.reading,
      submission: {
        mode: "objective",
        hasSubmission: hasBand(payload.readingBand),
      },
      reviewAnswers: payload.reviewAnswers?.reading,
    }),
    writing: normalizeSectionShape({
      section: "writing",
      status: writingStatus,
      bandScore: writingStatus === "reviewed" ? payload.writingBand : null,
      rawScore: payload.writingRawScore,
      reviewPending: writingStatus === "pending_review",
      feedback: payload.sectionFeedback?.writing,
      submission: {
        mode: payload.writingSubmissionMode || "none",
        hasSubmission: payload.writingHasSubmission === true,
        hasTypedAnswer: payload.writingHasTypedAnswer === true,
        hasImages: payload.writingHasImages === true,
        imageCount: typeof payload.writingImageCount === "number" ? payload.writingImageCount : 0,
      },
    }),
    speaking: normalizeSectionShape({
      section: "speaking",
      status: speakingStatus,
      bandScore: speakingStatus === "reviewed" ? payload.speakingBand : null,
      rawScore: payload.speakingRawScore,
      reviewPending: speakingStatus === "pending_review",
      feedback: payload.sectionFeedback?.speaking,
      submission: {
        mode: "recording",
        hasSubmission: payload.speakingHasSubmission === true,
        hasRecording: payload.speakingHasRecording === true,
      },
    }),
  };

  return {
    contractVersion: "v1.manual_review.student_result_summary",
    overall,
    sections,
    objectiveCompletedSections: ["listening", "reading"],
    pendingSubjectiveSections,
    reviewedSubjectiveSections,
    unavailableSubjectiveSections,
    // Legacy compatibility paths retained.
    overallStatus: overall.status,
  };
}

export function normalizeResultSummaryFromHistory(row = {}) {
  const summary = row?.resultSummary || {};
  const sectionFeedback = row?.sectionFeedback || summary?.sectionFeedback || {};

  const writingStatus = normalizeSectionStatusFromLegacy(
    summary?.sections?.writing,
    row?.subjectiveEvaluation?.writing?.status === "reviewed"
      ? "reviewed"
      : row?.subjectiveEvaluation?.writing?.status === "pending"
        ? "pending_review"
        : hasBand(row?.writingBand)
          ? "reviewed"
          : "not_submitted"
  );

  const speakingStatus = normalizeSectionStatusFromLegacy(
    summary?.sections?.speaking,
    row?.subjectiveEvaluation?.speaking?.status === "reviewed"
      ? "reviewed"
      : row?.subjectiveEvaluation?.speaking?.status === "pending"
        ? "pending_review"
        : hasBand(row?.speakingBand)
          ? "reviewed"
          : "not_submitted"
  );

  const writingSubmission = summary?.sections?.writing?.submission || {};
  const speakingSubmission = summary?.sections?.speaking?.submission || {};

  const objectiveOverallBand =
    summary?.overall?.objectiveBandScore ??
    summary?.overall?.objectiveOverallBand ??
    row?.resultStatus?.objectiveOverallBand ??
    null;

  const finalOverallBand =
    summary?.overall?.bandScore ??
    summary?.overall?.finalOverallBand ??
    (row?.overallBandStatus === "finalized" ? row?.overallBand : null);

  return buildResultSummaryContract({
    listeningBand: row?.listeningBand,
    readingBand: row?.readingBand,
    writingBand: row?.writingBand,
    speakingBand: row?.speakingBand,
    listeningRawScore: summary?.sections?.listening?.rawScore ?? sectionFeedback?.listening?.rawScore,
    readingRawScore: summary?.sections?.reading?.rawScore ?? sectionFeedback?.reading?.rawScore,
    writingRawScore: summary?.sections?.writing?.rawScore ?? sectionFeedback?.writing?.rawScore,
    speakingRawScore: summary?.sections?.speaking?.rawScore ?? sectionFeedback?.speaking?.rawScore,
    objectiveOverallBand,
    finalOverallBand,
    writingStatus,
    speakingStatus,
    writingHasSubmission: Boolean(writingSubmission?.hasSubmission || writingStatus !== "not_submitted"),
    writingSubmissionMode: writingSubmission?.mode || (writingStatus === "not_submitted" ? "none" : "typed"),
    writingHasTypedAnswer: Boolean(writingSubmission?.hasTypedAnswer),
    writingHasImages: Boolean(writingSubmission?.hasImages),
    writingImageCount: Number(writingSubmission?.imageCount || 0),
    speakingHasSubmission: Boolean(speakingSubmission?.hasSubmission || speakingStatus !== "not_submitted"),
    speakingHasRecording: Boolean(speakingSubmission?.hasRecording || speakingStatus !== "not_submitted"),
    sectionFeedback,
  });
}
