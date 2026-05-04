import mongoose from "mongoose";
import { SECTION_ORDER } from "../../../constants/sections.js";
import { EXAM_OWNER_TYPES, OWNER_TYPES } from "../../../constants/ownership.js";

const mockTemplateSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    examType: { type: String, enum: ["general", "academic"], default: "academic" },
    ownerType: { type: String, enum: EXAM_OWNER_TYPES, default: OWNER_TYPES.APP, index: true },
    ownerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    examId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Exam",
      default: null,
      index: true,
    },
    sectionOrder: { type: [String], default: SECTION_ORDER },
    difficultyDistribution: {
      type: Map,
      of: Number,
      default: {
        easy: 0.3,
        medium: 0.4,
        hard: 0.3,
      },
    },
    sectionQuestionCount: {
      type: Map,
      of: Number,
      default: {
        listening: 40,
        reading: 40,
        writing: 2,
        speaking: 3,
      },
    },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

mockTemplateSchema.path("ownerId").validate(function validateOwnerId(value) {
  if (this.ownerType === OWNER_TYPES.APP) {
    return value == null;
  }
  if (this.ownerType === OWNER_TYPES.COACHING) {
    return value != null;
  }
  return false;
}, "ownerId must be null for app ownerType and set for coaching ownerType");

mockTemplateSchema.index({ ownerType: 1, ownerId: 1, active: 1 });
mockTemplateSchema.index({ examId: 1, active: 1 });

const MockTemplate = mongoose.model("V1MockTemplate", mockTemplateSchema);

export default MockTemplate;
