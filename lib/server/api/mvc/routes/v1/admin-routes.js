import express from "express";
import { body, param, query } from "express-validator";
import { ROLES } from "../../../constants/roles.js";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { uploadListeningAudio } from "../../../middlewares/upload.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { objectIdParam } from "../../../validators/common-validator.js";
import {
  approvePayout,
  approveTeacherAccount,
  changeTeacherLifecycle,
  createCoaching,
  createExamRecord,
  createQuestionForExam,
  createQuestionRecord,
  createDiscount,
  createStudent,
  createTeacher,
  createTemplateForExam,
  createTemplateRecord,
  deleteCoaching,
  deleteExamRecord,
  deleteQuestionRecord,
  deleteStudent,
  deleteTeacher,
  deleteTemplate,
  getAppEvaluationRequests,
  getCoachings,
  getDatabaseCollections,
  getDatabaseDocuments,
  getExams,
  getDiscountCodes,
  getOverview,
  getPayments,
  getPayoutRequests,
  getQuestions,
  getStudents,
  getTeachers,
  getTemplates,
  rejectPayout,
  removeDatabaseDocument,
  safeRemoveUserAccount,
  suspendUserAccount,
  updateExamRecord,
  updateQuestionRecord,
  updateTemplateRecord,
} from "../../controllers/v1/admin-controller.js";

const router = express.Router();

const SUPPORTED_DB_COLLECTIONS = [
  "users",
  "student_profiles",
  "teacher_profiles",
  "institutes",
  "questions",
  "exams",
  "mock_templates",
  "mock_sessions",
  "test_histories",
  "evaluation_requests",
  "payment_transactions",
  "payout_requests",
  "coaching_assignment_requests",
  "discount_codes",
  "refresh_tokens",
];

router.use(requireAuth, allowRoles(ROLES.PLATFORM_ADMIN));

router.get("/db/collections", getDatabaseCollections);

router.get(
  "/db/:collection/documents",
  [
    param("collection").isIn(SUPPORTED_DB_COLLECTIONS),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
    query("search").optional().isString().isLength({ max: 120 }),
  ],
  validateRequest,
  getDatabaseDocuments
);

router.delete(
  "/db/:collection/documents/:id",
  [param("collection").isIn(SUPPORTED_DB_COLLECTIONS), objectIdParam("id")],
  validateRequest,
  removeDatabaseDocument
);

router.get("/overview", getOverview);

router.get(
  "/teachers",
  [
    query("state").optional().isIn(["pending_approval", "approved", "deactivated"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  getTeachers
);

router.patch("/teachers/:id/approve", [objectIdParam()], validateRequest, approveTeacherAccount);

router.patch(
  "/teachers/:id/lifecycle",
  [objectIdParam(), body("action").isIn(["reject", "deactivate"]), body("reason").optional().isString()],
  validateRequest,
  changeTeacherLifecycle
);

router.get(
  "/students",
  [
    query("status").optional().isIn(["active", "inactive", "blocked"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  getStudents
);

router.post(
  "/students",
  [
    body("name").isString().isLength({ min: 2, max: 80 }),
    body("email").isEmail(),
    body("password").isString().isLength({ min: 6, max: 128 }),
    body("testCredits").optional().isInt({ min: 1, max: 1000 }),
  ],
  validateRequest,
  createStudent
);

router.delete("/students/:id", [objectIdParam()], validateRequest, deleteStudent);

router.post(
  "/teachers",
  [
    body("name").isString().isLength({ min: 2, max: 80 }),
    body("email").isEmail(),
    body("password").isString().isLength({ min: 6, max: 128 }),
  ],
  validateRequest,
  createTeacher
);

router.delete("/teachers/:id", [objectIdParam()], validateRequest, deleteTeacher);

router.get(
  "/coachings",
  [query("page").optional().isInt({ min: 1 }), query("limit").optional().isInt({ min: 1, max: 100 })],
  validateRequest,
  getCoachings
);

router.post(
  "/coachings",
  [
    body("name").isString().isLength({ min: 2, max: 80 }),
    body("email").isEmail(),
    body("password").isString().isLength({ min: 6, max: 128 }),
    body("instituteName").isString().isLength({ min: 2, max: 140 }),
    body("description").optional().isString().isLength({ max: 1000 }),
    body("address").optional().isString().isLength({ max: 1000 }),
    body("contactPhone").optional().isString().isLength({ max: 80 }),
  ],
  validateRequest,
  createCoaching
);

router.delete("/coachings/:id", [objectIdParam()], validateRequest, deleteCoaching);

router.patch(
  "/users/:id/suspend",
  [objectIdParam(), body("reason").optional().isString()],
  validateRequest,
  suspendUserAccount
);

router.patch(
  "/users/:id/safe-remove",
  [objectIdParam(), body("reason").optional().isString()],
  validateRequest,
  safeRemoveUserAccount
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

router.get(
  "/evaluation-requests/app",
  [
    query("status").optional().isIn(["pending", "claimed", "reviewed", "expired", "cancelled"]),
    query("section").optional().isIn(["writing", "speaking"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  getAppEvaluationRequests
);

router.get(
  "/payments",
  [
    query("status").optional().isIn(["pending", "succeeded", "failed", "cancelled"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  getPayments
);

router.get(
  "/payouts",
  [
    query("status").optional().isIn(["pending", "approved", "rejected", "paid", "cancelled"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  getPayoutRequests
);

router.patch(
  "/payouts/:id/approve",
  [objectIdParam(), body("note").optional().isString().isLength({ max: 500 })],
  validateRequest,
  approvePayout
);

router.patch(
  "/payouts/:id/reject",
  [objectIdParam(), body("reason").optional().isString().isLength({ max: 500 })],
  validateRequest,
  rejectPayout
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
  createExamRecord
);

router.put("/exams/:id", [objectIdParam()], validateRequest, updateExamRecord);

router.delete("/exams/:id", [objectIdParam()], validateRequest, deleteExamRecord);

router.get("/questions", [query("examId").optional().isMongoId()], validateRequest, getQuestions);

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
    body("examId").optional().isMongoId(),
  ],
  validateRequest,
  createQuestionRecord
);

router.put("/questions/:id", uploadListeningAudio, [objectIdParam()], validateRequest, updateQuestionRecord);

router.post(
  "/exams/:id/questions",
  uploadListeningAudio,
  [
    objectIdParam(),
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
  createQuestionForExam
);

router.delete("/questions/:id", [objectIdParam()], validateRequest, deleteQuestionRecord);

router.get("/mock-templates", [query("examId").optional().isMongoId()], validateRequest, getTemplates);

router.post(
  "/mock-templates",
  [
    body("name").isString().isLength({ min: 2, max: 100 }),
    body("examType").optional().isIn(["general", "academic"]),
    body("examId").optional().isMongoId(),
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
  createTemplateRecord
);

router.post(
  "/exams/:id/mock-templates",
  [
    objectIdParam(),
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
    body("active").optional().isBoolean(),
  ],
  validateRequest,
  createTemplateForExam
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
  updateTemplateRecord
);

router.delete("/mock-templates/:id", [objectIdParam()], validateRequest, deleteTemplate);

export default router;
