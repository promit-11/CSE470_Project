import v1Routes from "./v1/index.js";
import { success } from "../../utils/api-response.js";

const routes = (app) => {
  app.get("/health", (_req, res) => {
    res.json(success({ status: "ok" }));
  });

  app.use("/api/v1", v1Routes);
};

export default routes;
