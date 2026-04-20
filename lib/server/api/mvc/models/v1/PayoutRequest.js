import mongoose from "mongoose";
import {
  PAYOUT_REQUEST_STATUSES,
  PAYOUT_REQUEST_STATUS_VALUES,
} from "../../../constants/workflow-statuses.js";

const payoutRequestSchema = new mongoose.Schema(
  {
    teacherId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      index: true,
    },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    requestedRewardCredits: {
      type: Number,
      min: 1,
      required: true,
    },
    conversionRate: { type: Number, min: 0, default: 1 },
    payoutAmount: { type: Number, min: 0, default: 0 },
    currency: {
      type: String,
      required: true,
      default: "BDT",
      uppercase: true,
      minlength: 3,
      maxlength: 3,
    },
    status: {
      type: String,
      enum: PAYOUT_REQUEST_STATUS_VALUES,
      default: PAYOUT_REQUEST_STATUSES.PENDING,
      index: true,
    },
    note: { type: String, default: "" },
    processedByUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      default: null,
    },
    processedAt: { type: Date, default: null },
    paidAt: { type: Date, default: null },
    provider: { type: String, default: "simulated" },
    providerRef: { type: String, default: "" },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

payoutRequestSchema.path("processedByUserId").validate(function validateProcessedBy(value) {
  if (
    this.status === PAYOUT_REQUEST_STATUSES.APPROVED ||
    this.status === PAYOUT_REQUEST_STATUSES.REJECTED ||
    this.status === PAYOUT_REQUEST_STATUSES.PAID
  ) {
    return value != null;
  }
  return true;
}, "processedByUserId is required once payout request is processed");

payoutRequestSchema.path("processedAt").validate(function validateProcessedAt(value) {
  if (
    this.status === PAYOUT_REQUEST_STATUSES.APPROVED ||
    this.status === PAYOUT_REQUEST_STATUSES.REJECTED ||
    this.status === PAYOUT_REQUEST_STATUSES.PAID
  ) {
    return value instanceof Date;
  }
  return true;
}, "processedAt is required once payout request is processed");

payoutRequestSchema.path("paidAt").validate(function validatePaidAt(value) {
  if (this.status === PAYOUT_REQUEST_STATUSES.PAID) {
    return value instanceof Date;
  }
  return true;
}, "paidAt is required when payout request is paid");

payoutRequestSchema.index({ teacherId: 1, status: 1, createdAt: -1 });
payoutRequestSchema.index({ status: 1, createdAt: -1 });
payoutRequestSchema.index({ providerRef: 1 }, { unique: true, sparse: true });
payoutRequestSchema.index(
  { teacherId: 1 },
  {
    unique: true,
    partialFilterExpression: {
      status: PAYOUT_REQUEST_STATUSES.PENDING,
    },
  }
);

const PayoutRequest = mongoose.model("V1PayoutRequest", payoutRequestSchema);

export default PayoutRequest;
