import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class StudentArchiveView extends ConsumerStatefulWidget {
  const StudentArchiveView({super.key});

  @override
  ConsumerState<StudentArchiveView> createState() => _StudentArchiveViewState();
}

class _StudentArchiveViewState extends ConsumerState<StudentArchiveView> {
  String _overallStatusLabel(String status) {
    switch (status) {
      case 'finalized':
        return 'Finalized';
      case 'pending_full_review':
        return 'Pending full review';
      case 'partial_unavailable_sections':
        return 'Partial (subjective missing)';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  Color _overallStatusColor(String status) {
    switch (status) {
      case 'finalized':
        return Colors.green;
      case 'pending_full_review':
        return Colors.orange;
      case 'partial_unavailable_sections':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentArchiveControllerProvider.notifier).load();
    });
  }

  Color _getBandColor(double score) {
    if (score >= 8.0) return Colors.green;
    if (score >= 7.0) return Colors.blue;
    if (score >= 6.0) return Colors.orange;
    return Colors.red;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'reviewed':
        return 'Reviewed';
      case 'pending_review':
      case 'pending':
      case 'submitted':
        return 'Pending Teacher Review';
      case 'not_submitted':
        return 'Not Submitted';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentArchiveControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Test History'),
        centerTitle: true,
        elevation: 0,
      ),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () =>
            ref.read(studentArchiveControllerProvider.notifier).load(),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(studentArchiveControllerProvider.notifier).load(),
          child: state.history.isEmpty
              ? EmptyStateView(
                  icon: Icons.history,
                  title: 'No Tests Yet',
                  message: 'Complete a mock test to see your results here.',
                  action: FilledButton.icon(
                    onPressed: Navigator.of(context).pop,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Return to Dashboard'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  itemCount: state.history.length,
                  itemBuilder: (context, index) {
                    final row = state.history[index];
                    final completedAt = row.completedAt;
                    final overall = row.resultSummary.overall;
                    final overallBand = overall.bandScore;
                    final overallStatus = overall.status;
                    final writing = row.resultSummary.section('writing');
                    final speaking = row.resultSummary.section('speaking');

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.14)),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'Test ${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (completedAt != null)
                                        Text(
                                          DateFormat.yMMMd().add_jm().format(
                                            completedAt,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _overallStatusColor(
                                        overallStatus,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: overallBand != null
                                        ? Text(
                                            overallBand.toStringAsFixed(1),
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall
                                                ?.copyWith(
                                                  color: _getBandColor(
                                                    overallBand,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          )
                                        : SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Text(
                                              _overallStatusLabel(
                                                overallStatus,
                                              ),
                                              softWrap: false,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: _overallStatusColor(
                                                      overallStatus,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            if (overallBand != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Overall Band: ${overallBand.toStringAsFixed(1)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _getBandColor(overallBand),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            if (overallBand == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  overallStatus ==
                                          'partial_unavailable_sections'
                                      ? 'Overall is partial because one or more subjective sections were not submitted.'
                                      : 'Final overall band is pending teacher review for subjective sections.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.orange[700]),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              'Section Scores',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 8),
                            GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.95,
                              children: <Widget>[
                                _scoreChip('L', row.listeningBand, context),
                                _scoreChip('R', row.readingBand, context),
                                _scoreChip(
                                  'W',
                                  writing.bandScore,
                                  context,
                                  status: writing.status,
                                ),
                                _scoreChip(
                                  'S',
                                  speaking.bandScore,
                                  context,
                                  status: speaking.status,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                _stateChip(
                                  'Writing: ${_statusLabel(writing.status)}',
                                  writing.status,
                                ),
                                _stateChip(
                                  'Speaking: ${_statusLabel(speaking.status)}',
                                  speaking.status,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _scoreChip(
    String label,
    double? score,
    BuildContext context, {
    String? status,
  }) {
    final hasScore = score != null;
    final normalized = (status ?? '').toLowerCase();
    final isPending = !hasScore && normalized == 'pending_review';
    final isMissing = !hasScore && normalized == 'not_submitted';
    final chipColor = isMissing
        ? Colors.grey
        : (isPending ? Colors.orange : _getBandColor(score ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (hasScore)
            Text(
              score.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _getBandColor(score),
                fontWeight: FontWeight.bold,
              ),
            )
          else
            Text(
              _statusLabel(status ?? ''),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isMissing ? Colors.grey[700] : Colors.orange[800],
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _stateChip(String label, String status) {
    final lower = status.toLowerCase();
    final color = lower == 'reviewed' || lower == 'completed'
        ? Colors.green
        : lower == 'pending_review'
        ? Colors.orange
        : lower == 'not_submitted'
        ? Colors.grey
        : Colors.blueGrey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.shade700,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}




