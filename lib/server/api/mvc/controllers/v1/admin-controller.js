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
  createDiscountCode,
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
  listDiscountCodes,
  rejectPayoutRequest,
  rejectOrDeactivateTeacher,
  safeRemoveUser,
  suspendUser,
  updateExam,
  updateQuestion,
  updateTemplate,
  deleteTemplate as deleteTemplateService,
} from "../../services/v1/admin-service.js";

export async function getDatabaseCollections(req, res, next) {
  try {
    res.json(success(await listDatabaseCollectionsSummary()));
  } catch (e) {
    next(e);
  }
}

export async function getDatabaseDocuments(req, res, next) {
  try {
    res.json(success(await listDatabaseDocuments(req.params.collection, req.query)));
  } catch (e) {
    next(e);
  }
}

export async function removeDatabaseDocument(req, res, next) {
  try {
    res.json(success(await deleteDatabaseDocument(req.params.collection, req.params.id, req.user.id)));
  } catch (e) {
    next(e);
  }
}

export async function getOverview(req, res, next) {
  try {
    res.json(success(await getAdminOverview()));
  } catch (e) {
    next(e);
  }
}

export async function getTeachers(req, res, next) {
  try {
    res.json(success(await listTeachers(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function approveTeacherAccount(req, res, next) {
  try {
    res.json(success(await approveTeacher(req.params.id)));
  } catch (e) {
    next(e);
  }
}

export async function changeTeacherLifecycle(req, res, next) {
  try {
    res.json(success(await rejectOrDeactivateTeacher(req.params.id, req.body.action, req.body.reason)));
  } catch (e) {
    next(e);
  }
}

export async function getStudents(req, res, next) {
  try {
    res.json(success(await listStudents(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function createStudent(req, res, next) {
  try {
    res.status(201).json(success(await createStudentByAdmin(req.body)));
  } catch (e) {
    next(e);
  }
}

export async function deleteStudent(req, res, next) {
  try {
    res.json(success(await deleteStudentByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
}

export async function createTeacher(req, res, next) {
  try {
    res.status(201).json(success(await createTeacherByAdmin(req.body)));
  } catch (e) {
    next(e);
  }
}

export async function deleteTeacher(req, res, next) {
  try {
    res.json(success(await deleteTeacherByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
}

export async function getCoachings(req, res, next) {
  try {
    res.json(success(await listCoachings(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function createCoaching(req, res, next) {
  try {
    res.status(201).json(success(await createCoachingByAdmin(req.body)));
  } catch (e) {
    next(e);
  }
}

export async function deleteCoaching(req, res, next) {
  try {
    res.json(success(await deleteCoachingByAdmin(req.params.id)));
  } catch (e) {
    next(e);
  }
}

export async function suspendUserAccount(req, res, next) {
  try {
    res.json(success(await suspendUser(req.params.id, req.body.reason)));
  } catch (e) {
    next(e);
  }
}

export async function safeRemoveUserAccount(req, res, next) {
  try {
    res.json(success(await safeRemoveUser(req.params.id, req.body.reason)));
  } catch (e) {
    next(e);
  }
}

export async function getAppEvaluationRequests(req, res, next) {
  try {
    res.json(success(await listAppEvaluationRequests(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function getPayments(req, res, next) {
  try {
    res.json(success(await listPaymentTransactions(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function getPayoutRequests(req, res, next) {
  try {
    res.json(success(await listPayoutRequests(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function approvePayout(req, res, next) {
  try {
    res.json(success(await approvePayoutRequest(req.user.id, req.params.id, req.body.note || "")));
  } catch (e) {
    next(e);
  }
}

export async function rejectPayout(req, res, next) {
  try {
    res.json(success(await rejectPayoutRequest(req.user.id, req.params.id, req.body.reason || "")));
  } catch (e) {
    next(e);
  }
}

export async function getExams(req, res, next) {
  try {
    res.json(success(await listExams()));
  } catch (e) {
    next(e);
  }
}

export async function createExamRecord(req, res, next) {
  try {
    res.status(201).json(success(await createExam(req.body)));
  } catch (e) {
    next(e);
  }
}

export async function updateExamRecord(req, res, next) {
  try {
    res.json(success(await updateExam(req.params.id, req.body)));
  } catch (e) {
    next(e);
  }
}

export async function deleteExamRecord(req, res, next) {
  try {
    await deleteExam(req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}

export async function getQuestions(req, res, next) {
  try {
    res.json(success(await listQuestions(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function createQuestionRecord(req, res, next) {
  try {
    res.status(201).json(success(await createQuestion(req.body, req.file || null)));
  } catch (e) {
    next(e);
  }
}

export async function createQuestionForExam(req, res, next) {
  try {
    res.status(201).json(success(await createQuestion({ ...req.body, examId: req.params.id }, req.file || null)));
  } catch (e) {
    next(e);
  }
}

export async function updateQuestionRecord(req, res, next) {
  try {
    res.json(success(await updateQuestion(req.params.id, req.body, req.file || null)));
  } catch (e) {
    next(e);
  }
}

export async function deleteQuestionRecord(req, res, next) {
  try {
    await deleteQuestion(req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}

export async function getTemplates(req, res, next) {
  try {
    res.json(success(await listTemplates(req.query)));
  } catch (e) {
    next(e);
  }
}

export async function createTemplateRecord(req, res, next) {
  try {
    res.status(201).json(success(await createTemplate(req.body)));
  } catch (e) {
    next(e);
  }
}

export async function getDiscountCodes(req, res, next) {
  try {
    res.json(success(await listDiscountCodes(req.user.id)));
  } catch (e) {
    next(e);
  }
}

export async function createDiscount(req, res, next) {
  try {
    res.status(201).json(success(await createDiscountCode(req.user.id, req.body)));
  } catch (e) {
    next(e);
  }
}

export async function createTemplateForExam(req, res, next) {
  try {
    res.status(201).json(success(await createTemplate({ ...req.body, examId: req.params.id })));
  } catch (e) {
    next(e);
  }
}

export async function updateTemplateRecord(req, res, next) {
  try {
    res.json(success(await updateTemplate(req.params.id, req.body)));
  } catch (e) {
    next(e);
  }
}

export async function deleteTemplate(req, res, next) {
  try {
    await deleteTemplateService(req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}
