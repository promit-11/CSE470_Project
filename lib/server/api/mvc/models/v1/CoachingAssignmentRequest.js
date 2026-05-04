import mongoose from "mongoose";
import {
  COACHING_ASSIGNMENT_REQUEST_STATUSES,
  COACHING_ASSIGNMENT_REQUEST_STATUS_VALUES,
} from "../../../constants/workflow-statuses.js";

const coachingAssignmentRequestSchema = new mongoose.Schema(
  {
    studentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      index: true,
    },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      required: true,
      index: true,
    },
    admissionCode: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 64,
    },
    status: {
      type: String,
      enum: COACHING_ASSIGNMENT_REQUEST_STATUS_VALUES,
      default: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
      index: true,
    },
    decidedByUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      default: null,
    },
    decisionNote: { type: String, default: "" },
    resolvedAt: { type: Date, default: null },
  },
  { timestamps: true }
);

coachingAssignmentRequestSchema.index({ studentId: 1, status: 1, createdAt: -1 });
coachingAssignmentRequestSchema.index({ coachingId: 1, status: 1, createdAt: -1 });
coachingAssignmentRequestSchema.index(
  { studentId: 1 },
  {
    unique: true,
    partialFilterExpression: {
      status: COACHING_ASSIGNMENT_REQUEST_STATUSES.PENDING,
    },
  }
);

const CoachingAssignmentRequest = mongoose.model(
  "V1CoachingAssignmentRequest",
  coachingAssignmentRequestSchema
);

export default CoachingAssignmentRequest;
