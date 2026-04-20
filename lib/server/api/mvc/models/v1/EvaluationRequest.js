import mongoose from "mongoose";
import { EXAM_OWNER_TYPES, OWNER_TYPES } from "../../../constants/ownership.js";
import {
  EVALUATION_REQUEST_STATUSES,
  EVALUATION_REQUEST_STATUS_VALUES,
  EVALUATION_SECTIONS,
} from "../../../constants/workflow-statuses.js";

const rubricSchema = new mongoose.Schema(
  {
    taskResponse: { type: Number, min: 0, max: 9, default: null },
    coherenceAndCohesion: { type: Number, min: 0, max: 9, default: null },
    lexicalResource: { type: Number, min: 0, max: 9, default: null },
    grammaticalRangeAndAccuracy: { type: Number, min: 0, max: 9, default: null },
    fluencyAndCoherence: { type: Number, min: 0, max: 9, default: null },
    pronunciation: { type: Number, min: 0, max: 9, default: null },
  },
  { _id: false }
);

const evaluationRequestSchema = new mongoose.Schema(
  {
    studentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      index: true,
    },
    teacherId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      default: null,
      index: true,
    },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    testSessionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1MockSession",
      required: true,
      index: true,
    },
    section: { type: String, enum: EVALUATION_SECTIONS, required: true, index: true },
    sourceType: {
      type: String,
      enum: EXAM_OWNER_TYPES,
      default: OWNER_TYPES.APP,
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: EVALUATION_REQUEST_STATUS_VALUES,
      default: EVALUATION_REQUEST_STATUSES.PENDING,
      index: true,
    },
    eligibleTeacherIds: {
      type: [mongoose.Schema.Types.ObjectId],
      default: [],
      index: true,
    },
    eligibleTeacherCount: { type: Number, min: 0, default: 0 },
    claimedAt: { type: Date, default: null },
    reviewedAt: { type: Date, default: null },
    expiresAt: { type: Date, default: null, index: true },

    reviewedBandScore: { type: Number, min: 0, max: 9, default: null },
    criteriaScores: { type: mongoose.Schema.Types.Mixed, default: {} },
    reviewComments: { type: String, default: "" },
    reviewStrengths: { type: [String], default: [] },
    reviewWeaknesses: { type: [String], default: [] },
    reviewSummary: { type: String, default: "" },
    reviewFeedback: { type: String, default: "" },
    correctionNotes: { type: [String], default: [] },
    recommendations: { type: [String], default: [] },
    rubric: { type: rubricSchema, default: () => ({}) },
  },
  { timestamps: true }
);

evaluationRequestSchema.path("coachingId").validate(function validateCoachingId(value) {
  if (this.sourceType === OWNER_TYPES.APP) {
    return value == null;
  }
  if (this.sourceType === OWNER_TYPES.COACHING) {
    return value != null;
  }
  return false;
}, "coachingId must be null for app sourceType and set for coaching sourceType");

evaluationRequestSchema.path("teacherId").validate(function validateTeacherAtStatus(value) {
  if (
    this.status === EVALUATION_REQUEST_STATUSES.CLAIMED ||
    this.status === EVALUATION_REQUEST_STATUSES.REVIEWED
  ) {
    return value != null;
  }
  return true;
}, "teacherId is required when request is claimed or reviewed");

evaluationRequestSchema.path("claimedAt").validate(function validateClaimedAt(value) {
  if (
    this.status === EVALUATION_REQUEST_STATUSES.CLAIMED ||
    this.status === EVALUATION_REQUEST_STATUSES.REVIEWED
  ) {
    return value instanceof Date;
  }
  return true;
}, "claimedAt is required when request is claimed or reviewed");

evaluationRequestSchema.path("reviewedAt").validate(function validateReviewedAt(value) {
  if (this.status === EVALUATION_REQUEST_STATUSES.REVIEWED) {
    return value instanceof Date;
  }
  return true;
}, "reviewedAt is required when request is reviewed");

evaluationRequestSchema.path("reviewedBandScore").validate(function validateReviewedBandScore(value) {
  if (this.status === EVALUATION_REQUEST_STATUSES.REVIEWED) {
    return typeof value === "number";
  }
  return true;
}, "reviewedBandScore is required when request is reviewed");

evaluationRequestSchema.index({ testSessionId: 1, section: 1 }, { unique: true });
evaluationRequestSchema.index({ status: 1, section: 1, sourceType: 1, coachingId: 1, createdAt: 1 });
evaluationRequestSchema.index({ teacherId: 1, status: 1, claimedAt: -1 });

const EvaluationRequest = mongoose.model("V1EvaluationRequest", evaluationRequestSchema);

export default EvaluationRequest;
