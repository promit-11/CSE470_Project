import 'package:cse470_app/controllers/exam_session_controller.dart';
import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cse470_app/core/utils/api_config.dart';

class ExamSessionView extends ConsumerStatefulWidget {
  const ExamSessionView({super.key});

  @override
  ConsumerState<ExamSessionView> createState() => _ExamSessionViewState();
}

class _ExamSessionViewState extends ConsumerState<ExamSessionView> {
  bool _initialized = false;
  String? _resumableSessionId;
  final TextEditingController _writingController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioPlayer _speakingPlayer = AudioPlayer();
  String? _playingAudioUrl;
  bool _isPlayingAudio = false;
  String? _playingSpeakingSource;
  bool _isPlayingSpeaking = false;
  final Map<String, Timer?> _perQuestionDebounce = {};
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    // Capture ScaffoldMessengerState once while the element tree is stable.
    _scaffoldMessenger = ScaffoldMessenger.of(context);

    // Read route arguments synchronously while the element tree is stable
    // (safe to call inherited widgets here). Store the resumable session id
    // for use later so we avoid calling ModalRoute.of(context) from async
    // callbacks where the element may be deactivated.
    final _routeArgs = ModalRoute.of(context)?.settings.arguments;
    _resumableSessionId = _routeArgs is String && _routeArgs.trim().isNotEmpty
        ? _routeArgs.trim()
        : null;

    // Read provider state synchronously while the element tree is stable
    // so we don't call `ref.read` from inside a callback that might run
    // after the widget is unmounted.
    final _initialController = ref.read(examSessionControllerProvider.notifier);
    final _initialDashboardState = ref.read(studentDashboardControllerProvider);
    final _initialHasActiveCoaching =
        _initialDashboardState.coachingFormData?.assignment.activeCoachingId !=
            null ||
        _initialDashboardState.profile?['coachingId'] != null;
    final _initialSourceType = _initialHasActiveCoaching ? 'coaching' : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_resumableSessionId != null) {
        _initialController.loadSession(_resumableSessionId!);
      } else {
        _initialController.startSession(sourceType: _initialSourceType);
      }
    });

    // NOTE: Move any provider listeners into `build()` as `ref.listen`
    // must be called during the build phase for Consumer widgets.
  }

  @override
  void dispose() {
    for (final t in _perQuestionDebounce.values) {
      t?.cancel();
    }
    _audioPlayer.dispose();
    _speakingPlayer.dispose();
    _writingController.dispose();
    super.dispose();
  }

  int _wordCount(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final cleaned = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.split(' ').length;
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _getTimeColor(int seconds) {
    if (seconds > 300) return Colors.green;
    if (seconds > 60) return Colors.orange;
    return Colors.red;
  }

  String _formatOptionalDuration(int? seconds) {
    if (seconds == null || seconds <= 0) {
      return '--:--';
    }
    return _formatTime(seconds);
  }

  String _speakingStateLabel(SpeakingRecordingUiState state) {
    switch (state) {
      case SpeakingRecordingUiState.idle:
        return 'No recording yet';
      case SpeakingRecordingUiState.recording:
        return 'Recording in progress';
      case SpeakingRecordingUiState.recordedNotUploaded:
        return 'Recorded locally, not uploaded';
      case SpeakingRecordingUiState.uploading:
        return 'Uploading recording';
      case SpeakingRecordingUiState.uploaded:
        return 'Uploaded to backend';
      case SpeakingRecordingUiState.locked:
        return 'Locked after submission';
    }
    throw StateError('Unknown SpeakingRecordingUiState: $state');
  }

  String _resolveMediaUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return raw;
    }
    var base = ApiConfig.baseUrl;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examSessionControllerProvider);
    final controller = ref.read(examSessionControllerProvider.notifier);

    // Listen for transient errors from the controller and show a SnackBar.
    ref.listen<ExamSessionState>(examSessionControllerProvider, (
      previous,
      next,
    ) {
      final prevMsg = previous?.errorMessage;
      final nextMsg = next.errorMessage;
      if (nextMsg != null && nextMsg != prevMsg) {
        if (!mounted) return;
        _scaffoldMessenger?.showSnackBar(SnackBar(content: Text(nextMsg)));
        // Clear the transient error in the controller so the UI does not
        // repeatedly show the same message.
        Future.microtask(() {
          if (!mounted) return;
          ref.read(examSessionControllerProvider.notifier).clearError();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Icon(
              Icons.assessment,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.currentSection?.toUpperCase() ?? 'Exam Session',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 2,
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getTimeColor(
                state.remainingSeconds,
              ).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.timer,
                  size: 18,
                  color: _getTimeColor(state.remainingSeconds),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatTime(state.remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getTimeColor(state.remainingSeconds),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AsyncView(
        isLoading: state.isLoading,
        // Only show the AsyncView error overlay for initial load (no session).
        errorMessage: state.session == null ? state.errorMessage : null,
        onRetry: () {
          if (_resumableSessionId != null) {
            controller.loadSession(_resumableSessionId!);
          } else {
            final dashboardState = ref.read(studentDashboardControllerProvider);
            final hasActiveCoaching =
                dashboardState.coachingFormData?.assignment.activeCoachingId !=
                    null ||
                dashboardState.profile?['coachingId'] != null;
            controller.startSession(
              sourceType: hasActiveCoaching ? 'coaching' : null,
            );
          }
        },
        child: state.session == null
            ? const Center(child: Text('Session not available'))
            : _buildContent(context, state, controller),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ExamSessionState state,
    ExamSessionController controller,
  ) {
    if (state.session!.status == 'completed') {
      final session = state.session!;
      final resultSummary = session.resultSummary;
      final sections =
          (resultSummary['sections'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final writingStatus =
          ((sections['writing'] as Map<String, dynamic>?)?['status'] ?? '')
              .toString();
      final speakingStatus =
          ((sections['speaking'] as Map<String, dynamic>?)?['status'] ?? '')
              .toString();
      final pendingSubjective =
          writingStatus != 'reviewed' || speakingStatus != 'reviewed';
      final listeningBand = session.sectionBands['listening'];
      final readingBand = session.sectionBands['reading'];

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 72,
                  color: Colors.green[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Test Completed!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (pendingSubjective)
                Text(
                  'Listening/Reading scored. Writing/Speaking pending teacher review.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                )
              else
                Text(
                  'Overall Band: ${session.overallBand?.toStringAsFixed(1) ?? '-'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              const SizedBox(height: 8),
              Text(
                'Listening: ${listeningBand?.toStringAsFixed(1) ?? '-'} â€¢ Reading: ${readingBand?.toStringAsFixed(1) ?? '-'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                session.feedbackSummary['notes']?.toString() ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                icon: Icons.arrow_forward,
                label: 'View Results',
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.studentResult,
                  (_) => false,
                ),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                icon: Icons.home,
                label: 'Return to Dashboard',
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.studentDashboard,
                  (_) => false,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_writingController.text != state.writingTypedDraft) {
      _writingController.text = state.writingTypedDraft;
      _writingController.selection = TextSelection.collapsed(
        offset: _writingController.text.length,
      );
    }

    final question = state.currentQuestion;
    final questions = state.currentQuestions;
    if (question == null) {
      return const Center(child: Text('No question available'));
    }

    final isNarrowLayout = MediaQuery.of(context).size.width < 780;

    final mainPane = ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionProgress(
          sections:
              state.session?.sectionOrder ??
              ['listening', 'reading', 'writing', 'speaking'],
          currentIndex:
              state.session?.sectionOrder.indexOf(state.currentSection ?? '') ??
              0,
        ),
        const SizedBox(height: 20),
        Card(
          elevation: 0,
          color: Colors.grey[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Question ${state.currentQuestionIndex + 1} of ${questions.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (state.flagged[question.id] ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.flag,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Marked for review',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  question.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (question.listeningAudioUrl.isNotEmpty &&
                    (state.currentSection == 'listening'))
                  Builder(
                    builder: (context) {
                      final resolvedUrl = _resolveMediaUrl(
                        question.listeningAudioUrl,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildListeningAudioControl(resolvedUrl),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (state.currentSection == 'writing')
          _buildWritingSectionCard(context, state, controller)
        else if (state.currentSection == 'speaking')
          _buildSpeakingSectionCard(context, state, controller)
        else if (question.options.isNotEmpty)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: RadioGroup<String>(
                groupValue: (state.answers[question.id] ?? '').toString(),
                onChanged: (value) {
                  if (value != null) {
                    controller.saveAnswer(question.id, value);
                  }
                },
                child: Column(
                  children: question.options
                      .map(
                        (option) => RadioListTile<String>(
                          value: option.key,
                          title: Text('${option.key}. ${option.text}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                minLines: 6,
                maxLines: 10,
                readOnly: !state.isCurrentSectionEditable,
                onChanged: (value) => controller.saveAnswer(question.id, value),
                decoration: InputDecoration(
                  hintText: 'Write your response here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Actions',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: () => controller.toggleFlag(question.id),
              icon: Icon(
                (state.flagged[question.id] ?? false)
                    ? Icons.flag
                    : Icons.flag_outlined,
              ),
              label: Text(
                (state.flagged[question.id] ?? false)
                    ? 'Unmark for Review'
                    : 'Mark for Review',
              ),
            ),
            OutlinedButton(
              onPressed: state.currentQuestionIndex > 0
                  ? () =>
                        controller.gotoQuestion(state.currentQuestionIndex - 1)
                  : null,
              child: const Text('â† Previous'),
            ),
            OutlinedButton(
              onPressed: state.currentQuestionIndex < questions.length - 1
                  ? () =>
                        controller.gotoQuestion(state.currentQuestionIndex + 1)
                  : null,
              child: const Text('Next â†’'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (state.currentSection != 'speaking') ...<Widget>[
          PrimaryButton(
            label: state.isSubmitting ? 'Submitting...' : 'Submit This Section',
            isLoading: state.isSubmitting,
            isEnabled: !state.isSubmitting && state.isCurrentSectionEditable,
            onPressed: () async {
              final navigator = Navigator.of(context);
              await controller.submitCurrentSection();
              final updated = ref.read(examSessionControllerProvider);
              if (updated.session?.status == 'completed') {
                if (!mounted) return;
                navigator.pushReplacementNamed(AppRoutes.studentResult);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
        SecondaryButton(
          label: 'Final Submit Mock',
          isEnabled:
              !state.isSubmitting && state.session?.status != 'completed',
          onPressed: () async {
            final navigator = Navigator.of(context);
            await controller.finalSubmit();
            final updated = ref.read(examSessionControllerProvider);
            if (!mounted || updated.errorMessage != null) return;
            navigator.pushReplacementNamed(AppRoutes.studentResult);
          },
        ),
      ],
    );

    final questionNavigatorPane = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(left: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Questions',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Answered',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Not attempted',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, gridConstraints) {
                final tentative = (gridConstraints.maxWidth / 30).floor();
                final crossAxisCount = tentative.clamp(2, 5);
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    final q = questions[index];
                    final answered =
                        state.answers[q.id] != null &&
                        state.answers[q.id].toString().trim().isNotEmpty;
                    final flagged = state.flagged[q.id] ?? false;
                    final selected = index == state.currentQuestionIndex;
                    return InkWell(
                      onTap:
                          state.currentSection == 'writing' ||
                              state.currentSection == 'speaking'
                          ? null
                          : () => controller.gotoQuestion(index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : answered
                              ? Colors.green[200]
                              : Colors.grey[400],
                          boxShadow: <BoxShadow>[
                            if (flagged)
                              BoxShadow(
                                color: Colors.orange.withValues(alpha: 0.5),
                                spreadRadius: 2,
                                blurRadius: 4,
                              ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (flagged)
                              Icon(
                                Icons.flag,
                                size: 10,
                                color: selected
                                    ? Colors.white
                                    : Colors.orange[700],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

    if (isNarrowLayout) {
      return Column(
        children: <Widget>[
          Expanded(child: mainPane),
          SizedBox(height: 220, child: questionNavigatorPane),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(flex: 3, child: mainPane),
        SizedBox(width: 240, child: questionNavigatorPane),
      ],
    );
  }

  Widget _buildListeningAudioControl(String audioUrl) {
    final isCurrentTrack = _playingAudioUrl == audioUrl;
    final isPlaying = isCurrentTrack && _isPlayingAudio;

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => _toggleListeningAudio(audioUrl),
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
            ),
          ),
          Expanded(
            child: Text(
              'Listening audio ready',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListeningAudio(String audioUrl) async {
    try {
      if (_playingAudioUrl == audioUrl && _isPlayingAudio) {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
      setState(() {
        _playingAudioUrl = audioUrl;
        _isPlayingAudio = true;
      });

      _audioPlayer.onPlayerComplete.first.then((event) {
        if (!mounted) return;
        setState(() {
          _isPlayingAudio = false;
        });
      });
    } catch (_) {
      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(content: Text('Could not play listening audio.')),
      );
    }
  }

  Future<void> _toggleSpeakingAudio({
    String? localPath,
    String? remoteUrl,
  }) async {
    final sourceKey = localPath != null
        ? 'local:$localPath'
        : 'remote:${remoteUrl ?? ''}';

    try {
      if (_playingSpeakingSource == sourceKey && _isPlayingSpeaking) {
        await _speakingPlayer.pause();
        if (!mounted) return;
        setState(() {
          _isPlayingSpeaking = false;
        });
        return;
      }

      await _speakingPlayer.stop();
      if (localPath != null) {
        await _speakingPlayer.play(DeviceFileSource(localPath));
      } else if (remoteUrl != null && remoteUrl.isNotEmpty) {
        await _speakingPlayer.play(UrlSource(remoteUrl));
      } else {
        return;
      }

      if (!mounted) return;
      setState(() {
        _playingSpeakingSource = sourceKey;
        _isPlayingSpeaking = true;
      });

      _speakingPlayer.onPlayerComplete.first.then((event) {
        if (!mounted) return;
        setState(() {
          _isPlayingSpeaking = false;
        });
      });
    } catch (_) {
      if (!mounted) return;
      _scaffoldMessenger?.showSnackBar(
        const SnackBar(content: Text('Could not play speaking audio.')),
      );
    }
  }

  Widget _buildWritingSectionCard(
    BuildContext context,
    ExamSessionState state,
    ExamSessionController controller,
  ) {
    final editable = state.canEditWriting;
    final writingMeta = state.currentSectionState?.writingSubmission;
    final writingQuestions = state.currentQuestions;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Writing Submission',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              editable
                  ? 'Choose typed response or image upload. You can switch modes before section submit.'
                  : 'Writing is locked after submission/final submit.',
            ),
            const SizedBox(height: 12),
            // Show prompts/tasks for writing. If backend provides a single
            // `writingSubmission` then we render the prompts but keep the
            // single typed input (existing behavior). If no `writingSubmission`
            // is present we fall back to per-question inputs and save
            // answers per-question.
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'typed',
                  label: Text('Typed'),
                  icon: Icon(Icons.keyboard_alt_outlined),
                ),
                ButtonSegment<String>(
                  value: 'images',
                  label: Text('Images'),
                  icon: Icon(Icons.photo_library_outlined),
                ),
              ],
              selected: <String>{state.writingMode},
              onSelectionChanged: editable
                  ? (next) => controller.setWritingMode(next.first)
                  : null,
            ),
            const SizedBox(height: 12),
            if (state.writingMode == 'typed')
              // If the backend exposes a `writingSubmission` object we
              // use the single-typed-draft flow (existing). Otherwise
              // render per-question text fields and save per-question.
              if (writingMeta != null) ...<Widget>[
                // Show prompts (Task 1/Task 2) above the single input.
                for (var i = 0; i < writingQuestions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Task ${i + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          writingQuestions[i].content,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: _writingController,
                  minLines: 8,
                  maxLines: 12,
                  readOnly: !editable,
                  onChanged: controller.setWritingTypedDraft,
                  decoration: InputDecoration(
                    hintText:
                        'Type your writing response here (Task 1 and Task 2)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Word count: ${_wordCount(state.writingTypedDraft)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...<Widget>[
                // Per-question typed inputs when writingSubmission is not present.
                for (var i = 0; i < writingQuestions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Task ${i + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          writingQuestions[i].content,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          key: ValueKey('writing-q-${writingQuestions[i].id}'),
                          initialValue:
                              (state.answers[writingQuestions[i].id] ?? '')
                                  .toString(),
                          minLines: 6,
                          maxLines: 12,
                          readOnly: !editable,
                          onChanged: (value) {
                            // Debounce per-question saves to avoid flooding the API.
                            _perQuestionDebounce[writingQuestions[i].id]
                                ?.cancel();
                            _perQuestionDebounce[writingQuestions[i].id] =
                                Timer(const Duration(milliseconds: 500), () {
                                  controller.saveAnswer(
                                    writingQuestions[i].id,
                                    value,
                                  );
                                });
                          },
                          decoration: InputDecoration(
                            hintText: 'Type your response for Task ${i + 1}...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Word count: ${_wordCount((state.answers[writingQuestions[i].id] ?? '').toString())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ]
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: (!editable || state.isMediaBusy)
                            ? null
                            : controller.pickWritingImages,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Images'),
                      ),
                      Text('Pages: ${state.writingImages.length}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (state.writingImages.isEmpty)
                    const Text('No writing images uploaded yet.')
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.writingImages.length,
                      onReorder: editable
                          ? controller.reorderWritingImages
                          : (_, _) {},
                      itemBuilder: (context, index) {
                        final image = state.writingImages[index];
                        return ListTile(
                          key: ValueKey(image.mediaId),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.grey.shade200,
                            ),
                            child: image.publicUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      image.publicUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.image_not_supported),
                                    ),
                                  )
                                : const Icon(Icons.image),
                          ),
                          title: Text(
                            image.fileName.isNotEmpty
                                ? image.fileName
                                : 'Uploaded page',
                          ),
                          subtitle: Text(
                            'Page ${image.pageOrder ?? index + 1}',
                          ),
                          trailing: IconButton(
                            onPressed:
                                (!editable ||
                                    state.isMediaBusy ||
                                    image.mediaId.isEmpty)
                                ? null
                                : () => controller.deleteWritingImage(
                                    image.mediaId,
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              'Backend submission mode: ${writingMeta?.mode ?? 'none'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingSectionCard(
    BuildContext context,
    ExamSessionState state,
    ExamSessionController controller,
  ) {
    final editable = state.canEditSpeaking;
    final uploadedRecording = state.speakingRecording;
    final localPath = state.localSpeakingRecordingPath;
    final localDuration = state.localSpeakingRecordingDurationSeconds;
    final isRecording =
        state.speakingRecordingState == SpeakingRecordingUiState.recording;
    final canUpload =
        editable &&
        !isRecording &&
        !state.isMediaBusy &&
        localPath != null &&
        localPath.isNotEmpty;
    final canDiscard =
        editable &&
        !isRecording &&
        !state.isMediaBusy &&
        localPath != null &&
        localPath.isNotEmpty;

    final speakingQuestions = state.currentQuestions;

    String partHelper(int index) {
      switch (index) {
        case 0:
          return 'Answer short personal questions.';
        case 1:
          return 'Speak about the cue card topic for about 1-2 minutes.';
        case 2:
          return 'Give longer discussion answers related to the cue card.';
        default:
          return '';
      }
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Speaking Submission',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Show Speaking Parts and prompts (Part 1 / Part 2 / Part 3)
            if (speakingQuestions.isNotEmpty) ...<Widget>[
              for (var i = 0; i < speakingQuestions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Part ${i + 1}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          speakingQuestions[i].content,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        if (partHelper(i).isNotEmpty)
                          Text(
                            partHelper(i),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
            Text(_speakingStateLabel(state.speakingRecordingState)),
            if (isRecording)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Recording time: ${_formatOptionalDuration(state.currentRecordingElapsedSeconds)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: !editable || state.isMediaBusy
                      ? null
                      : isRecording
                      ? controller.stopSpeakingRecording
                      : controller.startSpeakingRecording,
                  icon: Icon(
                    isRecording ? Icons.stop_circle_outlined : Icons.mic,
                  ),
                  label: Text(
                    isRecording ? 'Stop Recording' : 'Start Recording',
                  ),
                ),
                FilledButton.icon(
                  onPressed: canUpload
                      ? controller.uploadSpeakingRecording
                      : null,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Upload Recording'),
                ),
                OutlinedButton.icon(
                  onPressed: canDiscard
                      ? controller.discardSpeakingRecording
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard Local Take'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (localPath != null && localPath.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mic_external_on_outlined),
                title: const Text('Local recording ready'),
                subtitle: Text(
                  'Duration: ${_formatOptionalDuration(localDuration)}',
                ),
                trailing: IconButton(
                  onPressed: () => _toggleSpeakingAudio(localPath: localPath),
                  icon: Icon(
                    _playingSpeakingSource == 'local:$localPath' &&
                            _isPlayingSpeaking
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                ),
              )
            else
              const Text('No local recording buffered.'),
            const SizedBox(height: 8),
            if (uploadedRecording == null)
              const Text('No uploaded speaking recording yet.')
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  uploadedRecording.fileName.isNotEmpty
                      ? uploadedRecording.fileName
                      : 'Uploaded speaking recording',
                ),
                subtitle: Text(
                  uploadedRecording.publicUrl.isNotEmpty
                      ? 'Uploaded and available for teacher review.'
                      : 'Uploaded metadata saved.',
                ),
                trailing: IconButton(
                  onPressed: uploadedRecording.publicUrl.isNotEmpty
                      ? () => _toggleSpeakingAudio(
                          remoteUrl: uploadedRecording.publicUrl,
                        )
                      : null,
                  icon: Icon(
                    _playingSpeakingSource ==
                                'remote:${uploadedRecording.publicUrl}' &&
                            _isPlayingSpeaking
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
