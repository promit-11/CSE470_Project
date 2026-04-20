import test from "node:test";
import assert from "node:assert/strict";
import mongoose from "mongoose";
import request from "supertest";

import app from "../api/app.js";
import User from "../api/mvc/models/v1/User.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import TeacherProfile from "../api/mvc/models/v1/TeacherProfile.js";
import Institute from "../api/mvc/models/v1/Institute.js";
import Exam from "../api/mvc/models/v1/Exam.js";
import Question from "../api/mvc/models/v1/Question.js";
import MockTemplate from "../api/mvc/models/v1/MockTemplate.js";
import MockSession from "../api/mvc/models/v1/MockSession.js";
import TestHistory from "../api/mvc/models/v1/TestHistory.js";
import EvaluationRequest from "../api/mvc/models/v1/EvaluationRequest.js";
import CoachingAssignmentRequest from "../api/mvc/models/v1/CoachingAssignmentRequest.js";
import PaymentTransaction from "../api/mvc/models/v1/PaymentTransaction.js";
import PayoutRequest from "../api/mvc/models/v1/PayoutRequest.js";
import RefreshToken from "../api/mvc/models/v1/RefreshToken.js";
import DiscountCode from "../api/mvc/models/v1/DiscountCode.js";
import {
  FIXTURE_DATA,
  createTestUser,
  createTestQuestions,
  createTestTemplate,
} from "./fixtures.js";

const API = "/api/v1";

function authHeader(token) {
  return { Authorization: `Bearer ${token}` };
}

async function connectIfNeeded() {
  if (mongoose.connection.readyState === 1) {
    return;
  }
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
    Institute.deleteMany({}),
    Exam.deleteMany({}),
    Question.deleteMany({}),
    MockTemplate.deleteMany({}),
    MockSession.deleteMany({}),
    TestHistory.deleteMany({}),
    EvaluationRequest.deleteMany({}),
    CoachingAssignmentRequest.deleteMany({}),
    PaymentTransaction.deleteMany({}),
    PayoutRequest.deleteMany({}),
    RefreshToken.deleteMany({}),
    DiscountCode.deleteMany({}),
  ]);
}

async function registerUser({ name, email, role, instituteName }) {
  const response = await request(app)
    .post(`${API}/auth/register`)
    .send({
      name,
      email,
      password: FIXTURE_DATA.PASSWORD,
      role,
      instituteName,
    });

  assert.equal(response.statusCode, 201);
  return response.body.data.user;
}

async function loginUser(email) {
  const response = await request(app)
    .post(`${API}/auth/login`)
    .send({ email, password: FIXTURE_DATA.PASSWORD });

  assert.equal(response.statusCode, 200);
  return response.body.data;
}

async function createPlatformAdminAndToken() {
  const admin = await createTestUser({
    name: "Platform Admin",
    email: "platform-admin@test.local",
    role: "platform_admin",
    status: "active",
  });
  const session = await loginUser(admin.email);
  return { admin, accessToken: session.accessToken };
}

async function approveTeacher(adminToken, teacherUserId) {
  const response = await request(app)
    .patch(`${API}/admin/teachers/${teacherUserId}/approve`)
    .set(authHeader(adminToken))
    .send({});
  assert.equal(response.statusCode, 200);
}

async function seedAppQuestionBankAndTemplate() {
  await createTestQuestions("listening", 40);
  await createTestQuestions("reading", 40);
  await createTestQuestions("writing", 4);
  await createTestQuestions("speaking", 4);
  await createTestTemplate({
    name: "Architecture Template",
    examType: "academic",
    sectionQuestionCount: {
      listening: 40,
      reading: 40,
      writing: 2,
      speaking: 3,
    },
  });
}

async function progressToSpeakingWithSubjectiveContent(studentToken, sessionId) {
  const submitListening = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(studentToken))
    .send({ section: "listening" });
  assert.equal(submitListening.statusCode, 200);

  const submitReading = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(studentToken))
    .send({ section: "reading" });
  assert.equal(submitReading.statusCode, 200);

  const writingResponse = await request(app)
    .patch(`${API}/mock-sessions/${sessionId}/writing/typed-response`)
    .set(authHeader(studentToken))
    .send({
      typedAnswer:
        "This is a valid writing submission for manual review, with clear ideas and supporting detail.",
    });
  assert.equal(writingResponse.statusCode, 200);

  const submitWriting = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/submit-section`)
    .set(authHeader(studentToken))
    .send({ section: "writing" });
  assert.equal(submitWriting.statusCode, 200);

  const speakingUpload = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/speaking/recording`)
    .set(authHeader(studentToken))
    .attach("speakingRecording", Buffer.from("RIFFTESTAUDIO"), {
      filename: "speaking.wav",
      contentType: "audio/wav",
    });
  assert.equal(speakingUpload.statusCode, 200);
}

async function createPendingAppEvaluationRequestWithTeachers() {
  const { accessToken: adminToken } = await createPlatformAdminAndToken();

  const teacherOne = await registerUser({
    name: "Teacher One",
    email: "teacher-one@test.local",
    role: "teacher",
  });
  const teacherTwo = await registerUser({
    name: "Teacher Two",
    email: "teacher-two@test.local",
    role: "teacher",
  });

  await approveTeacher(adminToken, teacherOne.id);
  await approveTeacher(adminToken, teacherTwo.id);

  const teacherOneToken = (await loginUser("teacher-one@test.local")).accessToken;
  const teacherTwoToken = (await loginUser("teacher-two@test.local")).accessToken;

  await seedAppQuestionBankAndTemplate();

  await registerUser({
    name: "Eval Student",
    email: "eval-student@test.local",
    role: "student",
  });
  const studentToken = (await loginUser("eval-student@test.local")).accessToken;

  const generateResponse = await request(app)
    .post(`${API}/mock-sessions/generate`)
    .set(authHeader(studentToken))
    .send({ sourceType: "app" });
  assert.equal(generateResponse.statusCode, 201);

  const sessionId = generateResponse.body.data._id;
  await progressToSpeakingWithSubjectiveContent(studentToken, sessionId);

  const finalSubmitResponse = await request(app)
    .post(`${API}/mock-sessions/${sessionId}/final-submit`)
    .set(authHeader(studentToken))
    .send({});
  assert.equal(finalSubmitResponse.statusCode, 200);

  const requests = finalSubmitResponse.body.data.evaluationRequests;
  assert.equal(requests.length, 2);

  return {
    adminToken,
    teacherOneToken,
    teacherTwoToken,
    evaluationRequestId: requests[0].id,
  };
}

test("Architecture Workflow Backend Suite", async (t) => {
  await t.before(async () => {
    await connectIfNeeded();
  });

  await t.beforeEach(async () => {
    await cleanupAll();
  });

  await t.after(async () => {
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  await t.test("1) teacher registration and approval", async () => {
    const { accessToken: adminToken } = await createPlatformAdminAndToken();

    const teacher = await registerUser({
      name: "Pending Teacher",
      email: "pending-teacher@test.local",
      role: "teacher",
    });
    assert.equal(teacher.approvalStatus, "pending_approval");

    const blockedLogin = await request(app)
      .post(`${API}/auth/login`)
      .send({ email: "pending-teacher@test.local", password: FIXTURE_DATA.PASSWORD });
    assert.equal(blockedLogin.statusCode, 403);

    await approveTeacher(adminToken, teacher.id);

    const approvedLogin = await request(app)
      .post(`${API}/auth/login`)
      .send({ email: "pending-teacher@test.local", password: FIXTURE_DATA.PASSWORD });
    assert.equal(approvedLogin.statusCode, 200);
    assert.equal(approvedLogin.body.data.user.approvalStatus, "approved");
  });

  await t.test("2) student registration initializes 20 test credits", async () => {
    const student = await registerUser({
      name: "Credits Student",
      email: "credits-student@test.local",
      role: "student",
    });

    const profile = await StudentProfile.findOne({ userId: student.id }).lean();
    assert.ok(profile);
    assert.equal(profile.testCredits, 20);
  });

  await t.test("3) coaching assignment request lifecycle", async () => {
    await registerUser({
      name: "Coaching Admin",
      email: "coach-admin@test.local",
      role: "coaching_admin",
      instituteName: "Bright Coaching",
    });
    const coachingToken = (await loginUser("coach-admin@test.local")).accessToken;

    const profileResponse = await request(app)
      .get(`${API}/institutes/profile`)
      .set(authHeader(coachingToken));
    assert.equal(profileResponse.statusCode, 200);
    const coachingId = profileResponse.body.data._id;

    await registerUser({
      name: "Assignment Student",
      email: "assignment-student@test.local",
      role: "student",
    });
    const studentToken = (await loginUser("assignment-student@test.local")).accessToken;

    const requestResponse = await request(app)
      .post(`${API}/students/coaching-assignment/request`)
      .set(authHeader(studentToken))
      .send({ coachingId, admissionCode: "ADM-2026" });
    assert.equal(requestResponse.statusCode, 201);
    assert.equal(requestResponse.body.data.request.status, "pending");

    const queueResponse = await request(app)
      .get(`${API}/institutes/assignment-requests?status=pending`)
      .set(authHeader(coachingToken));
    assert.equal(queueResponse.statusCode, 200);
    assert.equal(queueResponse.body.data.length, 1);

    const requestId = queueResponse.body.data[0]._id;
    const acceptResponse = await request(app)
      .patch(`${API}/institutes/assignment-requests/${requestId}/accept`)
      .set(authHeader(coachingToken))
      .send({ note: "Admission verified" });

    assert.equal(acceptResponse.statusCode, 200);
    assert.equal(acceptResponse.body.data.request.status, "accepted");

    const studentUser = await User.findOne({ email: "assignment-student@test.local" }).lean();
    const profile = await StudentProfile.findOne({ userId: studentUser._id }).lean();
    assert.equal(String(profile.coachingId), String(coachingId));
    assert.equal(profile.studentMode, "coaching_assigned");
  });

  await t.test("4) ownership restrictions for app vs coaching tests", async () => {
    const { accessToken: adminToken } = await createPlatformAdminAndToken();

    await registerUser({
      name: "Ownership Coach",
      email: "ownership-coach@test.local",
      role: "coaching_admin",
      instituteName: "Ownership Institute",
    });
    const coachingToken = (await loginUser("ownership-coach@test.local")).accessToken;

    const appExamResponse = await request(app)
      .post(`${API}/admin/exams`)
      .set(authHeader(adminToken))
      .send({ title: "App IELTS Exam", type: "academic", active: true });
    assert.equal(appExamResponse.statusCode, 201);
    const appExamId = appExamResponse.body.data._id;

    const coachingDeleteAppExam = await request(app)
      .delete(`${API}/institutes/exams/${appExamId}`)
      .set(authHeader(coachingToken));
    assert.equal(coachingDeleteAppExam.statusCode, 404);

    const coachingExamResponse = await request(app)
      .post(`${API}/institutes/exams`)
      .set(authHeader(coachingToken))
      .send({ title: "Coaching IELTS Exam", type: "general", active: true });
    assert.equal(coachingExamResponse.statusCode, 201);
    const coachingExamId = coachingExamResponse.body.data._id;

    const adminDeleteCoachingExam = await request(app)
      .delete(`${API}/admin/exams/${coachingExamId}`)
      .set(authHeader(adminToken));
    assert.equal(adminDeleteCoachingExam.statusCode, 404);
  });

  await t.test("5) final submit creates evaluation requests", async () => {
    await seedAppQuestionBankAndTemplate();

    await registerUser({
      name: "Submit Student",
      email: "submit-student@test.local",
      role: "student",
    });
    const studentToken = (await loginUser("submit-student@test.local")).accessToken;

    const generateResponse = await request(app)
      .post(`${API}/mock-sessions/generate`)
      .set(authHeader(studentToken))
      .send({ sourceType: "app" });
    assert.equal(generateResponse.statusCode, 201);

    const sessionId = generateResponse.body.data._id;
    await progressToSpeakingWithSubjectiveContent(studentToken, sessionId);

    const finalSubmitResponse = await request(app)
      .post(`${API}/mock-sessions/${sessionId}/final-submit`)
      .set(authHeader(studentToken))
      .send({});

    assert.equal(finalSubmitResponse.statusCode, 200);
    assert.equal(finalSubmitResponse.body.data.resultState.overall.status, "pending_full_review");
    assert.equal(finalSubmitResponse.body.data.evaluationRequests.length, 2);

    const dbRows = await EvaluationRequest.find({ testSessionId: sessionId }).lean();
    assert.equal(dbRows.length, 2);
    assert.deepEqual(
      dbRows.map((row) => row.section).sort(),
      ["speaking", "writing"]
    );
    assert.equal(dbRows.every((row) => row.status === "pending"), true);
  });

  await t.test("6) atomic teacher claim conflict handling", async () => {
    const setup = await createPendingAppEvaluationRequestWithTeachers();

    const [claimOne, claimTwo] = await Promise.all([
      request(app)
        .patch(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/claim`)
        .set(authHeader(setup.teacherOneToken))
        .send({}),
      request(app)
        .patch(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/claim`)
        .set(authHeader(setup.teacherTwoToken))
        .send({}),
    ]);

    const statusCodes = [claimOne.statusCode, claimTwo.statusCode].sort((a, b) => a - b);
    assert.deepEqual(statusCodes, [200, 409]);

    const row = await EvaluationRequest.findById(setup.evaluationRequestId).lean();
    assert.equal(row.status, "claimed");
    assert.ok(row.teacherId);
  });

  await t.test("7) teacher review submission", async () => {
    const setup = await createPendingAppEvaluationRequestWithTeachers();

    const claimResponse = await request(app)
      .patch(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/claim`)
      .set(authHeader(setup.teacherOneToken))
      .send({});
    assert.equal(claimResponse.statusCode, 200);

    const requestRow = await EvaluationRequest.findById(setup.evaluationRequestId).lean();
    const isWriting = requestRow.section === "writing";

    const reviewPayload = {
      overallBand: 6.5,
      comments: "Consistent structure with room to improve lexical range.",
      strengths: ["Coherence"],
      weaknesses: ["Grammar"],
      criterionScores: isWriting
        ? {
            taskResponse: 6.5,
            coherenceAndCohesion: 6.5,
            lexicalResource: 6.0,
            grammaticalRangeAndAccuracy: 6.0,
          }
        : {
            fluencyAndCoherence: 6.5,
            lexicalResource: 6.0,
            grammaticalRangeAndAccuracy: 6.0,
          },
    };

    const reviewResponse = await request(app)
      .post(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/review`)
      .set(authHeader(setup.teacherOneToken))
      .send(reviewPayload);

    assert.equal(reviewResponse.statusCode, 200);

    const reviewed = await EvaluationRequest.findById(setup.evaluationRequestId).lean();
    assert.equal(reviewed.status, "reviewed");
    assert.equal(reviewed.reviewedBandScore, 6.5);
    assert.equal(reviewed.reviewComments.length > 0, true);
  });

  await t.test("8) rewardCredits grant for app-based reviews", async () => {
    const setup = await createPendingAppEvaluationRequestWithTeachers();

    const claimResponse = await request(app)
      .patch(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/claim`)
      .set(authHeader(setup.teacherOneToken))
      .send({});
    assert.equal(claimResponse.statusCode, 200);

    const requestRow = await EvaluationRequest.findById(setup.evaluationRequestId).lean();
    const isWriting = requestRow.section === "writing";

    const reviewResponse = await request(app)
      .post(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/review`)
      .set(authHeader(setup.teacherOneToken))
      .send({
        overallBand: 7.0,
        comments: "Reviewed",
        strengths: ["Task handling"],
        weaknesses: ["Vocabulary"],
        criterionScores: isWriting
          ? {
              taskResponse: 7.0,
              coherenceAndCohesion: 7.0,
              lexicalResource: 6.5,
              grammaticalRangeAndAccuracy: 6.5,
            }
          : {
              fluencyAndCoherence: 7.0,
              lexicalResource: 6.5,
              grammaticalRangeAndAccuracy: 6.5,
            },
      });

    assert.equal(reviewResponse.statusCode, 200);
    assert.equal(reviewResponse.body.data.rewardCreditsAdded, 3);

    const claimedTeacherId = claimResponse.body.data.request.teacherId;
    const profile = await TeacherProfile.findOne({ userId: claimedTeacherId }).lean();
    assert.equal(profile.rewardCredits, 3);
  });

  await t.test("9) simulated student payment", async () => {
    const student = await registerUser({
      name: "Payment Student",
      email: "payment-student@test.local",
      role: "student",
    });
    const studentToken = (await loginUser("payment-student@test.local")).accessToken;

    const purchaseResponse = await request(app)
      .post(`${API}/students/credits/purchase`)
      .set(authHeader(studentToken))
      .send({ packageId: "starter_5" });

    assert.equal(purchaseResponse.statusCode, 201);
    assert.equal(purchaseResponse.body.data.simulated, true);
    assert.equal(purchaseResponse.body.data.package.id, "starter_5");

    const profile = await StudentProfile.findOne({ userId: student.id }).lean();
    assert.equal(profile.testCredits, 25);

    const payment = await PaymentTransaction.findOne({ studentId: student.id }).lean();
    assert.ok(payment);
    assert.equal(payment.status, "succeeded");
    assert.equal(payment.testCreditsPurchased, 5);
  });

  await t.test("10) simulated teacher payout approval", async () => {
    const setup = await createPendingAppEvaluationRequestWithTeachers();

    const claimResponse = await request(app)
      .patch(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/claim`)
      .set(authHeader(setup.teacherOneToken))
      .send({});
    assert.equal(claimResponse.statusCode, 200);

    const requestRow = await EvaluationRequest.findById(setup.evaluationRequestId).lean();
    const isWriting = requestRow.section === "writing";

    const reviewResponse = await request(app)
      .post(`${API}/teachers/evaluation-requests/${setup.evaluationRequestId}/review`)
      .set(authHeader(setup.teacherOneToken))
      .send({
        overallBand: 6.0,
        comments: "Ready for payout flow",
        strengths: ["Structure"],
        weaknesses: ["Range"],
        criterionScores: isWriting
          ? {
              taskResponse: 6.0,
              coherenceAndCohesion: 6.0,
              lexicalResource: 6.0,
              grammaticalRangeAndAccuracy: 6.0,
            }
          : {
              fluencyAndCoherence: 6.0,
              lexicalResource: 6.0,
              grammaticalRangeAndAccuracy: 6.0,
            },
      });
    assert.equal(reviewResponse.statusCode, 200);

    const payoutRequestResponse = await request(app)
      .post(`${API}/teachers/payouts/request`)
      .set(authHeader(setup.teacherOneToken))
      .send({ requestedRewardCredits: 2, note: "withdraw" });
    assert.equal(payoutRequestResponse.statusCode, 201);
    const payoutRequestId = payoutRequestResponse.body.data.payoutRequest._id;

    const approveResponse = await request(app)
      .patch(`${API}/admin/payouts/${payoutRequestId}/approve`)
      .set(authHeader(setup.adminToken))
      .send({ note: "simulated approval" });

    assert.equal(approveResponse.statusCode, 200);
    assert.equal(approveResponse.body.data.payoutRequest.status, "paid");

    const teacherId = claimResponse.body.data.request.teacherId;
    const profile = await TeacherProfile.findOne({ userId: teacherId }).lean();
    assert.equal(profile.rewardCredits, 1);

    const payout = await PayoutRequest.findById(payoutRequestId).lean();
    assert.equal(payout.status, "paid");
  });
});
