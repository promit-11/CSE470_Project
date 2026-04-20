import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/views/widgets/band_trend_chart.dart';

TrendPoint _trend(double overall) {
  return TrendPoint(
    completedAt: DateTime(2024, 4, 18),
    overallBand: overall,
    overallBandStatus: 'finalized',
    overallEstimatedBand: overall,
    listeningBand: overall,
    readingBand: overall,
    writingBand: 0.0,
    speakingBand: 0.0,
    isFinalized: true,
  );
}

StudentHistoryEntry _historyEntry({
  required String id,
  required double overall,
}) {
  const resultSummary = StudentResultSummary(
    contractVersion: 'v1',
    overall: ResultOverallSummary(
      status: OverallStatus.finalized,
      rule: 'average',
      ruleLabel: 'Average',
      isPartial: false,
      bandScore: 7.0,
      objectiveBandScore: 7.0,
      pendingSections: <String>[],
      reviewedSections: <String>['writing', 'speaking'],
      unavailableSections: <String>[],
      overallEstimatedBand: 7.0,
    ),
    sections: <String, ResultSectionSummary>{},
    pendingSubjectiveSections: <String>[],
    reviewedSubjectiveSections: <String>['writing', 'speaking'],
    unavailableSubjectiveSections: <String>[],
  );

  const archiveState = StudentArchiveStateSummary(
    objectiveFinalized: true,
    subjectivePending: <String>[],
    subjectiveReviewed: <String>['writing', 'speaking'],
    subjectiveMissing: <String>[],
  );

  return StudentHistoryEntry(
    id: id,
    mockSessionId: 'session-$id',
    completedAt: DateTime(2024, 4, 18),
    resultSummary: resultSummary,
    archiveState: archiveState,
    strengths: const <String>['Vocabulary'],
    weaknesses: const <String>['Fluency'],
    feedbackNotes: 'Good progress.',
  );
}

Map<String, SectionFeedback> _feedback() {
  return const <String, SectionFeedback>{
    'listening': SectionFeedback(
      bandScore: 7.0,
      rawScore: 30,
      status: 'good',
      summary: 'Excellent listening comprehension',
      comments: '',
      strengths: <String>['Comprehension'],
      weaknesses: <String>[],
    ),
    'reading': SectionFeedback(
      bandScore: 6.5,
      rawScore: 28,
      status: 'good',
      summary: 'Strong reading pace',
      comments: '',
      strengths: <String>['Pace'],
      weaknesses: <String>[],
    ),
    'writing': SectionFeedback(
      bandScore: 6.0,
      rawScore: 0,
      status: 'needs_work',
      summary: 'Task response could be improved',
      comments: '',
      strengths: <String>[],
      weaknesses: <String>['Task response'],
    ),
  };
}

void main() {
  group('Analytics Rendering', () {
    testWidgets('Band trend chart renders with valid data', (
      WidgetTester tester,
    ) async {
      final trend = [_trend(6.5), _trend(6.8), _trend(7.0)];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: BandTrendChart(trend: trend)),
          ),
        ),
      );

      expect(find.byType(BandTrendChart), findsOneWidget);
    });

    testWidgets('Band trend chart handles empty data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: BandTrendChart(trend: const [])),
          ),
        ),
      );

      expect(find.byType(BandTrendChart), findsOneWidget);
    });

    testWidgets('Band trend chart handles single data point', (
      WidgetTester tester,
    ) async {
      final trend = [_trend(7.0)];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: BandTrendChart(trend: trend)),
          ),
        ),
      );

      expect(find.byType(BandTrendChart), findsOneWidget);
    });

    testWidgets('Band trend chart handles multiple data points', (
      WidgetTester tester,
    ) async {
      final trend = [
        _trend(6.0),
        _trend(6.2),
        _trend(6.5),
        _trend(6.8),
        _trend(7.0),
        _trend(7.2),
        _trend(7.5),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: BandTrendChart(trend: trend)),
          ),
        ),
      );

      expect(find.byType(BandTrendChart), findsOneWidget);
    });
  });

  group('Analytics Data Mapping', () {
    test('StudentAnalytics correctly maps section averages', () {
      final analytics = StudentAnalytics(
        totalMocks: 5,
        finalizedOverallCount: 1,
        latest: _historyEntry(id: '1', overall: 7.0),
        latestFinalized: _historyEntry(id: '1', overall: 7.0),
        trend: [_trend(7.0)],
        sectionAverages: {
          'listening': 7.0,
          'reading': 7.0,
          'writing': 0.0,
          'speaking': 0.0,
          'overall': 7.0,
        },
        sectionAverageCounts: const <String, int>{
          'listening': 1,
          'reading': 1,
          'writing': 1,
          'speaking': 1,
          'overall': 1,
        },
        latestSectionFeedback: _feedback(),
        strengths: ['Vocabulary', 'Grammar'],
        weaknesses: ['Fluency'],
        mockAccess: {'remainingCredits': 5, 'allowed': true},
        hasResumableSession: false,
        activeSessionId: null,
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics.totalMocks, 5);
      expect(analytics.sectionAverages['listening'], 7.0);
      expect(analytics.sectionAverages['reading'], 7.0);
      expect(analytics.sectionAverages['overall'], 7.0);
      expect(analytics.strengths.length, 2);
      expect(analytics.weaknesses.length, 1);
    });

    test('StudentHistoryEntry contains all required fields', () {
      final entry = _historyEntry(id: '123', overall: 7.5);

      expect(entry.mockSessionId, 'session-123');
      expect(entry.overallBand, 7.5);
      expect(entry.listeningBand, 7.5);
      expect(entry.readingBand, 7.5);
      expect(entry.writingBand, 0.0);
      expect(entry.speakingBand, 0.0);
      expect(entry.completedAt!.year, 2024);
    });

    test('TrendPoint correctly stores overall band score', () {
      final point1 = _trend(6.5);
      final point2 = _trend(7.0);

      expect(point1.overallBand, 6.5);
      expect(point2.overallBand, 7.0);
    });

    test('StudentAnalytics handles zero scores for writing/speaking', () {
      final analytics = StudentAnalytics(
        totalMocks: 1,
        finalizedOverallCount: 0,
        latest: _historyEntry(id: '1', overall: 6.0),
        latestFinalized: null,
        trend: [],
        sectionAverages: {
          'listening': 6.0,
          'reading': 6.0,
          'writing': 0.0,
          'speaking': 0.0,
          'overall': 6.0,
        },
        sectionAverageCounts: const <String, int>{
          'listening': 1,
          'reading': 1,
          'writing': 1,
          'speaking': 1,
          'overall': 1,
        },
        latestSectionFeedback: {},
        strengths: [],
        weaknesses: [],
        mockAccess: {},
        hasResumableSession: false,
        activeSessionId: null,
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics.sectionAverages['writing'], 0.0);
      expect(analytics.sectionAverages['speaking'], 0.0);
    });

    test('StudentAnalytics preserves section feedback mapping', () {
      final feedback = _feedback();

      final analytics = StudentAnalytics(
        totalMocks: 1,
        finalizedOverallCount: 0,
        latest: _historyEntry(id: '1', overall: 6.5),
        latestFinalized: null,
        trend: [],
        sectionAverages: {},
        sectionAverageCounts: const <String, int>{},
        latestSectionFeedback: feedback,
        strengths: [],
        weaknesses: [],
        mockAccess: {},
        hasResumableSession: false,
        activeSessionId: null,
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics.latestSectionFeedback.length, 3);
      expect(
        analytics.latestSectionFeedback['listening']?.note,
        'Excellent listening comprehension',
      );
      expect(
        analytics.latestSectionFeedback['reading']?.note,
        'Strong reading pace',
      );
    });

    test('StudentAnalytics correctly identifies strengths and weaknesses', () {
      const strengths = ['Vocabulary', 'Pronunciation', 'Fluency'];
      const weaknesses = ['Grammar', 'Time management'];

      final analytics = StudentAnalytics(
        totalMocks: 1,
        finalizedOverallCount: 0,
        latest: null,
        latestFinalized: null,
        trend: [],
        sectionAverages: {},
        sectionAverageCounts: const <String, int>{},
        latestSectionFeedback: {},
        strengths: strengths,
        weaknesses: weaknesses,
        mockAccess: {},
        hasResumableSession: false,
        activeSessionId: null,
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics.strengths.length, 3);
      expect(analytics.strengths.contains('Vocabulary'), true);
      expect(analytics.weaknesses.length, 2);
      expect(analytics.weaknesses.contains('Grammar'), true);
    });

    test('MockAccess provides credit information', () {
      final mockAccess = {
        'allowed': true,
        'plan': 'premium',
        'remainingCredits': 10,
        'lastPurchasedAt': '2024-04-18',
      };

      expect(mockAccess['allowed'], true);
      expect(mockAccess['remainingCredits'], 10);
      expect(mockAccess['plan'], 'premium');
    });

    test('StudentAnalytics properly handles resumable session', () {
      final analytics1 = StudentAnalytics(
        totalMocks: 0,
        finalizedOverallCount: 0,
        latest: null,
        latestFinalized: null,
        trend: [],
        sectionAverages: {},
        sectionAverageCounts: const <String, int>{},
        latestSectionFeedback: {},
        strengths: [],
        weaknesses: [],
        mockAccess: {},
        hasResumableSession: true,
        activeSessionId: 'session-123',
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics1.hasResumableSession, true);
      expect(analytics1.activeSessionId, 'session-123');

      final analytics2 = StudentAnalytics(
        totalMocks: 0,
        finalizedOverallCount: 0,
        latest: null,
        latestFinalized: null,
        trend: [],
        sectionAverages: {},
        sectionAverageCounts: const <String, int>{},
        latestSectionFeedback: {},
        strengths: [],
        weaknesses: [],
        mockAccess: {},
        hasResumableSession: false,
        activeSessionId: null,
        pendingReviewCounts: const <String, int>{'writing': 0, 'speaking': 0},
        analyticsRule: const <String, dynamic>{},
      );

      expect(analytics2.hasResumableSession, false);
      expect(analytics2.activeSessionId, null);
    });
  });

  group('Result Summary Data Structures', () {
    test('StudentHistoryEntry supports equality comparison', () {
      final entry1 = _historyEntry(id: '1', overall: 7.0);
      final entry2 = _historyEntry(id: '1', overall: 7.0);

      // Both should have same values
      expect(entry1.mockSessionId, entry2.mockSessionId);
      expect(entry1.overallBand, entry2.overallBand);
    });

    test('Band scores are within valid range', () {
      for (final score in [0.0, 4.5, 6.0, 7.5, 9.0]) {
        final entry = _historyEntry(id: 'range-$score', overall: score);

        expect((entry.overallBand ?? 0) >= 0, true);
        expect((entry.overallBand ?? 0) <= 9.0, true);
      }
    });

    test('Trend contains multiple data points for chart rendering', () {
      final trend = List.generate(10, (i) => _trend(6.0 + (i * 0.1)));

      expect(trend.length, 10);
      expect(trend.first.overallBand, 6.0);
      expect(trend.last.overallBand, 6.9);
    });
  });
}
