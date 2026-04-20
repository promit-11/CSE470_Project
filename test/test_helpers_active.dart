/// Active Test Helpers - Minimal implementations for test suite
library;

import 'package:cse470_app/models/mock_models.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/services/mock_service.dart';

// Factory to create minimal mock sessions
MockSession createMockSession({
  String id = 's1',
  String status = 'active',
  String currentSection = 'listening',
  List<MockSectionState>? sections,
}) {
  return MockSession(
    id: id,
    status: status,
    currentSection: currentSection,
    sections: sections ?? [createMockSectionState()],
    sectionOrder: const ['listening', 'reading', 'writing', 'speaking'],
    overallBand: null,
    overallBandStatus: 'pending_review',
    overallEstimatedBand: null,
    sectionBands: const {},
    feedbackSummary: const {},
    resultSummary: const {},
  );
}

MockSectionState createMockSectionState({
  String section = 'listening',
  String status = 'active',
  int durationSeconds = 3600,
  int remainingSeconds = 3600,
  double bandScore = 0,
}) {
  return MockSectionState(
    section: section,
    status: status,
    startedAt: DateTime.now(),
    submittedAt: null,
    durationSeconds: durationSeconds,
    remainingSeconds: remainingSeconds,
    rawScore: 0,
    bandScore: bandScore,
    answers: const [],
    questions: const [],
    writingSubmission: const MockWritingSubmission(
      mode: 'typed',
      typedAnswer: '',
      images: [],
    ),
    speakingSubmission: null,
  );
}

// Mock service with call logging
class MockMockServiceActive extends MockService {
  MockMockServiceActive() : super(ApiClient.instance);

  final List<String> callLog = [];
  bool shouldThrow = false;

  @override
  Future<MockSession> generateSession() async {
    callLog.add('generateSession');
    if (shouldThrow) throw Exception('Test error');
    return createMockSession(id: 'session-123');
  }

  @override
  Future<MockSession> getSession(String sessionId) async {
    callLog.add('getSession:$sessionId');
    if (shouldThrow) throw Exception('Test error');
    return createMockSession(id: sessionId);
  }

  @override
  Future<void> saveAnswer({
    required String sessionId,
    required String section,
    required String questionId,
    required dynamic value,
  }) async {
    callLog.add('saveAnswer:$section:$questionId');
    if (shouldThrow) throw Exception('Test error');
  }

  @override
  Future<MockSession> submitSection({
    required String sessionId,
    required String section,
    bool autoSubmitted = false,
  }) async {
    callLog.add('submitSection:$section');
    if (shouldThrow) throw Exception('Test error');
    final current = await getSession(sessionId);
    final sectionIndex = current.sectionOrder.indexOf(section);
    final nextSection = sectionIndex + 1 < current.sectionOrder.length
        ? current.sectionOrder[sectionIndex + 1]
        : section;
    return createMockSession(
      id: sessionId,
      status: current.status,
      currentSection: nextSection,
    );
  }

  @override
  Future<MockSession> finalSubmit(String sessionId) async {
    callLog.add('finalSubmit');
    if (shouldThrow) throw Exception('Test error');
    return createMockSession(id: sessionId, status: 'completed');
  }
}
