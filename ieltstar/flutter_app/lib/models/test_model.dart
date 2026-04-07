import 'question_model.dart';

class TestModel {
  const TestModel({
    this.id,
    required this.examId,
    required this.section,
    required this.category,
    this.source,
    this.instruction,
    this.questions = const [],
  });

  final String? id;
  final String examId;
  final int section;
  final String category;
  final String? source;
  final String? instruction;
  final List<QuestionModel> questions;

  factory TestModel.fromJson(Map<String, dynamic> json) {
    return TestModel(
      id: (json['_id'] ?? json['id'])?.toString(),
      examId: (json['examId'] ?? '').toString(),
      section: json['section'] is int
          ? json['section'] as int
          : int.tryParse('${json['section']}') ?? 0,
      category: (json['category'] ?? '') as String,
      source: json['source']?.toString(),
      instruction: json['instruction']?.toString(),
      questions: (json['questions'] as List<dynamic>? ?? const [])
          .map((item) =>
              QuestionModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'examId': examId,
      'section': section,
      'category': category,
      if (source != null) 'source': source,
      if (instruction != null) 'instruction': instruction,
      'questions': questions.map((question) => question.toJson()).toList(),
    };
  }
}
