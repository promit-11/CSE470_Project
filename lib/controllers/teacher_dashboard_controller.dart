import 'dart:async';

import 'package:cse470_app/models/teacher_models.dart';
import 'package:cse470_app/core/services/teacher_service.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TeacherClaimResult { success, conflict, failure }

class TeacherDashboardState {
  const TeacherDashboardState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.profile,
    this.pendingRequests = const <EvaluationRequestModel>[],
    this.claimedRequests = const <EvaluationRequestModel>[],
    this.reviewedRequests = const <EvaluationRequestModel>[],
    this.payoutRequests = const <TeacherPayoutRequestModel>[],
  });

  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final TeacherProfileModel? profile;
  final List<EvaluationRequestModel> pendingRequests;
  final List<EvaluationRequestModel> claimedRequests;
  final List<EvaluationRequestModel> reviewedRequests;
  final List<TeacherPayoutRequestModel> payoutRequests;

  TeacherDashboardState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool clearErrorMessage = false,
    TeacherProfileModel? profile,
    List<EvaluationRequestModel>? pendingRequests,
    List<EvaluationRequestModel>? claimedRequests,
    List<EvaluationRequestModel>? reviewedRequests,
    List<TeacherPayoutRequestModel>? payoutRequests,
  }) {
    return TeacherDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      profile: profile ?? this.profile,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      claimedRequests: claimedRequests ?? this.claimedRequests,
      reviewedRequests: reviewedRequests ?? this.reviewedRequests,
      payoutRequests: payoutRequests ?? this.payoutRequests,
    );
  }
}

class TeacherDashboardController extends StateNotifier<TeacherDashboardState> {
  TeacherDashboardController(this._teacherService)
    : super(const TeacherDashboardState());

  final TeacherService _teacherService;
  Timer? _queueRefreshTimer;
  bool _isLoadInFlight = false;

  void startQueueRefresh({Duration interval = const Duration(seconds: 45)}) {
    _queueRefreshTimer?.cancel();
    _queueRefreshTimer = Timer.periodic(interval, (_) {
      load(showLoader: false);
    });
  }

  void stopQueueRefresh() {
    _queueRefreshTimer?.cancel();
    _queueRefreshTimer = null;
  }

  Future<void> load({bool showLoader = true}) async {
    if (_isLoadInFlight) {
      return;
    }
    _isLoadInFlight = true;

    if (showLoader) {
      state = state.copyWith(isLoading: true, clearErrorMessage: true);
    }

    try {
      final summary = await _teacherService.getDashboardSummary();

      state = state.copyWith(
        isLoading: false,
        profile: summary.profile,
        pendingRequests: summary.pending,
        claimedRequests: summary.claimed,
        reviewedRequests: summary.reviewed,
        payoutRequests: summary.payouts,
      );
    } on AppException catch (e) {
      if (!showLoader) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final message = e.statusCode == 403
          ? 'Teacher account is not approved for review access yet.'
          : 'Failed to load teacher dashboard.';
      state = state.copyWith(isLoading: false, errorMessage: message);
    } catch (_) {
      if (!showLoader) {
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load teacher dashboard.',
      );
    } finally {
      _isLoadInFlight = false;
    }
  }

  Future<TeacherClaimResult> claimRequest(String requestId) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _teacherService.claimRequest(requestId);
      await load();
      state = state.copyWith(isSubmitting: false);
      return TeacherClaimResult.success;
    } catch (e) {
      if (e is AppException && e.statusCode == 403) {
        await load();
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'You are not eligible to claim this request.',
        );
        return TeacherClaimResult.failure;
      }
      if (e is AppException && e.statusCode == 409) {
        await load();
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'Request already claimed by another teacher. Queue refreshed.',
        );
        return TeacherClaimResult.conflict;
      }
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to claim request.',
      );
      return TeacherClaimResult.failure;
    }
  }

  Future<bool> submitReview({
    required String requestId,
    required TeacherReviewPayload payload,
  }) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _teacherService.submitReview(requestId, payload);
      await load();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (e) {
      String message = 'Failed to submit review.';
      if (e.statusCode == 409) {
        message = 'This request is no longer claimable/reviewable.';
      } else if (e.statusCode == 403) {
        message = 'You do not have permission to review this request.';
      } else if (e.statusCode == 422) {
        message = 'Review submission is invalid. Please check rubric inputs.';
      }
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to submit review.',
      );
      return false;
    }
  }

  Future<EvaluationRequestModel?> getRequestDetail(String requestId) async {
    try {
      return await _teacherService.getRequestDetail(requestId);
    } on AppException catch (e) {
      String message = 'Could not open evaluation request details.';
      if (e.statusCode == 403) {
        message = 'You do not have permission to view this request.';
      } else if (e.statusCode == 409) {
        message = 'This request is no longer in a viewable review state.';
      }
      state = state.copyWith(errorMessage: message);
      return null;
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Could not open evaluation request details.',
      );
      return null;
    }
  }

  Future<bool> requestPayout({required double requestedRewardCredits}) async {
    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    try {
      await _teacherService.requestPayout(
        requestedRewardCredits: requestedRewardCredits,
      );
      await load();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppException catch (e) {
      final message = (e.statusCode == 404 || e.statusCode == 501)
          ? 'Payout is not available for this deployment yet.'
          : 'Failed to create payout request.';
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to create payout request.',
      );
      return false;
    }
  }

  @override
  void dispose() {
    stopQueueRefresh();
    super.dispose();
  }
}
