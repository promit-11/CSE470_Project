import express from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import helmet from "helmet";
import morgan from "morgan";
import routes from "./mvc/routes/index.js";
import env from "./config/env.js";
import { connectDatabase } from "./config/database.js";
import { errorHandler } from "./middlewares/error-handler.js";
import { notFound } from "./middlewares/not-found.js";
import { ensureMediaStorageReady, getMediaStorageRootDir } from "./mvc/services/v1/media-storage-service.js";

// Create the app
const app = express();

//Add middleware
app.use(helmet());
app.use(express.json({ limit: env.jsonBodyLimit }));
app.use(express.urlencoded({ extended: true, limit: env.urlEncodedBodyLimit }));
app.use(cookieParser());
app.use(
  cors({
    origin: env.clientOrigin === "*" ? true : env.clientOrigin,
    credentials: true,
  })
);
app.use(morgan(env.nodeEnv === "production" ? "combined" : "dev"));

if (env.mediaStorageProvider === "local") {
  await ensureMediaStorageReady();
  app.use(
    env.mediaPublicBasePath,
    express.static(getMediaStorageRootDir(), {
      fallthrough: true,
      maxAge: env.nodeEnv === "production" ? "7d" : 0,
      index: false,
    })
  );
}

//Pass the app to the routes
routes(app);
app.use(notFound);
app.use(errorHandler);

// Connect to the database
try {
  console.log("Connecting to the database...");
  await connectDatabase();
  console.log("Successfully connected to MongoDB");
} catch (e) {
  console.log("Error connecting to database : ", e);
}

export default app;
