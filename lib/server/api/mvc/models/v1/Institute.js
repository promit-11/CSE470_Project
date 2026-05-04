import mongoose from "mongoose";

const instituteSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 140 },
    description: { type: String, default: "" },
    address: { type: String, default: "" },
    contactEmail: { type: String, required: true, lowercase: true, trim: true },
    contactPhone: { type: String, default: "" },
    adminUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1User",
      required: true,
      unique: true,
    },
  },
  { timestamps: true }
);

const Institute = mongoose.model("V1Institute", instituteSchema);

export default Institute;
