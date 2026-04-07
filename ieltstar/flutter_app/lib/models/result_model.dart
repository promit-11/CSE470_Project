class ResultModel {
  const ResultModel({
    this.id,
    this.name,
    this.email,
    this.profileURL,
    this.examId,
    this.testId,
    this.testType,
    this.section,
    this.score,
    this.date,
    this.readingScore,
    this.listeningScore,
    this.writingScore,
    this.speakingScore,
    this.overallBand,
    this.testHistory = const [],
  });

  final String? id;
  final String? name;
  final String? email;
  final String? profileURL;
  final String? examId;
  final String? testId;
  final String? testType;
  final int? section;
  final dynamic score;
  final DateTime? date;
  final num? readingScore;
  final num? listeningScore;
  final num? writingScore;
  final num? speakingScore;
  final num? overallBand;
  final List<ResultModel> testHistory;

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    return ResultModel(
      id: (json['_id'] ?? json['id'])?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      profileURL: json['profileURL']?.toString(),
      examId: json['examId']?.toString(),
      testId: json['testId']?.toString(),
      testType: json['testType']?.toString(),
      section: json['section'] is int
          ? json['section'] as int
          : int.tryParse('${json['section']}'),
      score: json['score'],
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString())
          : null,
      readingScore: _toNum(json['readingScore']),
      listeningScore: _toNum(json['listeningScore']),
      writingScore: _toNum(json['writingScore']),
      speakingScore: _toNum(json['speakingScore']),
      overallBand: _toNum(json['overallBand']),
      testHistory: (json['testHistory'] as List<dynamic>? ?? const [])
          .map((item) =>
              ResultModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }

  static num? _toNum(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '');
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (profileURL != null) 'profileURL': profileURL,
      if (examId != null) 'examId': examId,
      if (testId != null) 'testId': testId,
      if (testType != null) 'testType': testType,
      if (section != null) 'section': section,
      if (score != null) 'score': score,
      if (date != null) 'date': date!.toIso8601String(),
      if (readingScore != null) 'readingScore': readingScore,
      if (listeningScore != null) 'listeningScore': listeningScore,
      if (writingScore != null) 'writingScore': writingScore,
      if (speakingScore != null) 'speakingScore': speakingScore,
      if (overallBand != null) 'overallBand': overallBand,
      'testHistory': testHistory.map((item) => item.toJson()).toList(),
    };
  }
}
