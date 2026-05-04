// DEPRECATED (legacy flow): Uses legacy ExamService (/exams endpoints).
// Active admin runtime path uses AdminDashboardController + AdminService.
import 'package:cse470_app/models/exam.dart';
import 'package:cse470_app/core/services/exam_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminExamState {
  const AdminExamState({
    this.isLoading = false,
    this.errorMessage,
    this.exams = const <Exam>[],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<Exam> exams;

  AdminExamState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<Exam>? exams,
  }) {
    return AdminExamState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      exams: exams ?? this.exams,
    );
  }
}

class AdminExamController extends StateNotifier<AdminExamState> {
  AdminExamController(this._examService) : super(const AdminExamState());

  final ExamService _examService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final exams = await _examService.getExams();
      state = state.copyWith(isLoading: false, exams: exams);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> create({
    required String title,
    required String type,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _examService.createExam(
        Exam(id: '', title: title, type: type, date: date),
      );
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> update(Exam exam) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _examService.updateExam(exam.id, exam);
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> remove(String id) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _examService.deleteExam(id);
      await load();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
