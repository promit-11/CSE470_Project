import express from "express";
import authRoutes from "./auth-routes.js";
import studentRoutes from "./student-routes.js";
import teacherRoutes from "./teacher-routes.js";
import instituteRoutes from "./institute-routes.js";
import adminRoutes from "./admin-routes.js";
import mockRoutes from "./mock-routes.js";
import analyticsRoutes from "./analytics-routes.js";

const router = express.Router();

router.use("/auth", authRoutes);
router.use("/students", studentRoutes);
router.use("/teachers", teacherRoutes);
router.use("/institutes", instituteRoutes);
router.use("/admin", adminRoutes);
router.use("/mock-sessions", mockRoutes);
router.use("/analytics", analyticsRoutes);

export default router;
