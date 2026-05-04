import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentArchiveState {
  const StudentArchiveState({
    this.isLoading = false,
    this.errorMessage,
    this.history = const <StudentHistoryEntry>[],
  });

  final bool isLoading;
  final String? errorMessage;
  final List<StudentHistoryEntry> history;

  StudentArchiveState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<StudentHistoryEntry>? history,
  }) {
    return StudentArchiveState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      history: history ?? this.history,
    );
  }
}

class StudentArchiveController extends StateNotifier<StudentArchiveState> {
  StudentArchiveController(this._studentService)
    : super(const StudentArchiveState());

  final StudentService _studentService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final history = await _studentService.getHistory();
      state = state.copyWith(isLoading: false, history: history);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load test history.',
      );
    }
  }
}
