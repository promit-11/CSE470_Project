class MockQuestionOption {
  const MockQuestionOption({required this.key, required this.text});

  final String key;
  final String text;

  factory MockQuestionOption.fromJson(Map<String, dynamic> json) {
    return MockQuestionOption(
      key: (json['key'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
    );
  }
}

class MockQuestion {
  const MockQuestion({
    required this.id,
    required this.section,
    required this.questionType,
    required this.title,
    required this.content,
    required this.options,
    required this.listeningAudioUrl,
  });

  final String id;
  final String section;
  final String questionType;
  final String title;
  final String content;
  final List<MockQuestionOption> options;
  final String listeningAudioUrl;

  factory MockQuestion.fromJson(Map<String, dynamic> json) {
    return MockQuestion(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      questionType: (json['questionType'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MockQuestionOption.fromJson)
          .toList(),
      listeningAudioUrl: (json['listeningAudioUrl'] ?? '').toString(),
    );
  }
}

class MockMediaMetadata {
  const MockMediaMetadata({
    required this.mediaId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.publicUrl,
    required this.pageOrder,
  });

  final String mediaId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String publicUrl;
  final int? pageOrder;

  factory MockMediaMetadata.fromJson(Map<String, dynamic> json) {
    return MockMediaMetadata(
      mediaId: (json['mediaId'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sizeBytes: ((json['sizeBytes'] ?? 0) as num).toInt(),
      publicUrl: (json['publicUrl'] ?? '').toString(),
      pageOrder: (json['pageOrder'] as num?)?.toInt(),
    );
  }
}

class MockWritingSubmission {
  const MockWritingSubmission({
    required this.mode,
    required this.typedAnswer,
    required this.images,
  });

  final String mode;
  final String typedAnswer;
  final List<MockMediaMetadata> images;

  factory MockWritingSubmission.fromJson(Map<String, dynamic> json) {
    return MockWritingSubmission(
      mode: (json['mode'] ?? 'none').toString(),
      typedAnswer: (json['typedAnswer'] ?? '').toString(),
      images:
          (json['images'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(MockMediaMetadata.fromJson)
              .toList()
            ..sort((a, b) => (a.pageOrder ?? 0).compareTo(b.pageOrder ?? 0)),
    );
  }
}

class MockSpeakingSubmission {
  const MockSpeakingSubmission({required this.recording});

  final MockMediaMetadata? recording;

  factory MockSpeakingSubmission.fromJson(Map<String, dynamic> json) {
    final recordingJson = json['recording'];
    return MockSpeakingSubmission(
      recording: recordingJson is Map<String, dynamic>
          ? MockMediaMetadata.fromJson(recordingJson)
          : null,
    );
  }
}

class MockSectionState {
  const MockSectionState({
    required this.section,
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.status,
    required this.rawScore,
    required this.bandScore,
    required this.startedAt,
    required this.submittedAt,
    required this.answers,
    required this.questions,
    required this.writingSubmission,
    required this.speakingSubmission,
  });

  final String section;
  final int durationSeconds;
  final int remainingSeconds;
  final String status;
  final int rawScore;
  final double bandScore;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final List<Map<String, dynamic>> answers;
  final List<MockQuestion> questions;
  final MockWritingSubmission? writingSubmission;
  final MockSpeakingSubmission? speakingSubmission;

  bool get isSubmitted =>
      submittedAt != null ||
      status == 'submitted' ||
      status == 'auto_submitted';

  factory MockSectionState.fromJson(Map<String, dynamic> json) {
    return MockSectionState(
      section: (json['section'] ?? '').toString(),
      durationSeconds: (json['durationSeconds'] ?? 0) as int,
      remainingSeconds:
          (json['remainingSeconds'] ?? json['durationSeconds'] ?? 0) as int,
      status: (json['status'] ?? '').toString(),
      rawScore: (json['rawScore'] ?? 0) as int,
      bandScore: ((json['bandScore'] ?? 0) as num).toDouble(),
      startedAt: DateTime.tryParse((json['startedAt'] ?? '').toString()),
      submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()),
      answers: (json['answers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(),
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MockQuestion.fromJson)
          .toList(),
      writingSubmission: json['writingSubmission'] is Map<String, dynamic>
          ? MockWritingSubmission.fromJson(
              json['writingSubmission'] as Map<String, dynamic>,
            )
          : null,
      speakingSubmission: json['speakingSubmission'] is Map<String, dynamic>
          ? MockSpeakingSubmission.fromJson(
              json['speakingSubmission'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class MockSession {
  const MockSession({
    required this.id,
    required this.status,
    required this.currentSection,
    required this.sectionOrder,
    required this.sections,
    required this.overallBand,
    required this.overallBandStatus,
    required this.overallEstimatedBand,
    required this.sectionBands,
    required this.feedbackSummary,
    required this.resultSummary,
  });

  final String id;
  final String status;
  final String currentSection;
  final List<String> sectionOrder;
  final List<MockSectionState> sections;
  final double? overallBand;
  final String overallBandStatus;
  final double? overallEstimatedBand;
  final Map<String, double?> sectionBands;
  final Map<String, dynamic> feedbackSummary;
  final Map<String, dynamic> resultSummary;

  factory MockSession.fromJson(Map<String, dynamic> json) {
    final bands =
        (json['sectionBands'] as Map<String, dynamic>? ??
                const <String, dynamic>{})
            .map((key, value) => MapEntry(key, (value as num?)?.toDouble()));

    return MockSession(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      currentSection: (json['currentSection'] ?? '').toString(),
      sectionOrder:
          (json['sectionOrder'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
      sections: (json['sections'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MockSectionState.fromJson)
          .toList(),
      overallBand: (json['overallBand'] as num?)?.toDouble(),
      overallBandStatus: (json['overallBandStatus'] ?? '').toString(),
      overallEstimatedBand: (json['overallEstimatedBand'] as num?)?.toDouble(),
      sectionBands: bands,
      feedbackSummary:
          (json['feedbackSummary'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
      resultSummary:
          (json['resultSummary'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
    );
  }
}
