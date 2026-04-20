import 'package:cse470_app/core/services/admin_service.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardState {
  const AdminDashboardState({
    this.isLoading = false,
    this.isWorking = false,
    this.errorMessage,
    this.overview,
    this.exams = const <Map<String, dynamic>>[],
    this.questions = const <Map<String, dynamic>>[],
    this.templates = const <Map<String, dynamic>>[],
    this.students = const <Map<String, dynamic>>[],
    this.teachers = const <Map<String, dynamic>>[],
    this.coachings = const <Map<String, dynamic>>[],
    this.payoutRequests = const <Map<String, dynamic>>[],
    this.pendingApprovalTeachers = const <Map<String, dynamic>>[],
    this.pendingPayoutRequests = const <Map<String, dynamic>>[],
    this.pendingTeacherApprovals = 0,
    this.pendingPayouts = 0,
    this.pendingEvaluations = 0,
    this.claimedEvaluations = 0,
    this.reviewedEvaluations = 0,
  });

  final bool isLoading;
  final bool isWorking;
  final String? errorMessage;
  final Map<String, dynamic>? overview;
  final List<Map<String, dynamic>> exams;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> templates;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> teachers;
  final List<Map<String, dynamic>> coachings;
  final List<Map<String, dynamic>> payoutRequests;
  final List<Map<String, dynamic>> pendingApprovalTeachers;
  final List<Map<String, dynamic>> pendingPayoutRequests;
  final int pendingTeacherApprovals;
  final int pendingPayouts;
  final int pendingEvaluations;
  final int claimedEvaluations;
  final int reviewedEvaluations;

  AdminDashboardState copyWith({
    bool? isLoading,
    bool? isWorking,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<String, dynamic>? overview,
    List<Map<String, dynamic>>? exams,
    List<Map<String, dynamic>>? questions,
    List<Map<String, dynamic>>? templates,
    List<Map<String, dynamic>>? students,
    List<Map<String, dynamic>>? teachers,
    List<Map<String, dynamic>>? coachings,
    List<Map<String, dynamic>>? payoutRequests,
    List<Map<String, dynamic>>? pendingApprovalTeachers,
    List<Map<String, dynamic>>? pendingPayoutRequests,
    int? pendingTeacherApprovals,
    int? pendingPayouts,
    int? pendingEvaluations,
    int? claimedEvaluations,
    int? reviewedEvaluations,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isWorking: isWorking ?? this.isWorking,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      overview: overview ?? this.overview,
      exams: exams ?? this.exams,
      questions: questions ?? this.questions,
      templates: templates ?? this.templates,
      students: students ?? this.students,
      teachers: teachers ?? this.teachers,
      coachings: coachings ?? this.coachings,
      payoutRequests: payoutRequests ?? this.payoutRequests,
      pendingApprovalTeachers:
          pendingApprovalTeachers ?? this.pendingApprovalTeachers,
      pendingPayoutRequests:
          pendingPayoutRequests ?? this.pendingPayoutRequests,
      pendingTeacherApprovals:
          pendingTeacherApprovals ?? this.pendingTeacherApprovals,
      pendingPayouts: pendingPayouts ?? this.pendingPayouts,
      pendingEvaluations: pendingEvaluations ?? this.pendingEvaluations,
      claimedEvaluations: claimedEvaluations ?? this.claimedEvaluations,
      reviewedEvaluations: reviewedEvaluations ?? this.reviewedEvaluations,
    );
  }
}

class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  AdminDashboardController(this._service) : super(const AdminDashboardState());

  final AdminService _service;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getOverview(),
        _service.getExams(),
        _service.getQuestions(),
        _service.getTemplates(),
        _service.listStudents(),
        _service.listTeachers(),
        _service.listCoachings(),
        _service.listTeachers(state: 'pending_approval'),
        _service.listPayoutRequests(status: 'pending'),
        _service.listPayoutRequests(),
        _service.listAppEvaluationRequests(status: 'pending'),
        _service.listAppEvaluationRequests(status: 'claimed'),
        _service.listAppEvaluationRequests(status: 'reviewed'),
      ]);

      final overview = results[0] as Map<String, dynamic>;
      final exams = results[1] as List<Map<String, dynamic>>;
      final questions = results[2] as List<Map<String, dynamic>>;
      final templates = results[3] as List<Map<String, dynamic>>;
      final studentsResponse = results[4] as Map<String, dynamic>;
      final teachersResponse = results[5] as Map<String, dynamic>;
      final coachingsResponse = results[6] as Map<String, dynamic>;
      final pendingTeachersResponse = results[7] as Map<String, dynamic>;
      final pendingPayoutsResponse = results[8] as Map<String, dynamic>;
      final payoutRequestsResponse = results[9] as Map<String, dynamic>;
      final pendingEvalResponse = results[10] as Map<String, dynamic>;
      final claimedEvalResponse = results[11] as Map<String, dynamic>;
      final reviewedEvalResponse = results[12] as Map<String, dynamic>;

      List<Map<String, dynamic>> readItems(Map<String, dynamic> response) {
        return (response['items'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
      }

      int readTotal(Map<String, dynamic> response) {
        return (response['total'] as num?)?.toInt() ?? 0;
      }

      final students = readItems(studentsResponse)
          .map(
            (item) =>
                item['user'] as Map<String, dynamic>? ??
                const <String, dynamic>{},
          )
          .toList();
      final teachers = readItems(teachersResponse)
          .map(
            (item) => {
              ...(item['user'] as Map<String, dynamic>? ??
                  const <String, dynamic>{}),
              'teacherProfile': item['teacherProfile'],
              'coaching': item['coaching'],
            },
          )
          .toList();
      final coachings = readItems(coachingsResponse);
      final payoutRequests = readItems(payoutRequestsResponse);
      final pendingApprovalTeachers = readItems(pendingTeachersResponse)
          .map(
            (item) => {
              ...(item['user'] as Map<String, dynamic>? ??
                  const <String, dynamic>{}),
              'teacherProfile': item['teacherProfile'],
              'coaching': item['coaching'],
            },
          )
          .toList();
      final pendingPayoutRequests = readItems(pendingPayoutsResponse);

      state = state.copyWith(
        isLoading: false,
        overview: overview,
        exams: exams,
        questions: questions,
        templates: templates,
        students: students,
        teachers: teachers,
        coachings: coachings,
        payoutRequests: payoutRequests,
        pendingApprovalTeachers: pendingApprovalTeachers,
        pendingPayoutRequests: pendingPayoutRequests,
        pendingTeacherApprovals: readTotal(pendingTeachersResponse),
        pendingPayouts: readTotal(pendingPayoutsResponse),
        pendingEvaluations: readTotal(pendingEvalResponse),
        claimedEvaluations: readTotal(claimedEvalResponse),
        reviewedEvaluations: readTotal(reviewedEvalResponse),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load admin workspace.',
      );
    }
  }

  Future<void> createExam(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createExam(payload);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createQuestion(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createQuestion(payload);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createQuestionWithOptionalListeningAudio(
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createQuestion(
        payload,
        listeningAudioFile: listeningAudioFile,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createQuestionForExam(
    String examId,
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createQuestionForExam(
        examId,
        payload,
        listeningAudioFile: listeningAudioFile,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> updateQuestion(
    String questionId,
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.updateQuestion(
        questionId,
        payload,
        listeningAudioFile: listeningAudioFile,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createTemplate(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createTemplate(payload);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createTemplateForExam(
    String examId,
    Map<String, dynamic> payload,
  ) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createTemplateForExam(examId, payload);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteExam(String examId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteExam(examId);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteQuestion(questionId);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleTemplateActive(String templateId, bool active) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.updateTemplate(templateId, {'active': active});
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> approveTeacher(String teacherUserId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.approveTeacher(teacherUserId);
      await load();
      state = state.copyWith(isWorking: false);
    } on AppException catch (e) {
      String message = e.message;
      if (e.statusCode == 404) {
        message = 'Teacher not found.';
      } else if (e.statusCode == 409) {
        message = 'Teacher is already approved or in an invalid state.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not approve teacher.',
      );
    }
  }

  Future<void> rejectTeacher(String teacherUserId, {String reason = ''}) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.rejectTeacher(teacherUserId, reason: reason);
      await load();
      state = state.copyWith(isWorking: false);
    } on AppException catch (e) {
      String message = e.message;
      if (e.statusCode == 404) {
        message = 'Teacher not found.';
      } else if (e.statusCode == 409) {
        message = 'Teacher is already in an invalid state for rejection.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not reject teacher.',
      );
    }
  }

  Future<void> createStudent({
    required String name,
    required String email,
    required String password,
    int testCredits = 20,
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createStudent(
        name: name,
        email: email,
        password: password,
        testCredits: testCredits,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteStudent(String studentUserId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteStudent(studentUserId);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createTeacher(
        name: name,
        email: email,
        password: password,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteTeacher(String teacherUserId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteTeacher(teacherUserId);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createCoaching({
    required String adminName,
    required String email,
    required String password,
    required String instituteName,
    String description = '',
    String address = '',
    String contactPhone = '',
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createCoaching(
        adminName: adminName,
        email: email,
        password: password,
        instituteName: instituteName,
        description: description,
        address: address,
        contactPhone: contactPhone,
      );
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteCoaching(String coachingId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteCoaching(coachingId);
      await load();
      state = state.copyWith(isWorking: false);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> approvePayout(String payoutRequestId, {String note = ''}) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.approvePayout(payoutRequestId, note: note);
      await load();
      state = state.copyWith(isWorking: false);
    } on AppException catch (e) {
      String message = e.message;
      if (e.statusCode == 404) {
        message = 'Payout request not found.';
      } else if (e.statusCode == 409) {
        message = 'Payout request is already processed or in an invalid state.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not approve payout request.',
      );
    }
  }

  Future<void> rejectPayout(
    String payoutRequestId, {
    String reason = '',
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.rejectPayout(payoutRequestId, reason: reason);
      await load();
      state = state.copyWith(isWorking: false);
    } on AppException catch (e) {
      String message = e.message;
      if (e.statusCode == 404) {
        message = 'Payout request not found.';
      } else if (e.statusCode == 409) {
        message = 'Payout request is already processed or in an invalid state.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not reject payout request.',
      );
    }
  }
}
