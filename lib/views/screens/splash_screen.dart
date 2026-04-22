import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cse470_app/controllers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _route();
    });
  }

  Future<void> _route() async {
    await ref.read(authControllerProvider.notifier).initialize();
    if (!mounted) {
      return;
    }
    final auth = ref.read(authControllerProvider);
    if (!auth.isAuthenticated || auth.currentUser == null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    if (auth.currentUser!.isStudent) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.studentDashboard);
      return;
    }
    if (auth.currentUser!.isTeacher) {
      if (!auth.currentUser!.isTeacherApproved) {
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.teacherPendingApproval,
          arguments: auth.currentUser!.email,
        );
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.teacherDashboard);
      }
      return;
    }
    if (auth.currentUser!.isCoachingAdmin) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.coachingDashboard);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.adminExams);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
