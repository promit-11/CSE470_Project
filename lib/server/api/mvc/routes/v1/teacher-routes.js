import express from "express";
import { body } from "express-validator";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { ROLES } from "../../../constants/roles.js";
import { objectIdParam } from "../../../validators/common-validator.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import {
  claimRequest,
  createPayoutRequest,
  getClaimedRequests,
  getPendingRequests,
  getPayoutRequests,
  getProfile,
  getRequestDetails,
  getReviewedRequests,
  reviewRequest,
} from "../../controllers/v1/teacher-controller.js";

const router = express.Router();

router.use(requireAuth, allowRoles(ROLES.TEACHER));

router.get("/evaluation-requests/pending", getPendingRequests);

router.patch(
  "/evaluation-requests/:id/claim",
  [objectIdParam()],
  validateRequest,
  claimRequest
);

router.get("/evaluation-requests/claimed", getClaimedRequests);

router.get("/evaluation-requests/reviewed", getReviewedRequests);

router.get("/profile", getProfile);

router.get(
  "/evaluation-requests/:id",
  [objectIdParam()],
  validateRequest,
  getRequestDetails
);

router.post(
  "/evaluation-requests/:id/review",
  [
    objectIdParam(),
    body("overallBand").isFloat({ min: 0, max: 9 }),
    body("comments").optional().isString(),
    body("strengths").isArray(),
    body("weaknesses").isArray(),
    body("criterionScores").isObject(),
  ],
  validateRequest,
  reviewRequest
);

router.post(
  "/payouts/request",
  [
    body("requestedRewardCredits").isFloat({ min: 1 }),
    body("note").optional().isString().isLength({ max: 500 }),
  ],
  validateRequest,
  createPayoutRequest
);

router.get("/payouts", getPayoutRequests);

export default router;
