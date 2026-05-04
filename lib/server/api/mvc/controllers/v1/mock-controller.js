import { success } from "../../../utils/api-response.js";
import {
  deleteWritingImage,
  finalSubmit,
  generateMockSession,
  getSessionDetails,
  markQuestion,
  reorderWritingImages,
  saveAnswer,
  saveWritingTypedResponse,
  submitSection,
  uploadSpeakingRecording as uploadSpeakingRecordingForSession,
  uploadWritingImages as uploadWritingImagesForSession,
} from "../../services/v1/mock-service.js";

export async function generateSession(req, res, next) {
  try {
    const data = await generateMockSession(req.user.id, req.body.templateId, req.body.sourceType);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getSession(req, res, next) {
  try {
    const data = await getSessionDetails(req.user.id, req.params.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function answerQuestion(req, res, next) {
  try {
    const data = await saveAnswer(
      req.user.id,
      req.params.id,
      req.body.section,
      req.body.questionId,
      req.body.value
    );
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateWritingTypedResponse(req, res, next) {
  try {
    const data = await saveWritingTypedResponse(
      req.user.id,
      req.params.id,
      req.body.typedAnswer || ""
    );
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function addWritingImages(req, res, next) {
  try {
    const files = Array.isArray(req.files) ? req.files : [];
    const data = await uploadWritingImagesForSession(req.user.id, req.params.id, files);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function removeWritingImage(req, res, next) {
  try {
    const data = await deleteWritingImage(req.user.id, req.params.id, req.params.mediaId);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function reorderImages(req, res, next) {
  try {
    const data = await reorderWritingImages(req.user.id, req.params.id, req.body.orderedMediaIds);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function addSpeakingRecording(req, res, next) {
  try {
    const data = await uploadSpeakingRecordingForSession(req.user.id, req.params.id, req.file || null);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function flagQuestion(req, res, next) {
  try {
    const data = await markQuestion(
      req.user.id,
      req.params.id,
      req.body.section,
      req.body.questionId,
      req.body.flagged
    );
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function submitCurrentSection(req, res, next) {
  try {
    const data = await submitSection(
      req.user.id,
      req.params.id,
      req.body.section,
      req.body.autoSubmitted || false
    );
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function submitFinal(req, res, next) {
  try {
    const data = await finalSubmit(req.user.id, req.params.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}
