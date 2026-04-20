import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/models/coaching_models.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/models/teacher_models.dart';
import 'package:cse470_app/core/services/admin_service.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/services/institute_service.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:cse470_app/core/services/teacher_service.dart';
import 'package:cse470_app/views/screens/student_coaching_assignment_screen.dart';
import 'package:cse470_app/views/screens/teacher_pending_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStudentService extends StudentService {
  _FakeStudentService() : super(ApiClient.instance);

  bool requestSubmitted = false;
  int submitCalls = 0;

  @override
  Future<CoachingAssignmentFormData> getCoachingAssignmentForm() async {
    final assignment = requestSubmitted
        ? const <String, dynamic>{
            'hasActiveAssignment': false,
            'activeCoachingId': null,
            'pendingRequestId': 'request-1',
            'requestStatus': 'pending',
            'currentRequest': {
              'id': 'request-1',
              'status': 'pending',
              'coachingId': 'coaching-1',
              'admissionCode': 'ADM-2026',
              'decisionNote': '',
            },
          }
        : const <String, dynamic>{
            'hasActiveAssignment': false,
            'activeCoachingId': null,
            'pendingRequestId': null,
            'requestStatus': null,
            'currentRequest': null,
          };

    return CoachingAssignmentFormData.fromJson({
      'prefilled': {
        'user': {
          'id': 'student-1',
          'name': 'Student One',
          'email': 'student@test.local',
        },
        'profile': {
          'id': 'profile-1',
          'coachingId': null,
          'studentMode': 'independent',
        },
      },
      'assignment': assignment,
      'coachings': [
        {
          'id': 'coaching-1',
          'name': 'Bright Coaching',
          'description': 'Test coaching',
          'address': 'Dhaka',
          'contactEmail': 'coaching@test.local',
          'contactPhone': '12345',
        },
      ],
    });
  }

  @override
  Future<Map<String, dynamic>> submitCoachingAssignmentRequest({
    required String coachingId,
    required String admissionCode,
  }) async {
    submitCalls += 1;
    requestSubmitted = true;
    return {
      'ok': true,
      'coachingId': coachingId,
      'admissionCode': admissionCode,
    };
  }
}

class _FakeTeacherService extends TeacherService {
  _FakeTeacherService() : super(ApiClient.instance);

  final List<String> claimedRequestIds = <String>[];

  List<EvaluationRequestModel> _pending = <EvaluationRequestModel>[
    const EvaluationRequestModel(
      id: 'req-1',
      testSessionId: 'session-1',
      section: 'writing',
      status: 'pending',
      sourceType: 'app',
    ),
  ];

  List<EvaluationRequestModel> _claimed = const <EvaluationRequestModel>[];

  @override
  Future<TeacherProfileModel> getProfile() async {
    return const TeacherProfileModel(
      id: 'tp-1',
      userId: 'teacher-1',
      coachingId: null,
      rewardCredits: 5,
      bio: '',
      expertiseTags: <String>[],
    );
  }

  @override
  Future<List<EvaluationRequestModel>> getPendingRequests() async => _pending;

  @override
  Future<List<EvaluationRequestModel>> getClaimedRequests() async => _claimed;

  @override
  Future<List<EvaluationRequestModel>> getReviewedRequests() async =>
      const <EvaluationRequestModel>[];

  @override
  Future<List<TeacherPayoutRequestModel>> getPayoutRequests() async =>
      const <TeacherPayoutRequestModel>[];

  @override
  Future<EvaluationRequestModel> claimRequest(String id) async {
    claimedRequestIds.add(id);
    final request = _pending.firstWhere((r) => r.id == id);
    _pending = <EvaluationRequestModel>[];
    _claimed = <EvaluationRequestModel>[
      EvaluationRequestModel(
        id: request.id,
        testSessionId: request.testSessionId,
        section: request.section,
        status: 'claimed',
        sourceType: request.sourceType,
      ),
    ];
    return request;
  }
}

class _FakeAdminService extends AdminService {
  _FakeAdminService() : super(ApiClient.instance);

  final List<String> approvedTeacherIds = <String>[];

  @override
  Future<Map<String, dynamic>> getOverview() async {
    return {
      'students': 1,
      'teachers': 1,
      'coachings': 1,
      'completedSessions': 1,
      'pendingEvaluationRequests': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getExams() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getQuestions({
    String? section,
    String? examId,
  }) async => const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getTemplates() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> listStudents() async {
    return {'items': const <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> listTeachers({String? state}) async {
    if (state == 'pending_approval') {
      return {
        'total': 1,
        'items': [
          {
            'user': {
              'id': 'teacher-1',
              'name': 'Teacher One',
              'email': 'teacher@test.local',
              'approvalStatus': 'pending_approval',
            },
            'teacherProfile': {
              'expertiseTags': <String>['Writing'],
            },
            'coaching': null,
          },
        ],
      };
    }
    return {'items': const <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> listCoachings() async {
    return {'items': const <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> listPayoutRequests({String? status}) async {
    return {'items': const <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> listAppEvaluationRequests({
    String? status,
    String? section,
  }) async {
    return {'items': const <dynamic>[], 'total': 0};
  }

  @override
  Future<Map<String, dynamic>> approveTeacher(String teacherUserId) async {
    approvedTeacherIds.add(teacherUserId);
    return {'ok': true};
  }
}

class _FakeInstituteService extends InstituteService {
  _FakeInstituteService() : super(ApiClient.instance);

  final List<String> acceptedRequestIds = <String>[];

  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[
    <String, dynamic>{
      '_id': 'assign-1',
      'status': 'pending',
      'admissionCode': 'A-123',
      'student': <String, dynamic>{
        'name': 'Student One',
        'email': 'student@test.local',
      },
    },
  ];

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return {
      'name': 'Test Coaching',
      'description': '',
      'address': '',
      'contactPhone': '',
    };
  }

  @override
  Future<List<CoachingStudentSummary>> listStudents() async =>
      const <CoachingStudentSummary>[];

  @override
  Future<List<Map<String, dynamic>>> listDiscountCodes() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<CoachingAssignmentRequestSummary>> listAssignmentRequests({
    String? status,
  }) async => _requests.map(CoachingAssignmentRequestSummary.fromJson).toList();

  @override
  Future<List<CoachingTeacherSummary>> listTeachers() async =>
      const <CoachingTeacherSummary>[];

  @override
  Future<List<AvailableTeacherSummary>> listAvailableTeachers() async =>
      const <AvailableTeacherSummary>[];

  @override
  Future<List<Map<String, dynamic>>> getExams() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getQuestions({String? section}) async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> getTemplates() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> getEvaluationActivity({String? status}) async {
    return {
      'statusCounts': {'pending': 0, 'claimed': 0, 'reviewed': 0},
      'items': const <dynamic>[],
    };
  }

  @override
  Future<Map<String, dynamic>> acceptAssignmentRequest(
    String requestId, {
    String note = '',
  }) async {
    acceptedRequestIds.add(requestId);
    _requests = <Map<String, dynamic>>[];
    return {'ok': true};
  }
}

void main() {
  group('Frontend workflow coverage', () {
    testWidgets(
      '1) teacher pending approval UI shows pending message and email',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 2000));
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(0.9)),
                child: TeacherPendingApprovalScreen(email: 't@x.io'),
              ),
            ),
          ),
        );

        expect(find.text('Teacher Account Under Review'), findsOneWidget);
        expect(
          find.textContaining('pending platform approval'),
          findsOneWidget,
        );
        expect(find.textContaining('t@x.io'), findsOneWidget);
        expect(find.text('Back To Login'), findsOneWidget);
      },
    );

    testWidgets('2) student coaching assignment form submits request flow', (
      tester,
    ) async {
      final fakeStudentService = _FakeStudentService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentServiceProvider.overrideWithValue(fakeStudentService),
          ],
          child: const MaterialApp(home: StudentCoachingAssignmentScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Request Coaching Assignment'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bright Coaching').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'ADM-2026');
      await tester.tap(find.text('Submit Assignment Request'));
      await tester.pumpAndSettle();

      expect(fakeStudentService.submitCalls, 1);
      expect(find.textContaining('Current status: pending'), findsOneWidget);
    });

    test('3) teacher queue and claim behavior (controller flow)', () async {
      final fakeTeacherService = _FakeTeacherService();
      final container = ProviderContainer(
        overrides: [
          teacherServiceProvider.overrideWithValue(fakeTeacherService),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        teacherDashboardControllerProvider.notifier,
      );
      await controller.load();
      var state = container.read(teacherDashboardControllerProvider);
      expect(state.pendingRequests.length, 1);

      final result = await controller.claimRequest('req-1');
      expect(result.name, 'success');

      state = container.read(teacherDashboardControllerProvider);
      expect(state.pendingRequests, isEmpty);
      expect(state.claimedRequests.length, 1);

      expect(fakeTeacherService.claimedRequestIds, contains('req-1'));
    });

    test('4) result summary pending/reviewed states are mapped correctly', () {
      final pending = StudentHistoryEntry.fromJson({
        '_id': 'history-1',
        'mockSessionId': 'session-1',
        'listeningBand': 7,
        'readingBand': 6.5,
        'writingBand': null,
        'speakingBand': 6,
        'overallBand': null,
        'overallBandStatus': 'pending_full_review',
        'resultSummary': {
          'sections': {
            'writing': {'status': 'pending_review'},
            'speaking': {'status': 'reviewed'},
          },
        },
      });

      expect(pending.writingStatus, 'pending_review');
      expect(pending.speakingStatus, 'reviewed');
      expect(pending.overallBand, isNull);

      final reviewed = StudentHistoryEntry.fromJson({
        '_id': 'history-2',
        'mockSessionId': 'session-2',
        'listeningBand': 7,
        'readingBand': 7,
        'writingBand': 6.5,
        'speakingBand': 6.5,
        'overallBand': 6.5,
        'overallBandStatus': 'finalized',
        'resultSummary': {
          'sections': {
            'writing': {'status': 'reviewed'},
            'speaking': {'status': 'reviewed'},
          },
        },
      });

      expect(reviewed.writingStatus, 'reviewed');
      expect(reviewed.speakingStatus, 'reviewed');
      expect(reviewed.overallBand, 6.5);
    });

    test('5) admin teacher approval flow (controller)', () async {
      final fakeAdminService = _FakeAdminService();
      final container = ProviderContainer(
        overrides: [adminServiceProvider.overrideWithValue(fakeAdminService)],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        adminDashboardControllerProvider.notifier,
      );
      await controller.load();

      final loaded = container.read(adminDashboardControllerProvider);
      expect(loaded.pendingApprovalTeachers.length, 1);
      await controller.approveTeacher('teacher-1');

      expect(fakeAdminService.approvedTeacherIds, contains('teacher-1'));
    });

    test('6) coaching admin request acceptance flow (controller)', () async {
      final fakeInstituteService = _FakeInstituteService();
      final container = ProviderContainer(
        overrides: [
          instituteServiceProvider.overrideWithValue(fakeInstituteService),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(instituteControllerProvider.notifier);
      await controller.load();

      final loaded = container.read(instituteControllerProvider);
      expect(loaded.assignmentRequests.length, 1);
      await controller.acceptAssignmentRequest('assign-1', note: 'accepted');

      expect(fakeInstituteService.acceptedRequestIds, contains('assign-1'));
    });
  });
}
