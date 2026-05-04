import multer from "multer";
import env from "../config/env.js";
import { HttpError } from "../utils/http-error.js";

const WRITING_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);

const AUDIO_MIME_TYPES = new Set([
  "audio/mpeg",
  "audio/mp4",
  "audio/x-m4a",
  "audio/wav",
  "audio/x-wav",
  "audio/webm",
  "audio/ogg",
  "audio/aac",
]);

function makeUploader({ allowedMimeTypes, maxFileSizeBytes, maxFiles }) {
  return multer({
    storage: multer.memoryStorage(),
    limits: {
      fileSize: maxFileSizeBytes,
      files: maxFiles,
    },
    fileFilter: (_req, file, cb) => {
      if (!allowedMimeTypes.has(file.mimetype)) {
        return cb(
          new HttpError(422, "Unsupported media type", {
            mimeType: file.mimetype,
          })
        );
      }
      return cb(null, true);
    },
  });
}

function mapMulterError(error) {
  if (error instanceof HttpError) {
    return error;
  }

  if (error instanceof multer.MulterError) {
    if (error.code === "LIMIT_FILE_SIZE") {
      return new HttpError(413, "Uploaded file exceeds size limit");
    }
    if (error.code === "LIMIT_FILE_COUNT") {
      return new HttpError(413, "Too many files uploaded in one request");
    }
    if (error.code === "LIMIT_UNEXPECTED_FILE") {
      return new HttpError(422, "Unexpected upload field");
    }
    return new HttpError(422, error.message || "Invalid upload payload");
  }

  return error;
}

function withUploadErrorHandling(middleware) {
  return (req, res, next) => {
    middleware(req, res, (error) => {
      if (!error) {
        return next();
      }
      return next(mapMulterError(error));
    });
  };
}

const maxFilesPerRequest = Number(env.mediaMaxFilesPerRequest || 10);

const writingImageUploader = makeUploader({
  allowedMimeTypes: WRITING_IMAGE_MIME_TYPES,
  maxFileSizeBytes: Number(env.mediaMaxImageBytes),
  maxFiles: maxFilesPerRequest,
});

const speakingRecordingUploader = makeUploader({
  allowedMimeTypes: AUDIO_MIME_TYPES,
  maxFileSizeBytes: Number(env.mediaMaxAudioBytes),
  maxFiles: 1,
});

const listeningAudioUploader = makeUploader({
  allowedMimeTypes: AUDIO_MIME_TYPES,
  maxFileSizeBytes: Number(env.mediaMaxAudioBytes),
  maxFiles: 1,
});

export const uploadWritingImages = withUploadErrorHandling(
  writingImageUploader.array("writingImages", maxFilesPerRequest)
);

export const uploadSpeakingRecording = withUploadErrorHandling(
  speakingRecordingUploader.single("speakingRecording")
);

export const uploadListeningAudio = withUploadErrorHandling(
  listeningAudioUploader.single("listeningAudio")
);

export const MEDIA_VALIDATION_RULES = {
  writingImages: {
    field: "writingImages",
    acceptedMimeTypes: [...WRITING_IMAGE_MIME_TYPES],
    maxFileSizeBytes: Number(env.mediaMaxImageBytes),
    maxFiles: maxFilesPerRequest,
  },
  speakingRecording: {
    field: "speakingRecording",
    acceptedMimeTypes: [...AUDIO_MIME_TYPES],
    maxFileSizeBytes: Number(env.mediaMaxAudioBytes),
    maxFiles: 1,
  },
  listeningAudio: {
    field: "listeningAudio",
    acceptedMimeTypes: [...AUDIO_MIME_TYPES],
    maxFileSizeBytes: Number(env.mediaMaxAudioBytes),
    maxFiles: 1,
  },
};
