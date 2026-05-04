import mongoose from "mongoose";
import {
  PAYMENT_TRANSACTION_STATUSES,
  PAYMENT_TRANSACTION_STATUS_VALUES,
  PAYMENT_TRANSACTION_TYPES,
  PAYMENT_TRANSACTION_TYPE_VALUES,
} from "../../../constants/workflow-statuses.js";

const paymentTransactionSchema = new mongoose.Schema(
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
      default: null,
      index: true,
    },
    testCreditsPurchased: { type: Number, min: 1, required: true },
    transactionType: {
      type: String,
      enum: PAYMENT_TRANSACTION_TYPE_VALUES,
      default: PAYMENT_TRANSACTION_TYPES.TEST_CREDIT_PURCHASE,
      index: true,
    },
    status: {
      type: String,
      enum: PAYMENT_TRANSACTION_STATUS_VALUES,
      default: PAYMENT_TRANSACTION_STATUSES.PENDING,
      index: true,
    },
    amount: { type: Number, min: 0, required: true },
    currency: {
      type: String,
      required: true,
      default: "BDT",
      uppercase: true,
      minlength: 3,
      maxlength: 3,
    },
    provider: { type: String, default: "simulated" },
    providerRef: { type: String, default: "" },
    initiatedAt: { type: Date, default: Date.now },
    completedAt: { type: Date, default: null },
    failedAt: { type: Date, default: null },
    metadata: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  { timestamps: true }
);

paymentTransactionSchema.path("completedAt").validate(function validateCompletedAt(value) {
  if (this.status === PAYMENT_TRANSACTION_STATUSES.SUCCEEDED) {
    return value instanceof Date;
  }
  return true;
}, "completedAt is required when payment succeeds");

paymentTransactionSchema.path("failedAt").validate(function validateFailedAt(value) {
  if (this.status === PAYMENT_TRANSACTION_STATUSES.FAILED) {
    return value instanceof Date;
  }
  return true;
}, "failedAt is required when payment fails");

paymentTransactionSchema.index({ studentId: 1, createdAt: -1 });
paymentTransactionSchema.index({ status: 1, createdAt: -1 });
paymentTransactionSchema.index({ providerRef: 1 }, { unique: true, sparse: true });

const PaymentTransaction = mongoose.model("V1PaymentTransaction", paymentTransactionSchema);

export default PaymentTransaction;
