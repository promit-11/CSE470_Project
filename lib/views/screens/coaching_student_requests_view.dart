import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingStudentRequestsView extends ConsumerStatefulWidget {
  const CoachingStudentRequestsView({super.key});

  @override
  ConsumerState<CoachingStudentRequestsView> createState() => _CoachingStudentRequestsViewState();
}

class _CoachingStudentRequestsViewState extends ConsumerState<CoachingStudentRequestsView> {
  final _assignmentNote = TextEditingController();

  @override
  void dispose() {
    _assignmentNote.dispose();
    super.dispose();
  }

  void _showActionFeedback() {
    final latest = ref.read(instituteControllerProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          latest.errorMessage == null
              ? 'Request processed successfully.'
              : latest.errorMessage!,
        ),
        backgroundColor: latest.errorMessage == null
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instituteControllerProvider);
    final pendingCount = state.assignmentRequests
        .where((request) => request.status == 'pending')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Student Assignment Requests'),
        actions: <Widget>[
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Chip(
                avatar: const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                ),
                label: Text('$pendingCount pending'),
                visualDensity: VisualDensity.compact,
              ),
            ),
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
        child: state.assignmentRequests.isEmpty
            ? const EmptyStateView(
                title: 'No Assignment Requests',
                message: 'Incoming student coaching requests will appear here.',
                icon: Icons.assignment_late,
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(instituteControllerProvider.notifier).load(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  children: <Widget>[
                    ...state.assignmentRequests.map((request) {
                      final canProcess = request.isPending;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    canProcess
                                        ? Icons.schedule
                                        : Icons.done_all,
                                    color: canProcess
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          request.studentName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          request.studentEmail,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Chip(
                                    label: Text(request.status),
                                    backgroundColor: canProcess
                                        ? Colors.orange.shade100
                                        : Colors.green.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              InfoRow(
                                label: 'Admission Code',
                                value: request.admissionCode,
                                icon: Icons.card_giftcard,
                              ),
                              const SizedBox(height: 8),
                              if (canProcess) ...[
                                const Text(
                                  'Add optional note for your decision',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _assignmentNote,
                                  decoration: InputDecoration(
                                    hintText: 'Your note...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: state.isWorking
                                            ? null
                                            : () async {
                                                await ref
                                                    .read(
                                                      instituteControllerProvider
                                                          .notifier,
                                                    )
                                                    .acceptAssignmentRequest(
                                                      request.id,
                                                      note: _assignmentNote.text
                                                          .trim(),
                                                    );
                                                if (!mounted) return;
                                                _assignmentNote.clear();
                                                _showActionFeedback();
                                              },
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: state.isWorking
                                            ? null
                                            : () async {
                                                await ref
                                                    .read(
                                                      instituteControllerProvider
                                                          .notifier,
                                                    )
                                                    .rejectAssignmentRequest(
                                                      request.id,
                                                      note: _assignmentNote.text
                                                          .trim(),
                                                    );
                                                if (!mounted) return;
                                                _assignmentNote.clear();
                                                _showActionFeedback();
                                              },
                                        icon: const Icon(Icons.cancel),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
      ),
    );
  }
}




