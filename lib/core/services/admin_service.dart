import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:cse470_app/models/admin_models.dart';
import 'package:cse470_app/core/services/api_client.dart';

class AdminService {
  AdminService(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> getExams() async {
    final data = await _client.get('/admin/exams');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> createExam(Map<String, dynamic> payload) async {
    await _client.post('/admin/exams', payload);
  }

  Future<void> deleteExam(String examId) async {
    await _client.delete('/admin/exams/$examId');
  }

  Future<List<Map<String, dynamic>>> getQuestions({
    String? section,
    String? examId,
  }) async {
    final queryParts = <String>[];
    if (section != null && section.isNotEmpty) {
      queryParts.add('section=$section');
    }
    if (examId != null && examId.isNotEmpty) {
      queryParts.add('examId=$examId');
    }
    final path = queryParts.isEmpty
        ? '/admin/questions'
        : '/admin/questions?${queryParts.join('&')}';
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
      final data = await _client.post('/admin/questions', payload);
      return data as Map<String, dynamic>;
    }

    final form = await _buildQuestionFormData(
      payload: payload,
      listeningAudioFile: listeningAudioFile,
    );
    final data = await _client.postMultipart('/admin/questions', form);
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
      final data = await _client.put('/admin/questions/$questionId', payload);
      return data as Map<String, dynamic>;
    }

    final form = await _buildQuestionFormData(
      payload: payload,
      listeningAudioFile: listeningAudioFile,
    );
    final data = await _client.putMultipart(
      '/admin/questions/$questionId',
      form,
    );
    return data as Map<String, dynamic>;
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.delete('/admin/questions/$questionId');
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
    final data = await _client.get('/admin/mock-templates');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> createTemplate(Map<String, dynamic> payload) async {
    await _client.post('/admin/mock-templates', payload);
  }

  Future<void> createTemplateForExam(
    String examId,
    Map<String, dynamic> payload,
  ) async {
    final nextPayload = <String, dynamic>{...payload, 'examId': examId};
    await _client.post('/admin/mock-templates', nextPayload);
  }

  Future<Map<String, dynamic>> updateTemplate(
    String templateId,
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.put(
      '/admin/mock-templates/$templateId',
      payload,
    );
    return data as Map<String, dynamic>;
  }

  Future<AdminOverviewData> getOverviewTyped() async {
    final data = await getOverview();
    return AdminOverviewData.fromJson(data);
  }

  Future<List<AdminTeacherSummary>> listTeachersTyped({String? state}) async {
    final response = await listTeachers(state: state);
    final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items.map(AdminTeacherSummary.fromJson).toList();
  }

  Future<List<AdminPayoutRequestSummary>> listPayoutRequestsTyped({
    String? status,
  }) async {
    final response = await listPayoutRequests(status: status);
    final items = (response['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
    return items.map(AdminPayoutRequestSummary.fromJson).toList();
  }

  Future<Map<String, dynamic>> getOverview() async {
    final data = await _client.get('/admin/overview');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listTeachers({String? state}) async {
    final path = state == null || state.isEmpty
        ? '/admin/teachers'
        : '/admin/teachers?state=$state';
    final data = await _client.get(path);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveTeacher(String teacherUserId) async {
    final data = await _client.patch(
      '/admin/teachers/$teacherUserId/approve',
      {},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectTeacher(
    String teacherUserId, {
    String reason = '',
  }) async {
    final data = await _client.patch(
      '/admin/teachers/$teacherUserId/lifecycle',
      {'action': 'reject', if (reason.isNotEmpty) 'reason': reason},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listStudents() async {
    final data = await _client.get('/admin/students');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createStudent({
    required String name,
    required String email,
    required String password,
    int testCredits = 20,
  }) async {
    final data = await _client.post('/admin/students', {
      'name': name,
      'email': email,
      'password': password,
      'testCredits': testCredits,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteStudent(String studentUserId) async {
    final data = await _client.delete('/admin/students/$studentUserId');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTeacher({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _client.post('/admin/teachers', {
      'name': name,
      'email': email,
      'password': password,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteTeacher(String teacherUserId) async {
    final data = await _client.delete('/admin/teachers/$teacherUserId');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listCoachings() async {
    final data = await _client.get('/admin/coachings');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCoaching({
    required String adminName,
    required String email,
    required String password,
    required String instituteName,
    String description = '',
    String address = '',
    String contactPhone = '',
  }) async {
    final data = await _client.post('/admin/coachings', {
      'name': adminName,
      'email': email,
      'password': password,
      'instituteName': instituteName,
      if (description.trim().isNotEmpty) 'description': description.trim(),
      if (address.trim().isNotEmpty) 'address': address.trim(),
      if (contactPhone.trim().isNotEmpty) 'contactPhone': contactPhone.trim(),
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteCoaching(String coachingId) async {
    final data = await _client.delete('/admin/coachings/$coachingId');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listPayoutRequests({String? status}) async {
    final path = status == null || status.isEmpty
        ? '/admin/payouts'
        : '/admin/payouts?status=$status';
    final data = await _client.get(path);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approvePayout(
    String payoutRequestId, {
    String note = '',
  }) async {
    final data = await _client.patch(
      '/admin/payouts/$payoutRequestId/approve',
      {'note': note},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectPayout(
    String payoutRequestId, {
    String reason = '',
  }) async {
    final data = await _client.patch('/admin/payouts/$payoutRequestId/reject', {
      'reason': reason,
    });
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listAppEvaluationRequests({
    String? status,
    String? section,
  }) async {
    final queryParts = <String>[];
    if (status != null && status.isNotEmpty) {
      queryParts.add('status=$status');
    }
    if (section != null && section.isNotEmpty) {
      queryParts.add('section=$section');
    }
    final query = queryParts.isEmpty ? '' : '?${queryParts.join('&')}';
    final data = await _client.get('/admin/evaluation-requests/app$query');
    return data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDatabaseCollectionsSummary() async {
    final data = await _client.get('/admin/db/collections');
    return (data as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<Map<String, dynamic>> listDatabaseDocuments(
    String collection, {
    int page = 1,
    int limit = 20,
    String search = '',
  }) async {
    final encodedSearch = Uri.encodeQueryComponent(search.trim());
    final path = search.trim().isEmpty
        ? '/admin/db/$collection/documents?page=$page&limit=$limit'
        : '/admin/db/$collection/documents?page=$page&limit=$limit&search=$encodedSearch';
    final data = await _client.get(path);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deleteDatabaseDocument(
    String collection,
    String documentId,
  ) async {
    final data = await _client.delete(
      '/admin/db/$collection/documents/$documentId',
    );
    return data as Map<String, dynamic>;
  }
}
