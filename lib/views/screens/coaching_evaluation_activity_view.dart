import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingEvaluationActivityView extends ConsumerWidget {
  const CoachingEvaluationActivityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instituteControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Evaluation Activity'),
        actions: <Widget>[
          IconButton(
            onPressed: () =>
                ref.read(instituteControllerProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () => ref.read(instituteControllerProvider.notifier).load(),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(instituteControllerProvider.notifier).load(),
          child: Builder(
            builder: (context) {
              final activity =
                  state.evaluationActivity ?? const <String, dynamic>{};
              final counts =
                  activity['statusCounts'] as Map<String, dynamic>? ??
                  const <String, dynamic>{};
              final items =
                  activity['items'] as List<dynamic>? ?? const <dynamic>[];

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                children: <Widget>[
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: <Widget>[
                      _StatusCard(
                        label: 'Pending',
                        count: counts['pending'] ?? 0,
                        icon: Icons.hourglass_top,
                        color: Colors.orange,
                      ),
                      _StatusCard(
                        label: 'Claimed',
                        count: counts['claimed'] ?? 0,
                        icon: Icons.assignment_ind,
                        color: Colors.blue,
                      ),
                      _StatusCard(
                        label: 'Reviewed',
                        count: counts['reviewed'] ?? 0,
                        icon: Icons.verified,
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Recent Evaluation Requests',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (items.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'No evaluation requests at this time.',
                              ),
                            )
                          else
                            ...items.map((raw) {
                              final item = raw as Map<String, dynamic>;
                              final student =
                                  item['student'] as Map<String, dynamic>? ??
                                  const <String, dynamic>{};
                              final teacher =
                                  item['teacher'] as Map<String, dynamic>? ??
                                  const <String, dynamic>{};
                              final section = (item['section'] ?? '')
                                  .toString();
                              final status = (item['status'] ?? '').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              status,
                                            ).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            section.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: _getStatusColor(status),
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Chip(
                                          label: Text(status),
                                          backgroundColor: _getStatusColor(
                                            status,
                                          ).withValues(alpha: 0.2),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Student: ${student['name'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Teacher: ${teacher['name'] ?? '-'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'claimed':
        return Colors.blue;
      case 'reviewed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final dynamic count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryTight =
              constraints.maxHeight < 70 || constraints.maxWidth < 70;
          final isCompact =
              constraints.maxHeight < 95 || constraints.maxWidth < 95;

          final contentPadding = isVeryTight ? 4.0 : (isCompact ? 8.0 : 12.0);
          final iconSize = isVeryTight ? 12.0 : (isCompact ? 18.0 : 28.0);
          final valueSize = isVeryTight ? 12.0 : (isCompact ? 18.0 : 24.0);
          final labelSize = isVeryTight ? 8.0 : (isCompact ? 10.0 : 12.0);
          final spacingAfterIcon = isVeryTight ? 0.0 : (isCompact ? 2.0 : 8.0);
          final spacingAfterValue = isVeryTight ? 0.0 : (isCompact ? 1.0 : 4.0);

          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(icon, color: color, size: iconSize),
                  SizedBox(height: spacingAfterIcon),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacingAfterValue),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: labelSize, height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}



