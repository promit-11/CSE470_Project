import mongoose from "mongoose";
import { SECTION_ORDER, SECTION_DURATIONS_SECONDS } from "../../../constants/sections.js";
import { EXAM_OWNER_TYPES, OWNER_TYPES } from "../../../constants/ownership.js";
import mediaMetadataSchema from "./schemas/media-metadata.js";

const answerSchema = new mongoose.Schema(
  {
    questionId: { type: mongoose.Schema.Types.ObjectId, required: true },
    value: { type: mongoose.Schema.Types.Mixed, default: null },
    flagged: { type: Boolean, default: false },
  },
  { _id: false }
);

const writingSubmissionSchema = new mongoose.Schema(
  {
    mode: {
      type: String,
      enum: ["none", "typed", "images", "typed_and_images"],
      default: "none",
    },
    typedAnswer: { type: String, default: "" },
    images: { type: [mediaMetadataSchema], default: [] },
    updatedAt: { type: Date, default: null },
  },
  { _id: false }
);

const speakingSubmissionSchema = new mongoose.Schema(
  {
    recording: { type: mediaMetadataSchema, default: null },
    updatedAt: { type: Date, default: null },
  },
  { _id: false }
);

const sectionStateSchema = new mongoose.Schema(
  {
    section: { type: String, required: true },
    questionIds: { type: [mongoose.Schema.Types.ObjectId], default: [] },
    answers: { type: [answerSchema], default: [] },
    startedAt: { type: Date, default: null },
    submittedAt: { type: Date, default: null },
    durationSeconds: { type: Number, required: true },
    status: {
      type: String,
      enum: ["not_started", "in_progress", "submitted", "auto_submitted"],
      default: "not_started",
    },
    rawScore: { type: Number, default: 0 },
    bandScore: { type: Number, default: 0 },
    writingResponse: { type: String, default: "" },
    speakingResponse: { type: String, default: "" },
    writingSubmission: { type: writingSubmissionSchema, default: () => ({}) },
    speakingSubmission: { type: speakingSubmissionSchema, default: () => ({}) },
  },
  { _id: false }
);

const mockSessionSchema = new mongoose.Schema(
  {
    studentProfileId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1StudentProfile",
      required: true,
      index: true,
    },
    templateId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1MockTemplate",
      default: null,
    },
    sourceType: { type: String, enum: EXAM_OWNER_TYPES, default: OWNER_TYPES.APP, index: true },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    sectionOrder: { type: [String], default: SECTION_ORDER },
    currentSection: { type: String, default: SECTION_ORDER[0] },
    sections: {
      type: [sectionStateSchema],
      default: SECTION_ORDER.map((section) => ({
        section,
        durationSeconds: SECTION_DURATIONS_SECONDS[section],
      })),
    },
    status: {
      type: String,
      enum: ["active", "completed", "abandoned"],
      default: "active",
      index: true,
    },
    sectionBands: {
      listening: { type: Number, default: 0 },
      reading: { type: Number, default: 0 },
      writing: { type: Number, default: 0 },
      speaking: { type: Number, default: 0 },
    },
    overallBand: { type: Number, default: 0 },
    overallEstimatedBand: { type: Number, default: null },
    overallBandStatus: {
      type: String,
      enum: ["pending_full_review", "finalized"],
      default: "pending_full_review",
    },
    feedbackSummary: {
      strengths: { type: [String], default: [] },
      weaknesses: { type: [String], default: [] },
      notes: { type: String, default: "" },
    },
    resultStatus: { type: mongoose.Schema.Types.Mixed, default: {} },
    subjectiveEvaluation: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

mockSessionSchema.path("coachingId").validate(function validateCoachingId(value) {
  if (this.sourceType === OWNER_TYPES.APP) {
    return value == null;
  }
  if (this.sourceType === OWNER_TYPES.COACHING) {
    return value != null;
  }
  return false;
}, "coachingId must be null for app sourceType and set for coaching sourceType");

mockSessionSchema.index({ sourceType: 1, coachingId: 1, status: 1, createdAt: -1 });

const MockSession = mongoose.model("V1MockSession", mockSessionSchema);

export default MockSession;
