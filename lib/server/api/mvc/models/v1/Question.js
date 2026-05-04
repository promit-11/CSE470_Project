import mongoose from "mongoose";
import { SECTIONS } from "../../../constants/sections.js";
import { EXAM_OWNER_TYPES, OWNER_TYPES } from "../../../constants/ownership.js";
import mediaMetadataSchema from "./schemas/media-metadata.js";

const optionSchema = new mongoose.Schema(
  {
    key: { type: String, required: true },
    text: { type: String, required: true },
  },
  { _id: false }
);

const questionSchema = new mongoose.Schema(
  {
    section: {
      type: String,
      enum: Object.values(SECTIONS),
      required: true,
      index: true,
    },
    category: { type: String, required: true, trim: true },
    difficulty: { type: String, enum: ["easy", "medium", "hard"], required: true },
    questionType: { type: String, required: true },
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
    title: { type: String, required: true },
    content: { type: String, required: true },
    options: { type: [optionSchema], default: [] },
    answerKey: { type: [String], default: [] },
    explanation: { type: String, default: "" },
    tags: { type: [String], default: [] },
    source: { type: String, default: "" },
    instruction: { type: String, default: "" },
    mediaUrl: { type: String, default: "" },
    listeningAudio: { type: mediaMetadataSchema, default: null },
    active: { type: Boolean, default: true },
  },
  { timestamps: true }
);

questionSchema.path("ownerId").validate(function validateOwnerId(value) {
  if (this.ownerType === OWNER_TYPES.APP) {
    return value == null;
  }
  if (this.ownerType === OWNER_TYPES.COACHING) {
    return value != null;
  }
  return false;
}, "ownerId must be null for app ownerType and set for coaching ownerType");

questionSchema.index({ section: 1, difficulty: 1, category: 1 });
questionSchema.index({ ownerType: 1, ownerId: 1, section: 1, active: 1 });
questionSchema.index({ examId: 1, section: 1, active: 1 });

const Question = mongoose.model("V1Question", questionSchema);

export default Question;
