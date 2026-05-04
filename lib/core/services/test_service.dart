// DEPRECATED (legacy flow): Targets old endpoints (/tests, /tests/:id, /tests/:id/questions).
// Active runtime uses /api/v1/mock-sessions and /api/v1/admin/* services.
import 'package:cse470_app/models/question.dart';
import 'package:cse470_app/models/test_model.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/utils/ielts_sections.dart';

class TestService {
  TestService(this._client);

  final ApiClient _client;

  Future<List<TestModel>> getAllTests() async {
    final data = await _client.get('/tests');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TestModel.fromJson)
        .toList();
  }

  Future<TestModel> getTestById(String id) async {
    final data = await _client.get('/tests/$id');
    return TestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TestModel> createTest({
    required String examId,
    required String section,
    String? category,
    String? source,
    String? instruction,
  }) async {
    final normalizedSection = IeltsSections.normalize(section);
    final data = await _client.post('/tests', {
      'examId': examId,
      'section': normalizedSection,
      'category': category == null || category.trim().isEmpty
          ? IeltsSections.toLegacyCategory(normalizedSection)
          : category,
      'source': source,
      'instruction': instruction,
    });
    return TestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TestModel> updateTest(TestModel test) async {
    final normalizedSection = IeltsSections.normalize(test.section);
    final data = await _client.put('/tests/${test.id}', {
      'examId': test.examId,
      'section': normalizedSection,
      'category': test.category.isEmpty
          ? IeltsSections.toLegacyCategory(normalizedSection)
          : test.category,
      'source': test.source,
      'instruction': test.instruction,
    });
    return TestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTest(String id) async {
    await _client.delete('/tests/$id');
  }

  Future<TestModel> addQuestion(String testId, Question question) async {
    final data = await _client.post(
      '/tests/$testId/questions',
      question.toJson(),
    );
    return TestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TestModel> updateQuestion(
    String testId,
    String questionId,
    Question question,
  ) async {
    final data = await _client.put(
      '/tests/$testId/questions/$questionId',
      question.toJson(),
    );
    return TestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<TestModel> deleteQuestion(String testId, String questionId) async {
    final data = await _client.delete('/tests/$testId/questions/$questionId');
    return TestModel.fromJson(data as Map<String, dynamic>);
  }
}
