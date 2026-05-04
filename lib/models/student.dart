import 'package:cse470_app/models/test_history.dart';

class Student {
  const Student({
    required this.id,
    required this.name,
    required this.email,
    this.profileUrl,
    this.testHistory = const <TestHistory>[],
  });

  final String id;
  final String name;
  final String email;
  final String? profileUrl;
  final List<TestHistory> testHistory;

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      profileUrl: json['profileURL'] as String?,
      testHistory:
          ((json['testHistory'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(TestHistory.fromJson)
              .toList(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'email': email,
      if (profileUrl != null && profileUrl!.isNotEmpty)
        'profileURL': profileUrl,
    };
  }
}
