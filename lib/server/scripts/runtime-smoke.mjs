import request from "supertest";
import mongoose from "mongoose";
import app from "../api/app.js";

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function failWithResponse(prefix, response) {
  const msg = response?.body?.message || response?.text || "No response body";
  throw new Error(`${prefix}: ${response?.status} - ${msg}`);
}

async function main() {
  const stamp = Date.now();
  const studentEmail = `smoke.student.${stamp}@example.com`;
  const coachEmail = `smoke.coach.${stamp}@example.com`;
  const password = "StrongPass1";

  const registerStudent = await request(app).post("/api/v1/auth/register").send({
    name: "Smoke Student",
    email: studentEmail,
    password,
    role: "student",
  });
  if (registerStudent.status !== 201) {
    failWithResponse("Student register failed", registerStudent);
  }

  const registerCoach = await request(app).post("/api/v1/auth/register").send({
    name: "Smoke Coach",
    email: coachEmail,
    password,
    role: "coaching_admin",
    instituteName: "Smoke Institute",
  });
  if (registerCoach.status !== 201) {
    failWithResponse("Coach register failed", registerCoach);
  }

  const loginStudent = await request(app).post("/api/v1/auth/login").send({
    email: studentEmail,
    password,
  });
  if (loginStudent.status !== 200) {
    failWithResponse("Student login failed", loginStudent);
  }
  const studentToken = loginStudent.body?.data?.accessToken;
  assert(Boolean(studentToken), "Missing student access token");

  const loginCoach = await request(app).post("/api/v1/auth/login").send({
    email: coachEmail,
    password,
  });
  if (loginCoach.status !== 200) {
    failWithResponse("Coach login failed", loginCoach);
  }
  const coachToken = loginCoach.body?.data?.accessToken;
  assert(Boolean(coachToken), "Missing coach access token");

  const verify = await request(app)
    .post("/api/v1/institutes/students/verify")
    .set("Authorization", `Bearer ${coachToken}`)
    .send({ email: studentEmail });
  if (verify.status !== 201) {
    failWithResponse("Verify student failed", verify);
  }

  const now = new Date();
  const createDiscount = await request(app)
    .post("/api/v1/institutes/discount-codes")
    .set("Authorization", `Bearer ${coachToken}`)
    .send({
      code: `SMK${String(stamp).slice(-6)}`,
      discountType: "percentage",
      discountValue: 20,
      validFrom: now.toISOString(),
      validTo: new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000).toISOString(),
      usageLimit: 100,
      minMocks: 0,
    });
  if (createDiscount.status !== 201) {
    failWithResponse("Create discount failed", createDiscount);
  }

  const purchase = await request(app)
    .post("/api/v1/students/purchase-mock-access")
    .set("Authorization", `Bearer ${studentToken}`)
    .send({ packSize: 5 });
  if (purchase.status !== 201) {
    failWithResponse("Purchase failed", purchase);
  }
  const purchaseData = purchase.body?.data || {};
  assert(purchaseData.discountApplied === true, "Expected institute discount to auto-apply");

  const generate = await request(app)
    .post("/api/v1/mock-sessions/generate")
    .set("Authorization", `Bearer ${studentToken}`)
    .send({});
  if (generate.status !== 201) {
    failWithResponse("Generate session failed", generate);
  }
  const session = generate.body?.data;
  assert(session?._id, "Missing generated session id");

  const currentSection = session.currentSection;
  const section = (session.sections || []).find((s) => s.section === currentSection);
  assert(section, "Current section not found");
  const firstQuestion = (section.questions || [])[0];
  assert(firstQuestion?._id, "No question available in current section");

  const answerValue = (firstQuestion.options || []).length
    ? firstQuestion.options[0].key
    : "Smoke response";

  const answer = await request(app)
    .post(`/api/v1/mock-sessions/${session._id}/answer`)
    .set("Authorization", `Bearer ${studentToken}`)
    .send({
      section: currentSection,
      questionId: firstQuestion._id,
      value: answerValue,
    });
  if (answer.status !== 200) {
    failWithResponse("Save answer failed", answer);
  }

  const mark = await request(app)
    .post(`/api/v1/mock-sessions/${session._id}/mark`)
    .set("Authorization", `Bearer ${studentToken}`)
    .send({
      section: currentSection,
      questionId: firstQuestion._id,
      flagged: true,
    });
  if (mark.status !== 200) {
    failWithResponse("Mark question failed", mark);
  }

  const submitSection = await request(app)
    .post(`/api/v1/mock-sessions/${session._id}/submit-section`)
    .set("Authorization", `Bearer ${studentToken}`)
    .send({
      section: currentSection,
      autoSubmitted: false,
    });
  if (submitSection.status !== 200) {
    failWithResponse("Submit section failed", submitSection);
  }

  const finalSubmit = await request(app)
    .post(`/api/v1/mock-sessions/${session._id}/final-submit`)
    .set("Authorization", `Bearer ${studentToken}`)
    .send({});
  if (finalSubmit.status !== 200) {
    failWithResponse("Final submit failed", finalSubmit);
  }

  const completed = finalSubmit.body?.data;
  assert(completed?.status === "completed", "Session was not completed after final submit");

  console.log("Runtime smoke completed successfully.");
  console.log(
    JSON.stringify(
      {
        studentEmail,
        coachEmail,
        discountCode: createDiscount.body?.data?.code,
        purchase: {
          discountApplied: purchaseData.discountApplied,
          discountCode: purchaseData.discountCode,
          finalAmount: purchaseData.finalAmount,
          creditsAfterPurchase: purchaseData.creditsAfterPurchase,
        },
        mockSessionId: session._id,
        overallBand: completed?.overallBand,
      },
      null,
      2
    )
  );
}

main()
  .catch((error) => {
    console.error("Runtime smoke failed:", error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await mongoose.disconnect();
    } catch (_e) {
      // no-op
    }
  });
