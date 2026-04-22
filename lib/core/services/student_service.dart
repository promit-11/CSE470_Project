import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/core/services/api_client.dart';

class StudentService {
  StudentService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _client.get('/students/profile');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.put('/students/profile', payload);
    return data as Map<String, dynamic>;
  }

  Future<List<StudentHistoryEntry>> getHistory() async {
    final data = await _client.get('/students/history');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(StudentHistoryEntry.fromJson)
        .toList();
  }

  Future<StudentAnalytics> getAnalytics() async {
    final data = await _client.get('/students/analytics');
    return StudentAnalytics.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> purchaseMockAccess({int packSize = 1}) async {
    final data = await _client.post('/students/purchase-mock-access', {
      'packSize': packSize,
    });
    return data as Map<String, dynamic>;
  }

  Future<CoachingAssignmentFormData> getCoachingAssignmentForm() async {
    final data = await _client.get('/students/coaching-assignment/form');
    return CoachingAssignmentFormData.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> submitCoachingAssignmentRequest({
    required String coachingId,
    required String admissionCode,
  }) async {
    final data = await _client.post('/students/coaching-assignment/request', {
      'coachingId': coachingId,
      'admissionCode': admissionCode,
    });
    return data as Map<String, dynamic>;
  }
}
