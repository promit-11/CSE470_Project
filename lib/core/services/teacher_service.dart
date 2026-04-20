import 'package:cse470_app/models/teacher_models.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/utils/app_exceptions.dart';

class TeacherService {
  TeacherService(this._client);

  final ApiClient _client;

  Future<TeacherProfileModel> getProfile() async {
    final data = await _client.get('/teachers/profile');
    return TeacherProfileModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<EvaluationRequestModel>> getPendingRequests() async {
    final data = await _client.get('/teachers/evaluation-requests/pending');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(EvaluationRequestModel.fromJson)
        .toList();
  }

  Future<List<EvaluationRequestModel>> getClaimedRequests() async {
    final data = await _client.get('/teachers/evaluation-requests/claimed');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(EvaluationRequestModel.fromJson)
        .toList();
  }

  Future<List<EvaluationRequestModel>> getReviewedRequests() async {
    final data = await _client.get('/teachers/evaluation-requests/reviewed');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(EvaluationRequestModel.fromJson)
        .toList();
  }

  Future<EvaluationRequestModel> claimRequest(String id) async {
    final data = await _client.patch(
      '/teachers/evaluation-requests/$id/claim',
      {},
    );
    final map = data as Map<String, dynamic>;
    final request = map['request'] as Map<String, dynamic>?;
    return EvaluationRequestModel.fromJson(
      request ?? const <String, dynamic>{},
    );
  }

  Future<EvaluationRequestModel> getRequestDetail(String id) async {
    final data = await _client.get('/teachers/evaluation-requests/$id');
    return EvaluationRequestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TeacherReviewSubmitResult> submitReview(
    String id,
    TeacherReviewPayload payload,
  ) async {
    final data = await _client.post(
      '/teachers/evaluation-requests/$id/review',
      payload.toJson(),
    );
    return TeacherReviewSubmitResult.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> requestPayout({
    required double requestedRewardCredits,
    String note = '',
  }) async {
    final data = await _client.post('/teachers/payouts/request', {
      'requestedRewardCredits': requestedRewardCredits,
      'note': note,
    });
    return data as Map<String, dynamic>;
  }

  Future<List<TeacherPayoutRequestModel>> getPayoutRequests() async {
    try {
      final data = await _client.get('/teachers/payouts');
      return (data as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TeacherPayoutRequestModel.fromJson)
          .toList();
    } on AppException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 501) {
        return const <TeacherPayoutRequestModel>[];
      }
      rethrow;
    }
  }

  Future<TeacherDashboardSummary> getDashboardSummary() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      getProfile(),
      getPendingRequests(),
      getClaimedRequests(),
      getReviewedRequests(),
      getPayoutRequests(),
    ]);

    return TeacherDashboardSummary(
      profile: results[0] as TeacherProfileModel,
      pending: results[1] as List<EvaluationRequestModel>,
      claimed: results[2] as List<EvaluationRequestModel>,
      reviewed: results[3] as List<EvaluationRequestModel>,
      payouts: results[4] as List<TeacherPayoutRequestModel>,
    );
  }
}
