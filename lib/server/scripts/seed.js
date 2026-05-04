import bcrypt from "bcryptjs";
import env from "../api/config/env.js";
import { connectDatabase } from "../api/config/database.js";
import User from "../api/mvc/models/v1/User.js";
import StudentProfile from "../api/mvc/models/v1/StudentProfile.js";
import TeacherProfile from "../api/mvc/models/v1/TeacherProfile.js";
import Institute from "../api/mvc/models/v1/Institute.js";
import MockTemplate from "../api/mvc/models/v1/MockTemplate.js";
import Question from "../api/mvc/models/v1/Question.js";
import fs from "fs/promises";
import path from "path";
import { ensureMediaStorageReady, getMediaStorageRootDir } from "../api/mvc/services/v1/media-storage-service.js";

async function seed() {
  await connectDatabase();
  console.log("🌱 Seeding demo data...\n");

  // Ensure media storage dir exists and copy local seed audio if present.
  let seedListeningMeta = null;
  try {
    await ensureMediaStorageReady();
    const projectRoot = path.resolve(process.cwd(), "..", "..");
    const sourceAudio = path.join(projectRoot, "uploads", "listening.mp3");
    const mediaRoot = getMediaStorageRootDir();
    const targetFolder = path.join(mediaRoot, "questions", "app", "listening");
    const targetFileName = "seed-listening.mp3";
    const targetPath = path.join(targetFolder, targetFileName);

    try {
      // Copy file if source exists and target does not exist yet.
      const srcStat = await fs.stat(sourceAudio).catch(() => null);
      if (srcStat) {
        await fs.mkdir(targetFolder, { recursive: true });
        const tgtStat = await fs.stat(targetPath).catch(() => null);
        if (!tgtStat) {
          await fs.copyFile(sourceAudio, targetPath);
        }
        const finalStat = await fs.stat(targetPath);
        const storagePath = path.join("questions", "app", "listening", targetFileName).split(path.sep).join("/");
        seedListeningMeta = {
          mediaId: "seed-listening",
          fileName: targetFileName,
          mimeType: "audio/mpeg",
          sizeBytes: Number(finalStat.size || 0),
          storagePath,
          publicUrl: `${env.mediaPublicBasePath}/${storagePath}`,
          uploadedAt: new Date(),
          pageOrder: null,
        };
        console.log(`📎 Copied seed audio to ${targetPath}`);
      } else {
        console.log(`ℹ️ No local seed audio found at ${sourceAudio}; skipping audio attachment.`);
      }
    } catch (e) {
      console.log("⚠️ Failed to install seed listening audio:", e.message);
    }

  } catch (e) {
    console.log("⚠️ Failed preparing seed audio:", e.message);
  }

  // Seed platform admin
  const adminPasswordHash = await bcrypt.hash(env.platformAdminSeedPassword, 12);
  await User.findOneAndUpdate(
    { email: env.platformAdminSeedEmail.toLowerCase() },
    {
      name: "Platform Admin",
      email: env.platformAdminSeedEmail.toLowerCase(),
      passwordHash: adminPasswordHash,
      role: "platform_admin",
      status: "active",
      approvalStatus: "not_required",
    },
    { upsert: true, new: true }
  );

  // Seed demo student
  const studentPasswordHash = await bcrypt.hash("Student@123", 12);
  const student = await User.findOneAndUpdate(
    { email: "student1@demo.com" },
    {
      name: "Aisha Khan",
      email: "student1@demo.com",
      passwordHash: studentPasswordHash,
      role: "student",
      status: "active",
      approvalStatus: "not_required",
    },
    { upsert: true, new: true }
  );
  await StudentProfile.findOneAndUpdate(
    { userId: student._id },
    {
      userId: student._id,
      targetBand: 7,
      strengths: [],
      weaknesses: [],
      testCredits: 100,
      mockAccess: {
        allowed: true,
        plan: "standard",
        remainingCredits: 100,
      },
    },
    { upsert: true, new: true }
  );

  // Seed demo teacher
  const teacherPasswordHash = await bcrypt.hash("Teacher@123", 12);
  const teacher = await User.findOneAndUpdate(
    { email: "teacher1@demo.com" },
    {
      name: "Dr. Sarah Mitchell",
      email: "teacher1@demo.com",
      passwordHash: teacherPasswordHash,
      role: "teacher",
      status: "active",
      approvalStatus: "approved",
    },
    { upsert: true, new: true }
  );
  await TeacherProfile.findOneAndUpdate(
    { userId: teacher._id },
    {
      userId: teacher._id,
      rewardCredits: 50,
      bio: "Certified IELTS examiner with 10+ years experience",
      expertiseTags: ["writing", "speaking", "academic"],
    },
    { upsert: true, new: true }
  );

  // Seed coaching admin and institute
  const coachPasswordHash = await bcrypt.hash("Coach@123", 12);
  const coach = await User.findOneAndUpdate(
    { email: "coach1@demo.com" },
    {
      name: "Bright Academy Admin",
      email: "coach1@demo.com",
      passwordHash: coachPasswordHash,
      role: "coaching_admin",
      status: "active",
      approvalStatus: "not_required",
    },
    { upsert: true, new: true }
  );

  const institute = await Institute.findOneAndUpdate(
    { adminUserId: coach._id },
    {
      name: "Bright IELTS Academy",
      description: "Premium IELTS coaching and mock testing platform",
      address: "123 Education Street, Dhaka, Bangladesh",
      contactEmail: "coach1@demo.com",
      contactPhone: "+88-01-234-56789",
      adminUserId: coach._id,
      verifiedAt: new Date(),
    },
    { upsert: true, new: true }
  );

  // Seed mock template
  await MockTemplate.findOneAndUpdate(
    { name: "Default Academic" },
    {
      name: "Default Academic",
      examType: "academic",
      sectionOrder: ["listening", "reading", "writing", "speaking"],
      listeningQuestionCount: 40,
      readingQuestionCount: 40,
      writingTaskCount: 2,
      speakingPartCount: 3,
      difficultyRatios: {
        easy: 0.3,
        medium: 0.4,
        hard: 0.3,
      },
      active: true,
    },
    { upsert: true, new: true }
  );

  // Seed comprehensive sample questions
  const sampleQuestions = [
    // Listening questions
    {
      section: "listening",
      category: "part_1",
      difficulty: "easy",
      questionType: "mcq",
      title: "Listening Q1 - Booking Date",
      content: "What date is the booking confirmed for?",
      options: [
        { key: "A", text: "May 12th" },
        { key: "B", text: "May 13th" },
        { key: "C", text: "May 14th" },
      ],
      answerKey: ["B"],
      explanation: "The speaker confirms the booking for May 13th.",
      tags: ["booking", "dates"],
      source: "seed",
      active: true,
    },
    {
      section: "listening",
      category: "part_1",
      difficulty: "easy",
      questionType: "mcq",
      title: "Listening Q2 - Contact Method",
      content: "How will they contact you?",
      options: [
        { key: "A", text: "By email" },
        { key: "B", text: "By phone" },
        { key: "C", text: "By mail" },
      ],
      answerKey: ["A"],
      explanation: "The conversation specifies email as the contact method.",
      tags: ["contact"],
      source: "seed",
      active: true,
    },
    {
      section: "listening",
      category: "part_2",
      difficulty: "medium",
      questionType: "mcq",
      title: "Listening Q3 - Museum Location",
      content: "Where is the museum located?",
      options: [
        { key: "A", text: "City center" },
        { key: "B", text: "North district" },
        { key: "C", text: "Riverside area" },
      ],
      answerKey: ["C"],
      explanation: "The audio guide mentions the museum is in the riverside area.",
      tags: ["location", "places"],
      source: "seed",
      active: true,
    },
    {
      section: "listening",
      category: "part_2",
      difficulty: "medium",
      questionType: "mcq",
      title: "Listening Q4 - Opening Hours",
      content: "What are the museum opening hours?",
      options: [
        { key: "A", text: "9am - 5pm" },
        { key: "B", text: "10am - 6pm" },
        { key: "C", text: "11am - 7pm" },
      ],
      answerKey: ["B"],
      explanation: "The narrator states opening hours are 10am to 6pm daily.",
      tags: ["times", "information"],
      source: "seed",
      active: true,
    },
    {
      section: "listening",
      category: "part_3",
      difficulty: "hard",
      questionType: "mcq",
      title: "Listening Q5 - Climate Impact",
      content: "What is the main environmental concern discussed?",
      options: [
        { key: "A", text: "Rising sea levels" },
        { key: "B", text: "Deforestation" },
        { key: "C", text: "Ocean acidification" },
      ],
      answerKey: ["C"],
      explanation: "The discussion focuses on ocean acidification as the primary concern.",
      tags: ["environment", "discussion"],
      source: "seed",
      active: true,
    },
    // Reading questions
    {
      section: "reading",
      category: "passage_1",
      difficulty: "easy",
      questionType: "mcq",
      title: "Reading Q1 - Main Topic",
      content: "What is the passage mainly about?",
      options: [
        { key: "A", text: "The history of ancient Rome" },
        { key: "B", text: "Modern urban development" },
        { key: "C", text: "Agricultural methods" },
      ],
      answerKey: ["B"],
      explanation: "The passage focuses on how modern cities are expanding.",
      tags: ["main idea", "urban"],
      source: "seed",
      active: true,
    },
    {
      section: "reading",
      category: "passage_2",
      difficulty: "medium",
      questionType: "mcq",
      title: "Reading Q2 - Inference",
      content: "What can be inferred about the author's opinion?",
      options: [
        { key: "A", text: "Positive and supportive" },
        { key: "B", text: "Negative and critical" },
        { key: "C", text: "Neutral and objective" },
      ],
      answerKey: ["C"],
      explanation: "The author maintains a neutral, factual tone throughout.",
      tags: ["inference", "author tone"],
      source: "seed",
      active: true,
    },
    {
      section: "reading",
      category: "passage_2",
      difficulty: "medium",
      questionType: "mcq",
      title: "Reading Q3 - Vocabulary",
      content: "What does 'proliferation' mean in this context?",
      options: [
        { key: "A", text: "Rapid decrease" },
        { key: "B", text: "Rapid increase or spread" },
        { key: "C", text: "Controlled growth" },
      ],
      answerKey: ["B"],
      explanation: "Proliferation means rapid increase or widespread occurrence.",
      tags: ["vocabulary", "context"],
      source: "seed",
      active: true,
    },
    {
      section: "reading",
      category: "passage_3",
      difficulty: "hard",
      questionType: "mcq",
      title: "Reading Q4 - Synthesis",
      content: "How do sections B and C relate to each other?",
      options: [
        { key: "A", text: "Cause and effect" },
        { key: "B", text: "Contrast and comparison" },
        { key: "C", text: "Problem and solution" },
      ],
      answerKey: ["C"],
      explanation: "Section B presents a problem while Section C offers a solution.",
      tags: ["text structure", "synthesis"],
      source: "seed",
      active: true,
    },
    {
      section: "reading",
      category: "passage_3",
      difficulty: "hard",
      questionType: "mcq",
      title: "Reading Q5 - Detail Comprehension",
      content: "According to the passage, what percentage of the population is affected?",
      options: [
        { key: "A", text: "Approximately 25%" },
        { key: "B", text: "Approximately 50%" },
        { key: "C", text: "Approximately 75%" },
      ],
      answerKey: ["B"],
      explanation: "The text explicitly states that about half the population is affected.",
      tags: ["details", "comprehension"],
      source: "seed",
      active: true,
    },
    // Writing questions
    {
      section: "writing",
      category: "task_1",
      difficulty: "medium",
      questionType: "essay",
      title: "Writing Task 1 - Letter",
      content:
        "Write a formal letter of complaint to a hotel manager about poor service during your stay. Include what went wrong, how it affected you, and what compensation you expect.",
      answerKey: [],
      explanation: "This is a formal letter task. Manual review by teacher required.",
      tags: ["formal letter", "complaint"],
      source: "seed",
      active: true,
    },
    {
      section: "writing",
      category: "task_2",
      difficulty: "medium",
      questionType: "essay",
      title: "Writing Task 2 - Opinion Essay",
      content:
        "Some people believe that remote work increases productivity, while others argue it reduces team collaboration. Discuss both views and give your opinion. Write at least 250 words.",
      answerKey: [],
      explanation: "This is an opinion essay task. Teacher will evaluate on Task Achievement, Coherence, Lexical Resource, and Grammatical Accuracy.",
      tags: ["opinion", "essay"],
      source: "seed",
      active: true,
    },
    // Speaking questions
    {
      section: "speaking",
      category: "part_1",
      difficulty: "easy",
      questionType: "conversation",
      title: "Speaking Part 1 - Introduction",
      content:
        "Good morning. What is your full name? Can you tell me where you are from? Do you work or study?",
      answerKey: [],
      explanation: "Part 1 is a conversation. Teacher will assess fluency, vocabulary, and pronunciation.",
      tags: ["introduction", "personal"],
      source: "seed",
      active: true,
    },
    {
      section: "speaking",
      category: "part_2",
      difficulty: "medium",
      questionType: "cue_card",
      title: "Speaking Part 2 - Cue Card",
      content:
        "Describe a place you have visited that was interesting. You should say: where it was, when you visited it, what you did there, and explain why you found it interesting.",
      answerKey: [],
      explanation: "Part 2 requires a 1-2 minute monologue. Teacher evaluates fluency, task achievement, and pronunciation.",
      tags: ["description", "cue card"],
      source: "seed",
      active: true,
    },
    {
      section: "speaking",
      category: "part_3",
      difficulty: "hard",
      questionType: "discussion",
      title: "Speaking Part 3 - Discussion",
      content:
        "Let's talk about tourism. How has tourism changed over the past 20 years? What are the positive and negative effects of tourism on local communities?",
      answerKey: [],
      explanation: "Part 3 is a discussion. Teacher assesses extended responses, vocabulary, and argument construction.",
      tags: ["discussion", "tourism"],
      source: "seed",
      active: true,
    },
  ];

  // Attach seed listening audio metadata to listening questions if available
  if (typeof seedListeningMeta !== "undefined" && seedListeningMeta) {
    for (const item of sampleQuestions) {
      if (item.section === "listening") {
        item.listeningAudio = seedListeningMeta;
      }
    }
    
    // Also update any existing listening questions with the audio metadata
    try {
      await Question.updateMany(
        { section: "listening" },
        { listeningAudio: seedListeningMeta }
      );
      console.log("📎 Updated existing listening questions with audio metadata");
    } catch (e) {
      console.log("⚠️ Failed to update existing listening questions:", e.message);
    }
  }

  // Seed questions (idempotent using title + section as unique identifier)
  let questionsCreated = 0;
  for (const item of sampleQuestions) {
    const existing = await Question.findOne({
      title: item.title,
      section: item.section,
    });
    if (!existing) {
      await Question.create(item);
      questionsCreated++;
    }
  }

  console.log("✅ Seed complete!\n");
  console.log("📋 Demo Accounts:");
  console.log(`  Platform Admin: ${env.platformAdminSeedEmail} / ${env.platformAdminSeedPassword}`);
  console.log("  Teacher: teacher1@demo.com / Teacher@123");
  console.log("  Student: student1@demo.com / Student@123");
  console.log("  Coaching Admin: coach1@demo.com / Coach@123");
  console.log(`\n📊 Data Summary:`);
  console.log(`  Questions created: ${questionsCreated}`);
  console.log(`  Coaching center: ${institute.name}`);
  console.log(`  Sample questions: ${sampleQuestions.length} (Listening, Reading, Writing, Speaking)`);
  console.log("\n💡 Next: Run 'npm start' to launch the backend server.");
  console.log("   Then open the Flutter app and log in with demo accounts.\n");
  process.exit(0);
}

seed().catch((e) => {
  console.error("❌ Seed failed:", e.message);
  process.exit(1);
});
