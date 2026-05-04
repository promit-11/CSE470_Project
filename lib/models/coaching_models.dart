class CoachingStudentSummary {
  const CoachingStudentSummary({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.verifiedByInstitute,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final bool verifiedByInstitute;

  factory CoachingStudentSummary.fromJson(Map<String, dynamic> json) {
    final user =
        json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return CoachingStudentSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      name: (user['name'] ?? 'Unknown').toString(),
      email: (user['email'] ?? '').toString(),
      verifiedByInstitute: (json['verifiedByInstitute'] ?? false) == true,
    );
  }
}

class CoachingAssignmentRequestSummary {
  const CoachingAssignmentRequestSummary({
    required this.id,
    required this.status,
    required this.admissionCode,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.createdAt,
  });

  final String id;
  final String status;
  final String admissionCode;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  factory CoachingAssignmentRequestSummary.fromJson(Map<String, dynamic> json) {
    final student =
        json['student'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return CoachingAssignmentRequestSummary(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      admissionCode: (json['admissionCode'] ?? '').toString(),
      studentId: (student['id'] ?? student['_id'] ?? '').toString(),
      studentName: (student['name'] ?? 'Student').toString(),
      studentEmail: (student['email'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class CoachingTeacherSummary {
  const CoachingTeacherSummary({
    required this.teacherUserId,
    required this.name,
    required this.email,
    required this.approvalStatus,
    required this.accountStatus,
    required this.rewardCredits,
    required this.expertiseTags,
  });

  final String teacherUserId;
  final String name;
  final String email;
  final String approvalStatus;
  final String accountStatus;
  final double rewardCredits;
  final List<String> expertiseTags;

  factory CoachingTeacherSummary.fromJson(Map<String, dynamic> json) {
    final user =
        json['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final reward =
        (json['rewardCredits'] as num?) ??
        ((json['teacherProfile'] as Map<String, dynamic>?)?['rewardCredits']
            as num?) ??
        0;
    final tags =
        (json['expertiseTags'] as List<dynamic>?) ??
        ((json['teacherProfile'] as Map<String, dynamic>?)?['expertiseTags']
            as List<dynamic>?) ??
        const <dynamic>[];

    return CoachingTeacherSummary(
      teacherUserId: (user['_id'] ?? user['id'] ?? json['id'] ?? '').toString(),
      name: (user['name'] ?? json['name'] ?? 'Teacher').toString(),
      email: (user['email'] ?? json['email'] ?? '').toString(),
      approvalStatus: (user['approvalStatus'] ?? json['approvalStatus'] ?? '')
          .toString(),
      accountStatus: (user['status'] ?? json['status'] ?? '').toString(),
      rewardCredits: reward.toDouble(),
      expertiseTags: tags.map((e) => e.toString()).toList(),
    );
  }
}

class AvailableTeacherSummary {
  const AvailableTeacherSummary({
    required this.id,
    required this.name,
    required this.email,
    required this.approvalStatus,
    required this.status,
    required this.currentCoachingId,
    required this.isAssignable,
  });

  final String id;
  final String name;
  final String email;
  final String approvalStatus;
  final String status;
  final String? currentCoachingId;
  final bool isAssignable;

  factory AvailableTeacherSummary.fromJson(Map<String, dynamic> json) {
    return AvailableTeacherSummary(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Teacher').toString(),
      email: (json['email'] ?? '').toString(),
      approvalStatus: (json['approvalStatus'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      currentCoachingId: json['currentCoachingId']?.toString(),
      isAssignable: (json['isAssignable'] ?? false) == true,
    );
  }
}
