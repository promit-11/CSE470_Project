class QuestionModel {
  const QuestionModel({
    this.id,
    required this.title,
    this.description,
    this.options = const [],
    this.type,
    this.answer,
    this.marks,
  });

  final String? id;
  final String title;
  final String? description;
  final List<String> options;
  final String? type;
  final String? answer;
  final int? marks;

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: (json['_id'] ?? json['id'])?.toString(),
      title: (json['title'] ?? '') as String,
      description: json['description']?.toString(),
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      type: json['type']?.toString(),
      answer: json['answer']?.toString(),
      marks: json['marks'] is int
          ? json['marks'] as int
          : int.tryParse('${json['marks']}'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      'options': options,
      if (type != null) 'type': type,
      if (answer != null) 'answer': answer,
      if (marks != null) 'marks': marks,
    };
  }
}
