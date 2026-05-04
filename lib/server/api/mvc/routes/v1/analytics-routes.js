import express from "express";
import { ROLES } from "../../../constants/roles.js";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { getOverview } from "../../controllers/v1/analytics-controller.js";

const router = express.Router();

router.get(
  "/admin/overview",
  requireAuth,
  allowRoles(ROLES.PLATFORM_ADMIN),
  getOverview
);

export default router;
