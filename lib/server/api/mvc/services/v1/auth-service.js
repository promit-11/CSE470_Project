import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { v4 as uuidv4 } from "uuid";
import env from "../../../config/env.js";
import { ROLES } from "../../../constants/roles.js";
import { APPROVAL_STATUSES } from "../../../constants/workflow-statuses.js";
import { HttpError } from "../../../utils/http-error.js";
import User from "../../models/v1/User.js";
import StudentProfile from "../../models/v1/StudentProfile.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import Institute from "../../models/v1/Institute.js";
import RefreshToken from "../../models/v1/RefreshToken.js";

function isUserActive(user) {
  return !user?.status || user.status === "active";
}

function isTeacherApproved(user) {
  if (user?.role !== ROLES.TEACHER) {
    return true;
  }
  return !user?.approvalStatus || user.approvalStatus === APPROVAL_STATUSES.APPROVED;
}

function generateAccessToken(user) {
  return jwt.sign(
    {
      role: user.role,
      email: user.email,
    },
    env.jwtAccessSecret,
    {
      expiresIn: env.accessTokenTtl,
      subject: String(user._id),
    }
  );
}

function generateRefreshToken(user, tokenId) {
  return jwt.sign({ tokenId }, env.jwtRefreshSecret, {
    expiresIn: `${env.refreshTokenTtlDays}d`,
    subject: String(user._id),
  });
}

async function issueSessionTokens(user) {
  const tokenId = uuidv4();
  const refreshToken = generateRefreshToken(user, tokenId);
  await RefreshToken.create({
    userId: user._id,
    tokenId,
    expiresAt: new Date(Date.now() + env.refreshTokenTtlDays * 24 * 60 * 60 * 1000),
  });

  return {
    accessToken: generateAccessToken(user),
    refreshToken,
  };
}

export async function registerUser(payload) {
  const existing = await User.findOne({ email: payload.email }).lean();
  if (existing) {
    throw new HttpError(409, "Email already in use");
  }

  const passwordHash = await bcrypt.hash(payload.password, 12);
  const user = await User.create({
    name: payload.name,
    email: payload.email,
    passwordHash,
    role: payload.role,
    approvalStatus:
      payload.role === ROLES.TEACHER
        ? APPROVAL_STATUSES.PENDING_APPROVAL
        : APPROVAL_STATUSES.NOT_REQUIRED,
  });

  if (payload.role === ROLES.STUDENT) {
    await StudentProfile.create({
      userId: user._id,
      testCredits: 20,
    });
  }

  if (payload.role === ROLES.TEACHER) {
    await TeacherProfile.create({
      userId: user._id,
      rewardCredits: 0,
    });
  }

  if (payload.role === ROLES.COACHING_ADMIN) {
    await Institute.findOneAndUpdate(
      { adminUserId: user._id },
      {
        name: payload.instituteName || `${payload.name}'s Institute`,
        description: "",
        address: "",
        contactEmail: payload.email,
        contactPhone: "",
        adminUserId: user._id,
      },
      { upsert: true, new: true }
    );
  }

  const response = {
    user: sanitizeUser(user),
  };

  const canIssueTokens =
    isUserActive(user) && isTeacherApproved(user);

  if (canIssueTokens) {
    const tokens = await issueSessionTokens(user);
    response.accessToken = tokens.accessToken;
    response.refreshToken = tokens.refreshToken;
  }

  return response;
}

export async function loginUser(email, password) {
  const user = await User.findOne({ email }).lean();
  if (!user) {
    throw new HttpError(401, "Invalid credentials");
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    throw new HttpError(401, "Invalid credentials");
  }

  if (!isUserActive(user)) {
    throw new HttpError(403, "Account is not active");
  }

  if (!isTeacherApproved(user)) {
    throw new HttpError(
      403,
      "Teacher account is pending platform approval. Please wait for approval."
    );
  }

  const { accessToken, refreshToken } = await issueSessionTokens(user);
  return {
    accessToken,
    refreshToken,
    user: sanitizeUser(user),
  };
}

export async function refreshAccessToken(refreshToken) {
  let payload;
  try {
    payload = jwt.verify(refreshToken, env.jwtRefreshSecret);
  } catch (_e) {
    throw new HttpError(401, "Invalid refresh token");
  }

  const tokenRecord = await RefreshToken.findOne({
    tokenId: payload.tokenId,
    revoked: false,
  }).lean();

  if (!tokenRecord || tokenRecord.expiresAt < new Date()) {
    throw new HttpError(401, "Refresh token expired or revoked");
  }

  const user = await User.findById(payload.sub).lean();
  if (!user || !isUserActive(user)) {
    throw new HttpError(401, "Invalid user session");
  }

  if (!isTeacherApproved(user)) {
    throw new HttpError(403, "Teacher account is pending platform approval");
  }

  return {
    accessToken: generateAccessToken(user),
    user: sanitizeUser(user),
  };
}

export async function logout(refreshToken) {
  try {
    const payload = jwt.verify(refreshToken, env.jwtRefreshSecret);
    await RefreshToken.updateOne({ tokenId: payload.tokenId }, { revoked: true });
  } catch (_e) {
    return;
  }
}

export async function getCurrentUser(userId) {
  const user = await User.findById(userId).lean();
  if (!user) {
    throw new HttpError(404, "User not found");
  }

  return {
    user: sanitizeUser(user),
  };
}

export function sanitizeUser(user) {
  const normalizedStatus = user.status || "active";
  const normalizedApprovalStatus =
    user.approvalStatus ||
    (user.role === ROLES.TEACHER
      ? APPROVAL_STATUSES.APPROVED
      : APPROVAL_STATUSES.NOT_REQUIRED);

  return {
    id: String(user._id),
    name: user.name,
    email: user.email,
    role: user.role,
    status: normalizedStatus,
    approvalStatus: normalizedApprovalStatus,
  };
}
