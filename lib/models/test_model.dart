// DEPRECATED (legacy flow): This model belongs to the old /tests + /exams stack.
// Active runtime uses V1 mock-session flow with models in mock_models.dart.
// Keep only for temporary backward compatibility until legacy cleanup is complete.
import 'package:cse470_app/models/question.dart';
import 'package:cse470_app/core/utils/ielts_sections.dart';

class TestModel {
  const TestModel({
    required this.id,
    required this.examId,
    required this.section,
    required this.category,
    this.source,
    this.instruction,
    this.questions = const <Question>[],
  });

  final String id;
  final String examId;
  final String section;
  final String category;
  final String? source;
  final String? instruction;
  final List<Question> questions;

  factory TestModel.fromJson(Map<String, dynamic> json) {
    return TestModel(
      id: (json['_id'] ?? '').toString(),
      examId: (json['examId'] ?? '').toString(),
      section: IeltsSections.fromAny(
        section: json['section'],
        legacyCategory: json['category'],
      ),
      category: (json['category'] ?? '').toString().isEmpty
          ? IeltsSections.toLegacyCategory(
              IeltsSections.fromAny(
                section: json['section'],
                legacyCategory: json['category'],
              ),
            )
          : (json['category'] ?? '').toString(),
      source: json['source'] as String?,
      instruction: json['instruction'] as String?,
      questions: ((json['questions'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(Question.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'examId': examId,
      'section': IeltsSections.normalize(section),
      'category': category,
      'source': source,
      'instruction': instruction,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}
