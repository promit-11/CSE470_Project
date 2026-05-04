import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/widgets/ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeacherPendingApprovalView extends ConsumerWidget {
  const TeacherPendingApprovalView({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Approval Pending')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SectionCard(
              title: 'Teacher Account Under Review',
              icon: Icons.pending_actions,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Your teacher account is pending platform approval.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email.isEmpty
                        ? 'You will be able to sign in once approval is complete.'
                        : 'Account: $email\nYou will be able to sign in once approval is complete.',
                  ),
                  const SizedBox(height: 16),
                  SecondaryButton(
                    label: 'Back To Login',
                    icon: Icons.login,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Clear Session'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



