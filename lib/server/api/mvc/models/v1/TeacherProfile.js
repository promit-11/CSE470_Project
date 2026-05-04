import mongoose from "mongoose";

const teacherProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      unique: true,
      index: true,
    },
    coachingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      default: null,
      index: true,
    },
    rewardCredits: { type: Number, min: 0, default: 0 },
    bio: { type: String, default: "" },
    expertiseTags: { type: [String], default: [] },
  },
  { timestamps: true }
);

teacherProfileSchema.index({ coachingId: 1, createdAt: -1 });

const TeacherProfile = mongoose.model("V1TeacherProfile", teacherProfileSchema);

export default TeacherProfile;
