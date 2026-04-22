import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentDashboardState {
  const StudentDashboardState({
    this.isLoading = false,
    this.errorMessage,
    this.analytics,
    this.profile,
    this.isPurchasing = false,
    this.purchaseResult,
    this.coachingFormData,
  });

  final bool isLoading;
  final String? errorMessage;
  final StudentAnalytics? analytics;
  final Map<String, dynamic>? profile;
  final bool isPurchasing;
  final Map<String, dynamic>? purchaseResult;
  final CoachingAssignmentFormData? coachingFormData;

  StudentDashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    StudentAnalytics? analytics,
    Map<String, dynamic>? profile,
    bool? isPurchasing,
    Map<String, dynamic>? purchaseResult,
    bool clearPurchaseResult = false,
    CoachingAssignmentFormData? coachingFormData,
  }) {
    return StudentDashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      analytics: analytics ?? this.analytics,
      profile: profile ?? this.profile,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      purchaseResult: clearPurchaseResult
          ? null
          : (purchaseResult ?? this.purchaseResult),
      coachingFormData: coachingFormData ?? this.coachingFormData,
    );
  }
}

class StudentDashboardController extends StateNotifier<StudentDashboardState> {
  StudentDashboardController(this._studentService)
    : super(const StudentDashboardState());

  final StudentService _studentService;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final results = await Future.wait([
        _studentService.getProfile(),
        _studentService.getAnalytics(),
        _studentService.getCoachingAssignmentForm(),
      ], eagerError: false);

      final profile = results[0] as Map<String, dynamic>;
      final analytics = results[1] as StudentAnalytics;
      final coachingFormData = (results[2] is CoachingAssignmentFormData)
          ? results[2] as CoachingAssignmentFormData
          : null;

      state = state.copyWith(
        isLoading: false,
        analytics: analytics,
        profile: profile,
        coachingFormData: coachingFormData,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard data.',
      );
    }
  }

  Future<Map<String, dynamic>?> purchaseMockAccess({int packSize = 1}) async {
    state = state.copyWith(
      isPurchasing: true,
      clearErrorMessage: true,
      clearPurchaseResult: true,
    );
    try {
      final result = await _studentService.purchaseMockAccess(
        packSize: packSize,
      );
      final analytics = await _studentService.getAnalytics();
      state = state.copyWith(
        isPurchasing: false,
        purchaseResult: result,
        analytics: analytics,
      );
      return result;
    } catch (_) {
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'Could not complete purchase.',
      );
      return null;
    }
  }
}
