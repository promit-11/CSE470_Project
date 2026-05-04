import { body, param } from "express-validator";

export const objectIdParam = (field = "id") =>
  param(field).isMongoId().withMessage(`${field} must be a valid id`);

export const sectionValidator = body("section").isIn([
  "listening",
  "reading",
  "writing",
  "speaking",
]);
