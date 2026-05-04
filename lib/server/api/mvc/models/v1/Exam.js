import mongoose from "mongoose";
import { EXAM_OWNER_TYPES, OWNER_TYPES } from "../../../constants/ownership.js";

const examSchema = new mongoose.Schema(
  {
    title: { type: String, required: true },
    description: { type: String, default: "" },
    type: { type: String, enum: ["general", "academic"], required: true },
    ownerType: { type: String, enum: EXAM_OWNER_TYPES, default: OWNER_TYPES.APP, index: true },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    active: { type: Boolean, default: true },
    scheduledAt: { type: Date, default: null },
  },
  { timestamps: true }
);

examSchema.path("ownerId").validate(function validateOwnerId(value) {
  if (this.ownerType === OWNER_TYPES.APP) {
    return value == null;
  }
  if (this.ownerType === OWNER_TYPES.COACHING) {
    return value != null;
  }
  return false;
}, "ownerId must be null for app ownerType and set for coaching ownerType");

examSchema.index({ ownerType: 1, ownerId: 1, active: 1 });

const Exam = mongoose.model("V1Exam", examSchema);

export default Exam;
