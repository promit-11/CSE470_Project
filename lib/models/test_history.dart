// DEPRECATED (legacy flow): This model supports the old /tests + /exams stack.
// Active runtime history is served by /api/v1/students/history and dashboard models.
import 'package:cse470_app/core/utils/ielts_sections.dart';

class TestHistory {
  const TestHistory({
    required this.examId,
    required this.section,
    required this.testId,
    required this.testType,
    required this.score,
    required this.date,
  });

  final String examId;
  final String section;
  final String testId;
  final String testType;
  final double score;
  final DateTime date;

  factory TestHistory.fromJson(Map<String, dynamic> json) {
    return TestHistory(
      examId: (json['examId'] ?? '').toString(),
      section: IeltsSections.fromAny(
        section: json['section'],
        legacyCategory: json['testType'],
      ),
      testId: (json['testId'] ?? '').toString(),
      testType: (json['testType'] ?? '').toString(),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
