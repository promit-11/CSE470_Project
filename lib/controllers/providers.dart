import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cse470_app/controllers/admin_dashboard_controller.dart';
import 'package:cse470_app/controllers/auth_controller.dart';
import 'package:cse470_app/controllers/exam_session_controller.dart';
import 'package:cse470_app/controllers/institute_controller.dart';
import 'package:cse470_app/controllers/student_coaching_assignment_controller.dart';
import 'package:cse470_app/controllers/student_archive_controller.dart';
import 'package:cse470_app/controllers/student_dashboard_controller.dart';
import 'package:cse470_app/controllers/teacher_dashboard_controller.dart';
import 'package:cse470_app/core/services/admin_service.dart';
import 'package:cse470_app/core/services/api_client.dart';
import 'package:cse470_app/core/services/auth_service.dart';
import 'package:cse470_app/core/services/institute_service.dart';
import 'package:cse470_app/core/services/mock_service.dart';
import 'package:cse470_app/core/services/student_service.dart';
import 'package:cse470_app/core/services/teacher_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final studentServiceProvider = Provider<StudentService>((ref) {
  return StudentService(ref.read(apiClientProvider));
});

final mockServiceProvider = Provider<MockService>((ref) {
  return MockService(ref.read(apiClientProvider));
});

final instituteServiceProvider = Provider<InstituteService>((ref) {
  return InstituteService(ref.read(apiClientProvider));
});

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(ref.read(apiClientProvider));
});

final teacherServiceProvider = Provider<TeacherService>((ref) {
  return TeacherService(ref.read(apiClientProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    return AuthController(
      ref.read(authServiceProvider),
      ref.read(apiClientProvider),
    );
  },
);

final studentDashboardControllerProvider =
    StateNotifierProvider<StudentDashboardController, StudentDashboardState>((
      ref,
    ) {
      return StudentDashboardController(ref.read(studentServiceProvider));
    });

final studentArchiveControllerProvider =
    StateNotifierProvider<StudentArchiveController, StudentArchiveState>((ref) {
      return StudentArchiveController(ref.read(studentServiceProvider));
    });

final studentCoachingAssignmentControllerProvider =
    StateNotifierProvider<
      StudentCoachingAssignmentController,
      StudentCoachingAssignmentState
    >((ref) {
      return StudentCoachingAssignmentController(
        ref.read(studentServiceProvider),
      );
    });

final examSessionControllerProvider =
    StateNotifierProvider<ExamSessionController, ExamSessionState>((ref) {
      return ExamSessionController(ref.read(mockServiceProvider));
    });

final instituteControllerProvider =
    StateNotifierProvider<InstituteController, InstituteState>((ref) {
      return InstituteController(ref.read(instituteServiceProvider));
    });

final adminDashboardControllerProvider =
    StateNotifierProvider<AdminDashboardController, AdminDashboardState>((ref) {
      return AdminDashboardController(ref.read(adminServiceProvider));
    });

final teacherDashboardControllerProvider =
    StateNotifierProvider<TeacherDashboardController, TeacherDashboardState>((
      ref,
    ) {
      return TeacherDashboardController(ref.read(teacherServiceProvider));
    });
