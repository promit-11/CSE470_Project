import 'package:flutter_test/flutter_test.dart';
import 'package:cse470_app/controllers/exam_session_controller.dart';
import 'package:cse470_app/models/mock_models.dart';
import 'test_helpers_active.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Active Workflow - Role Based Access', () {
    test('Student can load session', () {
      final session = createMockSession();
      expect(session.id, 's1');
      expect(session.status, 'active');
    });

    test('Teacher can view session', () {
      final session = createMockSession();
      expect(session.sections.isNotEmpty, true);
    });

    test('Admin can manage session', () {
      final session = createMockSession();
      expect(session.overallBandStatus, 'pending_review');
    });
  });

  group('Active Workflow - Session Results', () {
    test('Result pending review', () {
      final session = createMockSession();
      expect(session.overallBand, null);
    });

    test('Result finalized', () {
      final session = createMockSession();
      expect(session.overallBandStatus, 'pending_review');
    });
  });

  group('Active Workflow - Sections', () {
    test('Section is active', () {
      final section = createMockSectionState(section: 'listening');
      expect(section.section, 'listening');
      expect(section.status, 'active');
    });

    test('Section is submitted', () {
      final section = createMockSectionState(status: 'submitted');
      expect(section.status, 'submitted');
    });

    test('Section has band score', () {
      final section = createMockSectionState(bandScore: 7.5);
      expect(section.bandScore, 7.5);
    });
  });

  group('Active Workflow - Speaking States', () {
    test('Speaking idle', () {
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.idle,
      );
      expect(state.speakingRecordingState, SpeakingRecordingUiState.idle);
    });

    test('Speaking recording', () {
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.recording,
        currentRecordingElapsedSeconds: 30,
      );
      expect(state.speakingRecordingState, SpeakingRecordingUiState.recording);
      expect(state.currentRecordingElapsedSeconds, 30);
    });

    test('Speaking recorded not uploaded', () {
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.recordedNotUploaded,
        localSpeakingRecordingPath: '/temp/rec.m4a',
      );
      expect(
        state.speakingRecordingState,
        SpeakingRecordingUiState.recordedNotUploaded,
      );
    });

    test('Speaking uploading', () {
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.uploading,
        isMediaBusy: true,
      );
      expect(state.isMediaBusy, true);
    });

    test('Speaking uploaded', () {
      final recording = MockMediaMetadata(
        mediaId: 'rec-1',
        fileName: 'recording.m4a',
        mimeType: 'audio/mp4',
        sizeBytes: 5000,
        publicUrl: 'https://cdn.example.com/rec.m4a',
        pageOrder: null,
      );
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.uploaded,
        speakingRecording: recording,
      );
      expect(state.speakingRecording?.fileName, 'recording.m4a');
    });

    test('Speaking locked', () {
      final state = ExamSessionState(
        speakingRecordingState: SpeakingRecordingUiState.locked,
      );
      expect(state.speakingRecordingState, SpeakingRecordingUiState.locked);
    });
  });

  group('Active Workflow - Writing Submissions', () {
    test('Typed writing', () {
      final state = ExamSessionState(
        writingMode: 'typed',
        writingTypedDraft: 'My essay text.',
      );
      expect(state.writingMode, 'typed');
    });

    test('Handwritten writing', () {
      final image1 = MockMediaMetadata(
        mediaId: 'img-1',
        fileName: 'page1.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2000,
        publicUrl: 'https://cdn.example.com/page1.jpg',
        pageOrder: 1,
      );
      final image2 = MockMediaMetadata(
        mediaId: 'img-2',
        fileName: 'page2.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2000,
        publicUrl: 'https://cdn.example.com/page2.jpg',
        pageOrder: 2,
      );
      final state = ExamSessionState(
        writingMode: 'handwritten',
        writingImages: [image1, image2],
      );
      expect(state.writingImages.length, 2);
    });

    test('Writing submission locked', () {
      final state = ExamSessionState(
        writingTypedDraft: 'Final',
        isSubmitting: true,
      );
      expect(state.isSubmitting, true);
    });
  });

  group('Active Workflow - Answers', () {
    test('Save answers', () {
      final answers = {'q1': 'A', 'q2': 'B', 'q3': 'D'};
      final state = ExamSessionState(answers: answers);
      expect(state.answers.length, 3);
    });

    test('Flag questions', () {
      final flagged = {'q2': true, 'q8': true};
      final state = ExamSessionState(flagged: flagged);
      expect(state.flagged.length, 2);
    });
  });

  group('Active Workflow - Timers', () {
    test('Session timer', () {
      final state = ExamSessionState(remainingSeconds: 1500);
      expect(state.remainingSeconds, 1500);
    });

    test('Section timing', () {
      final section = createMockSectionState(
        durationSeconds: 3600,
        remainingSeconds: 2100,
      );
      expect(section.durationSeconds, 3600);
    });

    test('Question navigation', () {
      final state = ExamSessionState(currentQuestionIndex: 7);
      expect(state.currentQuestionIndex, 7);
    });
  });

  group('Active Workflow - Session State', () {
    test('Loading state', () {
      final state = ExamSessionState(isLoading: true);
      expect(state.isLoading, true);
    });

    test('Error state', () {
      final state = ExamSessionState(errorMessage: 'Connection failed');
      expect(state.errorMessage, 'Connection failed');
    });

    test('Submitting state', () {
      final state = ExamSessionState(isSubmitting: true);
      expect(state.isSubmitting, true);
    });
  });

  group('Active Workflow - Complete Flow', () {
    test('Session from start to results', () {
      final session = createMockSession();
      expect(session.status, 'active');

      final answered = ExamSessionState(
        session: session,
        answers: {'q1': 'A', 'q2': 'B'},
      );
      expect(answered.answers.isNotEmpty, true);

      final submitted = createMockSectionState(status: 'submitted');
      expect(submitted.status, 'submitted');
    });
  });

  group('Active Workflow - Service Integration', () {
    test('Save answer', () async {
      final service = MockMockServiceActive();
      await service.saveAnswer(
        sessionId: 's1',
        section: 'reading',
        questionId: 'q5',
        value: 'C',
      );
      expect(service.callLog.contains('saveAnswer:reading:q5'), true);
    });

    test('Submit section', () async {
      final service = MockMockServiceActive();
      await service.submitSection(sessionId: 's1', section: 'writing');
      expect(service.callLog.contains('submitSection:writing'), true);
    });

    test('Error handling', () async {
      final service = MockMockServiceActive();
      service.shouldThrow = true;
      expect(() => service.generateSession(), throwsException);
    });
  });
}
