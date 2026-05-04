import { success } from "../../../utils/api-response.js";
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

export async function getPendingRequests(req, res, next) {
  try {
    const data = await listPendingEligibleRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function claimRequest(req, res, next) {
  try {
    const data = await claimEvaluationRequest(req.user.id, req.params.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getClaimedRequests(req, res, next) {
  try {
    const data = await listMyClaimedRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getReviewedRequests(req, res, next) {
  try {
    const data = await listMyReviewedRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getProfile(req, res, next) {
  try {
    const data = await getMyTeacherProfile(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getRequestDetails(req, res, next) {
  try {
    const data = await getMyEvaluationRequestDetails(req.user.id, req.params.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function reviewRequest(req, res, next) {
  try {
    const data = await submitEvaluationReview(req.user.id, req.params.id, req.body);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function createPayoutRequest(req, res, next) {
  try {
    const data = await requestPayout(req.user.id, req.body);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getPayoutRequests(req, res, next) {
  try {
    const data = await listMyPayoutRequests(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}
