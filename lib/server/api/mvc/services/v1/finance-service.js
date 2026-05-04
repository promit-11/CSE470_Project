import mongoose from "mongoose";
import { randomUUID } from "crypto";
import PaymentTransaction from "../../models/v1/PaymentTransaction.js";
import PayoutRequest from "../../models/v1/PayoutRequest.js";
import StudentProfile from "../../models/v1/StudentProfile.js";
import TeacherProfile from "../../models/v1/TeacherProfile.js";
import {
  PAYMENT_TRANSACTION_STATUSES,
  PAYMENT_TRANSACTION_TYPES,
  PAYOUT_REQUEST_STATUSES,
} from "../../../constants/workflow-statuses.js";
import { HttpError } from "../../../utils/http-error.js";

const SIMULATED_PROVIDER = "simulated";
const SIMULATED_CURRENCY = "BDT";
const SIMULATED_REWARD_TO_BDT_RATE = 10;

const CREDIT_PACKAGES = [
  {
    id: "starter_5",
    label: "Starter 5 Credits",
    testCredits: 5,
    amount: 250,
    currency: SIMULATED_CURRENCY,
  },
  {
    id: "standard_12",
    label: "Standard 12 Credits",
    testCredits: 12,
    amount: 540,
    currency: SIMULATED_CURRENCY,
  },
  {
    id: "pro_25",
    label: "Pro 25 Credits",
    testCredits: 25,
    amount: 1000,
    currency: SIMULATED_CURRENCY,
  },
];

function getPackageOrThrow(packageId) {
  const selected = CREDIT_PACKAGES.find((pkg) => pkg.id === packageId);
  if (!selected) {
    throw new HttpError(422, "Invalid packageId for simulated credit purchase");
  }
  return selected;
}

export function listSimulatedCreditPackages() {
  return {
    simulated: true,
    provider: SIMULATED_PROVIDER,
    packages: CREDIT_PACKAGES,
  };
}

async function createSimulatedCreditPurchaseCore(studentUserId, selectedPackage, dbSession = null) {
  const profile = await StudentProfile.findOne({ userId: studentUserId }).session(dbSession);
  if (!profile) {
    throw new HttpError(404, "Student profile not found");
  }

  const now = new Date();
  const providerRef = `SIMPAY-${randomUUID()}`;

  const transaction = await PaymentTransaction.create(
    [
      {
        studentId: studentUserId,
        coachingId: profile.coachingId || null,
        testCreditsPurchased: selectedPackage.testCredits,
        transactionType: PAYMENT_TRANSACTION_TYPES.TEST_CREDIT_PURCHASE,
        status: PAYMENT_TRANSACTION_STATUSES.PENDING,
        amount: selectedPackage.amount,
        currency: selectedPackage.currency,
        provider: SIMULATED_PROVIDER,
        providerRef,
        initiatedAt: now,
        metadata: {
          simulated: true,
          packageId: selectedPackage.id,
          packageLabel: selectedPackage.label,
        },
      },
    ],
    dbSession ? { session: dbSession } : undefined
  );

  const payment = transaction[0];
  payment.status = PAYMENT_TRANSACTION_STATUSES.SUCCEEDED;
  payment.completedAt = now;
  payment.metadata = {
    ...(payment.metadata || {}),
    simulationResult: "success",
  };
  await payment.save(dbSession ? { session: dbSession } : undefined);

  const previousTestCredits = Number(profile.testCredits) || 0;
  const previousMockCredits = Number(profile.mockAccess?.remainingCredits) || 0;
  const creditsToAdd = selectedPackage.testCredits;

  profile.testCredits = previousTestCredits + creditsToAdd;
  profile.mockAccess = {
    ...(profile.mockAccess?.toObject?.() || profile.mockAccess || {}),
    allowed: true,
    plan: "credit_pack",
    remainingCredits: Math.max(0, previousMockCredits) + creditsToAdd,
    lastPurchasedAt: now,
  };
  await profile.save(dbSession ? { session: dbSession } : undefined);

  return {
    simulated: true,
    provider: SIMULATED_PROVIDER,
    package: selectedPackage,
    paymentTransaction: payment.toObject(),
    creditsAdded: creditsToAdd,
    balances: {
      testCredits: profile.testCredits,
      mockAccessCredits: profile.mockAccess.remainingCredits,
    },
  };
}

export async function createSimulatedCreditPurchase(studentUserId, packageId) {
  const selectedPackage = getPackageOrThrow(packageId);
  const dbSession = await mongoose.startSession();

  try {
    try {
      let result;
      await dbSession.withTransaction(async () => {
        result = await createSimulatedCreditPurchaseCore(studentUserId, selectedPackage, dbSession);
      });
      return result;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return createSimulatedCreditPurchaseCore(studentUserId, selectedPackage, null);
    }
  } finally {
    await dbSession.endSession();
  }
}

export async function listStudentPaymentTransactions(studentUserId) {
  return PaymentTransaction.find({ studentId: studentUserId })
    .sort({ createdAt: -1 })
    .lean();
}

async function createTeacherPayoutRequestCore(teacherUserId, credits, note, dbSession = null) {
  const teacherProfile = await TeacherProfile.findOne({ userId: teacherUserId })
    .session(dbSession)
    .lean();
  if (!teacherProfile) {
    throw new HttpError(404, "Teacher profile not found");
  }

  const pending = await PayoutRequest.findOne({
    teacherId: teacherUserId,
    status: PAYOUT_REQUEST_STATUSES.PENDING,
  })
    .session(dbSession)
    .lean();

  if (pending) {
    throw new HttpError(409, "You already have a pending payout request");
  }

  if ((teacherProfile.rewardCredits || 0) < credits) {
    throw new HttpError(409, "Insufficient rewardCredits for payout request");
  }

  const payoutAmount = credits * SIMULATED_REWARD_TO_BDT_RATE;
  const payout = await PayoutRequest.insertMany(
    [
      {
        teacherId: teacherUserId,
        coachingId: teacherProfile.coachingId || null,
        requestedRewardCredits: credits,
        conversionRate: SIMULATED_REWARD_TO_BDT_RATE,
        payoutAmount,
        currency: SIMULATED_CURRENCY,
        status: PAYOUT_REQUEST_STATUSES.PENDING,
        note: `SIMULATED_PAYOUT_REQUEST${note ? ` | ${note}` : ""}`,
        provider: SIMULATED_PROVIDER,
        providerRef: `SIMPAYOUT-${randomUUID()}`,
        metadata: {
          simulated: true,
          createdBy: "teacher",
        },
      },
    ],
    dbSession ? { session: dbSession } : undefined
  );

  return {
    simulated: true,
    payoutRequest: payout[0].toObject(),
    availableRewardCredits: teacherProfile.rewardCredits,
  };
}

export async function createTeacherPayoutRequest(teacherUserId, requestedRewardCredits, note = "") {
  const credits = Number(requestedRewardCredits);
  if (!Number.isFinite(credits) || credits <= 0) {
    throw new HttpError(422, "requestedRewardCredits must be a positive number");
  }

  const dbSession = await mongoose.startSession();

  try {
    try {
      let result;
      await dbSession.withTransaction(async () => {
        result = await createTeacherPayoutRequestCore(teacherUserId, credits, note, dbSession);
      });
      return result;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return createTeacherPayoutRequestCore(teacherUserId, credits, note, null);
    }
  } finally {
    await dbSession.endSession();
  }
}

export async function listTeacherPayoutRequests(teacherUserId) {
  return PayoutRequest.find({ teacherId: teacherUserId })
    .sort({ createdAt: -1 })
    .lean();
}

async function approveSimulatedPayoutByAdminCore(adminUserId, payoutRequestId, note = "", dbSession = null) {
  const payout = await PayoutRequest.findOne({
    _id: payoutRequestId,
    status: PAYOUT_REQUEST_STATUSES.PENDING,
  }).session(dbSession);

  if (!payout) {
    const existing = await PayoutRequest.findById(payoutRequestId).session(dbSession).lean();
    if (!existing) {
      throw new HttpError(404, "Payout request not found");
    }
    throw new HttpError(409, "Payout request is no longer pending");
  }

  const teacherProfile = await TeacherProfile.findOne({ userId: payout.teacherId }).session(dbSession);
  if (!teacherProfile) {
    throw new HttpError(404, "Teacher profile not found");
  }

  if ((teacherProfile.rewardCredits || 0) < payout.requestedRewardCredits) {
    throw new HttpError(409, "Teacher does not have enough rewardCredits to settle this payout");
  }

  teacherProfile.rewardCredits = Math.max(
    0,
    (teacherProfile.rewardCredits || 0) - payout.requestedRewardCredits
  );
  await teacherProfile.save(dbSession ? { session: dbSession } : undefined);

  const now = new Date();
  payout.status = PAYOUT_REQUEST_STATUSES.PAID;
  payout.processedByUserId = adminUserId;
  payout.processedAt = now;
  payout.paidAt = now;
  payout.note = `SIMULATED_PAYOUT_SUCCESS${note ? ` | ${note}` : ""}`;
  payout.provider = SIMULATED_PROVIDER;
  payout.metadata = {
    ...(payout.metadata || {}),
    simulated: true,
    simulationResult: "success",
  };
  await payout.save(dbSession ? { session: dbSession } : undefined);

  return {
    simulated: true,
    payoutRequest: payout.toObject(),
    teacherRewardCreditsAfter: teacherProfile.rewardCredits,
  };
}

export async function approveSimulatedPayoutByAdmin(adminUserId, payoutRequestId, note = "") {
  const dbSession = await mongoose.startSession();

  try {
    try {
      let result;
      await dbSession.withTransaction(async () => {
        result = await approveSimulatedPayoutByAdminCore(adminUserId, payoutRequestId, note, dbSession);
      });
      return result;
    } catch (error) {
      const message = error?.message || "";
      const isStandaloneMongo =
        message.includes("Transaction numbers are only allowed on a replica set member or mongos") ||
        message.includes("replica set member or mongos");

      if (!isStandaloneMongo) {
        throw error;
      }

      return approveSimulatedPayoutByAdminCore(adminUserId, payoutRequestId, note, null);
    }
  } finally {
    await dbSession.endSession();
  }
}

export async function rejectPayoutByAdmin(adminUserId, payoutRequestId, reason = "") {
  const payout = await PayoutRequest.findOne({
    _id: payoutRequestId,
    status: PAYOUT_REQUEST_STATUSES.PENDING,
  });

  if (!payout) {
    const existing = await PayoutRequest.findById(payoutRequestId).lean();
    if (!existing) {
      throw new HttpError(404, "Payout request not found");
    }
    throw new HttpError(409, "Payout request is no longer pending");
  }

  const now = new Date();
  payout.status = PAYOUT_REQUEST_STATUSES.REJECTED;
  payout.processedByUserId = adminUserId;
  payout.processedAt = now;
  payout.note = `SIMULATED_PAYOUT_REJECTED${reason ? ` | ${reason}` : ""}`;
  payout.provider = SIMULATED_PROVIDER;
  payout.metadata = {
    ...(payout.metadata || {}),
    simulated: true,
    simulationResult: "rejected",
  };
  await payout.save();

  return {
    simulated: true,
    payoutRequest: payout.toObject(),
  };
}
