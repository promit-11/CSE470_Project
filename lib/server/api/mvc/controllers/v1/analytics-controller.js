import { success } from "../../../utils/api-response.js";
import { getAdminOverview } from "../../services/v1/analytics-service.js";

export async function getOverview(req, res, next) {
  try {
    res.json(success(await getAdminOverview()));
  } catch (e) {
    next(e);
  }
}
