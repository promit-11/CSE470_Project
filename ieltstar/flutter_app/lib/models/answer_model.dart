class AnswerModel {
  const AnswerModel({
    required this.testType,
    required this.testId,
    required this.examId,
    required this.section,
    required this.score,
    required this.userResponse,
  });

  final String testType;
  final String testId;
  final String examId;
  final int section;
  final dynamic score;
  final List<Map<String, dynamic>> userResponse;

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    return AnswerModel(
      testType: (json['testType'] ?? '') as String,
      testId: (json['testId'] ?? '').toString(),
      examId: (json['examId'] ?? '').toString(),
      section: json['section'] is int
          ? json['section'] as int
          : int.tryParse('${json['section']}') ?? 0,
      score: json['score'],
      userResponse: (json['userResponse'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'testType': testType,
      'testId': testId,
      'examId': examId,
      'section': section,
      'score': score,
      'userResponse': userResponse,
    };
  }
}
