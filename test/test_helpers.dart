/// Test utilities and mock services for frontend tests
library;

import 'package:cse470_app/models/mock_models.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/services/mock_service.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:cse470_app/core/services/admin_service.dart';
import 'package:file_picker/file_picker.dart';

/// Mock MockService for testing
class MockMockService extends MockService {
  MockMockService() : super(ApiClient.instance);

  // Configuration for testing
  bool shouldThrow = false;
  String throwMessage = 'Service error';

  // Track calls
  List<String> callLog = [];
  Map<String, int> saveAnswerCalls = {};
  Map<String, int> markQuestionCalls = {};

  @override
  Future<MockSession> generateSession() async {
    callLog.add('generateSession');
    if (shouldThrow) throw Exception(throwMessage);

    return MockSession(
      id: 'session-123',
      sectionOrder: ['listening', 'reading', 'writing', 'speaking'],
      currentSection: 'listening',
      sections: [
        _createMockSectionState('listening', 30 * 60, 3),
        _createMockSectionState('reading', 60 * 60, 3),
        _createMockSectionState('writing', 60 * 60, 2),
        _createMockSectionState('speaking', 15 * 60, 3),
      ],
      status: 'active',
      overallBand: 0,
      overallBandStatus: 'pending_review',
      overallEstimatedBand: 0,
      sectionBands: const <String, double>{
        'listening': 0,
        'reading': 0,
        'writing': 0,
        'speaking': 0,
      },
      feedbackSummary: const <String, dynamic>{'notes': ''},
      resultSummary: const <String, dynamic>{
        'sections': {
          'writing': {'status': 'pending_review'},
          'speaking': {'status': 'pending_review'},
        },
      },
    );
  }

  @override
  Future<MockSession> getSession(String sessionId) async {
    callLog.add('getSession:$sessionId');
    if (shouldThrow) throw Exception(throwMessage);

    return MockSession(
      id: sessionId,
      sectionOrder: ['listening', 'reading', 'writing', 'speaking'],
      currentSection: 'listening',
      sections: [
        _createMockSectionState('listening', 30 * 60, 3),
        _createMockSectionState('reading', 60 * 60, 3),
        _createMockSectionState('writing', 60 * 60, 2),
        _createMockSectionState('speaking', 15 * 60, 3),
      ],
      status: 'active',
      overallBand: 0,
      overallBandStatus: 'pending_review',
      overallEstimatedBand: 0,
      sectionBands: const <String, double>{
        'listening': 0,
        'reading': 0,
        'writing': 0,
        'speaking': 0,
      },
      feedbackSummary: const <String, dynamic>{'notes': ''},
      resultSummary: const <String, dynamic>{
        'sections': {
          'writing': {'status': 'pending_review'},
          'speaking': {'status': 'pending_review'},
        },
      },
    );
  }

  @override
  Future<void> saveAnswer({
    required String sessionId,
    required String section,
    required String questionId,
    required dynamic value,
  }) async {
    callLog.add('saveAnswer:$sessionId:$section:$questionId');
    final key = '$section:$questionId';
    saveAnswerCalls[key] = (saveAnswerCalls[key] ?? 0) + 1;
    if (shouldThrow) throw Exception(throwMessage);
  }

  @override
  Future<void> markQuestion({
    required String sessionId,
    required String section,
    required String questionId,
    required bool flagged,
  }) async {
    callLog.add('markQuestion:$sessionId:$section:$questionId:$flagged');
    final key = '$section:$questionId';
    markQuestionCalls[key] = (markQuestionCalls[key] ?? 0) + 1;
    if (shouldThrow) throw Exception(throwMessage);
  }

  @override
  Future<MockSession> submitSection({
    required String sessionId,
    required String section,
    bool autoSubmitted = false,
  }) async {
    callLog.add('submitSection:$sessionId:$section');
    if (shouldThrow) throw Exception(throwMessage);

    // Return session with next section as current
    final sections = [
      _createMockSectionState('listening', 30 * 60, 3, submitted: true),
      _createMockSectionState('reading', 60 * 60, 3),
      _createMockSectionState('writing', 60 * 60, 2),
      _createMockSectionState('speaking', 15 * 60, 3),
    ];

    String nextSection = 'listening';
    if (section == 'listening') nextSection = 'reading';
    if (section == 'reading') nextSection = 'writing';
    if (section == 'writing') nextSection = 'speaking';

    return MockSession(
      id: sessionId,
      sectionOrder: ['listening', 'reading', 'writing', 'speaking'],
      currentSection: nextSection,
      sections: sections,
      status: 'active',
      overallBand: 0,
      overallBandStatus: 'pending_review',
      overallEstimatedBand: 0,
      sectionBands: const <String, double>{
        'listening': 0,
        'reading': 0,
        'writing': 0,
        'speaking': 0,
      },
      feedbackSummary: const <String, dynamic>{'notes': ''},
      resultSummary: const <String, dynamic>{
        'sections': {
          'writing': {'status': 'pending_review'},
          'speaking': {'status': 'pending_review'},
        },
      },
    );
  }

  @override
  Future<MockSession> finalSubmit(String sessionId) async {
    callLog.add('finalSubmit:$sessionId');
    if (shouldThrow) throw Exception(throwMessage);

    return MockSession(
      id: sessionId,
      sectionOrder: ['listening', 'reading', 'writing', 'speaking'],
      currentSection: 'speaking',
      sections: [
        _createMockSectionState('listening', 30 * 60, 3, submitted: true),
        _createMockSectionState('reading', 60 * 60, 3, submitted: true),
        _createMockSectionState('writing', 60 * 60, 2, submitted: true),
        _createMockSectionState('speaking', 15 * 60, 3, submitted: true),
      ],
      status: 'completed',
      overallBand: 7.0,
      overallBandStatus: 'pending_review',
      overallEstimatedBand: 7.0,
      sectionBands: const <String, double>{
        'listening': 7.0,
        'reading': 7.0,
        'writing': 0.0,
        'speaking': 0.0,
      },
      feedbackSummary: const <String, dynamic>{
        'notes': 'Great attempt. Focus on writing and speaking.',
      },
      resultSummary: const <String, dynamic>{
        'sections': {
          'writing': {'status': 'pending_review'},
          'speaking': {'status': 'pending_review'},
        },
      },
    );
  }

  MockSectionState _createMockSectionState(
    String section,
    int duration,
    int questionCount, {
    bool submitted = false,
  }) {
    return MockSectionState(
      section: section,
      durationSeconds: duration,
      remainingSeconds: duration,
      status: submitted ? 'submitted' : 'pending',
      rawScore: 0,
      bandScore: 0,
      startedAt: null,
      submittedAt: null,
      answers: List.generate(
        questionCount,
        (i) => {'questionId': '$section-$i', 'value': null, 'flagged': false},
      ),
      questions: List.generate(
        questionCount,
        (i) => MockQuestion(
          id: '$section-$i',
          section: section,
          questionType: 'mcq',
          title: 'Question ${i + 1}',
          content: 'Test content for question ${i + 1}',
          options: [
            const MockQuestionOption(key: 'A', text: 'Option A'),
            const MockQuestionOption(key: 'B', text: 'Option B'),
            const MockQuestionOption(key: 'C', text: 'Option C'),
            const MockQuestionOption(key: 'D', text: 'Option D'),
          ],
          listeningAudioUrl: '',
        ),
      ),
      writingSubmission: null,
      speakingSubmission: null,
    );
  }
}

/// Mock StudentService for testing
class MockStudentService extends StudentService {
  MockStudentService() : super(ApiClient.instance);

  bool shouldThrow = false;
  String throwMessage = 'Service error';
  List<String> callLog = [];

  @override
  Future<StudentAnalytics> getAnalytics() async {
    callLog.add('getAnalytics');
    if (shouldThrow) throw Exception(throwMessage);

    final now = DateTime.now();
    return StudentAnalytics(
      totalMocks: 3,
      finalizedOverallCount: 0,
      latest: StudentHistoryEntry.fromJson({
        '_id': 'history-123',
        'mockSessionId': 'session-123',
        'completedAt': now.toIso8601String(),
        'resultSummary': {
          'overall': {
            'status': 'pending_full_review',
            'bandScore': null,
            'overallEstimatedBand': 7.0,
          },
          'sections': {
            'listening': {'status': 'completed', 'bandScore': 7.0},
            'reading': {'status': 'completed', 'bandScore': 7.0},
            'writing': {'status': 'pending_review'},
            'speaking': {'status': 'pending_review'},
          },
        },
        'archiveState': {
          'objectiveFinalized': true,
          'subjectivePending': ['writing', 'speaking'],
          'subjectiveReviewed': <String>[],
          'subjectiveMissing': <String>[],
        },
        'strengths': const ['Vocabulary', 'Grammar'],
        'weaknesses': const ['Fluency'],
        'feedbackNotes': 'Solid listening and reading performance.',
      }),
      latestFinalized: null,
      trend: [
        TrendPoint(
          completedAt: now.subtract(const Duration(days: 14)),
          overallBand: 6.5,
          overallBandStatus: 'pending_review',
          overallEstimatedBand: 6.5,
          listeningBand: 6.5,
          readingBand: 6.5,
          writingBand: 0.0,
          speakingBand: 0.0,
          isFinalized: false,
        ),
        TrendPoint(
          completedAt: now.subtract(const Duration(days: 7)),
          overallBand: 6.8,
          overallBandStatus: 'pending_review',
          overallEstimatedBand: 6.8,
          listeningBand: 6.8,
          readingBand: 6.8,
          writingBand: 0.0,
          speakingBand: 0.0,
          isFinalized: false,
        ),
        TrendPoint(
          completedAt: now,
          overallBand: 7.0,
          overallBandStatus: 'pending_review',
          overallEstimatedBand: 7.0,
          listeningBand: 7.0,
          readingBand: 7.0,
          writingBand: 0.0,
          speakingBand: 0.0,
          isFinalized: false,
        ),
      ],
      sectionAverages: {
        'listening': 7.0,
        'reading': 7.0,
        'writing': 0.0,
        'speaking': 0.0,
        'overall': 7.0,
      },
      sectionAverageCounts: const <String, int>{
        'listening': 3,
        'reading': 3,
        'writing': 0,
        'speaking': 0,
        'overall': 3,
      },
      latestSectionFeedback: const <String, SectionFeedback>{
        'listening': SectionFeedback(
          bandScore: 7.0,
          rawScore: 30,
          status: 'good',
          summary: 'Good progression in listening.',
          comments: '',
          strengths: <String>[],
          weaknesses: <String>[],
        ),
        'reading': SectionFeedback(
          bandScore: 7.0,
          rawScore: 30,
          status: 'good',
          summary: 'Good progression in reading.',
          comments: '',
          strengths: <String>[],
          weaknesses: <String>[],
        ),
      },
      strengths: ['Vocabulary', 'Grammar'],
      weaknesses: ['Fluency'],
      mockAccess: {'remainingCredits': 5, 'allowed': true},
      hasResumableSession: false,
      activeSessionId: null,
      pendingReviewCounts: const <String, int>{'writing': 3, 'speaking': 3},
      analyticsRule: const <String, dynamic>{
        'overall': 'pending_until_subjective_review',
      },
    );
  }

  @override
  Future<Map<String, dynamic>> purchaseMockAccess({int packSize = 1}) async {
    callLog.add('purchaseMockAccess:$packSize');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'packSize': packSize,
      'subtotal': 500 * packSize,
      'discountCode': 'TEST10',
      'discountAmount': 50 * packSize,
      'finalAmount': (500 * packSize) - (50 * packSize),
    };
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    callLog.add('getProfile');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'id': 'profile-123',
      'userId': 'user-123',
      'mockAccess': {'remainingCredits': 5},
    };
  }

  @override
  Future<List<StudentHistoryEntry>> getHistory() async {
    callLog.add('getHistory');
    if (shouldThrow) throw Exception(throwMessage);

    final now = DateTime.now();
    return [
      StudentHistoryEntry.fromJson({
        '_id': 'history-1',
        'mockSessionId': 'session-1',
        'completedAt': now.subtract(const Duration(days: 7)).toIso8601String(),
        'resultSummary': {
          'overall': {
            'status': 'pending_full_review',
            'bandScore': null,
            'overallEstimatedBand': 6.5,
          },
          'sections': {
            'listening': {'status': 'completed', 'bandScore': 6.5},
            'reading': {'status': 'completed', 'bandScore': 6.5},
            'writing': {'status': 'pending_review'},
            'speaking': {'status': 'pending_review'},
          },
        },
        'archiveState': {
          'objectiveFinalized': true,
          'subjectivePending': ['writing', 'speaking'],
          'subjectiveReviewed': <String>[],
          'subjectiveMissing': <String>[],
        },
        'strengths': const ['Vocabulary'],
        'weaknesses': const ['Fluency'],
        'feedbackNotes': 'Improve speaking flow.',
      }),
      StudentHistoryEntry.fromJson({
        '_id': 'history-2',
        'mockSessionId': 'session-2',
        'completedAt': now.subtract(const Duration(days: 3)).toIso8601String(),
        'resultSummary': {
          'overall': {
            'status': 'pending_full_review',
            'bandScore': null,
            'overallEstimatedBand': 6.8,
          },
          'sections': {
            'listening': {'status': 'completed', 'bandScore': 6.8},
            'reading': {'status': 'completed', 'bandScore': 6.8},
            'writing': {'status': 'pending_review'},
            'speaking': {'status': 'pending_review'},
          },
        },
        'archiveState': {
          'objectiveFinalized': true,
          'subjectivePending': ['writing', 'speaking'],
          'subjectiveReviewed': <String>[],
          'subjectiveMissing': <String>[],
        },
        'strengths': const ['Grammar'],
        'weaknesses': const ['Coherence'],
        'feedbackNotes': 'Keep practicing writing structure.',
      }),
    ];
  }
}

/// Mock AdminService for testing
class MockAdminService extends AdminService {
  MockAdminService() : super(ApiClient.instance);

  bool shouldThrow = false;
  String throwMessage = 'Service error';
  List<String> callLog = [];
  Map<String, String> createdQuestions = {};

  @override
  Future<Map<String, dynamic>> createQuestion(
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    callLog.add('createQuestion:${payload['section']}');
    if (shouldThrow) throw Exception(throwMessage);
    createdQuestions[payload['title']] = payload['section'];
    return <String, dynamic>{'ok': true};
  }

  @override
  Future<List<Map<String, dynamic>>> getQuestions({
    String? section,
    String? examId,
  }) async {
    callLog.add('getQuestions:$section');
    if (shouldThrow) throw Exception(throwMessage);

    return [
      {
        'id': 'q1',
        'title': 'Question 1',
        'section': section ?? 'listening',
        'difficulty': 'medium',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getExams() async {
    callLog.add('getExams');
    if (shouldThrow) throw Exception(throwMessage);

    return [
      {'id': 'exam1', 'title': 'Mock Exam 1'},
    ];
  }

  @override
  Future<Map<String, dynamic>> getOverview() async {
    callLog.add('getOverview');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'userCount': 100,
      'studentCount': 80,
      'instituteCount': 5,
      'sessionsCompleted': 250,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getTemplates() async {
    callLog.add('getTemplates');
    if (shouldThrow) throw Exception(throwMessage);

    return [
      {'id': 'template1', 'name': 'Default Template', 'active': true},
    ];
  }

  @override
  Future<void> createTemplate(Map<String, dynamic> payload) async {
    callLog.add('createTemplate');
    if (shouldThrow) throw Exception(throwMessage);
  }

  @override
  Future<void> createExam(Map<String, dynamic> payload) async {
    callLog.add('createExam');
    if (shouldThrow) throw Exception(throwMessage);
  }

  @override
  Future<Map<String, dynamic>> listStudents() async {
    callLog.add('listStudents');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'items': [
        {
          'user': {
            '_id': 'student-user-1',
            'name': 'Student One',
            'email': 'student1@example.com',
          },
        },
      ],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> listTeachers({String? state}) async {
    callLog.add('listTeachers:${state ?? ''}');
    if (shouldThrow) throw Exception(throwMessage);

    final items = [
      {
        'user': {
          '_id': 'teacher-user-1',
          'name': 'Teacher One',
          'email': 'teacher1@example.com',
        },
        'teacherProfile': {'status': state ?? 'approved'},
        'coaching': {'_id': 'coaching-1', 'name': 'Coaching One'},
      },
    ];

    return {'items': state == 'pending_approval' ? items : items, 'total': 1};
  }

  @override
  Future<Map<String, dynamic>> listCoachings() async {
    callLog.add('listCoachings');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'items': [
        {'_id': 'coaching-1', 'name': 'Coaching One', 'isActive': true},
      ],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> listPayoutRequests({String? status}) async {
    callLog.add('listPayoutRequests:${status ?? ''}');
    if (shouldThrow) throw Exception(throwMessage);

    final items = [
      {'_id': 'payout-1', 'status': status ?? 'approved', 'amount': 1000},
    ];
    return {'items': items, 'total': 1};
  }

  @override
  Future<Map<String, dynamic>> listAppEvaluationRequests({
    String? status,
    String? section,
  }) async {
    callLog.add('listAppEvaluationRequests:${status ?? ''}:${section ?? ''}');
    if (shouldThrow) throw Exception(throwMessage);

    return {
      'items': [
        {
          '_id': 'eval-1',
          'status': status ?? 'pending',
          'section': section ?? 'writing',
        },
      ],
      'total': 1,
    };
  }
}
