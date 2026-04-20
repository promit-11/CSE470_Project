/**
 * Test fixtures and utilities
 * Provides deterministic test data for all test suites
 */

import User from "../api/mvc/models/v1/User.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import Question from "../api/mvc/models/v1/Question.js";
import MockTemplate from "../api/mvc/models/v1/MockTemplate.js";
import Institute from "../api/mvc/models/v1/Institute.js";
import DiscountCode from "../api/mvc/models/v1/DiscountCode.js";
import bcrypt from "bcryptjs";

export const FIXTURE_DATA = {
  PASSWORD: "TestPassword123!",
  EMAIL_STUDENT: "student@test.local",
  EMAIL_ADMIN: "admin@test.local",
  EMAIL_COACHING: "coach@test.local",
  NAME_STUDENT: "Test Student",
  NAME_ADMIN: "Test Admin",
  NAME_COACHING: "Test Coach",
};

/**
 * Create a test user
 */
export async function createTestUser(override = {}) {
  const passwordHash = await bcrypt.hash(FIXTURE_DATA.PASSWORD, 12);
  const defaults = {
    name: FIXTURE_DATA.NAME_STUDENT,
    email: FIXTURE_DATA.EMAIL_STUDENT,
    role: "student",
    passwordHash,
    status: "active",
  };
  return User.create({ ...defaults, ...override });
}

/**
 * Create a test student profile linked to a user
 */
export async function createTestStudentProfile(user) {
  return StudentProfile.create({
    userId: user._id,
    mockAccess: {
      allowed: true,
      plan: "starter",
      remainingCredits: 10,
    },
  });
}

/**
 * Create test questions for a section
 */
export async function createTestQuestions(section, count = 5) {
  const questions = [];
  const difficulties = ["easy", "medium", "hard"];
  
  for (let i = 0; i < count; i++) {
    const difficulty = difficulties[i % 3];
    questions.push({
      section,
      difficulty,
      category: `category_${i}`,
      questionType: section === "writing" || section === "speaking" ? "essay" : "mcq",
      title: `Test ${section} question ${i + 1}`,
      content: `This is test content for ${section} question ${i + 1}`,
      options:
        section === "writing" || section === "speaking"
          ? []
          : [
              { key: "A", text: "Option A" },
              { key: "B", text: "Option B" },
              { key: "C", text: "Option C" },
              { key: "D", text: "Option D" },
            ],
      answerKey: section === "writing" || section === "speaking" ? [] : ["A"],
      explanation: "This is the explanation",
      tags: [section],
      active: true,
    });
  }

  return Question.insertMany(questions);
}

/**
 * Create test questions for all sections with consistent structure
 */
export async function createFullQuestionBank() {
  const sections = ["listening", "reading", "writing", "speaking"];
  const allQuestions = [];

  for (const section of sections) {
    const count = section === "writing" || section === "speaking" ? 5 : 100;
    const questions = await createTestQuestions(section, count);
    allQuestions.push(...questions);
  }

  return allQuestions;
}

/**
 * Create a test mock template
 */
export async function createTestTemplate(override = {}) {
  const defaults = {
    name: "Test Template",
    examType: "academic",
    sectionOrder: ["listening", "reading", "writing", "speaking"],
    difficultyDistribution: {
      easy: 0.3,
      medium: 0.4,
      hard: 0.3,
    },
    sectionQuestionCount: {
      listening: 40,
      reading: 40,
      writing: 2,
      speaking: 3,
    },
    active: true,
  };
  return MockTemplate.create({ ...defaults, ...override });
}

/**
 * Create a test institute with admin user
 */
export async function createTestInstitute(adminUser = null) {
  let admin = adminUser;
  if (!admin) {
    admin = await createTestUser({
      name: FIXTURE_DATA.NAME_COACHING,
      email: FIXTURE_DATA.EMAIL_COACHING,
      role: "coaching_admin",
    });
  }

  return Institute.create({
    name: "Test Institute",
    description: "A test coaching center",
    address: "123 Test St",
    contactEmail: admin.email,
    contactPhone: "555-0100",
    adminUserId: admin._id,
  });
}

/**
 * Create a test discount code
 */
export async function createTestDiscountCode(institute, override = {}) {
  const now = new Date();
  const defaults = {
    instituteId: institute._id,
    code: "TESTCODE10",
    discountType: "fixed",
    discountValue: 50,
    validFrom: new Date(now.getTime() - 24 * 60 * 60 * 1000), // Yesterday
    validTo: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
    usageLimit: 100,
    usedCount: 0,
    active: true,
    minMocks: 0,
  };
  return DiscountCode.create({ ...defaults, ...override });
}

/**
 * Clean up all test collections
 */
export async function cleanupDatabase() {
  await User.deleteMany({});
  await StudentProfile.deleteMany({});
  await Question.deleteMany({});
  await MockTemplate.deleteMany({});
  await Institute.deleteMany({});
  await DiscountCode.deleteMany({});
  // Note: Add more models as needed
}
