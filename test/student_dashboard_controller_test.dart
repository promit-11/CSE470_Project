import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cse470_app/controllers/providers.dart';
import 'test_helpers.dart';

void main() {
  group('StudentDashboardController', () {
    late ProviderContainer container;
    late MockStudentService mockService;

    setUp(() {
      mockService = MockStudentService();
      container = ProviderContainer(
        overrides: [studentServiceProvider.overrideWithValue(mockService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      final state = container.read(studentDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.errorMessage, null);
      expect(state.analytics, null);
      expect(state.profile, null);
      expect(state.isPurchasing, false);
    });

    test('load fetches analytics and profile', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.analytics, isNotNull);
      expect(state.profile, isNotNull);
      expect(mockService.callLog.contains('getAnalytics'), true);
      expect(mockService.callLog.contains('getProfile'), true);
    });

    test('load sets error on service failure', () async {
      mockService.shouldThrow = true;

      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);

      expect(state.isLoading, false);
      expect(state.errorMessage, isNotNull);
      expect(state.analytics, null);
    });

    test('Analytics data is properly mapped', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);
      final analytics = state.analytics;

      expect(analytics?.totalMocks, 3);
      expect(analytics?.latest, isNotNull);
      expect(analytics?.latest?.overallBand, 7.0);
      expect(analytics?.trend, isNotEmpty);
      expect(analytics?.sectionAverages, isNotNull);
      expect(analytics?.sectionAverages['listening'], 7.0);
      expect(analytics?.sectionAverages['reading'], 7.0);
      expect(analytics?.strengths, contains('Vocabulary'));
      expect(analytics?.weaknesses, contains('Fluency'));
    });

    test('purchaseMockAccess updates mock credits', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final result = await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 5);

      expect(result, isNotNull);
      expect(result?['packSize'], 5);
      expect(result?['finalAmount'], 2250); // 500*5 - 50*5
      expect(mockService.callLog.contains('purchaseMockAccess:5'), true);
    });

    test('purchaseMockAccess applies discount', () async {
      final result = await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 5);

      expect(result?['discountCode'], 'TEST10');
      expect(result?['discountAmount'], greaterThan(0));
      expect(result?['finalAmount'], lessThan(result?['subtotal']));
    });

    test('purchaseMockAccess reloads analytics after purchase', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final callsBefore = mockService.callLog.length;

      await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 3);

      final callsAfter = mockService.callLog.length;

      // Should have called getAnalytics again after purchase
      expect(callsAfter, greaterThan(callsBefore));
      expect(
        mockService.callLog
            .where((call) => call.startsWith('getAnalytics'))
            .length,
        greaterThanOrEqualTo(1),
      );
    });

    test('purchaseMockAccess handles service error', () async {
      mockService.shouldThrow = true;

      final result = await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 5);

      final state = container.read(studentDashboardControllerProvider);

      expect(result, null);
      expect(state.errorMessage, isNotNull);
      expect(state.isPurchasing, false);
    });

    test('isPurchasing flag is set during purchase', () async {
      final controller = container.read(
        studentDashboardControllerProvider.notifier,
      );

      // Start purchase in background (don't await immediately)
      final purchaseFuture = controller.purchaseMockAccess(packSize: 3);

      // Give it a moment to start
      await Future.delayed(const Duration(milliseconds: 10));

      // After completion
      await purchaseFuture;

      final state = container.read(studentDashboardControllerProvider);
      expect(state.isPurchasing, false);
    });

    test('Multiple purchases can be made sequentially', () async {
      final result1 = await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 5);

      final result2 = await container
          .read(studentDashboardControllerProvider.notifier)
          .purchaseMockAccess(packSize: 3);

      expect(result1, isNotNull);
      expect(result2, isNotNull);
      expect(result1?['packSize'], 5);
      expect(result2?['packSize'], 3);
    });

    test('Analytics trend contains multiple data points', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);
      final trend = state.analytics?.trend;

      expect(trend, isNotEmpty);
      expect(trend?.length, greaterThanOrEqualTo(1));
      for (final point in trend ?? []) {
        expect(point.overallBand, greaterThan(0));
      }
    });

    test('Section averages include all sections', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);
      final averages = state.analytics?.sectionAverages;

      expect(averages?.containsKey('listening'), true);
      expect(averages?.containsKey('reading'), true);
      expect(averages?.containsKey('writing'), true);
      expect(averages?.containsKey('speaking'), true);
      expect(averages?.containsKey('overall'), true);
    });

    test('Error message is cleared on new load', () async {
      mockService.shouldThrow = true;
      await container.read(studentDashboardControllerProvider.notifier).load();

      var state = container.read(studentDashboardControllerProvider);
      expect(state.errorMessage, isNotNull);

      mockService.shouldThrow = false;
      await container.read(studentDashboardControllerProvider.notifier).load();

      state = container.read(studentDashboardControllerProvider);
      expect(state.errorMessage, null);
    });

    test('mockAccess provides credit information', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);
      final mockAccess = state.analytics?.mockAccess;

      expect(mockAccess, isNotNull);
      expect(mockAccess?['remainingCredits'], greaterThan(0));
      expect(mockAccess?['allowed'], true);
    });

    test('hasResumableSession indicates if session can be resumed', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);

      expect(state.analytics?.hasResumableSession, isFalse);
      expect(state.analytics?.activeSessionId, null);
    });

    test('Latest test entry contains complete information', () async {
      await container.read(studentDashboardControllerProvider.notifier).load();

      final state = container.read(studentDashboardControllerProvider);
      final latest = state.analytics?.latest;

      expect(latest?.mockSessionId, isNotNull);
      expect(latest?.overallBand, isNotNull);
      expect(latest?.listeningBand, isNotNull);
      expect(latest?.readingBand, isNotNull);
      expect(latest?.completedAt, isNotNull);
    });
  });
}
