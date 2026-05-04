import { success } from "../../../utils/api-response.js";
import {
  acceptAssignmentRequest,
  assignTeacherToCoaching,
  createCoachingExam,
  createCoachingQuestion,
  createCoachingTemplate,
  createDiscountCode,
  deleteCoachingExam,
  deleteCoachingQuestion,
  deleteCoachingTemplate,
  listAvailableTeachersForCoaching,
  listCoachingEvaluationRequests,
  getInstituteByAdmin,
  listCoachingExams,
  listCoachingQuestions,
  listIncomingAssignmentRequests,
  listCoachingTemplates,
  listCoachingTeachers,
  listDiscountCodes,
  listInstituteStudents,
  removeStudentFromCoaching,
  removeTeacherFromCoaching,
  rejectAssignmentRequest,
  updateCoachingExam,
  updateCoachingQuestion,
  updateCoachingTemplate,
  updateInstitute,
  verifyStudent,
} from "../../services/v1/institute-service.js";

export async function getProfile(req, res, next) {
  try {
    const data = await getInstituteByAdmin(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateProfile(req, res, next) {
  try {
    const data = await updateInstitute(req.user.id, req.body);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function verifyStudentAccount(req, res, next) {
  try {
    const data = await verifyStudent(req.user.id, req.body.email);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getStudents(req, res, next) {
  try {
    const data = await listInstituteStudents(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function removeStudent(req, res, next) {
  try {
    const data = await removeStudentFromCoaching(req.user.id, req.params.studentId);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getTeachers(req, res, next) {
  try {
    const data = await listCoachingTeachers(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getAvailableTeachers(req, res, next) {
  try {
    const data = await listAvailableTeachersForCoaching(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getEvaluationRequests(req, res, next) {
  try {
    const data = await listCoachingEvaluationRequests(req.user.id, req.query);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getExams(req, res, next) {
  try {
    const data = await listCoachingExams(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function createExam(req, res, next) {
  try {
    const data = await createCoachingExam(req.user.id, req.body);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateExam(req, res, next) {
  try {
    const data = await updateCoachingExam(req.user.id, req.params.id, req.body);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function deleteExam(req, res, next) {
  try {
    await deleteCoachingExam(req.user.id, req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}

export async function getQuestions(req, res, next) {
  try {
    const data = await listCoachingQuestions(req.user.id, req.query);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function createQuestion(req, res, next) {
  try {
    const data = await createCoachingQuestion(req.user.id, req.body, req.file || null);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateQuestion(req, res, next) {
  try {
    const data = await updateCoachingQuestion(req.user.id, req.params.id, req.body, req.file || null);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function deleteQuestion(req, res, next) {
  try {
    await deleteCoachingQuestion(req.user.id, req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}

export async function getTemplates(req, res, next) {
  try {
    const data = await listCoachingTemplates(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function createTemplate(req, res, next) {
  try {
    const data = await createCoachingTemplate(req.user.id, req.body);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateTemplate(req, res, next) {
  try {
    const data = await updateCoachingTemplate(req.user.id, req.params.id, req.body);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function deleteTemplate(req, res, next) {
  try {
    await deleteCoachingTemplate(req.user.id, req.params.id);
    res.json(success({ deleted: true }));
  } catch (e) {
    next(e);
  }
}

export async function assignTeacher(req, res, next) {
  try {
    const data = await assignTeacherToCoaching(req.user.id, req.params.teacherId);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function removeTeacher(req, res, next) {
  try {
    const data = await removeTeacherFromCoaching(req.user.id, req.params.teacherId);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getAssignmentRequests(req, res, next) {
  try {
    const data = await listIncomingAssignmentRequests(req.user.id, req.query);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function acceptRequest(req, res, next) {
  try {
    const data = await acceptAssignmentRequest(req.user.id, req.params.id, req.body.note);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function rejectRequest(req, res, next) {
  try {
    const data = await rejectAssignmentRequest(req.user.id, req.params.id, req.body.note);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getDiscountCodes(req, res, next) {
  try {
    const data = await listDiscountCodes(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function createDiscount(req, res, next) {
  try {
    const data = await createDiscountCode(req.user.id, req.body);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}
