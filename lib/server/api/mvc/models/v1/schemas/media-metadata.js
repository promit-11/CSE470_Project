import mongoose from "mongoose";

const mediaMetadataSchema = new mongoose.Schema(
  {
    mediaId: { type: String, default: "" },
    fileName: { type: String, default: "" },
    mimeType: { type: String, default: "" },
    sizeBytes: { type: Number, default: 0 },
    storagePath: { type: String, default: "" },
    publicUrl: { type: String, default: "" },
    uploadedAt: { type: Date, default: null },
    pageOrder: { type: Number, default: null },
  },
  { _id: false }
);

export default mediaMetadataSchema;
