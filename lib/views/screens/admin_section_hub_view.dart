import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'admin_exam_workspace_view.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSectionHubView extends ConsumerWidget {
  const AdminSectionHubView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authController = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Platform Admin Sections'),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await authController.logout();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: AdminDashboardSection.values.map((section) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SectionCard(
              title: section.title,
              icon: section.icon,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Open ${section.title.toLowerCase()} in a dedicated screen.',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminExamWorkspaceView(section: section),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
