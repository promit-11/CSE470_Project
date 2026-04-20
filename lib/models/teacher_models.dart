double _toNullableDouble(dynamic value) {
  if (value == null) {
    return 0;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const <String, dynamic>{};
}

List<String> _toStringList(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList();
}

class TeacherWorkflowStatus {
  static const String pending = 'pending';
  static const String claimed = 'claimed';
  static const String reviewed = 'reviewed';
}

class TeacherProfileModel {
  const TeacherProfileModel({
    required this.id,
    required this.userId,
    required this.coachingId,
    required this.rewardCredits,
    required this.bio,
    required this.expertiseTags,
  });

  final String id;
  final String userId;
  final String? coachingId;
  final double rewardCredits;
  final String bio;
  final List<String> expertiseTags;

  factory TeacherProfileModel.fromJson(Map<String, dynamic> json) {
    return TeacherProfileModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      coachingId: json['coachingId']?.toString(),
      rewardCredits: _toNullableDouble(json['rewardCredits']),
      bio: (json['bio'] ?? '').toString(),
      expertiseTags:
          (json['expertiseTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
    );
  }
}

class TeacherMediaMetadata {
  const TeacherMediaMetadata({
    required this.mediaId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.publicUrl,
    required this.uploadedAt,
    required this.pageOrder,
  });

  final String mediaId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String publicUrl;
  final DateTime? uploadedAt;
  final int? pageOrder;

  factory TeacherMediaMetadata.fromJson(Map<String, dynamic> json) {
    return TeacherMediaMetadata(
      mediaId: (json['mediaId'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      mimeType: (json['mimeType'] ?? '').toString(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      publicUrl: (json['publicUrl'] ?? '').toString(),
      uploadedAt: DateTime.tryParse((json['uploadedAt'] ?? '').toString()),
      pageOrder: (json['pageOrder'] as num?)?.toInt(),
    );
  }
}

class EvaluationQuestionSummary {
  const EvaluationQuestionSummary({
    required this.id,
    required this.section,
    required this.questionType,
    required this.category,
    required this.difficulty,
    required this.title,
    required this.content,
    required this.instruction,
    required this.tags,
    required this.mediaUrl,
    required this.listeningAudioUrl,
  });

  final String id;
  final String section;
  final String questionType;
  final String category;
  final String difficulty;
  final String title;
  final String content;
  final String instruction;
  final List<String> tags;
  final String mediaUrl;
  final String listeningAudioUrl;

  factory EvaluationQuestionSummary.fromJson(Map<String, dynamic> json) {
    return EvaluationQuestionSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      questionType: (json['questionType'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      difficulty: (json['difficulty'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      instruction: (json['instruction'] ?? '').toString(),
      tags: _toStringList(json['tags']),
      mediaUrl: (json['mediaUrl'] ?? '').toString(),
      listeningAudioUrl: (json['listeningAudioUrl'] ?? '').toString(),
    );
  }
}

class EvaluationSectionAnswer {
  const EvaluationSectionAnswer({
    required this.questionId,
    required this.value,
  });

  final String questionId;
  final dynamic value;

  factory EvaluationSectionAnswer.fromJson(Map<String, dynamic> json) {
    return EvaluationSectionAnswer(
      questionId: (json['questionId'] ?? '').toString(),
      value: json['value'],
    );
  }
}

class EvaluationSessionSummary {
  const EvaluationSessionSummary({
    required this.id,
    required this.sourceType,
    required this.coachingId,
    required this.sectionOrder,
    required this.currentSection,
    required this.status,
  });

  final String id;
  final String sourceType;
  final String? coachingId;
  final List<String> sectionOrder;
  final String currentSection;
  final String status;

  factory EvaluationSessionSummary.fromJson(Map<String, dynamic> json) {
    return EvaluationSessionSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? '').toString(),
      coachingId: json['coachingId']?.toString(),
      sectionOrder: _toStringList(json['sectionOrder']),
      currentSection: (json['currentSection'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class EvaluationSectionContext {
  const EvaluationSectionContext({
    required this.section,
    required this.sectionStatus,
    required this.startedAt,
    required this.submittedAt,
    required this.durationSeconds,
    required this.answers,
    required this.questions,
  });

  final String section;
  final String sectionStatus;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int durationSeconds;
  final List<EvaluationSectionAnswer> answers;
  final List<EvaluationQuestionSummary> questions;

  factory EvaluationSectionContext.fromJson(Map<String, dynamic> json) {
    return EvaluationSectionContext(
      section: (json['section'] ?? '').toString(),
      sectionStatus: (json['sectionStatus'] ?? '').toString(),
      startedAt: DateTime.tryParse((json['startedAt'] ?? '').toString()),
      submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      answers: (json['answers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(EvaluationSectionAnswer.fromJson)
          .toList(),
      questions: (json['questions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(EvaluationQuestionSummary.fromJson)
          .toList(),
    );
  }
}

class WritingSubmissionDetail {
  const WritingSubmissionDetail({
    required this.mode,
    required this.typedAnswer,
    required this.images,
    required this.hasContent,
    required this.legacyWritingResponse,
  });

  final String mode;
  final String typedAnswer;
  final List<TeacherMediaMetadata> images;
  final bool hasContent;
  final String legacyWritingResponse;

  factory WritingSubmissionDetail.fromJson(Map<String, dynamic> json) {
    final images =
        (json['images'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TeacherMediaMetadata.fromJson)
            .toList()
          ..sort((a, b) => (a.pageOrder ?? 0).compareTo(b.pageOrder ?? 0));

    return WritingSubmissionDetail(
      mode: (json['mode'] ?? 'none').toString(),
      typedAnswer: (json['typedAnswer'] ?? '').toString(),
      images: images,
      hasContent: (json['hasContent'] ?? false) == true,
      legacyWritingResponse: (json['legacyWritingResponse'] ?? '').toString(),
    );
  }
}

class SpeakingSubmissionDetail {
  const SpeakingSubmissionDetail({
    required this.recording,
    required this.hasRecording,
    required this.legacySpeakingResponse,
  });

  final TeacherMediaMetadata? recording;
  final bool hasRecording;
  final String legacySpeakingResponse;

  factory SpeakingSubmissionDetail.fromJson(Map<String, dynamic> json) {
    return SpeakingSubmissionDetail(
      recording: json['recording'] is Map<String, dynamic>
          ? TeacherMediaMetadata.fromJson(
              json['recording'] as Map<String, dynamic>,
            )
          : null,
      hasRecording: (json['hasRecording'] ?? false) == true,
      legacySpeakingResponse: (json['legacySpeakingResponse'] ?? '').toString(),
    );
  }
}

class EvaluationRequestReviewDetail {
  const EvaluationRequestReviewDetail({
    required this.session,
    required this.sectionContext,
    required this.writingSubmission,
    required this.speakingSubmission,
  });

  final EvaluationSessionSummary session;
  final EvaluationSectionContext sectionContext;
  final WritingSubmissionDetail? writingSubmission;
  final SpeakingSubmissionDetail? speakingSubmission;

  factory EvaluationRequestReviewDetail.fromJson(Map<String, dynamic> json) {
    return EvaluationRequestReviewDetail(
      session: EvaluationSessionSummary.fromJson(_toMap(json['session'])),
      sectionContext: EvaluationSectionContext.fromJson(
        _toMap(json['sectionContext']),
      ),
      writingSubmission: json['writingSubmission'] is Map<String, dynamic>
          ? WritingSubmissionDetail.fromJson(
              json['writingSubmission'] as Map<String, dynamic>,
            )
          : null,
      speakingSubmission: json['speakingSubmission'] is Map<String, dynamic>
          ? SpeakingSubmissionDetail.fromJson(
              json['speakingSubmission'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class EvaluationRequestModel {
  const EvaluationRequestModel({
    required this.id,
    required this.testSessionId,
    required this.section,
    required this.status,
    required this.sourceType,
    this.teacherId,
    this.coachingId,
    this.claimedAt,
    this.reviewedAt,
    this.reviewedBandScore,
    this.reviewComments,
    this.reviewStrengths = const <String>[],
    this.reviewWeaknesses = const <String>[],
    this.criteriaScores = const <String, dynamic>{},
    this.reviewDetail,
    this.createdAt,
  });

  final String id;
  final String testSessionId;
  final String section;
  final String status;
  final String sourceType;
  final String? teacherId;
  final String? coachingId;
  final DateTime? claimedAt;
  final DateTime? reviewedAt;
  final double? reviewedBandScore;
  final String? reviewComments;
  final List<String> reviewStrengths;
  final List<String> reviewWeaknesses;
  final Map<String, dynamic> criteriaScores;
  final EvaluationRequestReviewDetail? reviewDetail;
  final DateTime? createdAt;

  bool get isWriting => section == 'writing';
  bool get isSpeaking => section == 'speaking';

  factory EvaluationRequestModel.fromJson(Map<String, dynamic> json) {
    final band = json['reviewedBandScore'];
    return EvaluationRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      testSessionId: (json['testSessionId'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? '').toString(),
      teacherId: json['teacherId']?.toString(),
      coachingId: json['coachingId']?.toString(),
      claimedAt: DateTime.tryParse((json['claimedAt'] ?? '').toString()),
      reviewedAt: DateTime.tryParse((json['reviewedAt'] ?? '').toString()),
      reviewedBandScore: band == null ? null : _toNullableDouble(band),
      reviewComments: (json['reviewComments'] ?? json['reviewFeedback'])
          ?.toString(),
      reviewStrengths: _toStringList(json['reviewStrengths']),
      reviewWeaknesses: _toStringList(json['reviewWeaknesses']),
      criteriaScores:
          (json['criteriaScores'] as Map<String, dynamic>?) ??
          const <String, dynamic>{},
      reviewDetail: json['reviewDetail'] is Map<String, dynamic>
          ? EvaluationRequestReviewDetail.fromJson(
              json['reviewDetail'] as Map<String, dynamic>,
            )
          : null,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class TeacherDashboardSummary {
  const TeacherDashboardSummary({
    required this.profile,
    required this.pending,
    required this.claimed,
    required this.reviewed,
    required this.payouts,
  });

  final TeacherProfileModel profile;
  final List<EvaluationRequestModel> pending;
  final List<EvaluationRequestModel> claimed;
  final List<EvaluationRequestModel> reviewed;
  final List<TeacherPayoutRequestModel> payouts;

  double get rewardCredits => profile.rewardCredits;
}

class TeacherReviewSubmitResult {
  const TeacherReviewSubmitResult({
    required this.request,
    required this.rewardCreditsAdded,
    required this.raw,
  });

  final EvaluationRequestModel request;
  final double rewardCreditsAdded;
  final Map<String, dynamic> raw;

  factory TeacherReviewSubmitResult.fromJson(Map<String, dynamic> json) {
    return TeacherReviewSubmitResult(
      request: EvaluationRequestModel.fromJson(_toMap(json['request'])),
      rewardCreditsAdded: _toNullableDouble(json['rewardCreditsAdded']),
      raw: json,
    );
  }
}

class TeacherReviewPayload {
  const TeacherReviewPayload({
    required this.overallBand,
    required this.comments,
    required this.strengths,
    required this.weaknesses,
    required this.criterionScores,
  });

  final double overallBand;
  final String comments;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, double> criterionScores;

  Map<String, dynamic> toJson() {
    return {
      'overallBand': overallBand,
      'comments': comments,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'criterionScores': criterionScores,
    };
  }
}

class TeacherPayoutRequestModel {
  const TeacherPayoutRequestModel({
    required this.id,
    required this.requestedRewardCredits,
    required this.payoutAmount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.processedAt,
    this.paidAt,
    this.note,
  });

  final String id;
  final double requestedRewardCredits;
  final double payoutAmount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final DateTime? processedAt;
  final DateTime? paidAt;
  final String? note;

  factory TeacherPayoutRequestModel.fromJson(Map<String, dynamic> json) {
    return TeacherPayoutRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      requestedRewardCredits: _toNullableDouble(json['requestedRewardCredits']),
      payoutAmount: _toNullableDouble(json['payoutAmount']),
      currency: (json['currency'] ?? 'BDT').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      processedAt: DateTime.tryParse((json['processedAt'] ?? '').toString()),
      paidAt: DateTime.tryParse((json['paidAt'] ?? '').toString()),
      note: json['note']?.toString(),
    );
  }
}
