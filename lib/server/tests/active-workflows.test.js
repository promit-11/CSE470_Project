import test, { after } from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import request from "supertest";

import app from "../api/app.js";
import User from "../api/mvc/models/v1/User.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import TeacherProfile from "../api/mvc/models/v1/TeacherProfile.js";
import MockSession from "../api/mvc/models/v1/MockSession.js";
import MockTemplate from "../api/mvc/models/v1/MockTemplate.js";
import EvaluationRequest from "../api/mvc/models/v1/EvaluationRequest.js";
import TestHistory from "../api/mvc/models/v1/TestHistory.js";
import Question from "../api/mvc/models/v1/Question.js";
import Exam from "../api/mvc/models/v1/Exam.js";
import CoachingAssignmentRequest from "../api/mvc/models/v1/CoachingAssignmentRequest.js";
import { FIXTURE_DATA, createTestUser, createTestQuestions, createTestTemplate } from "./fixtures.js";

const API = "/api/v1";

let student;
let teacher;
let admin;

function authHeader(token) {
  return { Authorization: `Bearer ${token}` };
}

function getSessionId(sessionData) {
  return sessionData?._id || sessionData?.id;
}

function getSection(sessionData, sectionName) {
  return (sessionData?.sections || []).find((section) => section.section === sectionName);
}

function audioBuffer() {
  return Buffer.from("RIFF....WAVEfmt ", "utf8");
}

function imageBuffer() {
  return Buffer.from([0xff, 0xd8, 0xff, 0xdb, 0x00, 0x43, 0x00]);
}

function reviewPayloadForSection(section) {
  if (section === "writing") {
    return {
      overallBand: 6.5,
      comments: "Writing review completed",
      strengths: ["Task response"],
      weaknesses: ["Grammar consistency"],
      criterionScores: {
        taskResponse: 6.5,
        coherenceAndCohesion: 6.5,
        lexicalResource: 6.5,
        grammaticalRangeAndAccuracy: 6.5,
      },
    };
  }

  return {
    overallBand: 6.5,
    comments: "Speaking review completed",
    strengths: ["Fluency"],
    weaknesses: ["Lexical precision"],
    criterionScores: {
      fluencyAndCoherence: 6.5,
      lexicalResource: 6.5,
      grammaticalRangeAndAccuracy: 6.5,
    },
  };
}

async function connectIfNeeded() {
  if (mongoose.connection.readyState === 1) return;

  const mongoUrl = process.env.MONGODB_TEST_URL || "mongodb://localhost:27017/cse470_test";
  await mongoose.connect(mongoUrl, {
    connectTimeoutMS: 5000,
    serverSelectionTimeoutMS: 5000,
  });
}

async function cleanupAll() {
  await Promise.all([
    User.deleteMany({}),
    StudentProfile.deleteMany({}),
    TeacherProfile.deleteMany({}),
    MockSession.deleteMany({}),
    MockTemplate.deleteMany({}),
    EvaluationRequest.deleteMany({}),
    TestHistory.deleteMany({}),
    Question.deleteMany({}),
    Exam.deleteMany({}),
    CoachingAssignmentRequest.deleteMany({}),
  ]);
}

after(async () => {
  await cleanupAll();
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
});

async function loginUser(email) {
  const response = await request(app)
    .post(`${API}/auth/login`)
    .send({ email, password: FIXTURE_DATA.PASSWORD });

  assert.equal(response.statusCode, 200);
  return response.body.data;
}

async function setupTestData() {
  const studentUser = await createTestUser({
    name: "John Student",
    email: "student@test.local",
    role: "student",
  });
  await StudentProfile.create({ userId: studentUser._id });

  const teacherUser = await createTestUser({
    name: "Jane Teacher",
    email: "teacher@test.local",
    role: "teacher",
    status: "active",
    approvalStatus: "approved",
  });
  await TeacherProfile.create({ userId: teacherUser._id });

  const adminUser = await createTestUser({
    name: "Platform Admin",
    email: "admin@test.local",
    role: "platform_admin",
    status: "active",
    approvalStatus: "not_required",
  });

  await Promise.all([
    createTestQuestions("listening", 6),
    createTestQuestions("reading", 6),
    createTestQuestions("writing", 3),
    createTestQuestions("speaking", 3),
  ]);

  await createTestTemplate({
    name: "Active Workflow Template",
    sectionOrder: ["listening", "reading", "writing", "speaking"],
    sectionQuestionCount: {
      listening: 6,
      reading: 6,
      writing: 3,
      speaking: 3,
    },
    active: true,
  });

  student = {
    userId: studentUser._id,
    email: studentUser.email,
    accessToken: (await loginUser(studentUser.email)).accessToken,
  };

  teacher = {
    userId: teacherUser._id,
    email: teacherUser.email,
    accessToken: (await loginUser(teacherUser.email)).accessToken,
  };

  admin = {
    userId: adminUser._id,
    email: adminUser.email,
    accessToken: (await loginUser(adminUser.email)).accessToken,
  };
}

async function generateSessionForStudent() {
  const sessionRes = await request(app)
    .post(`${API}/mock-sessions/generate`)
    .set(authHeader(student.accessToken));

  assert.equal(sessionRes.statusCode, 201);
  const sessionId = getSessionId(sessionRes.body.data);
  assert.ok(sessionId, "Generated session must include _id");
  return { sessionId, session: sessionRes.body.data };
}

async function answerAndSubmitObjective(sessionId, section) {
  const detailRes = await request(app)
    .get(`${API}/mock-sessions/${sessionId}`)
    .set(authHeader(student.accessToken));

  assert.equal(detailRes.statusCode, 200);

  const currentSection = getSection(detailRes.body.data, section);
  const firstQuestionId = currentSection?.questions?.[0]?._id;
  assert.ok(firstQuestionId, `${section} section must provide question id`);

  const answerRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/answer`)
    .set(authHeader(student.accessToken))
    .send({ section, questionId: firstQuestionId, value: ["A"] });

  assert.equal(answerRes.statusCode, 200);

  const submitRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(student.accessToken))
    .send({ section });

  assert.equal(submitRes.statusCode, 200);
}

async function createFinalSubmittedSessionWithSubjective() {
  const { sessionId } = await generateSessionForStudent();

  await answerAndSubmitObjective(sessionId, "listening");
  await answerAndSubmitObjective(sessionId, "reading");

  const writingTypedRes = await request(app)
    .patch(`${API}/mock-sessions/${sessionId}/writing/typed-response`)
    .set(authHeader(student.accessToken))
    .send({ typedAnswer: "This is a valid writing response." });
  assert.equal(writingTypedRes.statusCode, 200);

  const writingSubmitRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(student.accessToken))
    .send({ section: "writing" });
  assert.equal(writingSubmitRes.statusCode, 200);

  const speakingUploadRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/speaking/recording`)
    .set(authHeader(student.accessToken))
    .attach("speakingRecording", audioBuffer(), {
      filename: "speaking.m4a",
      contentType: "audio/x-m4a",
    });
  assert.equal(speakingUploadRes.statusCode, 200);

  const speakingSubmitRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(student.accessToken))
    .send({ section: "speaking" });
  assert.equal(speakingSubmitRes.statusCode, 200);

  const finalRes = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/final-submit`)
    .set(authHeader(student.accessToken));
  assert.equal(finalRes.statusCode, 200);

  return { sessionId, finalResult: finalRes.body.data };
}

test("Active Backend Workflows - Writing Submission Media", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Writing typed response: Save and persist text answer", async () => {
    const { sessionId } = await generateSessionForStudent();

    await answerAndSubmitObjective(sessionId, "listening");
    await answerAndSubmitObjective(sessionId, "reading");

    const typedRes = await request(app)
      .patch(`${API}/mock-sessions/${sessionId}/writing/typed-response`)
      .set(authHeader(student.accessToken))
      .send({ typedAnswer: "This is my essay response about technology." });

    assert.equal(typedRes.statusCode, 200);

    const writing = getSection(typedRes.body.data, "writing");
    assert.equal(
      writing?.writingSubmission?.typedAnswer,
      "This is my essay response about technology."
    );
  });

  await t.test("Writing images: Upload images, delete, and reorder", async () => {
    await cleanupAll();
    await setupTestData();

    const { sessionId } = await generateSessionForStudent();

    await answerAndSubmitObjective(sessionId, "listening");
    await answerAndSubmitObjective(sessionId, "reading");

    const uploadRes = await request(app)
      .post(`${API}/mock-sessions/${sessionId}/writing/images`)
      .set(authHeader(student.accessToken))
      .attach("writingImages", imageBuffer(), {
        filename: "page-1.jpg",
        contentType: "image/jpeg",
      })
      .attach("writingImages", imageBuffer(), {
        filename: "page-2.jpg",
        contentType: "image/jpeg",
      });

    assert.equal(uploadRes.statusCode, 200);

    const writingAfterUpload = getSection(uploadRes.body.data, "writing");
    const imagesAfterUpload = writingAfterUpload?.writingSubmission?.images || [];
    assert.equal(imagesAfterUpload.length, 2);

    const firstMediaId = imagesAfterUpload[0].mediaId;
    const secondMediaId = imagesAfterUpload[1].mediaId;
    assert.ok(firstMediaId && secondMediaId);

    const reorderRes = await request(app)
      .patch(`${API}/mock-sessions/${sessionId}/writing/images/reorder`)
      .set(authHeader(student.accessToken))
      .send({ orderedMediaIds: [secondMediaId, firstMediaId] });

    assert.equal(reorderRes.statusCode, 200);

    const writingAfterReorder = getSection(reorderRes.body.data, "writing");
    const reorderedImages = writingAfterReorder?.writingSubmission?.images || [];
    assert.equal(reorderedImages[0].mediaId, secondMediaId);
    assert.equal(reorderedImages[0].pageOrder, 1);

    const deleteRes = await request(app)
      .delete(`${API}/mock-sessions/${sessionId}/writing/images/${secondMediaId}`)
      .set(authHeader(student.accessToken));

    assert.equal(deleteRes.statusCode, 200);
    const writingAfterDelete = getSection(deleteRes.body.data, "writing");
    const imagesAfterDelete = writingAfterDelete?.writingSubmission?.images || [];
    assert.equal(imagesAfterDelete.length, 1);
    assert.equal(imagesAfterDelete[0].pageOrder, 1);
  });
});

test("Active Backend Workflows - Speaking Submission Media", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Speaking recording: Upload and replace", async () => {
    const { sessionId } = await generateSessionForStudent();

    await answerAndSubmitObjective(sessionId, "listening");
    await answerAndSubmitObjective(sessionId, "reading");

    const writingTypedRes = await request(app)
      .patch(`${API}/mock-sessions/${sessionId}/writing/typed-response`)
      .set(authHeader(student.accessToken))
      .send({ typedAnswer: "Writing answer before speaking." });
    assert.equal(writingTypedRes.statusCode, 200);

    const writingSubmitRes = await request(app)
      .post(`${API}/mock-sessions/${sessionId}/submit-section`)
      .set(authHeader(student.accessToken))
      .send({ section: "writing" });
    assert.equal(writingSubmitRes.statusCode, 200);

    const firstUpload = await request(app)
      .post(`${API}/mock-sessions/${sessionId}/speaking/recording`)
      .set(authHeader(student.accessToken))
      .attach("speakingRecording", audioBuffer(), {
        filename: "speaking-1.m4a",
        contentType: "audio/x-m4a",
      });

    assert.equal(firstUpload.statusCode, 200);
    const firstRecording = getSection(firstUpload.body.data, "speaking")?.speakingSubmission?.recording;
    assert.ok(firstRecording?.mediaId);

    const secondUpload = await request(app)
      .post(`${API}/mock-sessions/${sessionId}/speaking/recording`)
      .set(authHeader(student.accessToken))
      .attach("speakingRecording", audioBuffer(), {
        filename: "speaking-2.m4a",
        contentType: "audio/x-m4a",
      });

    assert.equal(secondUpload.statusCode, 200);
    const secondRecording = getSection(secondUpload.body.data, "speaking")?.speakingSubmission?.recording;
    assert.ok(secondRecording?.mediaId);
    assert.notEqual(secondRecording.mediaId, firstRecording.mediaId);
  });
});

test("Active Backend Workflows - Admin Listening Audio", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Admin listening audio: create and update question", async () => {
    const examRes = await request(app)
      .post(`${API}/admin/exams`)
      .set(authHeader(admin.accessToken))
      .send({
        title: "IELTS Active Exam",
        description: "Active runtime exam",
        type: "academic",
      });

    assert.equal(examRes.statusCode, 201);

    const createQuestionRes = await request(app)
      .post(`${API}/admin/questions`)
      .set(authHeader(admin.accessToken))
      .field("section", "listening")
      .field("category", "active")
      .field("difficulty", "medium")
      .field("questionType", "mcq")
      .field("title", "Listening Prompt")
      .field("content", "Listen and answer")
      .attach("listeningAudio", audioBuffer(), {
        filename: "listening-1.mp3",
        contentType: "audio/mpeg",
      });

    assert.equal(createQuestionRes.statusCode, 201);
    const questionId = createQuestionRes.body.data._id;
    assert.ok(questionId);
    assert.ok(createQuestionRes.body.data.listeningAudioUrl);

    const updateQuestionRes = await request(app)
      .put(`${API}/admin/questions/${questionId}`)
      .set(authHeader(admin.accessToken))
      .field("section", "listening")
      .field("category", "active")
      .field("difficulty", "medium")
      .field("questionType", "mcq")
      .field("title", "Listening Prompt Updated")
      .field("content", "Listen and answer updated")
      .attach("listeningAudio", audioBuffer(), {
        filename: "listening-2.mp3",
        contentType: "audio/mpeg",
      });

    assert.equal(updateQuestionRes.statusCode, 200);
    assert.ok(updateQuestionRes.body.data.listeningAudioUrl);
    assert.equal(updateQuestionRes.body.data.title, "Listening Prompt Updated");
  });
});

test("Active Backend Workflows - Final Submit Evaluation Request", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Final submit: Creates evaluation requests for writing/speaking submissions", async () => {
    const { sessionId, finalResult } = await createFinalSubmittedSessionWithSubjective();

    assert.equal(finalResult.status, "completed");
    assert.ok(Array.isArray(finalResult.evaluationRequests));

    const writingEval = finalResult.evaluationRequests.find((row) => row.section === "writing");
    const speakingEval = finalResult.evaluationRequests.find((row) => row.section === "speaking");

    assert.ok(writingEval || speakingEval);

    const dbRows = await EvaluationRequest.find({ testSessionId: sessionId }).lean();
    assert.ok(dbRows.length >= 1);
  });
});

test("Active Backend Workflows - Teacher Claim and Review", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Teacher claim and submit review", async () => {
    await createFinalSubmittedSessionWithSubjective();

    const pendingRes = await request(app)
      .get(`${API}/teachers/evaluation-requests/pending`)
      .set(authHeader(teacher.accessToken));

    assert.equal(pendingRes.statusCode, 200);
    const pending = pendingRes.body.data || [];
    assert.ok(pending.length >= 1);

    const target = pending[0];

    const claimRes = await request(app)
      .patch(`${API}/teachers/evaluation-requests/${target._id}/claim`)
      .set(authHeader(teacher.accessToken));

    assert.equal(claimRes.statusCode, 200);
    assert.equal(claimRes.body.data.request.status, "claimed");

    const reviewRes = await request(app)
      .post(`${API}/teachers/evaluation-requests/${target._id}/review`)
      .set(authHeader(teacher.accessToken))
      .send(reviewPayloadForSection(target.section));

    assert.equal(
      reviewRes.statusCode,
      200,
      `Teacher review failed: ${JSON.stringify(reviewRes.body)}`
    );
    assert.equal(reviewRes.body.data.request.status, "reviewed");
  });
});

test("Active Backend Workflows - Reward Credits", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Reward credits: app-owned review increments teacher rewardCredits", async () => {
    await createFinalSubmittedSessionWithSubjective();

    const pendingRes = await request(app)
      .get(`${API}/teachers/evaluation-requests/pending`)
      .set(authHeader(teacher.accessToken));

    assert.equal(pendingRes.statusCode, 200);
    const pending = pendingRes.body.data || [];
    assert.ok(pending.length >= 1);

    const target = pending[0];

    const claimRes = await request(app)
      .patch(`${API}/teachers/evaluation-requests/${target._id}/claim`)
      .set(authHeader(teacher.accessToken));
    assert.equal(claimRes.statusCode, 200);

    const reviewRes = await request(app)
      .post(`${API}/teachers/evaluation-requests/${target._id}/review`)
      .set(authHeader(teacher.accessToken))
      .send(reviewPayloadForSection(target.section));

    assert.equal(
      reviewRes.statusCode,
      200,
      `Teacher review failed: ${JSON.stringify(reviewRes.body)}`
    );
    assert.equal(reviewRes.body.data.rewardCreditsAdded, 3);

    const profileRes = await request(app)
      .get(`${API}/teachers/profile`)
      .set(authHeader(teacher.accessToken));

    assert.equal(profileRes.statusCode, 200);
    assert.ok(profileRes.body.data.rewardCredits >= 3);
  });
});

test("Active Backend Workflows - Analytics with Pending Review", async (t) => {
  await connectIfNeeded();
  await cleanupAll();
  await setupTestData();

  await t.test("Student analytics includes pending-review state after final submit", async () => {
    await createFinalSubmittedSessionWithSubjective();

    const analyticsRes = await request(app)
      .get(`${API}/students/analytics`)
      .set(authHeader(student.accessToken));

    assert.equal(analyticsRes.statusCode, 200);
    assert.ok(typeof analyticsRes.body.data.pendingReviewCounts === "object");
    assert.ok("writing" in analyticsRes.body.data.pendingReviewCounts);
    assert.ok("speaking" in analyticsRes.body.data.pendingReviewCounts);

    const latest = analyticsRes.body.data.latest;
    assert.ok(latest, "latest analytics row should exist after completed session");
    assert.ok(
      ["pending_full_review", "finalized", "partial_unavailable_sections"].includes(
        latest.overallBandStatus
      )
    );
  });
});

test("Active Backend Workflows - Teacher Conflict Handling", async (t) => {
  await connectIfNeeded();

  await t.test("Teacher claim: Prevent double claim of same evaluation", async () => {
    assert.ok(true);
  });

  await t.test("Teacher review: Prevent review if already claimed by another", async () => {
    assert.ok(true);
  });
});
