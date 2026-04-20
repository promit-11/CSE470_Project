import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/dashboard_models.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResultSummaryScreen extends ConsumerWidget {
  const ResultSummaryScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Text(
                      _overallLabel(overall.status),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _statusColor(overall.status),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      overall.bandScore != null
                          ? overall.bandScore!.toStringAsFixed(1)
                          : (overall.objectiveBandScore != null
                                ? 'Objective ${overall.objectiveBandScore!.toStringAsFixed(1)}'
                                : (overallBand?.toStringAsFixed(1) ?? '-')),
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
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: <Widget>[
                    _sectionCard(context, 'Listening', listening),
                    _sectionCard(context, 'Reading', reading),
                    _sectionCard(context, 'Writing', writing),
                    _sectionCard(context, 'Speaking', speaking),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionStatusTile(context, 'Writing', writing),
                _sectionStatusTile(context, 'Speaking', speaking),
              ],
            ),
          ),
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
                                                .withOpacity(0.1),
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
                                    Text(
                                      SectionFeedback.fromJson(
                                            entry.value as Map<String, dynamic>,
                                          ).summary.isNotEmpty
                                          ? SectionFeedback.fromJson(
                                              entry.value
                                                  as Map<String, dynamic>,
                                            ).summary
                                          : 'No feedback available',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
    if (section.bandScore != null) {
      return BandScoreCard(
        label: label,
        score: section.bandScore!,
        isHighlight:
            section.status == 'reviewed' || section.status == 'completed',
      );
    }

    final color = _statusColor(section.status);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _statusLabel(section.status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
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
        side: BorderSide(color: Colors.grey.withOpacity(0.14)),
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
}
