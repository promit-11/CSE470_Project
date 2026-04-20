/**
 * Institute Discount Application Tests
 * Covers: discount validation, application logic, student verification, usage limits
 */

import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import {
  createTestUser,
  createTestStudentProfile,
  createTestInstitute,
  createTestDiscountCode,
  cleanupDatabase,
} from "./fixtures.js";
import { purchaseMockAccess } from "../api/mvc/services/v1/student-service.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import DiscountCode from "../api/mvc/models/v1/DiscountCode.js";

test("Discount Application Suite", async (t) => {
  let testUser, testProfile, testInstitute, testDiscount;

  await t.before(async () => {
    const mongoUrl = process.env.MONGODB_TEST_URL || "mongodb://localhost:27017/cse470_test";
    if (mongoose.connection.readyState !== 1) {
      await mongoose.connect(mongoUrl, {
        connectTimeoutMS: 5000,
        serverSelectionTimeoutMS: 5000,
      });
    }
  });

  await t.beforeEach(async () => {
    await cleanupDatabase();

    testUser = await createTestUser({ email: "discount@example.com" });
    testProfile = await createTestStudentProfile(testUser);
    testInstitute = await createTestInstitute();
    testDiscount = await createTestDiscountCode(testInstitute);
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Should not apply discount to unverified student", async () => {
    // Student is not verified by institute
    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.appliedDiscount, null);
    assert.equal(result.discountCode, undefined);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should not apply discount from inactive code", async () => {
    // Verify student with institute
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Deactivate discount
    testDiscount.active = false;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should not apply discount if student has completed mocks below minimum", async () => {
    // Verify student with institute
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Set minimum to 5 mocks
    testDiscount.minMocks = 5;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should apply fixed discount to eligible verified student", async () => {
    // Verify student with institute
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Fixed discount of 50 units
    testDiscount.discountType = "fixed";
    testDiscount.discountValue = 50;
    testDiscount.minMocks = 0;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 50);
    assert.ok(result.finalAmount < result.subtotal);
  });

  await t.test("Should apply percentage discount to eligible verified student", async () => {
    // Verify student with institute
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // 10% discount
    testDiscount.discountType = "percentage";
    testDiscount.discountValue = 10;
    testDiscount.minMocks = 0;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    const expectedDiscount = Math.floor(result.subtotal * 0.1);
    assert.ok(result);
    assert.equal(result.discountAmount, expectedDiscount);
  });

  await t.test("Should not exceed subtotal with discount", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Set discount value higher than subtotal
    testDiscount.discountType = "fixed";
    testDiscount.discountValue = 10000;
    testDiscount.minMocks = 0;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.ok(result.discountAmount <= result.subtotal);
    assert.equal(result.finalAmount, 0); // Can't go negative
  });

  await t.test("Should respect discount usage limit", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Set limit to 1 usage, already used
    testDiscount.usageLimit = 1;
    testDiscount.usedCount = 1;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should honor discount validity dates (not yet valid)", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Set discount to start in future
    const now = new Date();
    testDiscount.validFrom = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    testDiscount.validTo = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should honor discount validity dates (expired)", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Set discount to be expired
    const now = new Date();
    testDiscount.validFrom = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    testDiscount.validTo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    assert.ok(result);
    assert.equal(result.discountAmount, 0);
  });

  await t.test("Should only apply discount to eligible students if list provided", async () => {
    const otherUser = await createTestUser({ email: "other@example.com" });
    const otherProfile = await createTestStudentProfile(otherUser);

    // Verify both students with institute
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    otherProfile.verifiedByInstitute = true;
    otherProfile.instituteId = testInstitute._id;
    await otherProfile.save();

    // Only testProfile is eligible
    testDiscount.eligibleStudentIds = [testProfile._id];
    testDiscount.minMocks = 0;
    await testDiscount.save();

    // testProfile should get discount
    const result1 = await purchaseMockAccess(String(testUser._id), 5);
    assert.ok(result1.discountAmount > 0);

    // otherProfile should not get discount
    const result2 = await purchaseMockAccess(String(otherUser._id), 5);
    assert.equal(result2.discountAmount, 0);
  });

  await t.test("Should select best discount when multiple applicable", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    await testProfile.save();

    // Create second discount with higher value
    const discount2 = await createTestDiscountCode(testInstitute, {
      code: "TESTCODE20",
      discountType: "fixed",
      discountValue: 100,
      minMocks: 0,
    });

    // Ensure first discount is lower
    testDiscount.discountValue = 50;
    testDiscount.minMocks = 0;
    await testDiscount.save();

    const result = await purchaseMockAccess(String(testUser._id), 5);

    // Should use higher discount
    assert.equal(result.discountAmount, 100);
  });

  await t.test("Should update student mock access on purchase", async () => {
    // Verify student
    testProfile.verifiedByInstitute = true;
    testProfile.instituteId = testInstitute._id;
    testProfile.mockAccess.remainingCredits = 0;
    testProfile.mockAccess.allowed = false;
    await testProfile.save();

    await purchaseMockAccess(String(testUser._id), 5);

    const updated = await StudentProfile.findById(testProfile._id);
    assert.equal(updated.mockAccess.remainingCredits, 5);
    assert.equal(updated.mockAccess.allowed, true);
    assert.ok(updated.mockAccess.lastPurchasedAt);
  });

  await t.test("Should add purchased credits on top of fallback test credits", async () => {
    testProfile.testCredits = 20;
    testProfile.mockAccess.remainingCredits = -1;
    testProfile.mockAccess.allowed = true;
    await testProfile.save();

    await purchaseMockAccess(String(testUser._id), { packSize: 5 });

    const updated = await StudentProfile.findById(testProfile._id);
    assert.equal(updated.mockAccess.remainingCredits, 25);
    assert.equal(updated.mockAccess.allowed, true);
  });
});
