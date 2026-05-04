import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/controllers/teacher_dashboard_controller.dart';
import 'package:cse470_app/models/teacher_models.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeacherDashboardView extends ConsumerStatefulWidget {
  const TeacherDashboardView({super.key});

  @override
  ConsumerState<TeacherDashboardView> createState() =>
      _TeacherDashboardViewState();
}

class _TeacherDashboardViewState extends ConsumerState<TeacherDashboardView> {
  late final TeacherDashboardController _teacherController;

  @override
  void initState() {
    super.initState();
    _teacherController = ref.read(teacherDashboardControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _teacherController.load();
      _teacherController.startQueueRefresh();
    });
  }

  @override
  void dispose() {
    _teacherController.stopQueueRefresh();
    super.dispose();
  }

  Future<void> _requestPayoutDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Request Payout'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Requested Reward Credits',
                hintText: 'Example: 12',
              ),
              validator: (value) {
                final number = double.tryParse((value ?? '').trim());
                if (number == null || number <= 0) {
                  return 'Enter a valid positive number';
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (ok != true || !context.mounted) {
      return;
    }

    final amount = double.parse(controller.text.trim());
    final success = await _teacherController.requestPayout(
      requestedRewardCredits: amount,
    );

    if (!context.mounted) {
      return;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Payout request submitted successfully.'
              : 'Could not submit payout request.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _claimRequest(String requestId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final result = await _teacherController.claimRequest(requestId);

    if (!context.mounted) {
      return;
    }

    final latestState = ref.read(teacherDashboardControllerProvider);

    String message;
    Color color;
    switch (result) {
      case TeacherClaimResult.success:
        message = 'Evaluation request claimed.';
        color = Colors.green;
        break;
      case TeacherClaimResult.conflict:
        message =
            'Unable to claim. It was already claimed by another teacher. Queue refreshed.';
        color = Colors.orange;
        break;
      case TeacherClaimResult.failure:
        message =
            latestState.errorMessage ??
            'Unable to claim this request right now.';
        color = Colors.red;
        break;
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _openReviewDetail(String requestId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.teacherReviewDetail, arguments: requestId);
    if (!mounted) {
      return;
    }
    if (result == true) {
      await _teacherController.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final state = ref.watch(teacherDashboardControllerProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teacher Dashboard'),
          actions: <Widget>[
            IconButton(
              onPressed: () => _teacherController.load(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh queue',
            ),
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
          bottom: TabBar(
            tabs: <Tab>[
              Tab(text: 'Pending (${state.pendingRequests.length})'),
              Tab(text: 'Claimed (${state.claimedRequests.length})'),
              Tab(text: 'Reviewed (${state.reviewedRequests.length})'),
            ],
          ),
        ),
        body: AsyncView(
          isLoading: state.isLoading,
          errorMessage: state.errorMessage,
          onRetry: () => _teacherController.load(),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SectionCard(
                  title: 'Teacher Workspace',
                  icon: Icons.person,
                  child: Column(
                    children: <Widget>[
                      InfoRow(
                        label: 'Name',
                        value: auth.currentUser?.name ?? 'Teacher',
                        icon: Icons.badge,
                      ),
                      InfoRow(
                        label: 'Reward Credits',
                        value:
                            state.profile?.rewardCredits.toStringAsFixed(1) ??
                            '0',
                        icon: Icons.stars,
                      ),
                      InfoRow(
                        label: 'Pending Requests',
                        value: '${state.pendingRequests.length}',
                        icon: Icons.hourglass_top,
                      ),
                      InfoRow(
                        label: 'Claimed Requests',
                        value: '${state.claimedRequests.length}',
                        icon: Icons.assignment_turned_in,
                      ),
                      InfoRow(
                        label: 'Payout Requests',
                        value: '${state.payoutRequests.length}',
                        icon: Icons.payments,
                      ),
                      const SizedBox(height: 8),
                      SecondaryButton(
                        label: state.isSubmitting
                            ? 'Submitting...'
                            : 'Request Payout (Prototype)',
                        icon: Icons.account_balance_wallet,
                        isEnabled: !state.isSubmitting,
                        onPressed: () async {
                          // make prototype nature explicit before opening dialog
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Prototype Feature'),
                              content: const Text(
                                'Payout requests are a prototype for this demo. They may be unavailable in this deployment.\n\nDo you want to continue?',
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
                          if (confirm == true) {
                            await _requestPayoutDialog();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _RequestListView(
                      items: state.pendingRequests,
                      emptyTitle: 'No Pending Requests',
                      emptyMessage:
                          'New eligible evaluation requests will appear here.',
                      actionLabel: state.isSubmitting ? 'Claiming...' : 'Claim',
                      actionIcon: Icons.lock_open,
                      actionEnabled: !state.isSubmitting,
                      onAction: (item) => _claimRequest(item.id),
                    ),
                    _RequestListView(
                      items: state.claimedRequests,
                      emptyTitle: 'No Claimed Requests',
                      emptyMessage:
                          'Claim a request from pending queue to review it.',
                      actionLabel: 'Open Review',
                      actionIcon: Icons.rate_review,
                      actionEnabled: true,
                      onAction: (item) => _openReviewDetail(item.id),
                    ),
                    _ReviewedListView(
                      requests: state.reviewedRequests,
                      payouts: state.payoutRequests,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestListView extends StatelessWidget {
  const _RequestListView({
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.actionLabel,
    required this.actionIcon,
    required this.actionEnabled,
    required this.onAction,
  });

  final List<EvaluationRequestModel> items;
  final String emptyTitle;
  final String emptyMessage;
  final String actionLabel;
  final IconData actionIcon;
  final bool actionEnabled;
  final ValueChanged<EvaluationRequestModel> onAction;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyStateView(
        title: emptyTitle,
        message: emptyMessage,
        icon: Icons.inbox,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.section.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                InfoRow(label: 'Status', value: item.status, icon: Icons.flag),
                InfoRow(
                  label: 'Source',
                  value: item.sourceType,
                  icon: Icons.account_tree,
                ),
                InfoRow(
                  label: 'Session ID',
                  value: item.testSessionId,
                  icon: Icons.fingerprint,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SecondaryButton(
                    label: actionLabel,
                    icon: actionIcon,
                    fullWidth: false,
                    isEnabled: actionEnabled,
                    onPressed: () => onAction(item),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReviewedListView extends StatelessWidget {
  const _ReviewedListView({required this.requests, required this.payouts});

  final List<EvaluationRequestModel> requests;
  final List<TeacherPayoutRequestModel> payouts;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty && payouts.isEmpty) {
      return const EmptyStateView(
        title: 'No Completed Reviews Yet',
        message: 'Reviewed items and payout history will appear here.',
        icon: Icons.history,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (requests.isNotEmpty)
          SectionCard(
            title: 'Completed Reviews',
            icon: Icons.verified,
            child: Column(
              children: requests
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.assignment_turned_in),
                      title: Text(
                        '${item.section.toUpperCase()} â€¢ Band ${item.reviewedBandScore?.toStringAsFixed(1) ?? '-'}',
                      ),
                      subtitle: Text(item.reviewComments ?? 'No comment'),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 12),
        if (payouts.isNotEmpty)
          SectionCard(
            title: 'Payout History',
            icon: Icons.payments,
            child: Column(
              children: payouts
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text(
                        '${item.requestedRewardCredits.toStringAsFixed(1)} credits -> ${item.payoutAmount.toStringAsFixed(1)} ${item.currency}',
                      ),
                      subtitle: Text('Status: ${item.status}'),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
