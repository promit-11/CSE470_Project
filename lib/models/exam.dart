class Exam {
  const Exam({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.description,
  });

  final String id;
  final String title;
  final String type;
  final DateTime date;
  final String? description;

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      date:
          DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'type': type,
      'date': date.toIso8601String(),
      if (description != null && description!.isNotEmpty)
        'description': description,
    };
  }
}
