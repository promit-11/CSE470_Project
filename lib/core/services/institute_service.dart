import 'package:dio/dio.dart';
import 'package:cse470_app/models/coaching_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:cse470_app/core/services/api_client.dart';

class InstituteService {
  InstituteService(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _client.get('/institutes/profile');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.put('/institutes/profile', payload);
    return data as Map<String, dynamic>;
  }

  Future<void> verifyStudent(String email) async {
    await _client.post('/institutes/students/verify', {'email': email});
  }

  Future<List<CoachingStudentSummary>> listStudents() async {
    final data = await _client.get('/institutes/students');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CoachingStudentSummary.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> removeStudent(String studentUserId) async {
    final data = await _client.patch(
      '/institutes/students/$studentUserId/remove',
      {},
    );
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listDiscountCodes() async {
    final data = await _client.get('/institutes/discount-codes');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> createDiscountCode(Map<String, dynamic> payload) async {
    await _client.post('/institutes/discount-codes', payload);
  }

  Future<List<CoachingAssignmentRequestSummary>> listAssignmentRequests({
    String? status,
  }) async {
    final path = status == null || status.isEmpty
        ? '/institutes/assignment-requests'
        : '/institutes/assignment-requests?status=$status';
    final data = await _client.get(path);
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CoachingAssignmentRequestSummary.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> acceptAssignmentRequest(
    String requestId, {
    String note = '',
  }) async {
    final data = await _client.patch(
      '/institutes/assignment-requests/$requestId/accept',
      <String, dynamic>{'note': note},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectAssignmentRequest(
    String requestId, {
    String note = '',
  }) async {
    final data = await _client.patch(
      '/institutes/assignment-requests/$requestId/reject',
      <String, dynamic>{'note': note},
    );
    return data as Map<String, dynamic>;
  }

  Future<List<CoachingTeacherSummary>> listTeachers() async {
    final data = await _client.get('/institutes/teachers');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(CoachingTeacherSummary.fromJson)
        .toList();
  }

  Future<List<AvailableTeacherSummary>> listAvailableTeachers() async {
    final data = await _client.get('/institutes/teachers/available');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AvailableTeacherSummary.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> assignTeacher(String teacherId) async {
    final data = await _client.patch(
      '/institutes/teachers/$teacherId/assign',
      {},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeTeacher(String teacherId) async {
    final data = await _client.patch(
      '/institutes/teachers/$teacherId/remove',
      {},
    );
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getExams() async {
    final data = await _client.get('/institutes/exams');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> payload) async {
    final data = await _client.post('/institutes/exams', payload);
    return data as Map<String, dynamic>;
  }

  Future<void> deleteExam(String id) async {
    await _client.delete('/institutes/exams/$id');
  }

  Future<List<Map<String, dynamic>>> getQuestions({String? section}) async {
    final path = section == null || section.isEmpty
        ? '/institutes/questions'
        : '/institutes/questions?section=$section';
    final data = await _client.get(path);
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> createQuestion(
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    if (listeningAudioFile == null) {
      final data = await _client.post('/institutes/questions', payload);
      return data as Map<String, dynamic>;
    }

    final form = await _buildQuestionFormData(
      payload: payload,
      listeningAudioFile: listeningAudioFile,
    );
    final data = await _client.postMultipart('/institutes/questions', form);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createQuestionForExam(
    String examId,
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    final nextPayload = <String, dynamic>{...payload, 'examId': examId};
    return createQuestion(nextPayload, listeningAudioFile: listeningAudioFile);
  }

  Future<Map<String, dynamic>> updateQuestion(
    String questionId,
    Map<String, dynamic> payload, {
    PlatformFile? listeningAudioFile,
  }) async {
    if (listeningAudioFile == null) {
      final data = await _client.put(
        '/institutes/questions/$questionId',
        payload,
      );
      return data as Map<String, dynamic>;
    }

    final form = await _buildQuestionFormData(
      payload: payload,
      listeningAudioFile: listeningAudioFile,
    );
    final data = await _client.putMultipart(
      '/institutes/questions/$questionId',
      form,
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteQuestion(String id) async {
    await _client.delete('/institutes/questions/$id');
  }

  Future<FormData> _buildQuestionFormData({
    required Map<String, dynamic> payload,
    required PlatformFile listeningAudioFile,
  }) async {
    final form = FormData();

    for (final entry in payload.entries) {
      if (entry.value == null) {
        continue;
      }
      if (entry.value is List || entry.value is Map) {
        continue;
      }
      form.fields.add(MapEntry(entry.key, entry.value.toString()));
    }

    form.files.add(
      MapEntry('listeningAudio', await _toMultipart(listeningAudioFile)),
    );
    return form;
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    final fileName = file.name.isNotEmpty ? file.name : 'listening-audio.bin';
    final mediaType = _guessMediaType(file.extension ?? fileName);

    if (file.bytes != null) {
      return MultipartFile.fromBytes(
        file.bytes!,
        filename: fileName,
        contentType: mediaType,
      );
    }

    if (file.path != null && file.path!.isNotEmpty) {
      return MultipartFile.fromFile(
        file.path!,
        filename: fileName,
        contentType: mediaType,
      );
    }

    throw Exception('Selected listening audio has no readable bytes/path');
  }

  MediaType _guessMediaType(String extensionOrName) {
    final ext = extensionOrName.toLowerCase();
    if (ext.endsWith('mp3')) return MediaType('audio', 'mpeg');
    if (ext.endsWith('wav')) return MediaType('audio', 'wav');
    if (ext.endsWith('m4a')) return MediaType('audio', 'mp4');
    if (ext.endsWith('aac')) return MediaType('audio', 'aac');
    if (ext.endsWith('ogg')) return MediaType('audio', 'ogg');
    if (ext.endsWith('webm')) return MediaType('audio', 'webm');
    return MediaType('application', 'octet-stream');
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    final data = await _client.get('/institutes/mock-templates');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> createTemplate(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.post('/institutes/mock-templates', payload);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTemplateForExam(
    String examId,
    Map<String, dynamic> payload,
  ) async {
    final nextPayload = <String, dynamic>{...payload, 'examId': examId};
    final data = await _client.post('/institutes/mock-templates', nextPayload);
    return data as Map<String, dynamic>;
  }

  Future<void> deleteTemplate(String id) async {
    await _client.delete('/institutes/mock-templates/$id');
  }

  Future<Map<String, dynamic>> getEvaluationActivity({String? status}) async {
    final path = status == null || status.isEmpty
        ? '/institutes/evaluation-requests'
        : '/institutes/evaluation-requests?status=$status';
    final data = await _client.get(path);
    return data as Map<String, dynamic>;
  }
}
