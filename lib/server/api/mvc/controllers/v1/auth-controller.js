import { success } from "../../../utils/api-response.js";
import {
  loginUser,
  logout as logoutService,
  refreshAccessToken,
  registerUser,
  getCurrentUser,
} from "../../services/v1/auth-service.js";

export async function register(req, res, next) {
  try {
    const result = await registerUser(req.body);
    res.status(201).json(success(result));
  } catch (e) {
    next(e);
  }
}

export async function login(req, res, next) {
  try {
    const { email, password } = req.body;
    const result = await loginUser(email, password);
    res.json(success(result));
  } catch (e) {
    next(e);
  }
}

export async function refresh(req, res, next) {
  try {
    const result = await refreshAccessToken(req.body.refreshToken);
    res.json(success(result));
  } catch (e) {
    next(e);
  }
}

export async function logout(req, res, next) {
  try {
    await logoutService(req.body.refreshToken);
    res.json(success({ loggedOut: true }));
  } catch (e) {
    next(e);
  }
}

export async function me(req, res, next) {
  try {
    const result = await getCurrentUser(req.user.id);
    res.json(success(result));
  } catch (e) {
    next(e);
  }
}
