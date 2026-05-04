double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _toNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<String> _toStringList(dynamic value) {
  return (value as List<dynamic>? ?? const <dynamic>[])
      .map((e) => e.toString())
      .toList();
}

class SectionStatus {
  static const String completed = 'completed';
  static const String pendingReview = 'pending_review';
  static const String reviewed = 'reviewed';
  static const String notSubmitted = 'not_submitted';
}

class OverallStatus {
  static const String finalized = 'finalized';
  static const String pendingFullReview = 'pending_full_review';
  static const String partialUnavailableSections =
      'partial_unavailable_sections';
}

class SectionFeedback {
  const SectionFeedback({
    required this.bandScore,
    required this.rawScore,
    required this.status,
    required this.summary,
    required this.comments,
    required this.strengths,
    required this.weaknesses,
  });

  final double? bandScore;
  final int? rawScore;
  final String status;
  final String summary;
  final String comments;
  final List<String> strengths;
  final List<String> weaknesses;

  String get note => summary;

  bool get hasContent {
    return summary.trim().isNotEmpty ||
        comments.trim().isNotEmpty ||
        strengths.isNotEmpty ||
        weaknesses.isNotEmpty;
  }

  factory SectionFeedback.fromJson(Map<String, dynamic> json) {
    return SectionFeedback(
      bandScore: _toNullableDouble(json['bandScore'] ?? json['band']),
      rawScore: (json['rawScore'] as num?)?.toInt(),
      status: (json['status'] ?? '').toString(),
      summary: (json['summary'] ?? json['note'] ?? '').toString(),
      comments: (json['comments'] ?? '').toString(),
      strengths: _toStringList(json['strengths']),
      weaknesses: _toStringList(json['weaknesses']),
    );
  }
}

class SectionSubmission {
  const SectionSubmission({
    required this.mode,
    required this.hasSubmission,
    required this.hasTypedAnswer,
    required this.hasImages,
    required this.imageCount,
    required this.hasRecording,
  });

  final String mode;
  final bool hasSubmission;
  final bool hasTypedAnswer;
  final bool hasImages;
  final int imageCount;
  final bool hasRecording;

  factory SectionSubmission.fromJson(Map<String, dynamic> json) {
    return SectionSubmission(
      mode: (json['mode'] ?? 'none').toString(),
      hasSubmission: (json['hasSubmission'] ?? false) == true,
      hasTypedAnswer: (json['hasTypedAnswer'] ?? false) == true,
      hasImages: (json['hasImages'] ?? false) == true,
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
      hasRecording: (json['hasRecording'] ?? false) == true,
    );
  }
}

class ResultSectionSummary {
  const ResultSectionSummary({
    required this.section,
    required this.status,
    required this.bandScore,
    required this.rawScore,
    required this.reviewPending,
    required this.feedback,
    required this.submission,
    required this.reviewAnswers,
  });

  final String section;
  final String status;
  final double? bandScore;
  final int? rawScore;
  final bool reviewPending;
  final SectionFeedback feedback;
  final SectionSubmission submission;
  final List<Map<String, dynamic>> reviewAnswers;

  bool get isReviewed =>
      status == SectionStatus.reviewed || status == SectionStatus.completed;
  bool get isPendingReview => status == SectionStatus.pendingReview;
  bool get isNotSubmitted => status == SectionStatus.notSubmitted;

  factory ResultSectionSummary.fromJson(String key, Map<String, dynamic> json) {
    final feedbackJson = _toMap(json['feedback']);
    return ResultSectionSummary(
      section: (json['section'] ?? key).toString(),
      status: (json['status'] ?? SectionStatus.notSubmitted).toString(),
      bandScore: _toNullableDouble(json['bandScore'] ?? json['band']),
      rawScore: (json['rawScore'] as num?)?.toInt(),
      reviewPending: (json['reviewPending'] ?? false) == true,
      feedback: SectionFeedback.fromJson(<String, dynamic>{
        ...feedbackJson,
        'bandScore':
            json['bandScore'] ?? json['band'] ?? feedbackJson['bandScore'],
        'rawScore': json['rawScore'] ?? feedbackJson['rawScore'],
        'status': json['status'] ?? feedbackJson['status'],
      }),
      submission: SectionSubmission.fromJson(_toMap(json['submission'])),
      reviewAnswers:
          (json['reviewAnswers'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[],
    );
  }
}

class ResultOverallSummary {
  const ResultOverallSummary({
    required this.status,
    required this.rule,
    required this.ruleLabel,
    required this.isPartial,
    required this.bandScore,
    required this.objectiveBandScore,
    required this.pendingSections,
    required this.reviewedSections,
    required this.unavailableSections,
    required this.overallEstimatedBand,
  });

  final String status;
  final String rule;
  final String ruleLabel;
  final bool isPartial;
  final double? bandScore;
  final double? objectiveBandScore;
  final List<String> pendingSections;
  final List<String> reviewedSections;
  final List<String> unavailableSections;
  final double? overallEstimatedBand;

  bool get isFinalized => status == OverallStatus.finalized;

  factory ResultOverallSummary.fromJson(Map<String, dynamic> json) {
    return ResultOverallSummary(
      status: (json['status'] ?? '').toString(),
      rule: (json['rule'] ?? '').toString(),
      ruleLabel: (json['ruleLabel'] ?? '').toString(),
      isPartial: (json['isPartial'] ?? false) == true,
      bandScore: _toNullableDouble(
        json['bandScore'] ?? json['finalOverallBand'] ?? json['overallBand'],
      ),
      objectiveBandScore: _toNullableDouble(
        json['objectiveBandScore'] ?? json['objectiveOverallBand'],
      ),
      pendingSections: _toStringList(json['pendingSections']),
      reviewedSections: _toStringList(json['reviewedSections']),
      unavailableSections: _toStringList(json['unavailableSections']),
      overallEstimatedBand: _toNullableDouble(json['overallEstimatedBand']),
    );
  }
}

class StudentResultSummary {
  const StudentResultSummary({
    required this.contractVersion,
    required this.overall,
    required this.sections,
    required this.pendingSubjectiveSections,
    required this.reviewedSubjectiveSections,
    required this.unavailableSubjectiveSections,
  });

  final String contractVersion;
  final ResultOverallSummary overall;
  final Map<String, ResultSectionSummary> sections;
  final List<String> pendingSubjectiveSections;
  final List<String> reviewedSubjectiveSections;
  final List<String> unavailableSubjectiveSections;

  ResultSectionSummary section(String key) {
    return sections[key] ??
        ResultSectionSummary.fromJson(key, <String, dynamic>{
          'section': key,
          'status': SectionStatus.notSubmitted,
        });
  }

  factory StudentResultSummary.fromJson(Map<String, dynamic> json) {
    final sectionsJson = _toMap(json['sections']);
    final sectionMap = <String, ResultSectionSummary>{};
    for (final entry in sectionsJson.entries) {
      sectionMap[entry.key] = ResultSectionSummary.fromJson(
        entry.key,
        _toMap(entry.value),
      );
    }
    return StudentResultSummary(
      contractVersion: (json['contractVersion'] ?? '').toString(),
      overall: ResultOverallSummary.fromJson(_toMap(json['overall'])),
      sections: sectionMap,
      pendingSubjectiveSections: _toStringList(
        json['pendingSubjectiveSections'],
      ),
      reviewedSubjectiveSections: _toStringList(
        json['reviewedSubjectiveSections'],
      ),
      unavailableSubjectiveSections: _toStringList(
        json['unavailableSubjectiveSections'],
      ),
    );
  }
}

class StudentArchiveStateSummary {
  const StudentArchiveStateSummary({
    required this.objectiveFinalized,
    required this.subjectivePending,
    required this.subjectiveReviewed,
    required this.subjectiveMissing,
  });

  final bool objectiveFinalized;
  final List<String> subjectivePending;
  final List<String> subjectiveReviewed;
  final List<String> subjectiveMissing;

  factory StudentArchiveStateSummary.fromJson(Map<String, dynamic> json) {
    return StudentArchiveStateSummary(
      objectiveFinalized: (json['objectiveFinalized'] ?? true) == true,
      subjectivePending: _toStringList(json['subjectivePending']),
      subjectiveReviewed: _toStringList(json['subjectiveReviewed']),
      subjectiveMissing: _toStringList(json['subjectiveMissing']),
    );
  }
}

class StudentHistoryEntry {
  const StudentHistoryEntry({
    required this.id,
    required this.mockSessionId,
    required this.completedAt,
    required this.resultSummary,
    required this.archiveState,
    required this.strengths,
    required this.weaknesses,
    required this.feedbackNotes,
  });

  final String id;
  final String mockSessionId;
  final DateTime? completedAt;
  final StudentResultSummary resultSummary;
  final StudentArchiveStateSummary archiveState;
  final List<String> strengths;
  final List<String> weaknesses;
  final String feedbackNotes;

  double get listeningBand => resultSummary.section('listening').bandScore ?? 0;
  double get readingBand => resultSummary.section('reading').bandScore ?? 0;
  double? get writingBand => resultSummary.section('writing').bandScore;
  double? get speakingBand => resultSummary.section('speaking').bandScore;
  double? get overallBand => resultSummary.overall.bandScore;
  String get overallBandStatus => resultSummary.overall.status;
  String get writingStatus => resultSummary.section('writing').status;
  String get speakingStatus => resultSummary.section('speaking').status;

  factory StudentHistoryEntry.fromJson(Map<String, dynamic> json) {
    final summaryJson = _toMap(json['resultSummary']);
    final sectionsJson = _toMap(summaryJson['sections']);
    if (sectionsJson.isEmpty) {
      sectionsJson.addAll(<String, dynamic>{
        'listening': <String, dynamic>{
          'status': (json['listeningStatus'] ?? '').toString(),
          'bandScore': json['listeningBand'],
        },
        'reading': <String, dynamic>{
          'status': (json['readingStatus'] ?? '').toString(),
          'bandScore': json['readingBand'],
        },
        'writing': <String, dynamic>{
          'status': (json['writingStatus'] ?? '').toString(),
          'bandScore': json['writingBand'],
        },
        'speaking': <String, dynamic>{
          'status': (json['speakingStatus'] ?? '').toString(),
          'bandScore': json['speakingBand'],
        },
      });
      summaryJson['sections'] = sectionsJson;
    }
    summaryJson['overall'] = <String, dynamic>{
      ..._toMap(summaryJson['overall']),
      'bandScore': summaryJson['overallBand'] ?? json['overallBand'],
      'status': summaryJson['overallStatus'] ?? json['overallBandStatus'],
      'objectiveBandScore': summaryJson['objectiveBandScore'],
      'overallEstimatedBand': summaryJson['overallEstimatedBand'],
    };
    final summary = StudentResultSummary.fromJson(summaryJson);
    final archive = StudentArchiveStateSummary.fromJson(
      _toMap(json['archiveState']),
    );

    return StudentHistoryEntry(
      id: (json['_id'] ?? '').toString(),
      mockSessionId: (json['mockSessionId'] ?? '').toString(),
      completedAt: DateTime.tryParse((json['completedAt'] ?? '').toString()),
      resultSummary: summary,
      archiveState: archive,
      strengths: _toStringList(json['strengths']),
      weaknesses: _toStringList(json['weaknesses']),
      feedbackNotes: (json['feedbackNotes'] ?? '').toString(),
    );
  }
}

class TrendPoint {
  const TrendPoint({
    required this.completedAt,
    required this.overallBand,
    required this.overallBandStatus,
    required this.overallEstimatedBand,
    required this.listeningBand,
    required this.readingBand,
    required this.writingBand,
    required this.speakingBand,
    required this.isFinalized,
  });

  final DateTime? completedAt;
  final double? overallBand;
  final String overallBandStatus;
  final double? overallEstimatedBand;
  final double listeningBand;
  final double readingBand;
  final double? writingBand;
  final double? speakingBand;
  final bool isFinalized;

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    final summary = StudentResultSummary.fromJson(
      _toMap(json['resultSummary']),
    );
    final listening =
        _toNullableDouble(json['listeningBand']) ??
        summary.section('listening').bandScore ??
        0;
    final reading =
        _toNullableDouble(json['readingBand']) ??
        summary.section('reading').bandScore ??
        0;
    final writing =
        _toNullableDouble(json['writingBand']) ??
        summary.section('writing').bandScore;
    final speaking =
        _toNullableDouble(json['speakingBand']) ??
        summary.section('speaking').bandScore;
    final status = (json['overallBandStatus'] ?? summary.overall.status)
        .toString();

    return TrendPoint(
      completedAt: DateTime.tryParse((json['completedAt'] ?? '').toString()),
      overallBand: _toNullableDouble(
        json['overallBand'] ?? json['overall'] ?? summary.overall.bandScore,
      ),
      overallBandStatus: status,
      overallEstimatedBand: _toNullableDouble(
        json['overallEstimatedBand'] ?? summary.overall.overallEstimatedBand,
      ),
      listeningBand: listening,
      readingBand: reading,
      writingBand: writing,
      speakingBand: speaking,
      isFinalized:
          (json['isFinalized'] ?? false) == true ||
          status == OverallStatus.finalized,
    );
  }
}

class StudentAnalytics {
  const StudentAnalytics({
    required this.totalMocks,
    required this.finalizedOverallCount,
    required this.latest,
    required this.latestFinalized,
    required this.trend,
    required this.sectionAverages,
    required this.sectionAverageCounts,
    required this.latestSectionFeedback,
    required this.strengths,
    required this.weaknesses,
    required this.mockAccess,
    required this.hasResumableSession,
    required this.activeSessionId,
    required this.pendingReviewCounts,
    required this.analyticsRule,
  });

  final int totalMocks;
  final int finalizedOverallCount;
  final StudentHistoryEntry? latest;
  final StudentHistoryEntry? latestFinalized;
  final List<TrendPoint> trend;
  final Map<String, double> sectionAverages;
  final Map<String, int> sectionAverageCounts;
  final Map<String, SectionFeedback> latestSectionFeedback;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, dynamic>? mockAccess;
  final bool hasResumableSession;
  final String? activeSessionId;
  final Map<String, int> pendingReviewCounts;
  final Map<String, dynamic> analyticsRule;

  factory StudentAnalytics.fromJson(Map<String, dynamic> json) {
    final latestJson = json['latest'];
    final latestFinalizedJson = json['latestFinalized'];
    final feedbackJson =
        (json['latestSectionFeedback'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final averagesJson =
        (json['sectionAverages'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};

    return StudentAnalytics(
      totalMocks: (json['totalMocks'] as num?)?.toInt() ?? 0,
      finalizedOverallCount:
          (json['finalizedOverallCount'] as num?)?.toInt() ?? 0,
      latest: latestJson is Map<String, dynamic>
          ? StudentHistoryEntry.fromJson(latestJson)
          : null,
      latestFinalized: latestFinalizedJson is Map<String, dynamic>
          ? StudentHistoryEntry.fromJson(latestFinalizedJson)
          : null,
      trend: (json['trend'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TrendPoint.fromJson)
          .toList(),
      sectionAverages: <String, double>{
        'listening': _toDouble(averagesJson['listening']),
        'reading': _toDouble(averagesJson['reading']),
        'writing': _toDouble(averagesJson['writing']),
        'speaking': _toDouble(averagesJson['speaking']),
        'overall': _toDouble(averagesJson['overall']),
      },
      sectionAverageCounts: <String, int>{
        'listening':
            ((averagesJson['counts'] as Map<String, dynamic>?)?['listening']
                    as num?)
                ?.toInt() ??
            0,
        'reading':
            ((averagesJson['counts'] as Map<String, dynamic>?)?['reading']
                    as num?)
                ?.toInt() ??
            0,
        'writing':
            ((averagesJson['counts'] as Map<String, dynamic>?)?['writing']
                    as num?)
                ?.toInt() ??
            0,
        'speaking':
            ((averagesJson['counts'] as Map<String, dynamic>?)?['speaking']
                    as num?)
                ?.toInt() ??
            0,
        'overall':
            ((averagesJson['counts'] as Map<String, dynamic>?)?['overall']
                    as num?)
                ?.toInt() ??
            0,
      },
      latestSectionFeedback: feedbackJson.map(
        (key, value) => MapEntry(
          key,
          SectionFeedback.fromJson(
            value is Map<String, dynamic> ? value : const <String, dynamic>{},
          ),
        ),
      ),
      strengths: _toStringList(json['strengths']),
      weaknesses: _toStringList(json['weaknesses']),
      mockAccess: json['mockAccess'] as Map<String, dynamic>?,
      hasResumableSession: (json['hasResumableSession'] ?? false) as bool,
      activeSessionId: json['activeSessionId']?.toString(),
      pendingReviewCounts: <String, int>{
        'writing':
            ((json['pendingReviewCounts'] as Map<String, dynamic>?)?['writing']
                    as num?)
                ?.toInt() ??
            0,
        'speaking':
            ((json['pendingReviewCounts'] as Map<String, dynamic>?)?['speaking']
                    as num?)
                ?.toInt() ??
            0,
      },
      analyticsRule: _toMap(json['analyticsRule']),
    );
  }
}
