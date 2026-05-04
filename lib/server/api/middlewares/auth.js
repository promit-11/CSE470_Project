import jwt from "jsonwebtoken";
import env from "../config/env.js";
import { ROLES } from "../constants/roles.js";
import { APPROVAL_STATUSES } from "../constants/workflow-statuses.js";
import { USER_ROLES } from "../constants/roles.js";
import { HttpError } from "../utils/http-error.js";
import User from "../mvc/models/v1/User.js";

function extractAccessToken(req) {
  const rawHeader = req.headers.authorization || "";
  const parts = String(rawHeader).trim().split(/\s+/).filter(Boolean);

  if (parts.length >= 2 && parts[0].toLowerCase() === "bearer") {
    return parts[1];
  }

  if (parts.length === 1 && parts[0]) {
    return parts[0];
  }

  const fallbackHeader = req.headers["x-access-token"];
  if (typeof fallbackHeader === "string" && fallbackHeader.trim()) {
    return fallbackHeader.trim();
  }

  const queryToken = req.query?.access_token;
  if (typeof queryToken === "string" && queryToken.trim()) {
    return queryToken.trim();
  }

  return "";
}

function isLegacyActiveUser(user) {
  return !user?.status || user.status === "active";
}

function isTeacherApprovedOrLegacy(user) {
  if (user?.role !== ROLES.TEACHER) {
    return true;
  }
  return !user?.approvalStatus || user.approvalStatus === APPROVAL_STATUSES.APPROVED;
}

export async function requireAuth(req, _res, next) {
  const token = extractAccessToken(req);
  if (!token) {
    return next(new HttpError(401, "Missing or invalid authorization token"));
  }

  try {
    const payload = jwt.verify(token, env.jwtAccessSecret);
    const user = await User.findById(payload.sub).lean();
    if (!user || !isLegacyActiveUser(user)) {
      return next(new HttpError(401, "User not authorized"));
    }
    if (!isTeacherApprovedOrLegacy(user)) {
      return next(new HttpError(403, "Teacher account is pending platform approval"));
    }
    req.user = {
      id: String(user._id),
      role: user.role,
      email: user.email,
      approvalStatus: user.approvalStatus,
    };
    return next();
  } catch (_e) {
    return next(new HttpError(401, "Token expired or invalid"));
  }
}

export function allowRoles(...roles) {
  const roleSet = new Set(roles.filter((r) => USER_ROLES.includes(r)));
  return (req, _res, next) => {
    if (!req.user || !roleSet.has(req.user.role)) {
      return next(new HttpError(403, "Forbidden"));
    }
    return next();
  };
}
