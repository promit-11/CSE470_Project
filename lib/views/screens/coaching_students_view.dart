import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingStudentsView extends ConsumerWidget {
  const CoachingStudentsView({super.key});

  Future<void> _removeStudent(
    BuildContext context,
    WidgetRef ref,
    String studentUserId,
    String studentName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Student'),
          content: Text(
            'Remove $studentName from this coaching? They will still be able to use app-owned exams if they have credits.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await ref
        .read(instituteControllerProvider.notifier)
        .removeStudent(studentUserId);

    if (!context.mounted) {
      return;
    }

    final latest = ref.read(instituteControllerProvider);
    final hasError =
        latest.errorMessage != null && latest.errorMessage!.isNotEmpty;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasError
              ? latest.errorMessage!
              : '$studentName removed from coaching.',
        ),
        backgroundColor: hasError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instituteControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Coaching Students'),
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
        child: state.students.isEmpty
            ? const EmptyStateView(
                title: 'No Students',
                message: 'Accepted and verified students will appear here.',
                icon: Icons.group_outlined,
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(instituteControllerProvider.notifier).load(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  itemCount: state.students.length,
                  itemBuilder: (context, index) {
                    final student = state.students[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              student.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          student.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 4),
                            Text(student.email),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Colors.red,
                          ),
                          tooltip: 'Remove student from coaching',
                          onPressed: () => _removeStudent(
                            context,
                            ref,
                            student.userId,
                            student.name,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}



