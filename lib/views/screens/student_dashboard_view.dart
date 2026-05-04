import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/models/coaching_assignment_models.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/band_trend_chart.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudentDashboardView extends ConsumerStatefulWidget {
  const StudentDashboardView({super.key});

  @override
  ConsumerState<StudentDashboardView> createState() =>
      _StudentDashboardViewState();
}

class _StudentDashboardViewState extends ConsumerState<StudentDashboardView> {
  /// Show simulated payment gateway dialog (prototype for demo).
  /// This is not a real payment processor - only for testing.
  Future<bool> _showPaymentGatewaySimulation({required int packSize}) async {
    String selectedMethod = 'Card';
    bool isProcessing = false;
    final estimatedAmount = packSize * 500;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('💳 Payment Gateway (Simulated - Demo Only)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Purchase: $packSize credits'),
                  const SizedBox(height: 4),
                  Text('Estimated total: $estimatedAmount (simulated)'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'Card', child: Text('Card')),
                      DropdownMenuItem(
                        value: 'Mobile Banking',
                        child: Text('Mobile Banking'),
                      ),
                      DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
                    ],
                    onChanged: isProcessing
                        ? null
                        : (value) {
                            if (value == null) return;
                            setDialogState(() {
                              selectedMethod = value;
                            });
                          },
                    decoration: const InputDecoration(
                      labelText: 'Payment Method',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isProcessing)
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Processing simulated payment...',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          setDialogState(() {
                            isProcessing = true;
                          });
                          await Future<void>.delayed(
                            const Duration(milliseconds: 1200),
                          );
                          navigator.pop(true);
                        },
                  child: Text(isProcessing ? 'Processing...' : 'Pay & Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? false;
  }

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

  String _sectionStateLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'pending_review':
        return 'Pending review';
      case 'reviewed':
        return 'Reviewed';
      case 'not_submitted':
        return 'Not submitted';
      default:
        return status.isEmpty ? 'Unknown' : status;
    }
  }

  String _formatCredits(dynamic creditsValue) {
    // Only show "Unlimited" if value is completely null
    // For -1 or any numeric value, show the actual number
    if (creditsValue == null) {
      return 'Unlimited';
    }

    // Convert to int if it's a number
    if (creditsValue is num) {
      return creditsValue.toInt().toString();
    }

    return creditsValue.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studentDashboardControllerProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(studentDashboardControllerProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final analytics = state.analytics;
    final latest = analytics?.latest;
    final latestOverall = latest?.resultSummary.overall;
    final latestWriting = latest?.resultSummary.section('writing');
    final latestSpeaking = latest?.resultSummary.section('speaking');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        centerTitle: true,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: AsyncView(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        onRetry: () =>
            ref.read(studentDashboardControllerProvider.notifier).load(),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(studentDashboardControllerProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              SectionCard(
                title: 'Welcome',
                icon: Icons.waving_hand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      auth.currentUser?.name ?? 'Student',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track performance, review feedback, and continue your mock test journey.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Performance Overview',
                icon: Icons.trending_up,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 5,
                      mainAxisSpacing: 5,
                      childAspectRatio: MediaQuery.of(context).size.width < 400
                          ? 0.95
                          : 1.35,
                      children: <Widget>[
                        StatCard(
                          label: 'Tests Completed',
                          value: '${analytics?.totalMocks ?? 0}',
                          icon: Icons.check_circle,
                        ),
                        StatCard(
                          label: 'Available Credits',
                          value: _formatCredits(
                            analytics?.mockAccess?['remainingCredits'],
                          ),
                          icon: Icons.card_giftcard,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (latestOverall != null)
                      InfoRow(
                        label: 'Latest Overall Status',
                        value: _overallStatusLabel(latestOverall.status),
                        icon: Icons.star,
                      ),
                    if (latestOverall != null)
                      InfoRow(
                        label: 'Latest Overall Band',
                        value: latestOverall.bandScore != null
                            ? latestOverall.bandScore!.toStringAsFixed(1)
                            : (latestOverall.objectiveBandScore != null
                                  ? 'Objective ${latestOverall.objectiveBandScore!.toStringAsFixed(1)}'
                                  : 'Pending'),
                        icon: Icons.grade,
                      ),
                    if (latestWriting != null)
                      InfoRow(
                        label: 'Latest Writing',
                        value: _sectionStateLabel(latestWriting.status),
                        icon: Icons.edit_note,
                      ),
                    if (latestSpeaking != null)
                      InfoRow(
                        label: 'Latest Speaking',
                        value: _sectionStateLabel(latestSpeaking.status),
                        icon: Icons.mic,
                      ),
                    if ((analytics?.pendingReviewCounts['writing'] ?? 0) > 0 ||
                        (analytics?.pendingReviewCounts['speaking'] ?? 0) > 0)
                      InfoRow(
                        label: 'Pending Subjective Reviews',
                        value:
                            'W: ${analytics?.pendingReviewCounts['writing'] ?? 0}, S: ${analytics?.pendingReviewCounts['speaking'] ?? 0}',
                        icon: Icons.hourglass_top,
                      ),
                    if (analytics != null)
                      InfoRow(
                        label: 'Finalized Overall Attempts',
                        value: '${analytics.finalizedOverallCount}',
                        icon: Icons.verified,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _CoachingStatusCard(coachingFormData: state.coachingFormData),
              const SizedBox(height: 24),
              if ((analytics?.trend ?? []).isNotEmpty)
                SectionCard(
                  title: 'Overall Band Trend',
                  icon: Icons.show_chart,
                  child: Card(
                    elevation: 0,
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: BandTrendChart(
                        trend: analytics?.trend ?? const [],
                      ),
                    ),
                  ),
                ),
              if ((analytics?.trend ?? []).isNotEmpty)
                const SizedBox(height: 16),
              if (analytics != null && analytics.sectionAverages.isNotEmpty)
                SectionCard(
                  title: 'Section Averages',
                  icon: Icons.assessment,
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: <Widget>[
                      ...analytics.sectionAverages.entries
                          .where(
                            (e) => const [
                              'listening',
                              'reading',
                              'writing',
                              'speaking',
                            ].contains(e.key),
                          )
                          .map((entry) {
                            final reviewedCount =
                                analytics.sectionAverageCounts[entry.key] ?? 0;
                            final label =
                                entry.key[0].toUpperCase() +
                                entry.key.substring(1);
                            if (reviewedCount == 0 &&
                                (entry.key == 'writing' ||
                                    entry.key == 'speaking')) {
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Pending review',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return BandScoreCard(
                              label: label,
                              score: entry.value.toDouble(),
                            );
                          }),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if ((analytics?.strengths ?? []).isNotEmpty ||
                  (analytics?.weaknesses ?? []).isNotEmpty)
                SectionCard(
                  title: 'Analysis',
                  icon: Icons.insights,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if ((analytics?.strengths ?? []).isNotEmpty) ...<Widget>[
                        Text(
                          'Strengths',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (analytics?.strengths ?? [])
                              .map(
                                (s) => Chip(
                                  avatar: const Icon(
                                    Icons.check_circle,
                                    size: 18,
                                  ),
                                  label: Text(s),
                                  backgroundColor: Colors.green[50],
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if ((analytics?.weaknesses ?? []).isNotEmpty) ...<Widget>[
                        Text(
                          'Areas to Improve',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (analytics?.weaknesses ?? [])
                              .map(
                                (w) => Chip(
                                  avatar: const Icon(Icons.info, size: 18),
                                  label: Text(w),
                                  backgroundColor: Colors.orange[50],
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                icon: Icons.play_arrow,
                label: (analytics?.hasResumableSession ?? false)
                    ? 'Resume Mock Test'
                    : 'Start New Mock Test',
                isEnabled: !state.isLoading,
                onPressed: () => Navigator.of(context).pushNamed(
                  AppRoutes.studentExam,
                  arguments: analytics?.activeSessionId,
                ),
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                icon: Icons.shopping_cart_checkout,
                label: state.isPurchasing
                    ? 'Processing Purchase...'
                    : 'Purchase 5 Credits (Simulated)',
                isEnabled: !state.isPurchasing,
                onPressed: () async {
                  // Make simulation explicit before opening payment dialog
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Simulated Purchase'),
                      content: const Text(
                        'This purchase is simulated for demo purposes. No real payment will be taken. Continue?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Continue'),
                        ),
                      ],
                    ),
                  );
                  if (proceed != true) return;

                  final paymentConfirmed = await _showPaymentGatewaySimulation(
                    packSize: 5,
                  );
                  if (!paymentConfirmed || !context.mounted) return;

                  final result = await ref
                      .read(studentDashboardControllerProvider.notifier)
                      .purchaseMockAccess(packSize: 5);
                  if (!context.mounted) return;
                  if (result == null) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Purchase failed.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final discountCode = (result['discountCode'] ?? '')
                      .toString();
                  final discountAmount = (result['discountAmount'] ?? 0)
                      .toString();
                  final subtotal = (result['subtotal'] ?? 0).toString();
                  final message =
                      'Purchased ${result['packSize']} credits. Subtotal: $subtotal, Total: ${result['finalAmount']}.'
                      '${discountCode.isEmpty ? '' : ' Applied discount code: $discountCode (-$discountAmount).'}';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(message),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.studentCoachingAssignment),
                icon: const Icon(Icons.apartment),
                label: const Text('Request Coaching Assignment'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.studentArchive),
                icon: const Icon(Icons.history),
                label: const Text('View Test History'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachingStatusCard extends StatelessWidget {
  const _CoachingStatusCard({required this.coachingFormData});

  final CoachingAssignmentFormData? coachingFormData;

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Assigned';
      case 'rejected':
        return 'Request Rejected';
      case 'pending':
        return 'Request Pending';
      default:
        return 'Independent';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.hourglass_top;
      default:
        return Icons.apartment;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (coachingFormData == null) {
      return const SizedBox.shrink();
    }

    final assignment = coachingFormData!.assignment;
    final statusText = assignment.currentRequest?.status ?? '';
    final statusLabel = _statusLabel(statusText);
    final statusColor = _statusColor(statusText);
    final statusIcon = _statusIcon(statusText);

    return SectionCard(
      title: 'Coaching Status',
      icon: Icons.school,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (assignment.activeCoachingId != null)
                      Text(
                        'Coaching Center: ${assignment.activeCoaching?.name ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (assignment.currentRequest != null &&
              assignment.currentRequest!.decisionNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Note: ${assignment.currentRequest!.decisionNote}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          if (assignment.activeCoaching != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (assignment.activeCoaching!.address.isNotEmpty)
                    Text(
                      'Address: ${assignment.activeCoaching!.address}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (assignment.activeCoaching!.contactEmail.isNotEmpty)
                    Text(
                      'Email: ${assignment.activeCoaching!.contactEmail}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (assignment.activeCoaching!.contactPhone.isNotEmpty)
                    Text(
                      'Phone: ${assignment.activeCoaching!.contactPhone}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Manage Coaching'),
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AppRoutes.studentCoachingAssignment),
            ),
          ),
        ],
      ),
    );
  }
}
