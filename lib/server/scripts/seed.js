import bcrypt from "bcryptjs";
import env from "../api/config/env.js";
import { connectDatabase } from "../api/config/database.js";
import User from "../api/mvc/models/v1/User.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import Institute from "../api/mvc/models/v1/Institute.js";
import MockTemplate from "../api/mvc/models/v1/MockTemplate.js";
import Question from "../api/mvc/models/v1/Question.js";

async function seed() {
  await connectDatabase();

  const adminPasswordHash = await bcrypt.hash(env.platformAdminSeedPassword, 12);
  const admin = await User.findOneAndUpdate(
    { email: env.platformAdminSeedEmail.toLowerCase() },
    {
      name: "Platform Admin",
      email: env.platformAdminSeedEmail.toLowerCase(),
      passwordHash: adminPasswordHash,
      role: "platform_admin",
      status: "active",
    },
    { upsert: true, new: true }
  );

  const studentPasswordHash = await bcrypt.hash("Student@123", 12);
  const student = await User.findOneAndUpdate(
    { email: "student1@demo.com" },
    {
      name: "Demo Student",
      email: "student1@demo.com",
      passwordHash: studentPasswordHash,
      role: "student",
      status: "active",
    },
    { upsert: true, new: true }
  );
  await StudentProfile.findOneAndUpdate(
    { userId: student._id },
    { userId: student._id, targetBand: 7, strengths: [], weaknesses: [] },
    { upsert: true, new: true }
  );

  const coachPasswordHash = await bcrypt.hash("Coach@123", 12);
  const coach = await User.findOneAndUpdate(
    { email: "coach1@demo.com" },
    {
      name: "Demo Coach",
      email: "coach1@demo.com",
      passwordHash: coachPasswordHash,
      role: "coaching_admin",
      status: "active",
    },
    { upsert: true, new: true }
  );

  await Institute.findOneAndUpdate(
    { adminUserId: coach._id },
    {
      name: "Bright IELTS Academy",
      description: "Official coaching partner",
      address: "Dhaka, Bangladesh",
      contactEmail: "coach1@demo.com",
      contactPhone: "+880123456789",
      adminUserId: coach._id,
    },
    { upsert: true, new: true }
  );

  await MockTemplate.findOneAndUpdate(
    { name: "Default Academic" },
    { name: "Default Academic", examType: "academic", active: true },
    { upsert: true, new: true }
  );

  const sampleQuestions = [
    {
      section: "listening",
      category: "part_1",
      difficulty: "easy",
      questionType: "mcq",
      title: "Listening Q1",
      content: "Choose the correct booking date.",
      options: [
        { key: "A", text: "12th May" },
        { key: "B", text: "13th May" },
        { key: "C", text: "14th May" },
      ],
      answerKey: ["B"],
      explanation: "The speaker confirms 13th May.",
      tags: ["booking"],
      source: "seed",
      instruction: "Select one answer",
      active: true,
    },
    {
      section: "reading",
      category: "passage_1",
      difficulty: "easy",
      questionType: "mcq",
      title: "Reading Q1",
      content: "What is the main cause of decline?",
      options: [
        { key: "A", text: "Climate" },
        { key: "B", text: "Overfishing" },
        { key: "C", text: "Tourism" },
      ],
      answerKey: ["B"],
      explanation: "Paragraph 3 highlights overfishing.",
      tags: ["environment"],
      source: "seed",
      instruction: "Select one answer",
      active: true,
    },
    {
      section: "writing",
      category: "task_2",
      difficulty: "medium",
      questionType: "essay",
      title: "Writing Task 2",
      content: "Some people think remote work improves productivity. Discuss both views.",
      answerKey: [],
      explanation: "Manual review expected.",
      tags: ["opinion"],
      source: "seed",
      instruction: "Write at least 250 words",
      active: true,
    },
    {
      section: "speaking",
      category: "part_2",
      difficulty: "medium",
      questionType: "cue_card",
      title: "Speaking Cue Card",
      content: "Describe a place you enjoy visiting.",
      answerKey: [],
      explanation: "Manual review expected.",
      tags: ["daily_life"],
      source: "seed",
      instruction: "Speak for 1-2 minutes",
      active: true,
    },
  ];

  for (const item of sampleQuestions) {
    await Question.findOneAndUpdate(
      { title: item.title, section: item.section },
      item,
      { upsert: true, new: true }
    );
  }

  console.log("Seed complete");
  console.log(`Platform admin: ${env.platformAdminSeedEmail} / ${env.platformAdminSeedPassword}`);
  console.log("Student: student1@demo.com / Student@123");
  console.log("Coaching admin: coach1@demo.com / Coach@123");
  process.exit(0);
}

seed().catch((e) => {
  console.error("Seed failed", e);
  process.exit(1);
});
