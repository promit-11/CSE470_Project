/**
 * Basic Health Check Tests
 * Validates core API endpoints are functional
 */

import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import app from "../api/app.js";

test("Health Check Suite", async (t) => {
  await t.before(async () => {
    // Don't connect to database for health check
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("GET /health returns ok", async () => {
    const response = await request(app).get("/health");
    assert.equal(response.statusCode, 200);
    assert.equal(response.body.success, true);
    assert.equal(response.body.data.status, "ok");
  });
});

