/**
 * Authentication Tests
 * Covers: register validation, login validation, token generation, invalid credentials
 */

import test from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import mongoose from "mongoose";
import app from "../api/app.js";
import { FIXTURE_DATA, createTestUser, cleanupDatabase } from "./fixtures.js";

test("Auth Suite", async (t) => {
  // Connect to test database before tests
  await t.before(async () => {
    if (mongoose.connection.readyState !== 1) {
      const mongoUrl = process.env.MONGODB_TEST_URL || "mongodb://localhost:27017/cse470_test";
      await mongoose.connect(mongoUrl, {
        connectTimeoutMS: 5000,
        serverSelectionTimeoutMS: 5000,
      });
    }
  });

  // Cleanup after each test
  await t.beforeEach(async () => {
    await cleanupDatabase();
  });

  // Disconnect after all tests
  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Register - should reject invalid name (too short)", async () => {
    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "a",
        email: "test@example.com",
        password: FIXTURE_DATA.PASSWORD,
        role: "student",
      });

    assert.equal(response.statusCode, 422);
    assert.equal(response.body.success, false);
  });

  await t.test("Register - should reject invalid email", async () => {
    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "Valid Name",
        email: "not-an-email",
        password: FIXTURE_DATA.PASSWORD,
        role: "student",
      });

    assert.equal(response.statusCode, 422);
    assert.equal(response.body.success, false);
  });

  await t.test("Register - should reject weak password", async () => {
    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "Valid Name",
        email: "test@example.com",
        password: "weak",
        role: "student",
      });

    assert.equal(response.statusCode, 422);
    assert.equal(response.body.success, false);
  });

  await t.test("Register - should reject invalid role", async () => {
    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "Valid Name",
        email: "test@example.com",
        password: FIXTURE_DATA.PASSWORD,
        role: "invalid_role",
      });

    assert.equal(response.statusCode, 422);
    assert.equal(response.body.success, false);
  });

  await t.test("Register - should successfully create student account", async () => {
    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "John Doe",
        email: "john@example.com",
        password: FIXTURE_DATA.PASSWORD,
        role: "student",
      });

    assert.equal(response.statusCode, 201);
    assert.equal(response.body.success, true);
    assert.ok(response.body.data.user.id);
    assert.equal(response.body.data.user.email, "john@example.com");
    assert.equal(response.body.data.user.role, "student");
    assert.ok(response.body.data.accessToken);
    assert.ok(response.body.data.refreshToken);
  });

  await t.test("Register - should reject duplicate email", async () => {
    await createTestUser({ email: "duplicate@example.com" });

    const response = await request(app)
      .post("/api/v1/auth/register")
      .send({
        name: "Another User",
        email: "duplicate@example.com",
        password: FIXTURE_DATA.PASSWORD,
        role: "student",
      });

    assert.equal(response.statusCode, 409);
    assert.equal(response.body.success, false);
  });

  await t.test("Login - should reject non-existent email", async () => {
    const response = await request(app)
      .post("/api/v1/auth/login")
      .send({
        email: "nonexistent@example.com",
        password: FIXTURE_DATA.PASSWORD,
      });

    assert.equal(response.statusCode, 401);
    assert.equal(response.body.success, false);
  });

  await t.test("Login - should reject incorrect password", async () => {
    await createTestUser({ email: "user@example.com" });

    const response = await request(app)
      .post("/api/v1/auth/login")
      .send({
        email: "user@example.com",
        password: "WrongPassword123!",
      });

    assert.equal(response.statusCode, 401);
    assert.equal(response.body.success, false);
  });

  await t.test("Login - should successfully login with correct credentials", async () => {
    const user = await createTestUser({ email: "user@example.com" });

    const response = await request(app)
      .post("/api/v1/auth/login")
      .send({
        email: "user@example.com",
        password: FIXTURE_DATA.PASSWORD,
      });

    assert.equal(response.statusCode, 200);
    assert.equal(response.body.success, true);
    assert.ok(response.body.data.accessToken);
    assert.ok(response.body.data.refreshToken);
    assert.equal(response.body.data.user.id, String(user._id));
  });

  await t.test("Login - should reject inactive account", async () => {
    await createTestUser({
      email: "inactive@example.com",
      status: "inactive",
    });

    const response = await request(app)
      .post("/api/v1/auth/login")
      .send({
        email: "inactive@example.com",
        password: FIXTURE_DATA.PASSWORD,
      });

    assert.equal(response.statusCode, 403);
    assert.equal(response.body.success, false);
  });

  await t.test("Refresh - should reject invalid refresh token", async () => {
    const response = await request(app)
      .post("/api/v1/auth/refresh")
      .send({
        refreshToken: "invalid_token",
      });

    assert.equal(response.statusCode, 401);
    assert.equal(response.body.success, false);
  });

  await t.test("Logout - should succeed with valid token", async () => {
    const user = await createTestUser({ email: "logout@example.com" });

    const loginResponse = await request(app)
      .post("/api/v1/auth/login")
      .send({
        email: "logout@example.com",
        password: FIXTURE_DATA.PASSWORD,
      });

    const response = await request(app)
      .post("/api/v1/auth/logout")
      .send({
        refreshToken: loginResponse.body.data.refreshToken,
      });

    assert.equal(response.statusCode, 200);
  });
});
