import { success } from "../../../utils/api-response.js";
import {
  getCreditPackages,
  getCoachingAssignmentForm,
  getMyAnalytics,
  getMyHistory,
  getMyPayments,
  getMyProfile,
  purchaseTestCredits,
  purchaseMockAccess,
  submitCoachingAssignmentRequest,
  updateMyProfile,
} from "../../services/v1/student-service.js";

export async function getProfile(req, res, next) {
  try {
    const data = await getMyProfile(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function updateProfile(req, res, next) {
  try {
    const data = await updateMyProfile(req.user.id, req.body);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getHistory(req, res, next) {
  try {
    const data = await getMyHistory(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getAnalytics(req, res, next) {
  try {
    const data = await getMyAnalytics(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getCoachingForm(req, res, next) {
  try {
    const data = await getCoachingAssignmentForm(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function requestCoachingAssignment(req, res, next) {
  try {
    const data = await submitCoachingAssignmentRequest(req.user.id, req.body);
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function purchaseCredits(req, res, next) {
  try {
    const data = await purchaseTestCredits(req.user.id, {
      packageId: req.body.packageId,
    });
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function listCreditPackages(_req, res, next) {
  try {
    const data = await getCreditPackages();
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function getPayments(req, res, next) {
  try {
    const data = await getMyPayments(req.user.id);
    res.json(success(data));
  } catch (e) {
    next(e);
  }
}

export async function purchaseMockCredits(req, res, next) {
  try {
    const data = await purchaseMockAccess(req.user.id, {
      packSize: req.body.packSize,
    });
    res.status(201).json(success(data));
  } catch (e) {
    next(e);
  }
}
