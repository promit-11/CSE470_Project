import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentCoachingAssignmentState {
  const StudentCoachingAssignmentState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.formData,
    this.lastSuccessMessage,
  });

  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final CoachingAssignmentFormData? formData;
  final String? lastSuccessMessage;

  StudentCoachingAssignmentState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
    CoachingAssignmentFormData? formData,
    String? lastSuccessMessage,
    bool clearSuccessMessage = false,
  }) {
    return StudentCoachingAssignmentState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      formData: formData ?? this.formData,
      lastSuccessMessage: clearSuccessMessage
          ? null
          : (lastSuccessMessage ?? this.lastSuccessMessage),
    );
  }
}

class StudentCoachingAssignmentController
    extends StateNotifier<StudentCoachingAssignmentState> {
  StudentCoachingAssignmentController(this._studentService)
    : super(const StudentCoachingAssignmentState());

  final StudentService _studentService;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );
    try {
      final formData = await _studentService.getCoachingAssignmentForm();
      state = state.copyWith(isLoading: false, formData: formData);
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load coaching assignment details.',
      );
    }
  }

  Future<bool> submitRequest({
    required String coachingId,
    required String admissionCode,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearErrorMessage: true,
      clearSuccessMessage: true,
    );

    try {
      await _studentService.submitCoachingAssignmentRequest(
        coachingId: coachingId,
        admissionCode: admissionCode,
      );
      await load();
      state = state.copyWith(
        isSubmitting: false,
        lastSuccessMessage:
            'Coaching assignment request submitted. Current status: pending.',
      );
      return true;
    } on AppException catch (e) {
      String message = e.message;
      if (e.statusCode == 409) {
        if (message.toLowerCase().contains('already has an active')) {
          message =
              'You are already assigned to a coaching. Please contact support to change.';
        } else if (message.toLowerCase().contains('pending')) {
          message =
              'You already have a pending request. Please wait for coaching review.';
        } else {
          message = 'This action is not allowed at this time.';
        }
      } else if (e.statusCode == 404) {
        message = 'Coaching center or profile not found.';
      } else if (e.statusCode == 400) {
        message =
            'Invalid data submitted. Please check your entries and try again.';
      }
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Could not submit coaching assignment request.',
      );
      return false;
    }
  }
}
