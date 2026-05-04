import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/teacher_models.dart';
import 'package:cse470_app/core/utils/api_config.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeacherReviewDetailView extends ConsumerStatefulWidget {
  const TeacherReviewDetailView({
    super.key,
    required this.evaluationRequestId,
  });

  final String evaluationRequestId;

  @override
  ConsumerState<TeacherReviewDetailView> createState() => _TeacherReviewDetailViewState();
}

class _TeacherReviewDetailViewState extends ConsumerState<TeacherReviewDetailView> {
  final _formKey = GlobalKey<FormState>();
  final _overallBandController = TextEditingController();
  final _commentsController = TextEditingController();
  final _strengthsController = TextEditingController();
  final _weaknessesController = TextEditingController();

  final _taskResponseController = TextEditingController();
  final _coherenceController = TextEditingController();
  final _lexicalController = TextEditingController();
  final _grammarController = TextEditingController();
  final _fluencyController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPlayingSpeaking = false;
  String? _errorMessage;
  EvaluationRequestModel? _request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDetail();
    });
  }

  @override
  void dispose() {
    _overallBandController.dispose();
    _commentsController.dispose();
    _strengthsController.dispose();
    _weaknessesController.dispose();
    _taskResponseController.dispose();
    _coherenceController.dispose();
    _lexicalController.dispose();
    _grammarController.dispose();
    _fluencyController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (widget.evaluationRequestId.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid evaluation request id.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final request = await ref
        .read(teacherDashboardControllerProvider.notifier)
        .getRequestDetail(widget.evaluationRequestId);

    if (!mounted) {
      return;
    }

    if (request == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load evaluation details.';
      });
      return;
    }

    setState(() {
      _request = request;
      _isLoading = false;
      _errorMessage = null;
      if (request.reviewedBandScore != null) {
        _overallBandController.text = request.reviewedBandScore!
            .toStringAsFixed(1);
      }
      _commentsController.text = request.reviewComments ?? '';
      _strengthsController.text = request.reviewStrengths.join(', ');
      _weaknessesController.text = request.reviewWeaknesses.join(', ');

      _taskResponseController.text =
          (request.criteriaScores['taskResponse'] ?? '').toString();
      _coherenceController.text =
          (request.criteriaScores['coherenceAndCohesion'] ??
                  request.criteriaScores['fluencyAndCoherence'] ??
                  '')
              .toString();
      _lexicalController.text =
          (request.criteriaScores['lexicalResource'] ?? '').toString();
      _grammarController.text =
          (request.criteriaScores['grammaticalRangeAndAccuracy'] ?? '')
              .toString();
      _fluencyController.text =
          (request.criteriaScores['fluencyAndCoherence'] ?? '').toString();
    });
  }

  String? _bandValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 0 || parsed > 9) {
      return 'Enter a band between 0 and 9';
    }
    return null;
  }

  List<String> _csvToList(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _resolveMediaUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) {
      return '';
    }
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

  Future<void> _toggleSpeakingPlayback() async {
    final recording = _request?.reviewDetail?.speakingSubmission?.recording;
    final url = _resolveMediaUrl(recording?.publicUrl ?? '');
    if (url.isEmpty) {
      return;
    }

    try {
      if (_isPlayingSpeaking) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() {
          _isPlayingSpeaking = false;
        });
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (!mounted) return;
      setState(() {
        _isPlayingSpeaking = true;
      });

      _audioPlayer.onPlayerComplete.first.then((_) {
        if (!mounted) return;
        setState(() {
          _isPlayingSpeaking = false;
        });
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not play speaking recording.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? _csvRequiredValidator(String? value, String fieldName) {
    if (_csvToList(value ?? '').isEmpty) {
      return '$fieldName requires at least one item';
    }
    return null;
  }

  Future<void> _submitReview() async {
    if (_request == null || !_formKey.currentState!.validate()) {
      return;
    }

    final section = _request!.section;
    final criterionScores = <String, double>{
      'lexicalResource': double.parse(_lexicalController.text.trim()),
      'grammaticalRangeAndAccuracy': double.parse(
        _grammarController.text.trim(),
      ),
    };

    if (section == 'writing') {
      criterionScores['taskResponse'] = double.parse(
        _taskResponseController.text.trim(),
      );
      criterionScores['coherenceAndCohesion'] = double.parse(
        _coherenceController.text.trim(),
      );
    } else {
      criterionScores['fluencyAndCoherence'] = double.parse(
        _fluencyController.text.trim(),
      );
    }

    final payload = TeacherReviewPayload(
      overallBand: double.parse(_overallBandController.text.trim()),
      comments: _commentsController.text.trim(),
      strengths: _csvToList(_strengthsController.text),
      weaknesses: _csvToList(_weaknessesController.text),
      criterionScores: criterionScores,
    );

    setState(() => _isSubmitting = true);
    final ok = await ref
        .read(teacherDashboardControllerProvider.notifier)
        .submitReview(requestId: _request!.id, payload: payload);

    if (!mounted) {
      return;
    }

    setState(() => _isSubmitting = false);

    if (!ok) {
      final message = ref.read(teacherDashboardControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Could not submit review.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review submitted successfully.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Evaluation')),
      body: AsyncView(
        isLoading: _isLoading,
        errorMessage: _errorMessage,
        onRetry: _loadDetail,
        child: _request == null
            ? const EmptyStateView(
                title: 'No Request Loaded',
                message: 'Unable to load this review request.',
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      SectionCard(
                        title:
                            '${_request!.section.toUpperCase()} Review â€¢ ${_request!.status}',
                        icon: Icons.assignment,
                        child: Column(
                          children: <Widget>[
                            InfoRow(
                              label: 'Session ID',
                              value: _request!.testSessionId,
                            ),
                            InfoRow(
                              label: 'Source',
                              value: _request!.sourceType,
                            ),
                            if (_request!
                                    .reviewDetail
                                    ?.sectionContext
                                    .sectionStatus
                                    .isNotEmpty ==
                                true)
                              InfoRow(
                                label: 'Section Status',
                                value: _request!
                                    .reviewDetail!
                                    .sectionContext
                                    .sectionStatus,
                              ),
                            if (_request!.isSpeaking)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Review speaking based on the uploaded response and rubric fields.',
                                  style: TextStyle(color: Colors.blueGrey[700]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_request!.isWriting)
                        _buildWritingSubmissionCard(context)
                      else
                        _buildSpeakingSubmissionCard(context),
                      const SizedBox(height: 12),
                      _buildSectionContextCard(context),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Scores',
                        icon: Icons.score,
                        child: Column(
                          children: <Widget>[
                            FormInputField(
                              controller: _overallBandController,
                              label: 'Overall Band',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _bandValidator,
                            ),
                            const SizedBox(height: 10),
                            if (_request!.isWriting) ...<Widget>[
                              FormInputField(
                                controller: _taskResponseController,
                                label: 'Task Response',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: _bandValidator,
                              ),
                              const SizedBox(height: 10),
                              FormInputField(
                                controller: _coherenceController,
                                label: 'Coherence and Cohesion',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: _bandValidator,
                              ),
                            ] else ...<Widget>[
                              FormInputField(
                                controller: _fluencyController,
                                label: 'Fluency and Coherence (Text Response)',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: _bandValidator,
                              ),
                            ],
                            const SizedBox(height: 10),
                            FormInputField(
                              controller: _lexicalController,
                              label: 'Lexical Resource',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _bandValidator,
                            ),
                            const SizedBox(height: 10),
                            FormInputField(
                              controller: _grammarController,
                              label: 'Grammatical Range and Accuracy',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _bandValidator,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'Feedback',
                        icon: Icons.feedback,
                        child: Column(
                          children: <Widget>[
                            FormInputField(
                              controller: _commentsController,
                              label: 'Comments',
                              maxLines: 4,
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Comments are required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            FormInputField(
                              controller: _strengthsController,
                              label: 'Strengths (comma separated)',
                              maxLines: 2,
                              validator: (value) =>
                                  _csvRequiredValidator(value, 'Strengths'),
                            ),
                            const SizedBox(height: 10),
                            FormInputField(
                              controller: _weaknessesController,
                              label: 'Weaknesses (comma separated)',
                              maxLines: 2,
                              validator: (value) =>
                                  _csvRequiredValidator(value, 'Weaknesses'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: _isSubmitting
                            ? 'Submitting...'
                            : 'Submit Review',
                        isEnabled: !_isSubmitting,
                        isLoading: _isSubmitting,
                        icon: Icons.send,
                        onPressed: _submitReview,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildWritingSubmissionCard(BuildContext context) {
    final writing = _request?.reviewDetail?.writingSubmission;
    final images = writing?.images ?? const <TeacherMediaMetadata>[];
    final typedAnswer = writing?.typedAnswer.trim() ?? '';
    final legacy = writing?.legacyWritingResponse.trim() ?? '';

    return SectionCard(
      title: 'Writing Submission',
      icon: Icons.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (typedAnswer.isNotEmpty) ...<Widget>[
            Text(
              'Typed Answer',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(typedAnswer),
            ),
            const SizedBox(height: 12),
          ],
          if (legacy.isNotEmpty && typedAnswer.isEmpty) ...<Widget>[
            Text(
              'Legacy Text Response',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(legacy),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Uploaded Pages',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (images.isEmpty)
            const Text('No writing images uploaded for this response.')
          else
            ...images.map((image) {
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: image.publicUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              _resolveMediaUrl(image.publicUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
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
                  subtitle: Text('Page ${image.pageOrder ?? '-'}'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSpeakingSubmissionCard(BuildContext context) {
    final speaking = _request?.reviewDetail?.speakingSubmission;
    final recording = speaking?.recording;

    return SectionCard(
      title: 'Speaking Submission',
      icon: Icons.mic,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (recording == null || recording.publicUrl.isEmpty)
            const Text('No speaking recording available for this request.')
          else
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  recording.fileName.isNotEmpty
                      ? recording.fileName
                      : 'Speaking recording',
                ),
                subtitle: Text(
                  'Playback URL available${recording.sizeBytes > 0 ? ' â€¢ ${recording.sizeBytes} bytes' : ''}',
                ),
                trailing: IconButton(
                  onPressed: _toggleSpeakingPlayback,
                  icon: Icon(
                    _isPlayingSpeaking
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                  ),
                ),
              ),
            ),
          if ((speaking?.legacySpeakingResponse ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Legacy response: ${speaking!.legacySpeakingResponse}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionContextCard(BuildContext context) {
    final sectionContext = _request?.reviewDetail?.sectionContext;
    if (sectionContext == null) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      title: 'Section Context',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InfoRow(
            label: 'Questions in section',
            value: '${sectionContext.questions.length}',
            icon: Icons.quiz,
          ),
          InfoRow(
            label: 'Answered items',
            value: '${sectionContext.answers.length}',
            icon: Icons.fact_check,
          ),
          if (sectionContext.questions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...sectionContext.questions
                .take(4)
                .map(
                  (q) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(q.title.isNotEmpty ? q.title : q.content),
                    subtitle: Text(
                      '${q.questionType} â€¢ ${q.category} â€¢ ${q.difficulty}',
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}




