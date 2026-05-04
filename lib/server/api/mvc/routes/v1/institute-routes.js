import express from "express";
import { body, query } from "express-validator";
import { ROLES } from "../../../constants/roles.js";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { uploadListeningAudio } from "../../../middlewares/upload.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { objectIdParam } from "../../../validators/common-validator.js";
import {
  acceptRequest,
  assignTeacher,
  createDiscount,
  createExam,
  createQuestion,
  createTemplate,
  deleteExam,
  deleteQuestion,
  deleteTemplate,
  getAssignmentRequests,
  getAvailableTeachers,
  getDiscountCodes,
  getEvaluationRequests,
  getExams,
  getProfile,
  getQuestions,
  getStudents,
  getTeachers,
  getTemplates,
  removeStudent,
  removeTeacher,
  rejectRequest,
  updateExam,
  updateProfile,
  updateQuestion,
  updateTemplate,
  verifyStudentAccount,
} from "../../controllers/v1/institute-controller.js";

const router = express.Router();

router.use(requireAuth, allowRoles(ROLES.COACHING_ADMIN));

router.get("/profile", getProfile);

router.put(
  "/profile",
  [
    body("name").optional().isString().isLength({ min: 2, max: 140 }),
    body("description").optional().isString(),
    body("address").optional().isString(),
    body("contactPhone").optional().isString().isLength({ min: 7, max: 20 }),
  ],
  validateRequest,
  updateProfile
);

router.post(
  "/students/verify",
  [body("email").trim().isEmail().normalizeEmail()],
  validateRequest,
  verifyStudentAccount
);

router.get("/students", getStudents);

router.patch(
  "/students/:studentId/remove",
  [objectIdParam("studentId")],
  validateRequest,
  removeStudent
);

router.get("/teachers", getTeachers);

router.get("/teachers/available", getAvailableTeachers);

router.get(
  "/evaluation-requests",
  [
    query("status").optional().isIn(["pending", "claimed", "reviewed", "expired", "cancelled"]),
    query("section").optional().isIn(["writing", "speaking"]),
  ],
  validateRequest,
  getEvaluationRequests
);

router.get("/exams", getExams);

router.post(
  "/exams",
  [
    body("title").isString().isLength({ min: 2, max: 160 }),
    body("description").optional().isString(),
    body("type").isIn(["general", "academic"]),
    body("active").optional().isBoolean(),
  ],
  validateRequest,
  createExam
);

router.put(
  "/exams/:id",
  [objectIdParam(), body("title").optional().isString().isLength({ min: 2, max: 160 }), body("description").optional().isString(), body("type").optional().isIn(["general", "academic"]), body("active").optional().isBoolean()],
  validateRequest,
  updateExam
);

router.delete("/exams/:id", [objectIdParam()], validateRequest, deleteExam);

router.get("/questions", getQuestions);

router.post(
  "/questions",
  uploadListeningAudio,
  [
    body("section").isIn(["listening", "reading", "writing", "speaking"]),
    body("category").isString(),
    body("difficulty").isIn(["easy", "medium", "hard"]),
    body("questionType").isString(),
    body("title").isString(),
    body("content").isString(),
    body("options").optional().isArray(),
    body("answerKey").optional().isArray(),
    body("mediaUrl").optional().isString().isLength({ min: 1, max: 1000 }),
  ],
  validateRequest,
  createQuestion
);

router.put(
  "/questions/:id",
  uploadListeningAudio,
  [
    objectIdParam(),
    body("section").optional().isIn(["listening", "reading", "writing", "speaking"]),
    body("category").optional().isString(),
    body("difficulty").optional().isIn(["easy", "medium", "hard"]),
    body("questionType").optional().isString(),
    body("title").optional().isString(),
    body("content").optional().isString(),
    body("options").optional().isArray(),
    body("answerKey").optional().isArray(),
    body("mediaUrl").optional().isString().isLength({ min: 1, max: 1000 }),
  ],
  validateRequest,
  updateQuestion
);

router.delete("/questions/:id", [objectIdParam()], validateRequest, deleteQuestion);

router.get("/mock-templates", getTemplates);

router.post(
  "/mock-templates",
  [
    body("name").isString().isLength({ min: 2, max: 100 }),
    body("examType").optional().isIn(["general", "academic"]),
    body("sectionOrder").optional().isArray(),
    body("sectionOrder.*").optional().isIn(["listening", "reading", "writing", "speaking"]),
    body("difficultyDistribution").optional().custom((value) => {
      if (typeof value !== "object" || value === null) return true;
      const [easy, medium, hard] = [value.easy, value.medium, value.hard].map(Number);
      if (!Number.isFinite(easy) || !Number.isFinite(medium) || !Number.isFinite(hard)) {
        throw new Error("difficultyDistribution values must be numbers");
      }
      if (easy < 0 || medium < 0 || hard < 0) {
        throw new Error("difficultyDistribution values must be non-negative");
      }
      return true;
    }),
    body("sectionQuestionCount").optional().custom((value) => {
      if (typeof value !== "object" || value === null) return true;
      const sections = ["listening", "reading", "writing", "speaking"];
      for (const section of sections) {
        const count = Number(value[section]);
        if (Number.isFinite(count) && count < 0) {
          throw new Error(`sectionQuestionCount.${section} must be non-negative`);
        }
      }
      return true;
    }),
  ],
  validateRequest,
  createTemplate
);

router.put(
  "/mock-templates/:id",
  [
    objectIdParam(),
    body("name").optional().isString().isLength({ min: 2, max: 100 }),
    body("examType").optional().isIn(["general", "academic"]),
    body("sectionOrder").optional().isArray(),
    body("sectionOrder.*").optional().isIn(["listening", "reading", "writing", "speaking"]),
    body("difficultyDistribution").optional().custom((value) => {
      if (typeof value !== "object" || value === null) return true;
      const [easy, medium, hard] = [value.easy, value.medium, value.hard].map(Number);
      if (!Number.isFinite(easy) || !Number.isFinite(medium) || !Number.isFinite(hard)) {
        throw new Error("difficultyDistribution values must be numbers");
      }
      if (easy < 0 || medium < 0 || hard < 0) {
        throw new Error("difficultyDistribution values must be non-negative");
      }
      return true;
    }),
    body("sectionQuestionCount").optional().custom((value) => {
      if (typeof value !== "object" || value === null) return true;
      const sections = ["listening", "reading", "writing", "speaking"];
      for (const section of sections) {
        const count = Number(value[section]);
        if (Number.isFinite(count) && count < 0) {
          throw new Error(`sectionQuestionCount.${section} must be non-negative`);
        }
      }
      return true;
    }),
    body("active").optional().isBoolean(),
  ],
  validateRequest,
  updateTemplate
);

router.delete("/mock-templates/:id", [objectIdParam()], validateRequest, deleteTemplate);

router.patch(
  "/teachers/:teacherId/assign",
  [objectIdParam("teacherId")],
  validateRequest,
  assignTeacher
);

router.patch(
  "/teachers/:teacherId/remove",
  [objectIdParam("teacherId")],
  validateRequest,
  removeTeacher
);

router.get(
  "/assignment-requests",
  [query("status").optional().isIn(["pending", "accepted", "rejected", "cancelled"])],
  validateRequest,
  getAssignmentRequests
);

router.patch(
  "/assignment-requests/:id/accept",
  [objectIdParam(), body("note").optional().isString()],
  validateRequest,
  acceptRequest
);

router.patch(
  "/assignment-requests/:id/reject",
  [objectIdParam(), body("note").optional().isString()],
  validateRequest,
  rejectRequest
);

router.get("/discount-codes", getDiscountCodes);

router.post(
  "/discount-codes",
  [
    body("code").trim().isString().isLength({ min: 4, max: 24 }),
    body("discountType").isIn(["percentage", "fixed"]),
    body("discountValue")
      .isFloat({ gt: 0 })
      .custom((value, { req }) => {
        if (req.body.discountType === "percentage" && Number(value) > 100) {
          throw new Error("Percentage discount cannot exceed 100");
        }
        return true;
      }),
    body("validFrom").isISO8601(),
    body("validTo")
      .isISO8601()
      .custom((value, { req }) => {
        const from = new Date(req.body.validFrom);
        const to = new Date(value);
        if (Number.isNaN(from.getTime()) || Number.isNaN(to.getTime()) || to <= from) {
          throw new Error("validTo must be later than validFrom");
        }
        return true;
      }),
    body("usageLimit").isInt({ min: 1 }),
    body("minMocks").optional().isInt({ min: 0 }),
    body("eligibleStudentIds").optional().isArray(),
    body("eligibleStudentIds.*").optional().isMongoId(),
  ],
  validateRequest,
  createDiscount
);

export default router;
