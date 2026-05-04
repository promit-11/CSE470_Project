import mongoose from "mongoose";

const discountCodeSchema = new mongoose.Schema(
  {
    instituteId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "V1Institute",
      required: true,
      index: true,
    },
    code: { type: String, required: true, uppercase: true, trim: true },
    discountType: { type: String, enum: ["percentage", "fixed"], default: "percentage" },
    discountValue: { type: Number, required: true, min: 1 },
    validFrom: { type: Date, required: true },
    validTo: { type: Date, required: true },
    usageLimit: { type: Number, min: 1, default: 100 },
    usedCount: { type: Number, min: 0, default: 0 },
    active: { type: Boolean, default: true },
    minMocks: { type: Number, min: 0, default: 0 },
    eligibleStudentIds: {
      type: [mongoose.Schema.Types.ObjectId],
      ref: "V1StudentProfile",
      default: [],
    },
  },
  { timestamps: true }
);

discountCodeSchema.index({ instituteId: 1, code: 1 }, { unique: true });

const DiscountCode = mongoose.model("V1DiscountCode", discountCodeSchema);

export default DiscountCode;
