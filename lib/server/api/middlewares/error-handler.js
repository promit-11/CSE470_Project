import { failure } from "../utils/api-response.js";

export function errorHandler(error, _req, res, _next) {
  const status = error.status || 500;
  const message = error.message || "Internal server error";
  const details = error.details || undefined;
  res.status(status).json(failure(message, details));
}
