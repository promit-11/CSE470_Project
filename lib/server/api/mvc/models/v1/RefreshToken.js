import mongoose from "mongoose";

const refreshTokenSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "V1User", required: true, index: true },
    tokenId: { type: String, required: true, unique: true },
    expiresAt: { type: Date, required: true, index: true },
    revoked: { type: Boolean, default: false },
  },
  { timestamps: true }
);

const RefreshToken = mongoose.model("V1RefreshToken", refreshTokenSchema);

export default RefreshToken;
