// DEPRECATED (legacy flow): Targets old endpoints (/exams, /exams/:id/tests).
// Active runtime uses V1 admin and mock-session services.
import 'package:cse470_app/models/exam.dart';
import 'package:cse470_app/models/test_model.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/utils/ielts_sections.dart';

class ExamService {
  ExamService(this._client);

  final ApiClient _client;

  Future<List<Exam>> getExams() async {
    final data = await _client.get('/exams');
    final list = (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(Exam.fromJson)
        .toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<Exam> createExam(Exam exam) async {
    final data = await _client.post('/exams', exam.toJson());
    return Exam.fromJson(data as Map<String, dynamic>);
  }

  Future<Exam> updateExam(String id, Exam exam) async {
    final data = await _client.put('/exams/$id', exam.toJson());
    return Exam.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteExam(String id) async {
    await _client.delete('/exams/$id');
  }

  Future<List<TestModel>> getTestsInExam(String examId) async {
    final data = await _client.get('/exams/$examId/tests');
    final list = (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TestModel.fromJson)
        .toList();
    list.sort(
      (a, b) => a.category.compareTo(b.category) != 0
          ? a.category.compareTo(b.category)
          : IeltsSections.orderIndex(
              a.section,
            ).compareTo(IeltsSections.orderIndex(b.section)),
    );
    return list;
  }
}
