import express from "express";
import { body } from "express-validator";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { ROLES } from "../../../constants/roles.js";
import { success } from "../../../utils/api-response.js";
import { objectIdParam } from "../../../validators/common-validator.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import {
  claimEvaluationRequest,
  getMyEvaluationRequestDetails,
  listMyClaimedRequests,
  listMyPayoutRequests,
  listMyReviewedRequests,
  listPendingEligibleRequests,
  getMyTeacherProfile,
  requestPayout,
  submitEvaluationReview,
} from "../../services/v1/teacher-service.js";

const router = express.Router();

router.use(requireAuth, allowRoles(ROLES.TEACHER));

router.get("/evaluation-requests/pending", async (req, res, next) => {
  try {
    const data = await listPendingEligibleRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
});

router.patch(
  "/evaluation-requests/:id/claim",
  [objectIdParam()],
  validateRequest,
  async (req, res, next) => {
    try {
      const data = await claimEvaluationRequest(req.user.id, req.params.id);
      res.json(success(data));
    } catch (e) {
      next(e);
    }
  }
);

router.get("/evaluation-requests/claimed", async (req, res, next) => {
  try {
    const data = await listMyClaimedRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
});

router.get("/evaluation-requests/reviewed", async (req, res, next) => {
  try {
    const data = await listMyReviewedRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
});

router.get("/profile", async (req, res, next) => {
  try {
    const data = await getMyTeacherProfile(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
});

router.get(
  "/evaluation-requests/:id",
  [objectIdParam()],
  validateRequest,
  async (req, res, next) => {
    try {
      const data = await getMyEvaluationRequestDetails(req.user.id, req.params.id);
      res.json(success(data));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      const data = await submitEvaluationReview(req.user.id, req.params.id, req.body);
      res.json(success(data));
    } catch (e) {
      next(e);
    }
  }
);

router.post(
  "/payouts/request",
  [
    body("requestedRewardCredits").isFloat({ min: 1 }),
    body("note").optional().isString().isLength({ max: 500 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      const data = await requestPayout(req.user.id, req.body);
      res.status(201).json(success(data));
    } catch (e) {
      next(e);
    }
  }
);

router.get("/payouts", async (req, res, next) => {
  try {
    const data = await listMyPayoutRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
});

export default router;
