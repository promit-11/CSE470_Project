import TestHistory from "../../models/v1/TestHistory.js";
import User from "../../models/v1/User.js";
import MockSession from "../../models/v1/MockSession.js";
import Institute from "../../models/v1/Institute.js";

export async function getAdminOverview() {
  const [userCount, studentCount, instituteCount, sessionsCompleted] = await Promise.all([
    User.countDocuments(),
    User.countDocuments({ role: "student" }),
    Institute.countDocuments(),
    MockSession.countDocuments({ status: "completed" }),
  ]);

  const avgRows = await TestHistory.aggregate([
    {
      $project: {
        overallBand: 1,
        overallBandStatus: 1,
        listeningBand: 1,
        readingBand: 1,
        writingBand: 1,
        speakingBand: 1,
      },
    },
    {
      $group: {
        _id: null,
        avgOverallBand: {
          $avg: {
            $cond: [{ $eq: ["$overallBandStatus", "finalized"] }, "$overallBand", null],
          },
        },
        avgListening: { $avg: "$listeningBand" },
        avgReading: { $avg: "$readingBand" },
        avgWriting: {
          $avg: {
            $cond: [{ $gt: ["$writingBand", 0] }, "$writingBand", null],
          },
        },
        avgSpeaking: {
          $avg: {
            $cond: [{ $gt: ["$speakingBand", 0] }, "$speakingBand", null],
          },
        },
      },
    },
  ]);

  return {
    userCount,
    studentCount,
    instituteCount,
    sessionsCompleted,
    averages: avgRows[0] || {
      avgOverallBand: 0,
      avgListening: 0,
      avgReading: 0,
      avgWriting: 0,
      avgSpeaking: 0,
    },
  };
}
