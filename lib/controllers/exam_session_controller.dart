import 'dart:async';
import 'dart:io';

import 'package:cse470_app/models/mock_models.dart';
import 'package:cse470_app/core/services/mock_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

enum SpeakingRecordingUiState {
  idle,
  recording,
  recordedNotUploaded,
  uploading,
  uploaded,
  locked,
}

class ExamSessionState {
  const ExamSessionState({
    this.isLoading = false,
    this.errorMessage,
    this.session,
    this.remainingSeconds = 0,
    this.currentQuestionIndex = 0,
    this.answers = const <String, dynamic>{},
    this.flagged = const <String, bool>{},
    this.isSubmitting = false,
    this.writingMode = 'typed',
    this.writingTypedDraft = '',
    this.writingImages = const <MockMediaMetadata>[],
    this.speakingRecording,
    this.speakingRecordingState = SpeakingRecordingUiState.idle,
    this.localSpeakingRecordingPath,
    this.localSpeakingRecordingDurationSeconds,
    this.currentRecordingElapsedSeconds = 0,
    this.isMediaBusy = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final MockSession? session;
  final int remainingSeconds;
  final int currentQuestionIndex;
  final Map<String, dynamic> answers;
  final Map<String, bool> flagged;
  final bool isSubmitting;
  final String writingMode;
  final String writingTypedDraft;
  final List<MockMediaMetadata> writingImages;
  final MockMediaMetadata? speakingRecording;
  final SpeakingRecordingUiState speakingRecordingState;
  final String? localSpeakingRecordingPath;
  final int? localSpeakingRecordingDurationSeconds;
  final int currentRecordingElapsedSeconds;
  final bool isMediaBusy;

  String? get currentSection => session?.currentSection;

  MockSectionState? get currentSectionState {
    final s = session;
    if (s == null) {
      return null;
    }
    final section = s.currentSection;
    for (final item in s.sections) {
      if (item.section == section) {
        return item;
      }
    }
    return null;
  }

  List<MockQuestion> get currentQuestions =>
      currentSectionState?.questions ?? const [];

  bool get isSessionCompleted => session?.status == 'completed';

  bool get isCurrentSectionEditable {
    final section = currentSectionState;
    if (section == null) {
      return false;
    }
    if (isSessionCompleted) {
      return false;
    }
    return !section.isSubmitted;
  }

  bool get canEditWriting =>
      currentSection == 'writing' && isCurrentSectionEditable;

  bool get canEditSpeaking =>
      currentSection == 'speaking' && isCurrentSectionEditable;

  MockQuestion? get currentQuestion {
    if (currentQuestions.isEmpty ||
        currentQuestionIndex >= currentQuestions.length) {
      return null;
    }
    return currentQuestions[currentQuestionIndex];
  }

  ExamSessionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearErrorMessage = false,
    MockSession? session,
    int? remainingSeconds,
    int? currentQuestionIndex,
    Map<String, dynamic>? answers,
    Map<String, bool>? flagged,
    bool? isSubmitting,
    String? writingMode,
    String? writingTypedDraft,
    List<MockMediaMetadata>? writingImages,
    MockMediaMetadata? speakingRecording,
    bool setSpeakingRecordingNull = false,
    SpeakingRecordingUiState? speakingRecordingState,
    String? localSpeakingRecordingPath,
    bool clearLocalSpeakingRecordingPath = false,
    int? localSpeakingRecordingDurationSeconds,
    bool clearLocalSpeakingRecordingDuration = false,
    int? currentRecordingElapsedSeconds,
    bool? isMediaBusy,
  }) {
    return ExamSessionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      session: session ?? this.session,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      flagged: flagged ?? this.flagged,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      writingMode: writingMode ?? this.writingMode,
      writingTypedDraft: writingTypedDraft ?? this.writingTypedDraft,
      writingImages: writingImages ?? this.writingImages,
      speakingRecording: setSpeakingRecordingNull
          ? null
          : (speakingRecording ?? this.speakingRecording),
      speakingRecordingState:
          speakingRecordingState ?? this.speakingRecordingState,
      localSpeakingRecordingPath: clearLocalSpeakingRecordingPath
          ? null
          : (localSpeakingRecordingPath ?? this.localSpeakingRecordingPath),
      localSpeakingRecordingDurationSeconds: clearLocalSpeakingRecordingDuration
          ? null
          : (localSpeakingRecordingDurationSeconds ??
                this.localSpeakingRecordingDurationSeconds),
      currentRecordingElapsedSeconds:
          currentRecordingElapsedSeconds ?? this.currentRecordingElapsedSeconds,
      isMediaBusy: isMediaBusy ?? this.isMediaBusy,
    );
  }
}

class ExamSessionController extends StateNotifier<ExamSessionState> {
  ExamSessionController(this._mockService) : super(const ExamSessionState());

  final MockService _mockService;
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _timer;
  Timer? _writingSaveDebounce;
  Timer? _speakingRecordingTimer;
  DateTime? _speakingRecordingStartedAt;
  DateTime? _sectionDeadlineAt;

  Future<void> startSession({String? sourceType}) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final session = await _mockService.generateSession(
        sourceType: sourceType,
      );
      final section = session.sections
          .where((s) => s.section == session.currentSection)
          .first;
      state = state.copyWith(
        isLoading: false,
        session: session,
        remainingSeconds: section.remainingSeconds,
        currentQuestionIndex: 0,
        answers: _extractAnswers(section),
        flagged: _extractFlags(section),
      );
      _syncMediaState(session);
      _startTimer(section.remainingSeconds);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not create mock session.',
      );
    }
  }

  Future<void> loadSession(String sessionId) async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final session = await _mockService.getSession(sessionId);
      final section = session.sections
          .where((s) => s.section == session.currentSection)
          .first;
      state = state.copyWith(
        isLoading: false,
        session: session,
        remainingSeconds: section.remainingSeconds,
        currentQuestionIndex: 0,
        answers: _extractAnswers(section),
        flagged: _extractFlags(section),
      );
      _syncMediaState(session);
      _startTimer(section.remainingSeconds);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not restore mock session.',
      );
    }
  }

  void _startTimer(int initialRemainingSeconds) {
    _timer?.cancel();
    _sectionDeadlineAt = DateTime.now().add(
      Duration(seconds: initialRemainingSeconds),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final deadline = _sectionDeadlineAt;
      if (deadline == null) {
        timer.cancel();
        return;
      }

      final next = deadline.difference(DateTime.now()).inSeconds;
      if (next <= 0) {
        timer.cancel();
        state = state.copyWith(remainingSeconds: 0);
        await submitCurrentSection(autoSubmitted: true);
        return;
      }
      state = state.copyWith(remainingSeconds: next);
    });
  }

  Map<String, dynamic> _extractAnswers(MockSectionState sectionState) {
    final map = <String, dynamic>{};
    for (final answer in sectionState.answers) {
      map[(answer['questionId'] ?? '').toString()] = answer['value'];
    }
    return map;
  }

  Map<String, bool> _extractFlags(MockSectionState sectionState) {
    final map = <String, bool>{};
    for (final answer in sectionState.answers) {
      map[(answer['questionId'] ?? '').toString()] =
          (answer['flagged'] ?? false) as bool;
    }
    return map;
  }

  Future<void> saveAnswer(String questionId, dynamic value) async {
    final session = state.session;
    final section = state.currentSection;
    if (session == null || section == null || !state.isCurrentSectionEditable) {
      return;
    }
    final updated = <String, dynamic>{...state.answers, questionId: value};
    state = state.copyWith(answers: updated);
    try {
      await _mockService.saveAnswer(
        sessionId: session.id,
        section: section,
        questionId: questionId,
        value: value,
      );
    } catch (_) {
      try {
        final refreshed = await _mockService.getSession(session.id);
        state = state.copyWith(session: refreshed);
      } catch (_) {
        // Keep optimistic local answer when recovery fetch fails.
        // Surface a transient error so the UI can show feedback.
        state = state.copyWith(
          errorMessage: 'Could not save answer. Please check your connection.',
        );
      }
    }
  }

  Future<void> toggleFlag(String questionId) async {
    final session = state.session;
    final section = state.currentSection;
    if (session == null || section == null || !state.isCurrentSectionEditable) {
      return;
    }
    final next = !(state.flagged[questionId] ?? false);
    final updated = <String, bool>{...state.flagged, questionId: next};
    state = state.copyWith(flagged: updated);
    try {
      await _mockService.markQuestion(
        sessionId: session.id,
        section: section,
        questionId: questionId,
        flagged: next,
      );
    } catch (_) {
      try {
        final refreshed = await _mockService.getSession(session.id);
        state = state.copyWith(session: refreshed);
      } catch (_) {
        // Keep optimistic local flag when recovery fetch fails.
      }
    }
  }

  void gotoQuestion(int index) {
    if (index < 0 || index >= state.currentQuestions.length) {
      return;
    }
    state = state.copyWith(currentQuestionIndex: index);
  }

  Future<void> submitCurrentSection({bool autoSubmitted = false}) async {
    final session = state.session;
    final section = state.currentSection;
    if (session == null || section == null || state.isSubmitting) {
      return;
    }
    state = state.copyWith(isSubmitting: true);
    try {
      if (section == 'writing' && state.isCurrentSectionEditable) {
        _writingSaveDebounce?.cancel();
        final writingSynced = await _mockService.saveWritingTypedResponse(
          sessionId: session.id,
          typedAnswer: state.writingTypedDraft,
        );
        state = state.copyWith(session: writingSynced);
        _syncMediaState(writingSynced);
      }

      if (section == 'speaking' && state.isCurrentSectionEditable) {
        final localPath = state.localSpeakingRecordingPath;
        if (localPath != null && localPath.isNotEmpty) {
          final uploaded = await _mockService.uploadSpeakingRecording(
            sessionId: session.id,
            filePath: localPath,
            fileName: _fileNameFromPath(localPath),
            mimeType: 'audio/mp4',
          );
          await _deleteTempFile(localPath);
          state = state.copyWith(
            session: uploaded,
            clearLocalSpeakingRecordingPath: true,
            clearLocalSpeakingRecordingDuration: true,
            currentRecordingElapsedSeconds: 0,
            speakingRecordingState: SpeakingRecordingUiState.uploaded,
          );
          _syncMediaState(uploaded);
        }
      }

      final updated = await _mockService.submitSection(
        sessionId: session.id,
        section: section,
        autoSubmitted: autoSubmitted,
      );
      MockSectionState? current;
      for (final item in updated.sections) {
        if (item.section == updated.currentSection) {
          current = item;
          break;
        }
      }
      state = state.copyWith(
        session: updated,
        isSubmitting: false,
        currentQuestionIndex: 0,
        remainingSeconds: current?.remainingSeconds ?? 0,
        answers: current == null
            ? <String, dynamic>{}
            : _extractAnswers(current),
        flagged: current == null ? <String, bool>{} : _extractFlags(current),
      );
      _syncMediaState(updated);
      if (updated.status == 'active') {
        _startTimer(current?.remainingSeconds ?? 0);
      } else {
        _timer?.cancel();
        _sectionDeadlineAt = null;
      }
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Section submit failed.',
      );
    }
  }

  Future<void> finalSubmit() async {
    final session = state.session;
    if (session == null || state.isSubmitting) {
      return;
    }
    state = state.copyWith(isSubmitting: true);
    try {
      _writingSaveDebounce?.cancel();

      if (state.canEditWriting) {
        final writingSynced = await _mockService.saveWritingTypedResponse(
          sessionId: session.id,
          typedAnswer: state.writingTypedDraft,
        );
        state = state.copyWith(session: writingSynced);
        _syncMediaState(writingSynced);
      }

      if (state.canEditSpeaking) {
        final localPath = state.localSpeakingRecordingPath;
        if (localPath != null && localPath.isNotEmpty) {
          final uploaded = await _mockService.uploadSpeakingRecording(
            sessionId: session.id,
            filePath: localPath,
            fileName: _fileNameFromPath(localPath),
            mimeType: 'audio/mp4',
          );
          await _deleteTempFile(localPath);
          state = state.copyWith(
            session: uploaded,
            clearLocalSpeakingRecordingPath: true,
            clearLocalSpeakingRecordingDuration: true,
            currentRecordingElapsedSeconds: 0,
            speakingRecordingState: SpeakingRecordingUiState.uploaded,
          );
          _syncMediaState(uploaded);
        }
      }

      final updated = await _mockService.finalSubmit(session.id);
      _timer?.cancel();
      _sectionDeadlineAt = null;
      state = state.copyWith(session: updated, isSubmitting: false);
      _syncMediaState(updated);
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Final submit failed.',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _writingSaveDebounce?.cancel();
    _speakingRecordingTimer?.cancel();
    _sectionDeadlineAt = null;
    _audioRecorder.dispose();
    super.dispose();
  }

  void setWritingMode(String mode) {
    if (mode != 'typed' && mode != 'images') {
      return;
    }
    state = state.copyWith(writingMode: mode);
  }

  /// Clear any transient error message shown in the UI.
  /// The view can call this after displaying a SnackBar.
  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<void> setWritingTypedDraft(String value) async {
    state = state.copyWith(writingTypedDraft: value);
    if (!state.canEditWriting || state.session == null) {
      return;
    }

    _writingSaveDebounce?.cancel();
    _writingSaveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final session = state.session;
      if (session == null || !state.canEditWriting) {
        return;
      }
      try {
        final updated = await _mockService.saveWritingTypedResponse(
          sessionId: session.id,
          typedAnswer: state.writingTypedDraft,
        );
        state = state.copyWith(session: updated);
        _syncMediaState(updated);
      } catch (_) {
        state = state.copyWith(
          errorMessage: 'Could not save writing text draft.',
        );
      }
    });
  }

  Future<void> pickWritingImages() async {
    if (!state.canEditWriting || state.session == null || state.isMediaBusy) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) {
      return;
    }

    state = state.copyWith(isMediaBusy: true, clearErrorMessage: true);
    try {
      final updated = await _mockService.uploadWritingImages(
        sessionId: state.session!.id,
        files: picked.files,
      );
      state = state.copyWith(session: updated, isMediaBusy: false);
      _syncMediaState(updated);
    } catch (_) {
      state = state.copyWith(
        isMediaBusy: false,
        errorMessage: 'Could not upload writing images.',
      );
    }
  }

  Future<void> deleteWritingImage(String mediaId) async {
    if (!state.canEditWriting || state.session == null || state.isMediaBusy) {
      return;
    }

    state = state.copyWith(isMediaBusy: true, clearErrorMessage: true);
    try {
      final updated = await _mockService.deleteWritingImage(
        sessionId: state.session!.id,
        mediaId: mediaId,
      );
      state = state.copyWith(session: updated, isMediaBusy: false);
      _syncMediaState(updated);
    } catch (_) {
      state = state.copyWith(
        isMediaBusy: false,
        errorMessage: 'Could not delete writing image.',
      );
    }
  }

  Future<void> reorderWritingImages(int oldIndex, int newIndex) async {
    if (!state.canEditWriting || state.session == null || state.isMediaBusy) {
      return;
    }

    final current = <MockMediaMetadata>[...state.writingImages];
    if (oldIndex < 0 || oldIndex >= current.length) {
      return;
    }

    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex < 0 || adjustedNewIndex > current.length) {
      return;
    }

    final moved = current.removeAt(oldIndex);
    current.insert(adjustedNewIndex, moved);
    state = state.copyWith(writingImages: current);

    final orderedIds = current
        .map((item) => item.mediaId)
        .where((id) => id.isNotEmpty)
        .toList();
    if (orderedIds.isEmpty) {
      return;
    }

    state = state.copyWith(isMediaBusy: true, clearErrorMessage: true);
    try {
      final updated = await _mockService.reorderWritingImages(
        sessionId: state.session!.id,
        orderedMediaIds: orderedIds,
      );
      state = state.copyWith(session: updated, isMediaBusy: false);
      _syncMediaState(updated);
    } catch (_) {
      state = state.copyWith(
        isMediaBusy: false,
        errorMessage: 'Could not reorder writing images.',
      );
      try {
        final refreshed = await _mockService.getSession(state.session!.id);
        state = state.copyWith(session: refreshed);
        _syncMediaState(refreshed);
      } catch (_) {
        // Keep local order if recovery fetch fails.
      }
    }
  }

  Future<void> startSpeakingRecording() async {
    if (!state.canEditSpeaking || state.session == null || state.isMediaBusy) {
      return;
    }

    if (state.speakingRecordingState == SpeakingRecordingUiState.recording) {
      return;
    }

    try {
      final allowed = await _audioRecorder.hasPermission();
      if (!allowed) {
        state = state.copyWith(
          errorMessage:
              'Microphone permission is required to record speaking audio.',
        );
        return;
      }

      final outputPath = _buildTempRecordingPath();
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );

      _speakingRecordingStartedAt = DateTime.now();
      _startSpeakingRecordingTimer();
      state = state.copyWith(
        clearErrorMessage: true,
        speakingRecordingState: SpeakingRecordingUiState.recording,
        clearLocalSpeakingRecordingPath: true,
        clearLocalSpeakingRecordingDuration: true,
        currentRecordingElapsedSeconds: 0,
      );
    } catch (_) {
      _stopSpeakingRecordingTimer();
      state = state.copyWith(
        speakingRecordingState: state.speakingRecording != null
            ? SpeakingRecordingUiState.uploaded
            : SpeakingRecordingUiState.idle,
        errorMessage: 'Could not start speaking recording.',
      );
    }
  }

  Future<void> stopSpeakingRecording() async {
    if (state.speakingRecordingState != SpeakingRecordingUiState.recording) {
      return;
    }

    try {
      final path = await _audioRecorder.stop();
      _stopSpeakingRecordingTimer();

      if (path == null || path.isEmpty) {
        state = state.copyWith(
          speakingRecordingState: state.speakingRecording != null
              ? SpeakingRecordingUiState.uploaded
              : SpeakingRecordingUiState.idle,
          errorMessage: 'Recording was not saved. Please try again.',
        );
        return;
      }

      state = state.copyWith(
        speakingRecordingState: SpeakingRecordingUiState.recordedNotUploaded,
        localSpeakingRecordingPath: path,
        localSpeakingRecordingDurationSeconds:
            state.currentRecordingElapsedSeconds,
      );
    } catch (_) {
      _stopSpeakingRecordingTimer();
      state = state.copyWith(
        speakingRecordingState: state.speakingRecording != null
            ? SpeakingRecordingUiState.uploaded
            : SpeakingRecordingUiState.idle,
        errorMessage: 'Could not stop speaking recording.',
      );
    }
  }

  Future<void> discardSpeakingRecording() async {
    if (state.speakingRecordingState == SpeakingRecordingUiState.recording) {
      await stopSpeakingRecording();
    }

    final path = state.localSpeakingRecordingPath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup failures for temp files.
      }
    }

    state = state.copyWith(
      clearLocalSpeakingRecordingPath: true,
      clearLocalSpeakingRecordingDuration: true,
      currentRecordingElapsedSeconds: 0,
      speakingRecordingState: state.speakingRecording != null
          ? SpeakingRecordingUiState.uploaded
          : SpeakingRecordingUiState.idle,
    );
  }

  Future<void> uploadSpeakingRecording() async {
    if (!state.canEditSpeaking || state.session == null || state.isMediaBusy) {
      return;
    }

    final localPath = state.localSpeakingRecordingPath;
    if (localPath == null || localPath.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Record and stop audio before uploading.',
      );
      return;
    }

    state = state.copyWith(
      speakingRecordingState: SpeakingRecordingUiState.uploading,
      isMediaBusy: true,
      clearErrorMessage: true,
    );
    try {
      final updated = await _mockService.uploadSpeakingRecording(
        sessionId: state.session!.id,
        filePath: localPath,
        fileName: _fileNameFromPath(localPath),
        mimeType: 'audio/mp4',
      );

      await _deleteTempFile(localPath);

      state = state.copyWith(
        session: updated,
        isMediaBusy: false,
        clearLocalSpeakingRecordingPath: true,
        clearLocalSpeakingRecordingDuration: true,
        currentRecordingElapsedSeconds: 0,
        speakingRecordingState: SpeakingRecordingUiState.uploaded,
      );
      _syncMediaState(updated);
    } catch (_) {
      state = state.copyWith(
        isMediaBusy: false,
        speakingRecordingState: SpeakingRecordingUiState.recordedNotUploaded,
        errorMessage: 'Could not upload speaking recording.',
      );
    }
  }

  void _syncMediaState(MockSession session) {
    MockSectionState? writingSection;
    MockSectionState? speakingSection;

    for (final section in session.sections) {
      if (section.section == 'writing') {
        writingSection = section;
      }
      if (section.section == 'speaking') {
        speakingSection = section;
      }
    }

    final writing = writingSection?.writingSubmission;
    final speaking = speakingSection?.speakingSubmission;

    final backendMode = writing?.mode ?? 'none';
    final uiMode = backendMode == 'images' ? 'images' : 'typed';

    final speakingLocked =
        session.currentSection == 'speaking' && !state.isCurrentSectionEditable;

    SpeakingRecordingUiState speakingState;
    if (speakingLocked) {
      speakingState = SpeakingRecordingUiState.locked;
    } else if (state.speakingRecordingState ==
        SpeakingRecordingUiState.recording) {
      speakingState = SpeakingRecordingUiState.recording;
    } else if (state.localSpeakingRecordingPath != null &&
        state.localSpeakingRecordingPath!.isNotEmpty) {
      speakingState = SpeakingRecordingUiState.recordedNotUploaded;
    } else if (speaking?.recording != null) {
      speakingState = SpeakingRecordingUiState.uploaded;
    } else {
      speakingState = SpeakingRecordingUiState.idle;
    }

    state = state.copyWith(
      writingMode: uiMode,
      writingTypedDraft: writing?.typedAnswer ?? '',
      writingImages: writing?.images ?? const <MockMediaMetadata>[],
      speakingRecording: speaking?.recording,
      setSpeakingRecordingNull: speaking?.recording == null,
      speakingRecordingState: speakingState,
    );
  }

  String _buildTempRecordingPath() {
    final fileName = 'speaking_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName';
  }

  void _startSpeakingRecordingTimer() {
    _speakingRecordingTimer?.cancel();
    _speakingRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _speakingRecordingStartedAt;
      if (startedAt == null) {
        return;
      }
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      state = state.copyWith(currentRecordingElapsedSeconds: elapsed);
    });
  }

  void _stopSpeakingRecordingTimer() {
    _speakingRecordingTimer?.cancel();
    _speakingRecordingTimer = null;
    _speakingRecordingStartedAt = null;
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore temp cleanup failures.
    }
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    if (parts.isEmpty) {
      return 'speaking.m4a';
    }
    return parts.last.isEmpty ? 'speaking.m4a' : parts.last;
  }
}
