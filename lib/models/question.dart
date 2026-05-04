class Question {
  const Question({
    required this.id,
    required this.title,
    required this.answer,
    required this.marks,
    this.description,
    this.options = const <String>[],
    this.type,
  });

  final String id;
  final String title;
  final String answer;
  final double marks;
  final String? description;
  final List<String> options;
  final String? type;

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: (json['_id'] ?? '').toString(),
      title: (json['title'] ?? '') as String,
      description: json['description'] as String?,
      answer: (json['answer'] ?? '').toString(),
      marks: (json['marks'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String?,
      options: ((json['options'] as List<dynamic>?) ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description ?? '',
      'options': options,
      'type': type,
      'answer': answer,
      'marks': marks,
    };
  }
}
