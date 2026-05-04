import express from "express";
import { body, param } from "express-validator";
import { ROLES } from "../../../constants/roles.js";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import {
  uploadSpeakingRecording,
  uploadWritingImages,
} from "../../../middlewares/upload.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { objectIdParam } from "../../../validators/common-validator.js";
import {
  addSpeakingRecording,
  addWritingImages,
  answerQuestion,
  flagQuestion,
  generateSession,
  getSession,
  removeWritingImage,
  reorderImages,
  submitCurrentSection,
  submitFinal,
  updateWritingTypedResponse,
} from "../../controllers/v1/mock-controller.js";

const router = express.Router();

router.use(requireAuth, allowRoles(ROLES.STUDENT));

router.post(
  "/generate",
  [body("templateId").optional().isMongoId(), body("sourceType").optional().isIn(["app", "coaching"])],
  validateRequest,
  generateSession
);

router.get("/:id", [objectIdParam()], validateRequest, getSession);

router.post(
  "/:id/answer",
  [
    objectIdParam(),
    body("section").isIn(["listening", "reading", "writing", "speaking"]),
    body("questionId").isMongoId(),
  ],
  validateRequest,
  answerQuestion
);

router.patch(
  "/:id/writing/typed-response",
  [objectIdParam(), body("typedAnswer").optional().isString()],
  validateRequest,
  updateWritingTypedResponse
);

router.post(
  "/:id/writing/images",
  [objectIdParam()],
  uploadWritingImages,
  validateRequest,
  addWritingImages
);

router.delete(
  "/:id/writing/images/:mediaId",
  [objectIdParam(), param("mediaId").isString().isLength({ min: 8, max: 128 })],
  validateRequest,
  removeWritingImage
);

router.patch(
  "/:id/writing/images/reorder",
  [objectIdParam(), body("orderedMediaIds").isArray(), body("orderedMediaIds.*").isString()],
  validateRequest,
  reorderImages
);

router.post(
  "/:id/speaking/recording",
  [objectIdParam()],
  uploadSpeakingRecording,
  validateRequest,
  addSpeakingRecording
);

router.post(
  "/:id/mark",
  [
    objectIdParam(),
    body("section").isIn(["listening", "reading", "writing", "speaking"]),
    body("questionId").isMongoId(),
    body("flagged").isBoolean(),
  ],
  validateRequest,
  flagQuestion
);

router.post(
  "/:id/submit-section",
  [
    objectIdParam(),
    body("section").isIn(["listening", "reading", "writing", "speaking"]),
    body("autoSubmitted").optional().isBoolean(),
  ],
  validateRequest,
  submitCurrentSection
);

router.post("/:id/final-submit", [objectIdParam()], validateRequest, submitFinal);

export default router;
