import mongoose from "mongoose";

const testHistorySchema = new mongoose.Schema(
  {
    studentProfileId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1StudentProfile",
      required: true,
      index: true,
    },
    mockSessionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1MockSession",
      required: true,
      unique: true,
    },
    listeningBand: { type: Number, default: 0 },
    readingBand: { type: Number, default: 0 },
    writingBand: { type: Number, default: 0 },
    speakingBand: { type: Number, default: 0 },
    overallBand: { type: Number, default: 0 },
    overallEstimatedBand: { type: Number, default: null },
    overallBandStatus: {
      type: String,
      enum: ["pending_full_review", "finalized"],
      default: "pending_full_review",
    },
    strengths: { type: [String], default: [] },
    weaknesses: { type: [String], default: [] },
    feedbackNotes: { type: String, default: "" },
    sectionFeedback: { type: mongoose.Schema.Types.Mixed, default: {} },
    resultSummary: { type: mongoose.Schema.Types.Mixed, default: {} },
    resultStatus: { type: mongoose.Schema.Types.Mixed, default: {} },
    subjectiveEvaluation: { type: mongoose.Schema.Types.Mixed, default: {} },
    completedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const TestHistory = mongoose.model("V1TestHistory", testHistorySchema);

export default TestHistory;
