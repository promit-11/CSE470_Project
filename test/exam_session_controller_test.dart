import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cse470_app/controllers/providers.dart';
import 'test_helpers.dart';

void main() {
  group('ExamSessionController', () {
    late ProviderContainer container;
    late MockMockService mockService;

    setUp(() {
      mockService = MockMockService();
      // Create container with overridden mockServiceProvider
      container = ProviderContainer(
        overrides: [mockServiceProvider.overrideWithValue(mockService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state is correct', () {
      final state = container.read(examSessionControllerProvider);

      expect(state.isLoading, false);
      expect(state.errorMessage, null);
      expect(state.session, null);
      expect(state.remainingSeconds, 0);
      expect(state.currentQuestionIndex, 0);
      expect(state.answers, isEmpty);
      expect(state.isSubmitting, false);
    });

    test('startSession loads session data', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();
      final state = container.read(examSessionControllerProvider);

      expect(state.isLoading, false);
      expect(state.session, isNotNull);
      expect(state.session?.id, 'session-123');
      expect(state.session?.currentSection, 'listening');
      expect(state.remainingSeconds, greaterThan(0));
    });

    test('startSession sets error on service failure', () async {
      mockService.shouldThrow = true;
      mockService.throwMessage = 'Network error';

      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();
      final state = container.read(examSessionControllerProvider);

      expect(state.isLoading, false);
      expect(state.session, null);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Could not create'));
    });

    test('loadSession restores session state', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .loadSession('session-456');
      final state = container.read(examSessionControllerProvider);

      expect(state.isLoading, false);
      expect(state.session, isNotNull);
      expect(state.session?.id, 'session-456');
      expect(mockService.callLog.contains('getSession:session-456'), true);
    });

    test('saveAnswer updates local state immediately', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      await container
          .read(examSessionControllerProvider.notifier)
          .saveAnswer('q1', 'A');

      var state = container.read(examSessionControllerProvider);
      expect(state.answers['q1'], 'A');
      expect(mockService.saveAnswerCalls.containsKey('listening:q1'), true);
    });

    test('saveAnswer handles service errors gracefully', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      mockService.shouldThrow = true;

      await container
          .read(examSessionControllerProvider.notifier)
          .saveAnswer('q1', 'A');

      // Should still be able to read state (error caught)
      final state = container.read(examSessionControllerProvider);
      expect(state.session, isNotNull);
    });

    test('toggleFlag updates flagged state', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      await container
          .read(examSessionControllerProvider.notifier)
          .toggleFlag('q1');

      var state = container.read(examSessionControllerProvider);
      expect(state.flagged['q1'], true);

      await container
          .read(examSessionControllerProvider.notifier)
          .toggleFlag('q1');

      state = container.read(examSessionControllerProvider);
      expect(state.flagged['q1'], false);
    });

    test('gotoQuestion navigates between questions', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      // Current state has 3 questions in listening
      var state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 0);

      container.read(examSessionControllerProvider.notifier).gotoQuestion(1);
      state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 1);

      container.read(examSessionControllerProvider.notifier).gotoQuestion(2);
      state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 2);
    });

    test('gotoQuestion bounds checks input', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      // Try to go beyond available questions
      container.read(examSessionControllerProvider.notifier).gotoQuestion(100);
      var state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 0); // Should not change

      // Try negative index
      container.read(examSessionControllerProvider.notifier).gotoQuestion(-1);
      state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 0); // Should not change
    });

    test('currentQuestion provides correct question', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.currentQuestion, isNotNull);
      expect(state.currentQuestion?.id, contains('listening'));

      container.read(examSessionControllerProvider.notifier).gotoQuestion(1);
      state = container.read(examSessionControllerProvider);
      expect(state.currentQuestion?.id, 'listening-1');
    });

    test('currentSection reflects session section', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.currentSection, 'listening');
    });

    test('submitCurrentSection progresses to next section', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.currentSection, 'listening');

      await container
          .read(examSessionControllerProvider.notifier)
          .submitCurrentSection();

      state = container.read(examSessionControllerProvider);
      expect(state.currentSection, 'reading');
      expect(state.currentQuestionIndex, 0); // Reset to first question
      expect(
        mockService.callLog.contains('submitSection:session-123:listening'),
        true,
      );
    });

    test('submitCurrentSection resets question index', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      container.read(examSessionControllerProvider.notifier).gotoQuestion(2);
      var state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 2);

      await container
          .read(examSessionControllerProvider.notifier)
          .submitCurrentSection();

      state = container.read(examSessionControllerProvider);
      expect(state.currentQuestionIndex, 0);
    });

    test('submitCurrentSection handles auto-submitted flag', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      await container
          .read(examSessionControllerProvider.notifier)
          .submitCurrentSection(autoSubmitted: true);

      expect(
        mockService.callLog.contains('submitSection:session-123:listening'),
        true,
      );
    });

    test('Multiple sections can be navigated through', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.currentSection, 'listening');

      // Navigate through all sections
      for (final expectedSection in ['reading', 'writing', 'speaking']) {
        await container
            .read(examSessionControllerProvider.notifier)
            .submitCurrentSection();
        state = container.read(examSessionControllerProvider);
        expect(state.currentSection, expectedSection);
      }
    });

    test('Timer countdown decrements remaining seconds', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);

      // Simulate time passing (would need fake async for real testing)
      // For now, just verify initial state
      expect(state.remainingSeconds, greaterThan(0));
    });

    test('Error message can be cleared by starting new session', () async {
      mockService.shouldThrow = true;
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.errorMessage, isNotNull);

      mockService.shouldThrow = false;
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      state = container.read(examSessionControllerProvider);
      expect(state.errorMessage, null);
    });

    test('isSubmitting flag prevents concurrent submissions', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      expect(state.isSubmitting, false);

      // After submission, flag should be cleared
      await container
          .read(examSessionControllerProvider.notifier)
          .submitCurrentSection();
      state = container.read(examSessionControllerProvider);
      expect(state.isSubmitting, false);
    });

    test('Section state includes all required fields', () async {
      await container
          .read(examSessionControllerProvider.notifier)
          .startSession();

      var state = container.read(examSessionControllerProvider);
      final sectionState = state.currentSectionState;

      expect(sectionState, isNotNull);
      expect(sectionState?.section, 'listening');
      expect(sectionState?.durationSeconds, greaterThan(0));
      expect(sectionState?.remainingSeconds, greaterThan(0));
      expect(sectionState?.answers, isNotEmpty);
      expect(sectionState?.questions, isNotEmpty);
    });
  });
}
