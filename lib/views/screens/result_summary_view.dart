import 'dart:async';

import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResultSummaryView extends ConsumerStatefulWidget {
  const ResultSummaryView({super.key});

  @override
  ConsumerState<ResultSummaryView> createState() => _ResultSummaryViewState();
}

class _ResultSummaryViewState extends ConsumerState<ResultSummaryView> {
  Timer? _pollTimer;
  bool _hasInitialRefresh = false;
  bool _isRefreshing = false;

  Future<void> _refreshResultIfNeeded() async {
    if (_hasInitialRefresh) {
      return;
    }

    _hasInitialRefresh = true;
    setState(() => _isRefreshing = true);

    try {
      // Force fresh load of the session to ensure latest result data
      final sessionId = ModalRoute.of(context)?.settings.arguments as String?;
      if (sessionId != null && mounted) {
        await ref
            .read(examSessionControllerProvider.notifier)
            .loadSession(sessionId);
      }
    } catch (_) {
      // Silently continue if refresh fails
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _startPollingIfNeeded(String sessionId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      try {
        await ref
            .read(examSessionControllerProvider.notifier)
            .loadSession(sessionId);
      } catch (_) {
        // ignore individual polling failures
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'completed':
        return 'Completed';
      case 'pending_review':
        return 'Pending Teacher Review';
      case 'reviewed':
        return 'Reviewed';
      case 'not_submitted':
        return 'Not Submitted';
      default:
        return raw.isEmpty ? 'Unknown' : raw;
    }
  }

  String _overallLabel(String raw) {
    switch (raw) {
      case 'finalized':
        return 'Finalized';
      case 'pending_full_review':
        return 'Pending Full Review';
      case 'partial_unavailable_sections':
        return 'Partial (Subjective Missing)';
      default:
        return raw.isEmpty ? 'Unknown' : raw;
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'reviewed':
      case 'completed':
      case 'finalized':
        return Colors.green;
      case 'pending_review':
      case 'pending_full_review':
        return Colors.orange;
      case 'not_submitted':
      case 'partial_unavailable_sections':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force refresh of fresh result data on first render
    _refreshResultIfNeeded();

    final session = ref.watch(examSessionControllerProvider).session;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Result Summary')),
        body: EmptyStateView(
          icon: Icons.description_outlined,
          title: 'No Session Data',
          message:
              'Unable to load your test results. Please return to dashboard.',
          action: FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (_) => false),
            child: const Text('Return to Dashboard'),
          ),
        ),
      );
    }

    final overallBand = session.overallBand;
    final feedbackSummary = session.feedbackSummary;
    final summary = StudentResultSummary.fromJson(session.resultSummary);
    final overall = summary.overall;
    final listening = summary.section('listening');
    final reading = summary.section('reading');
    final writing = summary.section('writing');
    final speaking = summary.section('speaking');

    // Start/stop polling depending on overall status.
    if (session.overallBandStatus != 'finalized') {
      _startPollingIfNeeded(session.id);
    } else {
      _stopPolling();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Test Results'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: <Widget>[
          SectionCard(
            title: 'Result Summary',
            icon: Icons.verified,
            child: Column(
              children: <Widget>[
                Icon(Icons.check_circle, size: 56, color: Colors.green[400]),
                const SizedBox(height: 12),
                Text(
                  'Test Completed!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here are your results',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionCard(
            title: 'Overall Band Score',
            icon: Icons.star,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            overall.isFinalized
                                ? 'Final Overall Band'
                                : (overall.isPartial
                                      ? 'Estimated Overall Band'
                                      : _overallLabel(overall.status)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _statusColor(overall.status),
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!overall.isFinalized)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              overall.isPartial
                                  ? 'Estimated'
                                  : 'Pending Review',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overall.bandScore != null
                          ? overall.bandScore!.toStringAsFixed(1)
                          : (overall.objectiveBandScore != null
                                ? 'Objective ${overall.objectiveBandScore!.toStringAsFixed(1)}'
                                : (overall.overallEstimatedBand != null
                                      ? 'Est ${overall.overallEstimatedBand!.toStringAsFixed(1)}'
                                      : (overallBand?.toStringAsFixed(1) ??
                                            '-'))),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (overall.status == OverallStatus.pendingFullReview)
                      Text(
                        'Listening/Reading are available. Final overall band appears after Writing and Speaking review.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    if (overall.status ==
                        OverallStatus.partialUnavailableSections)
                      Text(
                        'Overall is partial because one or more subjective sections were not submitted.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (overall.status != OverallStatus.finalized) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  overall.status == OverallStatus.partialUnavailableSections
                      ? 'Subjective sections that were not submitted will remain unavailable.'
                      : 'Writing and Speaking stay pending until manual review completes.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SectionCard(
            title: 'Section Scores',
            icon: Icons.assessment,
            child: Column(
              children: <Widget>[
                if (_isRefreshing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading final result...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxis = width < 420 ? 1 : 2;
                      final childAspect = crossAxis == 1 ? 2.5 : 0.85;
                      return GridView.count(
                        crossAxisCount: crossAxis,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: childAspect,
                        children: <Widget>[
                          _sectionCard(context, 'Listening', listening),
                          _sectionCard(context, 'Reading', reading),
                          _sectionCard(context, 'Writing', writing),
                          _sectionCard(context, 'Speaking', speaking),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionStatusTile(context, 'Writing', writing),
          _sectionStatusTile(context, 'Speaking', speaking),
          if ((feedbackSummary['notes']?.toString() ?? '').trim().isNotEmpty)
            const SizedBox(height: 12),
          if ((feedbackSummary['notes']?.toString() ?? '').trim().isNotEmpty)
            SectionCard(
              title: 'General Feedback',
              icon: Icons.comment,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  feedbackSummary['notes']?.toString() ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (feedbackSummary['sectionFeedback'] != null &&
              (feedbackSummary['sectionFeedback'] as Map<String, dynamic>)
                  .isNotEmpty)
            const SizedBox(height: 12),
          if (feedbackSummary['sectionFeedback'] != null &&
              (feedbackSummary['sectionFeedback'] as Map<String, dynamic>)
                  .isNotEmpty)
            SectionCard(
              title: 'Section-wise Feedback',
              icon: Icons.feedback,
              child: Column(
                children: <Widget>[
                  ...((feedbackSummary['sectionFeedback']
                              as Map<String, dynamic>?)
                          ?.entries
                          .map(
                            (entry) => Card(
                              elevation: 0,
                              color: Colors.grey[50],
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Text(
                                          entry.key.toUpperCase(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            (() {
                                              final feedback =
                                                  SectionFeedback.fromJson(
                                                    entry.value
                                                        as Map<String, dynamic>,
                                                  );
                                              if (feedback.bandScore != null) {
                                                return 'Band ${feedback.bandScore!.toStringAsFixed(1)}';
                                              }
                                              return _statusLabel(
                                                feedback.status,
                                              );
                                            })(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Builder(
                                      builder: (_) {
                                        final feedback =
                                            SectionFeedback.fromJson(
                                              entry.value
                                                  as Map<String, dynamic>,
                                            );
                                        final lines = <Widget>[];
                                        if (feedback.summary.isNotEmpty) {
                                          lines.add(
                                            Text(
                                              feedback.summary,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        } else {
                                          lines.add(
                                            Text(
                                              'No feedback available',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        }
                                        if (feedback.comments
                                            .trim()
                                            .isNotEmpty) {
                                          lines.add(const SizedBox(height: 8));
                                          lines.add(
                                            Text(
                                              'Teacher comments: ${feedback.comments}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        }
                                        if (feedback.strengths.isNotEmpty) {
                                          lines.add(const SizedBox(height: 8));
                                          lines.add(
                                            Text(
                                              'Strengths: ${feedback.strengths.join(', ')}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        }
                                        if (feedback.weaknesses.isNotEmpty) {
                                          lines.add(const SizedBox(height: 8));
                                          lines.add(
                                            Text(
                                              'Weaknesses: ${feedback.weaknesses.join(', ')}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: lines,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList() ??
                      []),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _answerReviewSection(context, listening, reading),
          const SizedBox(height: 28),
          PrimaryButton(
            icon: Icons.home,
            label: 'Return to Dashboard',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (_) => false),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            icon: Icons.history,
            label: 'View Test History',
            onPressed: () => Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.studentArchive, (_) => false),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    BuildContext context,
    String label,
    ResultSectionSummary section,
  ) {
    final color = _statusColor(section.status);
    final hasBand = section.bandScore != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (hasBand)
              Text(
                section.bandScore!.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              Icon(
                section.status == 'not_submitted'
                    ? Icons.not_interested
                    : Icons.hourglass_top,
                size: 28,
                color: color,
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                hasBand ? 'Reviewed' : _statusLabel(section.status),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionStatusTile(
    BuildContext context,
    String title,
    ResultSectionSummary section,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(_statusLabel(section.status)),
        trailing: section.bandScore != null
            ? Text(
                section.bandScore!.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : Icon(
                section.status == 'not_submitted'
                    ? Icons.not_interested
                    : Icons.hourglass_top,
                color: _statusColor(section.status),
              ),
      ),
    );
  }

  Widget _answerReviewSection(
    BuildContext context,
    ResultSectionSummary listening,
    ResultSectionSummary reading,
  ) {
    final hasListening = (listening.reviewAnswers).isNotEmpty;
    final hasReading = (reading.reviewAnswers).isNotEmpty;
    if (!hasListening && !hasReading) {
      return const SizedBox.shrink();
    }
    return SectionCard(
      title: 'Review Answers',
      icon: Icons.question_answer,
      child: Column(
        children: [
          if (hasListening) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Listening',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            ...listening.reviewAnswers.asMap().entries.map((e) {
              final idx = e.key + 1;
              final item = e.value;
              final qText = (item['questionText'] ?? '').toString();
              final student = item['studentAnswer'];
              final correct = item['correctAnswer'];
              final isCorrect = item['isCorrect'] == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(child: Text(idx.toString())),
                title: Text(qText.isNotEmpty ? qText : 'Question $idx'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Your answer: ${student ?? 'Not answered'}'),
                    Text(
                      'Correct answer: ${((correct is List) ? correct.join(', ') : (correct?.toString() ?? '-'))}',
                    ),
                  ],
                ),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              );
            }),
          ],
          if (hasReading) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Reading',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            ...reading.reviewAnswers.asMap().entries.map((e) {
              final idx = e.key + 1;
              final item = e.value;
              final qText = (item['questionText'] ?? '').toString();
              final student = item['studentAnswer'];
              final correct = item['correctAnswer'];
              final isCorrect = item['isCorrect'] == true;
              return ListTile(
                dense: true,
                leading: CircleAvatar(child: Text(idx.toString())),
                title: Text(qText.isNotEmpty ? qText : 'Question $idx'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('Your answer: ${student ?? 'Not answered'}'),
                    Text(
                      'Correct answer: ${((correct is List) ? correct.join(', ') : (correct?.toString() ?? '-'))}',
                    ),
                  ],
                ),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
