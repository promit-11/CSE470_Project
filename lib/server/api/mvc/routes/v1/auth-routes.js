import express from "express";
import { validateRequest } from "../../../middlewares/validate-request.js";
import { loginValidator, refreshValidator, registerValidator } from "../../../validators/auth-validator.js";
import { requireAuth } from "../../../middlewares/auth.js";
import { login, logout, me, refresh, register } from "../../controllers/v1/auth-controller.js";

const router = express.Router();

router.post("/register", registerValidator, validateRequest, register);

router.post("/login", loginValidator, validateRequest, login);

router.post("/refresh", refreshValidator, validateRequest, refresh);

router.post("/logout", refreshValidator, validateRequest, logout);

router.get("/me", requireAuth, me);

export default router;
