// Coaching admin dashboard hub.
// File name retains the legacy institute label for compatibility.
import 'package:cse470_app/controllers/providers.dart';
import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/screens/coaching_profile_view.dart';
import 'package:cse470_app/views/screens/coaching_student_requests_view.dart';
import 'package:cse470_app/views/screens/coaching_students_view.dart';
import 'package:cse470_app/views/screens/coaching_teacher_management_view.dart';
import 'package:cse470_app/views/screens/coaching_content_management_view.dart';
import 'package:cse470_app/views/screens/coaching_evaluation_activity_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InstituteDashboardView extends ConsumerStatefulWidget {
  const InstituteDashboardView({super.key});

  @override
  ConsumerState<InstituteDashboardView> createState() =>
      _InstituteDashboardViewState();
}

class _InstituteDashboardViewState
    extends ConsumerState<InstituteDashboardView> {
  late final dynamic _instituteController;
  late final dynamic _authController;

  Future<void> _openManaged(Widget screen) async {
    _instituteController.stopQueueRefresh();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => screen));
    if (!context.mounted) return;
    _instituteController.startQueueRefresh();
    await _instituteController.load(showLoader: false);
  }

  @override
  void initState() {
    super.initState();
    _instituteController = ref.read(instituteControllerProvider.notifier);
    _authController = ref.read(authControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _instituteController.load(force: true);
      _instituteController.startQueueRefresh();
    });
  }

  @override
  void dispose() {
    _instituteController.stopQueueRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(instituteControllerProvider);
    final pendingAssignmentCount = state.assignmentRequests
        .where((request) => request.status == 'pending')
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Coaching Center Dashboard'),
        actions: <Widget>[
          if (pendingAssignmentCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Chip(
                avatar: const Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                ),
                label: Text('$pendingAssignmentCount pending'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            onPressed: () => _instituteController.load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () async {
              await _authController.logout();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _instituteController.load(),
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
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (state.profile?['name'] ?? 'Coaching Center').toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: <Widget>[
                _DashboardStatCard(
                  label: 'Pending Requests',
                  count: pendingAssignmentCount,
                  icon: Icons.assignment_late,
                  color: Colors.orange,
                ),
                _DashboardStatCard(
                  label: 'Students',
                  count: state.students.length,
                  icon: Icons.groups,
                  color: Colors.blue,
                ),
                _DashboardStatCard(
                  label: 'Teachers',
                  count: state.teachers.length,
                  icon: Icons.school,
                  color: Colors.purple,
                ),
                _DashboardStatCard(
                  label: 'Content Items',
                  count:
                      state.exams.length +
                      state.questions.length +
                      state.templates.length,
                  icon: Icons.library_books,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Manage',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _NavigationTile(
              title: 'Coaching Profile',
              subtitle: 'Edit center information',
              icon: Icons.apartment,
              onTap: () => _openManaged(const CoachingProfileView()),
            ),
            const SizedBox(height: 8),
            _NavigationTile(
              title: 'Student Assignment Requests',
              subtitle: '$pendingAssignmentCount pending',
              icon: Icons.assignment,
              badgeCount: pendingAssignmentCount > 0
                  ? pendingAssignmentCount
                  : null,
              onTap: () => _openManaged(const CoachingStudentRequestsView()),
            ),
            const SizedBox(height: 8),
            _NavigationTile(
              title: 'Coaching Students',
              subtitle: '${state.students.length} students',
              icon: Icons.groups,
              onTap: () => _openManaged(const CoachingStudentsView()),
            ),
            const SizedBox(height: 8),
            _NavigationTile(
              title: 'Teacher Management',
              subtitle: '${state.teachers.length} assigned teachers',
              icon: Icons.school,
              onTap: () => _openManaged(const CoachingTeacherManagementView()),
            ),
            const SizedBox(height: 8),
            _NavigationTile(
              title: 'Content Management',
              subtitle:
                  '${state.exams.length + state.questions.length + state.templates.length} items',
              icon: Icons.library_books,
              onTap: () => _openManaged(const CoachingContentManagementView()),
            ),
            const SizedBox(height: 8),
            _NavigationTile(
              title: 'Evaluation Activity',
              subtitle: 'Monitor student evaluations',
              icon: Icons.monitor_heart,
              onTap: () => _openManaged(const CoachingEvaluationActivityView()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeCount,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: badgeCount != null && badgeCount! > 0
            ? Chip(
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
              )
            : const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
