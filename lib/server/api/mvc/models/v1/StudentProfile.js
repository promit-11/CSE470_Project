import mongoose from "mongoose";

const studentProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      unique: true,
    },
    instituteId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
    },
    verifiedByInstitute: { type: Boolean, default: false },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    assignmentStatus: {
      type: String,
      enum: ["independent", "assigned"],
      default: "independent",
      index: true,
    },
    studentMode: {
      type: String,
      enum: ["independent", "coaching_assigned"],
      default: "independent",
      index: true,
    },
    pendingAssignmentRequestId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1CoachingAssignmentRequest",
      default: null,
    },
    testCredits: { type: Number, min: 0, default: 20 },
    targetBand: { type: Number, min: 0, max: 9, default: 6.5 },
    strengths: { type: [String], default: [] },
    weaknesses: { type: [String], default: [] },
    mockAccess: {
      allowed: { type: Boolean, default: true },
      plan: { type: String, default: "standard" },
      remainingCredits: { type: Number, default: -1 },
      lastPurchasedAt: { type: Date, default: null },
    },
  },
  { timestamps: true }
);

studentProfileSchema.path("assignmentStatus").validate(function validateAssignmentStatus(value) {
  if (this.coachingId) {
    return value === "assigned";
  }
  return value === "independent";
}, "assignmentStatus must match coachingId state");

studentProfileSchema.path("studentMode").validate(function validateStudentMode(value) {
  if (this.coachingId) {
    return value === "coaching_assigned";
  }
  return value === "independent";
}, "studentMode must match coachingId state");

studentProfileSchema.index({ coachingId: 1, assignmentStatus: 1 });
studentProfileSchema.index({ coachingId: 1, studentMode: 1 });

const StudentProfile = mongoose.model("V1StudentProfile", studentProfileSchema);

export default StudentProfile;
