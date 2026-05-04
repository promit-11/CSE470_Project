import 'dart:async';

import 'package:cse470_app/models/coaching_models.dart';
import 'package:cse470_app/core/services/institute_service.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InstituteState {
  const InstituteState({
    this.isLoading = false,
    this.isWorking = false,
    this.errorMessage,
    this.profile,
    this.students = const <CoachingStudentSummary>[],
    this.discountCodes = const <Map<String, dynamic>>[],
    this.assignmentRequests = const <CoachingAssignmentRequestSummary>[],
    this.teachers = const <CoachingTeacherSummary>[],
    this.availableTeachers = const <AvailableTeacherSummary>[],
    this.exams = const <Map<String, dynamic>>[],
    this.questions = const <Map<String, dynamic>>[],
    this.templates = const <Map<String, dynamic>>[],
    this.evaluationActivity,
  });

  final bool isLoading;
  final bool isWorking;
  final String? errorMessage;
  final Map<String, dynamic>? profile;
  final List<CoachingStudentSummary> students;
  final List<Map<String, dynamic>> discountCodes;
  final List<CoachingAssignmentRequestSummary> assignmentRequests;
  final List<CoachingTeacherSummary> teachers;
  final List<AvailableTeacherSummary> availableTeachers;
  final List<Map<String, dynamic>> exams;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> templates;
  final Map<String, dynamic>? evaluationActivity;

  InstituteState copyWith({
    bool? isLoading,
    bool? isWorking,
    String? errorMessage,
    bool clearErrorMessage = false,
    Map<String, dynamic>? profile,
    List<CoachingStudentSummary>? students,
    List<Map<String, dynamic>>? discountCodes,
    List<CoachingAssignmentRequestSummary>? assignmentRequests,
    List<CoachingTeacherSummary>? teachers,
    List<AvailableTeacherSummary>? availableTeachers,
    List<Map<String, dynamic>>? exams,
    List<Map<String, dynamic>>? questions,
    List<Map<String, dynamic>>? templates,
    Map<String, dynamic>? evaluationActivity,
  }) {
    return InstituteState(
      isLoading: isLoading ?? this.isLoading,
      isWorking: isWorking ?? this.isWorking,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      profile: profile ?? this.profile,
      students: students ?? this.students,
      discountCodes: discountCodes ?? this.discountCodes,
      assignmentRequests: assignmentRequests ?? this.assignmentRequests,
      teachers: teachers ?? this.teachers,
      availableTeachers: availableTeachers ?? this.availableTeachers,
      exams: exams ?? this.exams,
      questions: questions ?? this.questions,
      templates: templates ?? this.templates,
      evaluationActivity: evaluationActivity ?? this.evaluationActivity,
    );
  }
}

class InstituteController extends StateNotifier<InstituteState> {
  InstituteController(this._service) : super(const InstituteState());

  final InstituteService _service;
  Timer? _queueRefreshTimer;
  bool _isLoadInFlight = false;
  bool _isQueueRefreshInFlight = false;
  DateTime? _lastFullLoadAt;

  void startQueueRefresh({Duration interval = const Duration(seconds: 45)}) {
    _queueRefreshTimer?.cancel();
    _queueRefreshTimer = Timer.periodic(interval, (_) {
      _refreshQueueSnapshot();
    });
  }

  void stopQueueRefresh() {
    _queueRefreshTimer?.cancel();
    _queueRefreshTimer = null;
  }

  Future<void> load({bool showLoader = true, bool force = false}) async {
    if (!force && _lastFullLoadAt != null) {
      final elapsed = DateTime.now().difference(_lastFullLoadAt!);
      if (elapsed < const Duration(seconds: 20)) {
        return;
      }
    }
    if (_isLoadInFlight) {
      return;
    }
    _isLoadInFlight = true;
    if (showLoader) {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
    }
    try {
      final results = await Future.wait<dynamic>([
        _service.getProfile(),
        _service.listStudents(),
        _service.listDiscountCodes(),
        _service.listAssignmentRequests(),
        _service.listTeachers(),
        _service.listAvailableTeachers(),
        _service.getExams(),
        _service.getQuestions(),
        _service.getTemplates(),
        _service.getEvaluationActivity(status: 'pending'),
      ]);

      state = state.copyWith(
        isLoading: false,
        isWorking: false,
        profile: results[0] as Map<String, dynamic>,
        students: results[1] as List<CoachingStudentSummary>,
        discountCodes: results[2] as List<Map<String, dynamic>>,
        assignmentRequests:
            results[3] as List<CoachingAssignmentRequestSummary>,
        teachers: results[4] as List<CoachingTeacherSummary>,
        availableTeachers: results[5] as List<AvailableTeacherSummary>,
        exams: results[6] as List<Map<String, dynamic>>,
        questions: results[7] as List<Map<String, dynamic>>,
        templates: results[8] as List<Map<String, dynamic>>,
        evaluationActivity: results[9] as Map<String, dynamic>,
      );
      _lastFullLoadAt = DateTime.now();
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isWorking: false,
        errorMessage: 'Failed to load institute workspace.',
      );
    } finally {
      _isLoadInFlight = false;
    }
  }

  Future<void> _refreshQueueSnapshot() async {
    if (_isQueueRefreshInFlight || _isLoadInFlight) {
      return;
    }
    _isQueueRefreshInFlight = true;
    try {
      final results = await Future.wait<dynamic>([
        _service.listAssignmentRequests(),
        _service.listTeachers(),
        _service.listAvailableTeachers(),
        _service.getEvaluationActivity(status: 'pending'),
      ]);

      state = state.copyWith(
        assignmentRequests:
            results[0] as List<CoachingAssignmentRequestSummary>,
        teachers: results[1] as List<CoachingTeacherSummary>,
        availableTeachers: results[2] as List<AvailableTeacherSummary>,
        evaluationActivity: results[3] as Map<String, dynamic>,
      );
    } catch (_) {
      // Ignore background refresh failures to avoid noisy UI state changes.
    } finally {
      _isQueueRefreshInFlight = false;
    }
  }

  Future<void> verifyStudent(String email) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.verifyStudent(email);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createDiscountCode(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createDiscountCode(payload);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> updateProfile(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.updateProfile(payload);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> acceptAssignmentRequest(
    String requestId, {
    String note = '',
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.acceptAssignmentRequest(requestId, note: note);
      await load(force: true);
    } on AppException catch (e) {
      String message = 'Could not accept assignment request.';
      if (e.statusCode == 409) {
        message = 'This assignment request was already processed.';
      } else if (e.statusCode == 403) {
        message = 'You are not allowed to accept this request.';
      } else if (e.statusCode == 404) {
        message = 'Assignment request not found.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not accept assignment request.',
      );
    }
  }

  Future<void> rejectAssignmentRequest(
    String requestId, {
    String note = '',
  }) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.rejectAssignmentRequest(requestId, note: note);
      await load(force: true);
    } on AppException catch (e) {
      String message = 'Could not reject assignment request.';
      if (e.statusCode == 409) {
        message = 'This assignment request was already processed.';
      } else if (e.statusCode == 403) {
        message = 'You are not allowed to reject this request.';
      } else if (e.statusCode == 404) {
        message = 'Assignment request not found.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not reject assignment request.',
      );
    }
  }

  Future<void> assignTeacher(String teacherId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.assignTeacher(teacherId);
      await load(force: true);
    } on AppException catch (e) {
      String message = 'Could not assign teacher.';
      if (e.statusCode == 409) {
        message = 'Teacher is already assigned or not eligible.';
      } else if (e.statusCode == 403) {
        message = 'You are not allowed to assign this teacher.';
      } else if (e.statusCode == 404) {
        message = 'Teacher or coaching profile not found.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not assign teacher.',
      );
    }
  }

  Future<void> removeTeacher(String teacherId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.removeTeacher(teacherId);
      await load(force: true);
    } on AppException catch (e) {
      String message = 'Could not remove teacher.';
      if (e.statusCode == 409) {
        message = 'Teacher removal is not allowed in current state.';
      } else if (e.statusCode == 403) {
        message = 'Teacher is not assigned to your coaching.';
      } else if (e.statusCode == 404) {
        message = 'Teacher or coaching profile not found.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not remove teacher.',
      );
    }
  }

  Future<void> removeStudent(String studentUserId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.removeStudent(studentUserId);
      await load(force: true);
    } on AppException catch (e) {
      String message = 'Could not remove student.';
      if (e.statusCode == 403) {
        message = 'Student is not assigned to your coaching.';
      } else if (e.statusCode == 404) {
        message = 'Student account/profile not found.';
      }
      state = state.copyWith(isWorking: false, errorMessage: message);
    } catch (_) {
      state = state.copyWith(
        isWorking: false,
        errorMessage: 'Could not remove student.',
      );
    }
  }

  Future<void> createExam(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createExam(payload);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteExam(String examId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteExam(examId);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createQuestion(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createQuestion(payload);
      await load(force: true);
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
      await load(force: true);
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
      await load(force: true);
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
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteQuestion(questionId);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> createTemplate(Map<String, dynamic> payload) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.createTemplate(payload);
      await load(force: true);
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
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    state = state.copyWith(isWorking: true, clearErrorMessage: true);
    try {
      await _service.deleteTemplate(templateId);
      await load(force: true);
    } catch (e) {
      state = state.copyWith(isWorking: false, errorMessage: e.toString());
    }
  }

  @override
  void dispose() {
    stopQueueRefresh();
    super.dispose();
  }
}
