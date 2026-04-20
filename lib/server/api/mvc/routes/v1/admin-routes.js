import express from "express";
import { body, param, query } from "express-validator";
import { ROLES } from "../../../constants/roles.js";
import { allowRoles, requireAuth } from "../../../middlewares/auth.js";
import { uploadListeningAudio } from "../../../middlewares/upload.js";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { success } from "../../../utils/api-response.js";
import {
  approveTeacher,
  createCoachingByAdmin,
  createStudentByAdmin,
  createTeacherByAdmin,
  approvePayoutRequest,
    deleteCoachingByAdmin,
    deleteStudentByAdmin,
    deleteTeacherByAdmin,
  createExam,
  createQuestion,
  createTemplate,
  deleteDatabaseDocument,
  deleteExam,
  deleteQuestion,
  getAdminOverview,
  listAppEvaluationRequests,
  listCoachings,
  listDatabaseCollectionsSummary,
  listDatabaseDocuments,
  listExams,
  listPaymentTransactions,
  listPayoutRequests,
  listQuestions,
  listStudents,
  listTeachers,
  listTemplates,
  rejectPayoutRequest,
  rejectOrDeactivateTeacher,
  safeRemoveUser,
  suspendUser,
  updateExam,
  updateQuestion,
  updateTemplate,
} from "../../services/v1/admin-service.js";
import { objectIdParam } from "../../../validators/common-validator.js";

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

router.get("/db/collections", async (_req, res, next) => {
  try {
    res.json(success(await listDatabaseCollectionsSummary()));
  } catch (e) {
    next(e);
  }
});

router.get(
  "/db/:collection/documents",
  [
    param("collection").isIn(SUPPORTED_DB_COLLECTIONS),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
    query("search").optional().isString().isLength({ max: 120 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listDatabaseDocuments(req.params.collection, req.query)));
    } catch (e) {
      next(e);
    }
  }
);

router.delete(
  "/db/:collection/documents/:id",
  [param("collection").isIn(SUPPORTED_DB_COLLECTIONS), objectIdParam("id")],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await deleteDatabaseDocument(req.params.collection, req.params.id, req.user.id)));
    } catch (e) {
      next(e);
    }
  }
);

router.get("/overview", async (_req, res, next) => {
  try {
    res.json(success(await getAdminOverview()));
  } catch (e) {
    next(e);
  }
});

router.get(
  "/teachers",
  [
    query("state").optional().isIn(["pending_approval", "approved", "deactivated"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listTeachers(req.query)));
    } catch (e) {
      next(e);
    }
  }
);

router.patch("/teachers/:id/approve", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await approveTeacher(req.params.id)));
  } catch (e) {
    next(e);
  }
});

router.patch(
  "/teachers/:id/lifecycle",
  [objectIdParam(), body("action").isIn(["reject", "deactivate"]), body("reason").optional().isString()],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(
        success(await rejectOrDeactivateTeacher(req.params.id, req.body.action, req.body.reason))
      );
    } catch (e) {
      next(e);
    }
  }
);

router.get(
  "/students",
  [query("status").optional().isIn(["active", "inactive", "blocked"]), query("page").optional().isInt({ min: 1 }), query("limit").optional().isInt({ min: 1, max: 100 })],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listStudents(req.query)));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createStudentByAdmin(req.body)));
    } catch (e) {
      next(e);
    }
  }
);

router.delete("/students/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await deleteStudentByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
});

router.post(
  "/teachers",
  [
    body("name").isString().isLength({ min: 2, max: 80 }),
    body("email").isEmail(),
    body("password").isString().isLength({ min: 6, max: 128 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createTeacherByAdmin(req.body)));
    } catch (e) {
      next(e);
    }
  }
);

router.delete("/teachers/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await deleteTeacherByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
});

router.get(
  "/coachings",
  [query("page").optional().isInt({ min: 1 }), query("limit").optional().isInt({ min: 1, max: 100 })],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listCoachings(req.query)));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createCoachingByAdmin(req.body)));
    } catch (e) {
      next(e);
    }
  }
);

router.delete("/coachings/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await deleteCoachingByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
});

router.patch(
  "/users/:id/suspend",
  [objectIdParam(), body("reason").optional().isString()],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await suspendUser(req.params.id, req.body.reason)));
    } catch (e) {
      next(e);
    }
  }
);

router.patch(
  "/users/:id/safe-remove",
  [objectIdParam(), body("reason").optional().isString()],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await safeRemoveUser(req.params.id, req.body.reason)));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      res.json(success(await listAppEvaluationRequests(req.query)));
    } catch (e) {
      next(e);
    }
  }
);

router.get(
  "/payments",
  [
    query("status").optional().isIn(["pending", "succeeded", "failed", "cancelled"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listPaymentTransactions(req.query)));
    } catch (e) {
      next(e);
    }
  }
);

router.get(
  "/payouts",
  [
    query("status").optional().isIn(["pending", "approved", "rejected", "paid", "cancelled"]),
    query("page").optional().isInt({ min: 1 }),
    query("limit").optional().isInt({ min: 1, max: 100 }),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await listPayoutRequests(req.query)));
    } catch (e) {
      next(e);
    }
  }
);

router.patch(
  "/payouts/:id/approve",
  [objectIdParam(), body("note").optional().isString().isLength({ max: 500 })],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await approvePayoutRequest(req.user.id, req.params.id, req.body.note || "")));
    } catch (e) {
      next(e);
    }
  }
);

router.patch(
  "/payouts/:id/reject",
  [objectIdParam(), body("reason").optional().isString().isLength({ max: 500 })],
  validateRequest,
  async (req, res, next) => {
    try {
      res.json(success(await rejectPayoutRequest(req.user.id, req.params.id, req.body.reason || "")));
    } catch (e) {
      next(e);
    }
  }
);

router.get("/exams", async (_req, res, next) => {
  try {
    res.json(success(await listExams()));
  } catch (e) {
    next(e);
  }
});

router.post(
  "/exams",
  [
    body("title").isString().isLength({ min: 2, max: 160 }),
    body("description").optional().isString(),
    body("type").isIn(["general", "academic"]),
    body("active").optional().isBoolean(),
  ],
  validateRequest,
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createExam(req.body)));
    } catch (e) {
      next(e);
    }
  }
);

router.put("/exams/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await updateExam(req.params.id, req.body)));
  } catch (e) {
    next(e);
  }
});

router.delete("/exams/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    await deleteExam(req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
});

router.get("/questions", [query("examId").optional().isMongoId()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await listQuestions(req.query)));
  } catch (e) {
    next(e);
  }
});

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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createQuestion(req.body, req.file || null)));
    } catch (e) {
      next(e);
    }
  }
);

router.put("/questions/:id", uploadListeningAudio, [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await updateQuestion(req.params.id, req.body, req.file || null)));
  } catch (e) {
    next(e);
  }
});

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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createQuestion({ ...req.body, examId: req.params.id }, req.file || null)));
    } catch (e) {
      next(e);
    }
  }
);

router.delete("/questions/:id", [objectIdParam()], validateRequest, async (req, res, next) => {
  try {
    await deleteQuestion(req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
});

router.get("/mock-templates", [query("examId").optional().isMongoId()], validateRequest, async (req, res, next) => {
  try {
    res.json(success(await listTemplates(req.query)));
  } catch (e) {
    next(e);
  }
});

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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createTemplate(req.body)));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      res.status(201).json(success(await createTemplate({ ...req.body, examId: req.params.id })));
    } catch (e) {
      next(e);
    }
  }
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
  async (req, res, next) => {
    try {
      res.json(success(await updateTemplate(req.params.id, req.body)));
    } catch (e) {
      next(e);
    }
  }
);

export default router;
