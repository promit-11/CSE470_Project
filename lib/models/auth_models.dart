enum UserRole { student, teacher, coachingAdmin, platformAdmin }

UserRole userRoleFromApi(String value) {
  switch (value) {
    case 'student':
      return UserRole.student;
    case 'teacher':
      return UserRole.teacher;
    case 'coaching_admin':
      return UserRole.coachingAdmin;
    case 'platform_admin':
      return UserRole.platformAdmin;
    default:
      return UserRole.student;
  }
}

String userRoleToApi(UserRole role) {
  switch (role) {
    case UserRole.student:
      return 'student';
    case UserRole.teacher:
      return 'teacher';
    case UserRole.coachingAdmin:
      return 'coaching_admin';
    case UserRole.platformAdmin:
      return 'platform_admin';
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.approvalStatus,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String status;
  final String approvalStatus;

  bool get isStudent => role == UserRole.student;
  bool get isTeacher => role == UserRole.teacher;
  bool get isCoachingAdmin => role == UserRole.coachingAdmin;
  bool get isPlatformAdmin => role == UserRole.platformAdmin;
  bool get isTeacherApproved => isTeacher && approvalStatus == 'approved';
  bool get isTeacherPendingApproval =>
      isTeacher && approvalStatus == 'pending_approval';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: userRoleFromApi((json['role'] ?? 'student').toString()),
      status: (json['status'] ?? 'active').toString(),
      approvalStatus: (json['approvalStatus'] ?? 'not_required').toString(),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;
}
