// DEPRECATED (legacy flow): Uses TestService/ExamService old endpoints.
// Active admin runtime path uses AdminDashboardController + AdminService (/api/v1/admin/*).
import 'package:cse470_app/models/question.dart';
import 'package:cse470_app/models/test_model.dart';
import 'package:cse470_app/core/services/exam_service.dart';
import 'package:cse470_app/core/services/test_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminTestState {
  const AdminTestState({
    this.isLoading = false,
    this.errorMessage,
    this.tests = const <TestModel>[],
    this.selectedTest,
  });

  final bool isLoading;
  final String? errorMessage;
  final List<TestModel> tests;
  final TestModel? selectedTest;

  AdminTestState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<TestModel>? tests,
    TestModel? selectedTest,
    bool clearSelectedTest = false,
  }) {
    return AdminTestState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      tests: tests ?? this.tests,
      selectedTest: clearSelectedTest
          ? null
          : (selectedTest ?? this.selectedTest),
    );
  }
}

class AdminTestController extends StateNotifier<AdminTestState> {
  AdminTestController(this._testService, this._examService)
    : super(const AdminTestState());

  final TestService _testService;
  final ExamService _examService;

  Future<void> loadForExam(String examId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final tests = await _examService.getTestsInExam(examId);
      state = state.copyWith(isLoading: false, tests: tests);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> createTest({
    required String examId,
    required String section,
    required String category,
    String? source,
    String? instruction,
  }) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _testService.createTest(
        examId: examId,
        section: section,
        category: category,
        source: source,
        instruction: instruction,
      );
      await loadForExam(examId);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteTest(String examId, String testId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      await _testService.deleteTest(testId);
      await loadForExam(examId);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadTest(String testId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final selectedTest = await _testService.getTestById(testId);
      state = state.copyWith(isLoading: false, selectedTest: selectedTest);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addQuestion(String testId, Question question) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final selectedTest = await _testService.addQuestion(testId, question);
      state = state.copyWith(isLoading: false, selectedTest: selectedTest);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateQuestion(
    String testId,
    String questionId,
    Question question,
  ) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final selectedTest = await _testService.updateQuestion(
        testId,
        questionId,
        question,
      );
      state = state.copyWith(isLoading: false, selectedTest: selectedTest);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteQuestion(String testId, String questionId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final selectedTest = await _testService.deleteQuestion(
        testId,
        questionId,
      );
      state = state.copyWith(isLoading: false, selectedTest: selectedTest);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}
