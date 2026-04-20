/**
 * Section Submission & Scoring Tests
 * Covers: answer submission, flagging, section timeout, listening/reading scoring, final submission
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
import {
  generateMockSession,
  saveAnswer,
  markQuestion,
  submitSection,
  finalSubmit,
} from "../api/mvc/services/v1/mock-service.js";
import MockSession from "../api/mvc/models/v1/MockSession.js";
import Question from "../api/mvc/models/v1/Question.js";
import TestHistory from "../api/mvc/models/v1/TestHistory.js";

test("Submission & Scoring Suite", async (t) => {
  let testUser, testProfile, testSession;

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

    testUser = await createTestUser({ email: "subtest@example.com" });
    testProfile = await createTestStudentProfile(testUser);
    await createFullQuestionBank();
    await createTestTemplate();

    testSession = await generateMockSession(String(testUser._id));
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("Should save answer for current section", async () => {
    const section = "listening";
    const questionId = testSession.sections[0].questionIds[0];

    const result = await saveAnswer(String(testUser._id), String(testSession._id), section, String(questionId), "A");

    assert.ok(result.ok);

    const updated = await MockSession.findById(testSession._id);
    const listeningSection = updated.sections[0];
    const answer = listeningSection.answers[0];

    assert.equal(answer.value, "A");
    assert.equal(listeningSection.status, "in_progress");
    assert.ok(listeningSection.startedAt);
  });

  await t.test("Should reject answer for non-current section", async () => {
    try {
      const readingQuestionId = testSession.sections[1].questionIds[0];
      await saveAnswer(String(testUser._id), String(testSession._id), "reading", String(readingQuestionId), "B");
      assert.fail("Should have thrown error");
    } catch (error) {
      assert.match(error.message, /Only the current IELTS section can be modified/);
    }
  });

  await t.test("Should flag and unflag question", async () => {
    const section = "listening";
    const questionId = testSession.sections[0].questionIds[0];

    // Flag
    await markQuestion(String(testUser._id), String(testSession._id), section, String(questionId), true);

    let updated = await MockSession.findById(testSession._id);
    let answer = updated.sections[0].answers[0];
    assert.equal(answer.flagged, true);

    // Unflag
    await markQuestion(String(testUser._id), String(testSession._id), section, String(questionId), false);

    updated = await MockSession.findById(testSession._id);
    answer = updated.sections[0].answers[0];
    assert.equal(answer.flagged, false);
  });

  await t.test("Should submit section and move to next", async () => {
    const section = "listening";
    const questionIds = testSession.sections[0].questionIds;

    // Submit all answers
    for (let i = 0; i < Math.min(3, questionIds.length); i++) {
      await saveAnswer(String(testUser._id), String(testSession._id), section, String(questionIds[i]), "A");
    }

    // Submit section
    const result = await submitSection(String(testUser._id), String(testSession._id), section);

    assert.ok(result);

    const updated = await MockSession.findById(testSession._id);
    assert.equal(updated.sections[0].status, "submitted");
    assert.ok(updated.sections[0].submittedAt);
    assert.equal(updated.currentSection, "reading");
  });

  await t.test("Should calculate correct listening score", async () => {
    const section = "listening";
    const questionIds = testSession.sections[0].questionIds;

    // Get correct answers for listening questions
    const allQuestions = await Question.find({ section: "listening" });
    const questionMap = new Map(allQuestions.map((q) => [String(q._id), q]));

    // Answer first 30 questions correctly
    for (let i = 0; i < Math.min(30, questionIds.length); i++) {
      const qId = questionIds[i];
      const question = questionMap.get(String(qId));
      const correctAnswer = question?.answerKey?.[0] || "A";
      await saveAnswer(String(testUser._id), String(testSession._id), section, String(qId), correctAnswer);
    }

    // Submit section
    await submitSection(String(testUser._id), String(testSession._id), section);

    const updated = await MockSession.findById(testSession._id);
    const listeningSection = updated.sections[0];

    // Listening band scale: 30+ correct = 7.0 or higher
    assert.ok(typeof listeningSection.rawScore === "number");
    assert.ok(listeningSection.rawScore >= 25);
    assert.ok(typeof listeningSection.bandScore === "number");
    assert.ok(listeningSection.bandScore >= 6.5);
  });

  await t.test("Should calculate correct reading score", async () => {
    // Move to reading section
    await submitSection(String(testUser._id), String(testSession._id), "listening");

    const section = "reading";
    const questionIds = testSession.sections[1].questionIds;

    const allQuestions = await Question.find({ section: "reading" });
    const questionMap = new Map(allQuestions.map((q) => [String(q._id), q]));

    // Answer most questions correctly
    for (let i = 0; i < Math.min(35, questionIds.length); i++) {
      const qId = questionIds[i];
      const question = questionMap.get(String(qId));
      const correctAnswer = question?.answerKey?.[0] || "A";
      await saveAnswer(String(testUser._id), String(testSession._id), section, String(qId), correctAnswer);
    }

    // Submit section
    await submitSection(String(testUser._id), String(testSession._id), section);

    const updated = await MockSession.findById(testSession._id);
    const readingSection = updated.sections[1];

    assert.ok(typeof readingSection.rawScore === "number");
    assert.ok(readingSection.rawScore >= 30);
    assert.ok(typeof readingSection.bandScore === "number");
    assert.ok(readingSection.bandScore >= 7.0);
  });

  await t.test("Should handle writing section submission (essay)", async () => {
    // Move to writing section
    await submitSection(String(testUser._id), String(testSession._id), "listening");
    await submitSection(String(testUser._id), String(testSession._id), "reading");

    const section = "writing";
    const questionIds = testSession.sections[2].questionIds;

    // For writing, submit text response
    for (const qId of questionIds) {
      await saveAnswer(
        String(testUser._id),
        String(testSession._id),
        section,
        String(qId),
        "This is my essay response for the writing task. It demonstrates my ability to write in English."
      );
    }

    // Submit section
    const result = await submitSection(String(testUser._id), String(testSession._id), section);
    assert.ok(result);

    const updated = await MockSession.findById(testSession._id);
    const writingSection = updated.sections[2];

    assert.equal(writingSection.status, "submitted");
    assert.ok(writingSection.submittedAt);
    // Writing gets band score 0 (requires manual grading)
    assert.equal(writingSection.bandScore, 0);
  });

  await t.test("Should handle speaking section submission", async () => {
    // Move to speaking section
    await submitSection(String(testUser._id), String(testSession._id), "listening");
    await submitSection(String(testUser._id), String(testSession._id), "reading");
    await submitSection(String(testUser._id), String(testSession._id), "writing");

    const section = "speaking";
    const questionIds = testSession.sections[3].questionIds;

    // For speaking, submit text response
    for (const qId of questionIds) {
      await saveAnswer(
        String(testUser._id),
        String(testSession._id),
        section,
        String(qId),
        "I would like to talk about my experience with technology. It has been very important in my life."
      );
    }

    // Submit section
    const result = await submitSection(String(testUser._id), String(testSession._id), section);
    assert.ok(result);

    const updated = await MockSession.findById(testSession._id);
    const speakingSection = updated.sections[3];

    assert.equal(speakingSection.status, "submitted");
    assert.ok(speakingSection.submittedAt);
    // Speaking gets band score 0 (requires manual grading)
    assert.equal(speakingSection.bandScore, 0);
  });

  await t.test("Should create TestHistory on final submit", async () => {
    // Complete all sections
    await submitSection(String(testUser._id), String(testSession._id), "listening");
    await submitSection(String(testUser._id), String(testSession._id), "reading");
    await submitSection(String(testUser._id), String(testSession._id), "writing");
    await submitSection(String(testUser._id), String(testSession._id), "speaking");

    // Final submit
    const result = await finalSubmit(String(testUser._id), String(testSession._id));

    assert.ok(result);

    // Check TestHistory was created
    const history = await TestHistory.findOne({ mockSessionId: testSession._id });
    assert.ok(history);
    assert.equal(String(history.studentProfileId), String(testProfile._id));
    assert.ok(typeof history.listeningBand === "number");
    assert.ok(typeof history.readingBand === "number");
    assert.equal(history.writingBand, null);
    assert.equal(history.speakingBand, null);
    assert.equal(history.overallBand, null);
    assert.equal(history.resultSummary.sections.writing.status, "not_submitted");
    assert.equal(history.resultSummary.sections.speaking.status, "not_submitted");
    assert.equal(result.evaluationRequests.length, 0);
  });

  await t.test("Should keep overall pending when subjective submissions are missing", async () => {
    // Complete all sections with good scores
    await submitSection(String(testUser._id), String(testSession._id), "listening");
    await submitSection(String(testUser._id), String(testSession._id), "reading");
    await submitSection(String(testUser._id), String(testSession._id), "writing");
    await submitSection(String(testUser._id), String(testSession._id), "speaking");

    await finalSubmit(String(testUser._id), String(testSession._id));

    const history = await TestHistory.findOne({ mockSessionId: testSession._id });

    assert.equal(history.overallBand, null);
    assert.equal(history.resultSummary.overall.status, "partial_unavailable_sections");
    assert.equal(history.resultSummary.overall.isPartial, true);
  });

  await t.test("Should mark session as completed on final submit", async () => {
    // Complete all sections
    await submitSection(String(testUser._id), String(testSession._id), "listening");
    await submitSection(String(testUser._id), String(testSession._id), "reading");
    await submitSection(String(testUser._id), String(testSession._id), "writing");
    await submitSection(String(testUser._id), String(testSession._id), "speaking");

    await finalSubmit(String(testUser._id), String(testSession._id));

    const updated = await MockSession.findById(testSession._id);
    assert.equal(updated.status, "completed");
  });
});
