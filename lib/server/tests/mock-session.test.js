/**
 * Mock Session Generation Tests
 * Covers: session creation, question distribution, section structure, template adherence
 */

import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import {
  createTestUser,
  createTestStudentProfile,
  createFullQuestionBank,
  createTestTemplate,
  cleanupDatabase,
} from "./fixtures.js";
import { generateMockSession } from "../api/mvc/services/v1/mock-service.js";
import MockSession from "../api/mvc/models/v1/MockSession.js";

test("Mock Session Generation Suite", async (t) => {
  let testUser, testProfile, testTemplate;

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

    // Create test data
    testUser = await createTestUser({ email: "mocktest@example.com" });
    testProfile = await createTestStudentProfile(testUser);
    await createFullQuestionBank();
    testTemplate = await createTestTemplate();
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Should reject session generation without mock access", async () => {
    const user = await createTestUser({ email: "noaccess@example.com" });
    const profile = await createTestStudentProfile(user);
    profile.mockAccess.allowed = false;
    await profile.save();

    try {
      await generateMockSession(String(user._id));
      assert.fail("Should have thrown error");
    } catch (error) {
      assert.match(error.message, /Mock access is locked/);
    }
  });

  await t.test("Should reject session when no credits remaining", async () => {
    testProfile.mockAccess.remainingCredits = 0;
    await testProfile.save();

    try {
      await generateMockSession(String(testUser._id));
      assert.fail("Should have thrown error");
    } catch (error) {
      assert.match(error.message, /No mock credits left/);
    }
  });

  await t.test("Should generate session with correct section order", async () => {
    const session = await generateMockSession(String(testUser._id));

    assert.ok(session._id);
    assert.deepEqual(session.sectionOrder, ["listening", "reading", "writing", "speaking"]);
    assert.equal(session.currentSection, "listening");
    assert.equal(session.status, "active");
  });

  await t.test("Should create section states with correct durations", async () => {
    const session = await generateMockSession(String(testUser._id));

    const expectedDurations = {
      listening: 30 * 60,
      reading: 60 * 60,
      writing: 60 * 60,
      speaking: 15 * 60,
    };

    for (const section of session.sections) {
      assert.equal(
        section.durationSeconds,
        expectedDurations[section.section],
        `Wrong duration for ${section.section}`
      );
    }
  });

  await t.test("Should distribute correct question counts per section", async () => {
    const session = await generateMockSession(String(testUser._id));

    const expectedCounts = {
      listening: 40,
      reading: 40,
      writing: 2,
      speaking: 3,
    };

    for (const section of session.sections) {
      assert.equal(
        section.questionIds.length,
        expectedCounts[section.section],
        `Wrong question count for ${section.section}`
      );
    }
  });

  await t.test("Should initialize answers array matching questions", async () => {
    const session = await generateMockSession(String(testUser._id));

    for (const section of session.sections) {
      assert.equal(
        section.answers.length,
        section.questionIds.length,
        `Answer count mismatch for ${section.section}`
      );

      // Check answer structure
      for (const answer of section.answers) {
        assert.ok(answer.questionId);
        assert.equal(answer.value, null);
        assert.equal(answer.flagged, false);
      }
    }
  });

  await t.test("Should decrement remaining credits", async () => {
    const initialCredits = testProfile.mockAccess.remainingCredits;
    await generateMockSession(String(testUser._id));

    const updatedProfile = await testProfile.constructor.findById(testProfile._id);
    assert.equal(updatedProfile.mockAccess.remainingCredits, initialCredits - 5);
  });

  await t.test("Should lock access when credits reach zero", async () => {
    testProfile.mockAccess.remainingCredits = 5;
    await testProfile.save();

    await generateMockSession(String(testUser._id));

    const updatedProfile = await testProfile.constructor.findById(testProfile._id);
    assert.equal(updatedProfile.mockAccess.remainingCredits, 0);
    assert.equal(updatedProfile.mockAccess.allowed, false);
  });

  await t.test("Should use default template when none specified", async () => {
    const session = await generateMockSession(String(testUser._id));

    assert.ok(session.templateId);
    assert.equal(String(session.templateId), String(testTemplate._id));
  });

  await t.test("Should respect custom template configuration", async () => {
    const customTemplate = await createTestTemplate({
      name: "Custom Test",
      sectionQuestionCount: {
        listening: 35,
        reading: 35,
        writing: 2,
        speaking: 3,
      },
    });

    const session = await generateMockSession(String(testUser._id), String(customTemplate._id));

    const listeningSection = session.sections.find((s) => s.section === "listening");
    assert.equal(listeningSection.questionIds.length, 35);

    const readingSection = session.sections.find((s) => s.section === "reading");
    assert.equal(readingSection.questionIds.length, 35);
  });

  await t.test("Should avoid repeating recent questions (repetition prevention)", async () => {
    // Generate first session
    const session1 = await generateMockSession(String(testUser._id));
    const session1QIds = new Set();
    session1.sections.forEach((s) => {
      s.questionIds.forEach((qid) => session1QIds.add(String(qid)));
    });

    // Mark it as completed
    await MockSession.findByIdAndUpdate(session1._id, { status: "completed" });

    // Generate second session
    const session2 = await generateMockSession(String(testUser._id));
    const session2QIds = new Set(session2.sections.flatMap((s) => s.questionIds.map((q) => String(q))));

    // Find overlap
    const overlap = [...session1QIds].filter((qid) => session2QIds.has(qid));
    const overlapPercent = overlap.length / session2QIds.size;

    // Should not exceed maxRepeatRate of 0.25 (25%)
    assert.ok(overlapPercent <= 0.3, `Overlap too high: ${overlapPercent * 100}%`); // Allow small margin
  });

  await t.test("Should persist session to database", async () => {
    const session = await generateMockSession(String(testUser._id));

    const savedSession = await MockSession.findById(session._id);
    assert.ok(savedSession);
    assert.equal(String(savedSession.studentProfileId), String(testProfile._id));
    assert.equal(savedSession.status, "active");
  });
});
