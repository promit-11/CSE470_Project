import { validationResult } from "express-validator";
import { HttpError } from "../utils/http-error.js";

export function validateRequest(req, _res, next) {
  const result = validationResult(req);
  if (!result.isEmpty()) {
    return next(new HttpError(422, "Validation failed", result.array()));
  }
  return next();
}
