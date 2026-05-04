import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';

import 'package:cse470_app/models/mock_models.dart';
import 'package:cse470_app/core/services/api_client.dart';

class MockService {
  MockService(this._client);

  final ApiClient _client;

  Future<MockSession> generateSession({String? sourceType}) async {
    final payload = <String, dynamic>{};
    if (sourceType != null && sourceType.isNotEmpty) {
      payload['sourceType'] = sourceType;
    }
    final data = await _client.post('/mock-sessions/generate', payload);
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> getSession(String sessionId) async {
    final data = await _client.get('/mock-sessions/$sessionId');
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<void> saveAnswer({
    required String sessionId,
    required String section,
    required String questionId,
    required dynamic value,
  }) async {
    await _client.post('/mock-sessions/$sessionId/answer', {
      'section': section,
      'questionId': questionId,
      'value': value,
    });
  }

  Future<void> markQuestion({
    required String sessionId,
    required String section,
    required String questionId,
    required bool flagged,
  }) async {
    await _client.post('/mock-sessions/$sessionId/mark', {
      'section': section,
      'questionId': questionId,
      'flagged': flagged,
    });
  }

  Future<MockSession> submitSection({
    required String sessionId,
    required String section,
    bool autoSubmitted = false,
  }) async {
    final data = await _client.post(
      '/mock-sessions/$sessionId/submit-section',
      {'section': section, 'autoSubmitted': autoSubmitted},
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> finalSubmit(String sessionId) async {
    final data = await _client.post(
      '/mock-sessions/$sessionId/final-submit',
      {},
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> saveWritingTypedResponse({
    required String sessionId,
    required String typedAnswer,
  }) async {
    final data = await _client.patch(
      '/mock-sessions/$sessionId/writing/typed-response',
      {'typedAnswer': typedAnswer},
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> uploadWritingImages({
    required String sessionId,
    required List<PlatformFile> files,
  }) async {
    final form = FormData();
    for (final file in files) {
      final multipart = await _toMultipart(file);
      form.files.add(MapEntry('writingImages', multipart));
    }
    final data = await _client.postMultipart(
      '/mock-sessions/$sessionId/writing/images',
      form,
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> deleteWritingImage({
    required String sessionId,
    required String mediaId,
  }) async {
    final data = await _client.delete(
      '/mock-sessions/$sessionId/writing/images/$mediaId',
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> reorderWritingImages({
    required String sessionId,
    required List<String> orderedMediaIds,
  }) async {
    final data = await _client.patch(
      '/mock-sessions/$sessionId/writing/images/reorder',
      {'orderedMediaIds': orderedMediaIds},
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MockSession> uploadSpeakingRecording({
    required String sessionId,
    required String filePath,
    String fileName = 'speaking.m4a',
    String mimeType = 'audio/mp4',
  }) async {
    final form = FormData();
    form.files.add(
      MapEntry(
        'speakingRecording',
        await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      ),
    );
    final data = await _client.postMultipart(
      '/mock-sessions/$sessionId/speaking/recording',
      form,
    );
    return MockSession.fromJson(data as Map<String, dynamic>);
  }

  Future<MultipartFile> _toMultipart(PlatformFile file) async {
    final fileName = file.name.isNotEmpty ? file.name : 'upload.bin';

    if (file.bytes != null) {
      return MultipartFile.fromBytes(file.bytes!, filename: fileName);
    }

    if (file.path != null && file.path!.isNotEmpty) {
      return MultipartFile.fromFile(file.path!, filename: fileName);
    }

    throw Exception('Selected file has no readable bytes/path');
  }
}
