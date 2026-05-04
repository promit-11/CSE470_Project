import { failure } from "../utils/api-response.js";

export function notFound(_req, res) {
  res.status(404).json(failure("Resource not found"));
}
