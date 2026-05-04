import mongoose from "mongoose";
import env from "./env.js";

export async function connectDatabase() {
  const connectionString = `${env.dbUrl}/${env.dbName}`;
  await mongoose.connect(connectionString);
}
