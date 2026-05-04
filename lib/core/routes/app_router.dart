import 'package:cse470_app/core/routes/app_routes.dart';
import 'package:cse470_app/views/screens/admin_section_hub_view.dart';
import 'package:cse470_app/views/screens/exam_session_view.dart';
import 'package:cse470_app/views/screens/institute_dashboard_view.dart';
import 'package:cse470_app/views/screens/login_view.dart';
import 'package:cse470_app/views/screens/register_view.dart';
import 'package:cse470_app/views/screens/result_summary_view.dart';
import 'package:cse470_app/views/screens/splash_view.dart';
import 'package:cse470_app/views/screens/student_archive_view.dart';
import 'package:cse470_app/views/screens/student_coaching_assignment_view.dart';
import 'package:cse470_app/views/screens/student_dashboard_view.dart';
import 'package:cse470_app/views/screens/teacher_dashboard_view.dart';
import 'package:cse470_app/views/screens/teacher_pending_approval_view.dart';
import 'package:cse470_app/views/screens/teacher_review_detail_view.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return MaterialPageRoute<void>(builder: (_) => const SplashView());
      case AppRoutes.login:
        return MaterialPageRoute<void>(builder: (_) => const LoginView());
      case AppRoutes.register:
        return MaterialPageRoute<void>(builder: (_) => const RegisterView());
      case AppRoutes.studentDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const StudentDashboardView(),
        );
      case AppRoutes.studentArchive:
        return MaterialPageRoute<void>(
          builder: (_) => const StudentArchiveView(),
        );
      case AppRoutes.studentCoachingAssignment:
        return MaterialPageRoute<void>(
          builder: (_) => const StudentCoachingAssignmentView(),
        );
      case AppRoutes.studentExam:
        return MaterialPageRoute<void>(builder: (_) => const ExamSessionView());
      case AppRoutes.studentResult:
        return MaterialPageRoute<void>(
          builder: (_) => const ResultSummaryView(),
        );
      case AppRoutes.teacherPendingApproval:
        return MaterialPageRoute<void>(
          builder: (_) => TeacherPendingApprovalView(
            email: (settings.arguments as String?) ?? '',
          ),
        );
      case AppRoutes.teacherDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const TeacherDashboardView(),
        );
      case AppRoutes.teacherReviewDetail:
        return MaterialPageRoute<void>(
          builder: (_) => TeacherReviewDetailView(
            evaluationRequestId: (settings.arguments as String?) ?? '',
          ),
        );
      case AppRoutes.coachingDashboard:
        return MaterialPageRoute<void>(
          builder: (_) => const InstituteDashboardView(),
        );
      case AppRoutes.adminExams:
        return MaterialPageRoute<void>(
          builder: (_) => const AdminSectionHubView(),
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
