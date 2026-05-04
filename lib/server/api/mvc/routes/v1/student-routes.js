import express from "express";
import { body } from "express-validator";
import { requireAuth, allowRoles } from "../../../middlewares/auth.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { ROLES } from "../../../constants/roles.js";
import {
  getAnalytics,
  getCoachingForm,
  getHistory,
  getPayments,
  getProfile,
  listCreditPackages,
  purchaseCredits,
  purchaseMockCredits,
  requestCoachingAssignment,
  updateProfile,
} from "../../controllers/v1/student-controller.js";

const router = express.Router();

router.use(requireAuth, allowRoles(ROLES.STUDENT));

router.get("/profile", getProfile);

router.put(
  "/profile",
  [
    body("targetBand").optional().isFloat({ min: 0, max: 9 }),
    body("strengths").optional().isArray(),
    body("weaknesses").optional().isArray(),
  ],
  validateRequest,
  updateProfile
);

router.get("/history", getHistory);

router.get("/analytics", getAnalytics);

router.get("/coaching-assignment/form", getCoachingForm);

router.post(
  "/coaching-assignment/request",
  [body("coachingId").isMongoId(), body("admissionCode").trim().isLength({ min: 2, max: 64 })],
  validateRequest,
  requestCoachingAssignment
);

router.post(
  "/credits/purchase",
  [body("packageId").isString().isLength({ min: 2, max: 64 })],
  validateRequest,
  purchaseCredits
);

router.get("/credits/packages", listCreditPackages);

router.get("/payments", getPayments);

router.post(
  "/purchase-mock-access",
  [body("packSize").optional().isInt({ min: 1, max: 50 })],
  validateRequest,
  purchaseMockCredits
);

export default router;
