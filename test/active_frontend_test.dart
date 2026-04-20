/// Active Frontend Tests - State Model and Service Integration
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cse470_app/controllers/exam_session_controller.dart';
import 'test_helpers_active.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ExamSessionState - State Management', () {
    test('Initial state is empty', () {
      final state = ExamSessionState();
      expect(state.isLoading, false);
      expect(state.errorMessage, null);
      expect(state.session, null);
    });

    test('State with session loaded', () {
      final session = createMockSession(id: 'test-123');
      final state = ExamSessionState(session: session);
      expect(state.session?.id, 'test-123');
    });

    test('State copyWith updates specific fields', () {
      final session = createMockSession();
      final state1 = ExamSessionState(session: session);
      final state2 = state1.copyWith(currentQuestionIndex: 5);

      expect(state1.currentQuestionIndex, 0);
      expect(state2.currentQuestionIndex, 5);
    });

    test('State with answers', () {
      final state = ExamSessionState(answers: const {'q1': 'A', 'q2': 'B'});
      expect(state.answers.length, 2);
    });

    test('State with flagged questions', () {
      final state = ExamSessionState(flagged: const {'q1': true, 'q3': true});
      expect(state.flagged.length, 2);
    });

    test('State with writing mode', () {
      final state1 = ExamSessionState(writingMode: 'images');
      expect(state1.writingMode, 'images');

      final state2 = ExamSessionState(writingMode: 'typed');
      expect(state2.writingMode, 'typed');
    });

    test('State with submission status', () {
      final state = ExamSessionState(isSubmitting: true);
      expect(state.isSubmitting, true);
    });

    test('State with error message', () {
      final state = ExamSessionState(errorMessage: 'Test error');
      expect(state.errorMessage, 'Test error');
    });

    test('State with loading', () {
      final state = ExamSessionState(isLoading: true);
      expect(state.isLoading, true);
    });
  });

  group('Mock Models - Session and Section', () {
    test('MockSession with default values', () {
      final session = createMockSession();
      expect(session.id, 's1');
      expect(session.status, 'active');
      expect(session.currentSection, 'listening');
    });

    test('MockSession with custom values', () {
      final session = createMockSession(
        id: 'custom',
        status: 'completed',
        currentSection: 'writing',
      );
      expect(session.id, 'custom');
      expect(session.status, 'completed');
      expect(session.currentSection, 'writing');
    });

    test('MockSectionState with default values', () {
      final section = createMockSectionState();
      expect(section.section, 'listening');
      expect(section.status, 'active');
      expect(section.durationSeconds, 3600);
    });

    test('MockSectionState with custom section', () {
      final section = createMockSectionState(
        section: 'writing',
        status: 'submitted',
      );
      expect(section.section, 'writing');
      expect(section.status, 'submitted');
    });
  });

  group('Mock Service - Call Logging and Behavior', () {
    test('Service initializes without calls', () {
      final service = MockMockServiceActive();
      expect(service.callLog, isEmpty);
    });

    test('generateSession is logged', () async {
      final service = MockMockServiceActive();
      await service.generateSession();
      expect(service.callLog.contains('generateSession'), true);
    });

    test('getSession is logged with session ID', () async {
      final service = MockMockServiceActive();
      await service.getSession('sess-789');
      expect(service.callLog.contains('getSession:sess-789'), true);
    });

    test('saveAnswer is logged with section and question', () async {
      final service = MockMockServiceActive();
      await service.saveAnswer(
        sessionId: 'sess-1',
        section: 'listening',
        questionId: 'q5',
        value: 'B',
      );
      expect(service.callLog.contains('saveAnswer:listening:q5'), true);
    });

    test('submitSection is logged and advances section', () async {
      final service = MockMockServiceActive();
      final result = await service.submitSection(
        sessionId: 'sess-1',
        section: 'listening',
      );
      expect(service.callLog.contains('submitSection:listening'), true);
      expect(result.currentSection, 'reading');
    });

    test('finalSubmit is logged and completes session', () async {
      final service = MockMockServiceActive();
      final result = await service.finalSubmit('sess-1');
      expect(service.callLog.contains('finalSubmit'), true);
      expect(result.status, 'completed');
    });

    test('shouldThrow flag causes exceptions', () async {
      final service = MockMockServiceActive();
      service.shouldThrow = true;

      expect(() => service.generateSession(), throwsException);
    });

    test('Multiple calls are logged in order', () async {
      final service = MockMockServiceActive();
      await service.generateSession();
      await service.saveAnswer(
        sessionId: 'sess-1',
        section: 'listening',
        questionId: 'q1',
        value: 'A',
      );
      await service.submitSection(sessionId: 'sess-1', section: 'listening');

      expect(service.callLog.length, greaterThanOrEqualTo(3));
      expect(service.callLog[0], 'generateSession');
      expect(service.callLog.any((log) => log.contains('saveAnswer')), true);
      expect(service.callLog.any((log) => log.contains('submitSection')), true);
    });
  });

  group('Active Test Infrastructure', () {
    test('Test helpers create valid mock objects', () {
      final session = createMockSession();
      final state = ExamSessionState(session: session);

      expect(session.sections, isNotEmpty);
      expect(state.session, isNotNull);
    });

    test('Mock service can be instantiated and used', () async {
      final service = MockMockServiceActive();
      final session = await service.generateSession();

      expect(session.id, isNotNull);
      expect(session.sections, isNotEmpty);
    });

    test('Service call log enables verification', () async {
      final service = MockMockServiceActive();
      await service.generateSession();
      await service.getSession('test');

      expect(service.callLog.length, 2);
      expect(
        service.callLog.where((log) => log.contains('Session')).length,
        greaterThan(0),
      );
    });
  });
}
