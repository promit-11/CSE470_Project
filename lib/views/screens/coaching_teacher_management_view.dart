import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/views/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachingTeacherManagementView extends ConsumerWidget {
  const CoachingTeacherManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instituteControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Teacher Management'),
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Assign Approved Teacher',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.availableTeachers.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No approved teachers available for assignment.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select Teacher',
                            hintText: 'Choose an approved teacher',
                          ),
                          items: state.availableTeachers
                              .map(
                                (teacher) => DropdownMenuItem<String>(
                                  value: teacher.id,
                                  child: Text(
                                    '${teacher.name} (${teacher.email})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: state.isWorking
                              ? null
                              : (value) async {
                                  if (value == null || value.isEmpty) return;
                                  await ref
                                      .read(
                                        instituteControllerProvider.notifier,
                                      )
                                      .assignTeacher(value);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        state.errorMessage ??
                                            'Teacher assigned successfully.',
                                      ),
                                      backgroundColor:
                                          state.errorMessage == null
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  );
                                },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Assigned Teachers',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (state.teachers.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No teachers assigned yet.',
                            style: TextStyle(color: Colors.blue),
                          ),
                        )
                      else
                        ...state.teachers.map((teacherProfile) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    teacherProfile.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(teacherProfile.name),
                              subtitle: Text(teacherProfile.email),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove),
                                onPressed: state.isWorking
                                    ? null
                                    : () async {
                                        await ref
                                            .read(
                                              instituteControllerProvider
                                                  .notifier,
                                            )
                                            .removeTeacher(
                                              teacherProfile.teacherUserId,
                                            );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              state.errorMessage ??
                                                  'Teacher removed successfully.',
                                            ),
                                            backgroundColor:
                                                state.errorMessage == null
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );
                                      },
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
