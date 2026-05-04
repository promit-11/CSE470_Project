import { body } from "express-validator";
import { ROLES } from "../constants/roles.js";

export const registerValidator = [
  body("name").trim().isLength({ min: 2, max: 80 }),
  body("email").trim().isEmail().normalizeEmail(),
  body("password")
    .isString()
    .isLength({ min: 8, max: 72 })
    .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/),
  body("role").isIn([ROLES.STUDENT, ROLES.TEACHER, ROLES.COACHING_ADMIN]),
  body("instituteName").optional().isString().isLength({ min: 2, max: 120 }),
];

export const loginValidator = [
  body("email").trim().isEmail().normalizeEmail(),
  body("password").isString().isLength({ min: 8, max: 72 }),
];

export const refreshValidator = [body("refreshToken").isString().isLength({ min: 1 })];
