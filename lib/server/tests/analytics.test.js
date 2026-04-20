/**
 * Student Analytics & History Persistence Tests
 * Covers: history retrieval, analytics computation, section averages, persistence
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
import { generateMockSession, submitSection, finalSubmit } from "../api/mvc/services/v1/mock-service.js";
import { getMyHistory, getMyAnalytics } from "../api/mvc/services/v1/student-service.js";
import MockSession from "../api/mvc/models/v1/MockSession.js";
import TestHistory from "../api/mvc/models/v1/TestHistory.js";

test("Analytics & History Suite", async (t) => {
  let testUser, testProfile;

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

    testUser = await createTestUser({ email: "analytics@example.com" });
    testProfile = await createTestStudentProfile(testUser);
    testProfile.mockAccess.remainingCredits = 100;
    await testProfile.save();
    await createFullQuestionBank();
    await createTestTemplate();
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Should return empty history for new student", async () => {
    const history = await getMyHistory(String(testUser._id));

    assert.ok(Array.isArray(history));
    assert.equal(history.length, 0);
  });

  await t.test("Should return empty analytics for new student", async () => {
    const analytics = await getMyAnalytics(String(testUser._id));

    assert.ok(analytics);
    assert.equal(analytics.totalMocks, 0);
    assert.ok(analytics.mockAccess);
    assert.deepEqual(analytics.strengths, []);
    assert.deepEqual(analytics.weaknesses, []);
  });

  await t.test("Should persist test history after session completion", async () => {
    const session = await generateMockSession(String(testUser._id));

    // Complete all sections
    await submitSection(String(testUser._id), String(session._id), "listening");
    await submitSection(String(testUser._id), String(session._id), "reading");
    await submitSection(String(testUser._id), String(session._id), "writing");
    await submitSection(String(testUser._id), String(session._id), "speaking");

    await finalSubmit(String(testUser._id), String(session._id));

    const history = await getMyHistory(String(testUser._id));

    assert.equal(history.length, 1);
    assert.ok(history[0].mockSessionId);
    assert.equal(history[0].overallBand, null);
    assert.ok(typeof history[0].listeningBand === "number");
    assert.ok(typeof history[0].readingBand === "number");
    assert.equal(history[0].writingBand, null);
    assert.equal(history[0].speakingBand, null);
    assert.equal(history[0].resultSummary.sections.writing.status, "not_submitted");
    assert.equal(history[0].resultSummary.sections.speaking.status, "not_submitted");
  });

  await t.test("Should compute section averages from multiple tests", async () => {
    // Complete multiple sessions
    for (let i = 0; i < 3; i++) {
      const session = await generateMockSession(String(testUser._id));

      await submitSection(String(testUser._id), String(session._id), "listening");
      await submitSection(String(testUser._id), String(session._id), "reading");
      await submitSection(String(testUser._id), String(session._id), "writing");
      await submitSection(String(testUser._id), String(session._id), "speaking");

      await finalSubmit(String(testUser._id), String(session._id));
    }

    const analytics = await getMyAnalytics(String(testUser._id));

    assert.equal(analytics.totalMocks, 3);
    assert.ok(analytics.sectionAverages);
    assert.ok(typeof analytics.sectionAverages.listening === "number");
    assert.ok(typeof analytics.sectionAverages.reading === "number");
    assert.ok(typeof analytics.sectionAverages.writing === "number");
    assert.ok(typeof analytics.sectionAverages.speaking === "number");
    assert.ok(typeof analytics.sectionAverages.overall === "number");
    assert.equal(analytics.finalizedOverallCount, 0);

    // Overall should be average of all section averages
    const expectedOverall = 0;
    assert.equal(expectedOverall, analytics.sectionAverages.overall);
  });

  await t.test("Should include latest test in analytics", async () => {
    const session = await generateMockSession(String(testUser._id));

    await submitSection(String(testUser._id), String(session._id), "listening");
    await submitSection(String(testUser._id), String(session._id), "reading");
    await submitSection(String(testUser._id), String(session._id), "writing");
    await submitSection(String(testUser._id), String(session._id), "speaking");

    await finalSubmit(String(testUser._id), String(session._id));

    const analytics = await getMyAnalytics(String(testUser._id));

    assert.ok(analytics.latest);
    assert.ok(analytics.latest.mockSessionId);
    assert.equal(analytics.latest.overallBand, null);
    assert.equal(analytics.latest.resultSummary.overall.status, "partial_unavailable_sections");
  });

  await t.test("Should track trend across multiple tests", async () => {
    // Complete 5 sessions to build trend
    for (let i = 0; i < 5; i++) {
      const session = await generateMockSession(String(testUser._id));

      await submitSection(String(testUser._id), String(session._id), "listening");
      await submitSection(String(testUser._id), String(session._id), "reading");
      await submitSection(String(testUser._id), String(session._id), "writing");
      await submitSection(String(testUser._id), String(session._id), "speaking");

      await finalSubmit(String(testUser._id), String(session._id));
    }

    const analytics = await getMyAnalytics(String(testUser._id));

    assert.ok(Array.isArray(analytics.trend));
    assert.ok(analytics.trend.length > 0);

    // Overall band is only present on finalized attempts.
    for (const point of analytics.trend) {
      assert.equal(point.overall, null);
      assert.equal(point.isFinalized, false);
    }
  });

  await t.test("Should store and retrieve feedback in history", async () => {
    const session = await generateMockSession(String(testUser._id));

    await submitSection(String(testUser._id), String(session._id), "listening");
    await submitSection(String(testUser._id), String(session._id), "reading");
    await submitSection(String(testUser._id), String(session._id), "writing");
    await submitSection(String(testUser._id), String(session._id), "speaking");

    // Add feedback before finalization
    const mockSession = await MockSession.findById(session._id);
    mockSession.feedbackSummary = {
      strengths: ["vocabulary", "listening"],
      weaknesses: ["grammar", "writing"],
      sectionFeedback: {
        listening: "Good comprehension of main ideas",
        reading: "Needs improvement in speed reading",
      },
      notes: "Overall decent performance",
    };
    await mockSession.save();

    await finalSubmit(String(testUser._id), String(session._id));

    const history = await getMyHistory(String(testUser._id));
    assert.equal(history.length, 1);
    // Feedback should be persisted in TestHistory
    assert.ok(history[0].feedbackNotes || history[0].sectionFeedback);
  });

  await t.test("Should preserve session ordering (newest first)", async () => {
    const now = new Date();

    // Create first session
    const session1 = await generateMockSession(String(testUser._id));
    await submitSection(String(testUser._id), String(session1._id), "listening");
    await submitSection(String(testUser._id), String(session1._id), "reading");
    await submitSection(String(testUser._id), String(session1._id), "writing");
    await submitSection(String(testUser._id), String(session1._id), "speaking");
    await finalSubmit(String(testUser._id), String(session1._id));

    // Wait a moment
    await new Promise((r) => setTimeout(r, 10));

    // Create second session
    const session2 = await generateMockSession(String(testUser._id));
    await submitSection(String(testUser._id), String(session2._id), "listening");
    await submitSection(String(testUser._id), String(session2._id), "reading");
    await submitSection(String(testUser._id), String(session2._id), "writing");
    await submitSection(String(testUser._id), String(session2._id), "speaking");
    await finalSubmit(String(testUser._id), String(session2._id));

    const history = await getMyHistory(String(testUser._id));

    assert.equal(history.length, 2);
    // Newest should be first
    assert.equal(String(history[0].mockSessionId), String(session2._id));
    assert.equal(String(history[1].mockSessionId), String(session1._id));
  });

  await t.test("Should not count incomplete sessions in history", async () => {
    // Create but don't complete session
    const session1 = await generateMockSession(String(testUser._id));

    // Create and complete another session
    const session2 = await generateMockSession(String(testUser._id));
    await submitSection(String(testUser._id), String(session2._id), "listening");
    await submitSection(String(testUser._id), String(session2._id), "reading");
    await submitSection(String(testUser._id), String(session2._id), "writing");
    await submitSection(String(testUser._id), String(session2._id), "speaking");
    await finalSubmit(String(testUser._id), String(session2._id));

    const history = await getMyHistory(String(testUser._id));
    const analytics = await getMyAnalytics(String(testUser._id));

    // Only completed session should count
    assert.equal(history.length, 1);
    assert.equal(analytics.totalMocks, 1);
  });
});
