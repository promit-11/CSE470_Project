class AdminOverviewData {
  const AdminOverviewData({
    required this.students,
    required this.teachers,
    required this.coachings,
    required this.completedSessions,
    required this.pendingEvaluationRequests,
  });

  final int students;
  final int teachers;
  final int coachings;
  final int completedSessions;
  final int pendingEvaluationRequests;

  factory AdminOverviewData.fromJson(Map<String, dynamic> json) {
    return AdminOverviewData(
      students: (json['students'] as num?)?.toInt() ?? 0,
      teachers: (json['teachers'] as num?)?.toInt() ?? 0,
      coachings: (json['coachings'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      pendingEvaluationRequests:
          (json['pendingEvaluationRequests'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminTeacherSummary {
  const AdminTeacherSummary({
    required this.userId,
    required this.name,
    required this.email,
    required this.status,
    required this.approvalStatus,
    required this.coachingAssigned,
    required this.rewardCredits,
    required this.createdAt,
  });

  final String userId;
  final String name;
  final String email;
  final String status;
  final String approvalStatus;
  final bool coachingAssigned;
  final double rewardCredits;
  final DateTime? createdAt;

  bool get isPendingApproval => approvalStatus == 'pending_approval';
  bool get isApproved => approvalStatus == 'approved';
  bool get isActive => status == 'active';

  factory AdminTeacherSummary.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    final profile =
        (json['teacherProfile'] as Map<String, dynamic>?) ?? const {};
    final coaching = (json['coaching'] as Map<String, dynamic>?) ?? const {};

    return AdminTeacherSummary(
      userId: (user['id'] ?? user['_id'] ?? '').toString(),
      name: (user['name'] ?? 'Unknown').toString(),
      email: (user['email'] ?? '').toString(),
      status: (user['status'] ?? '').toString(),
      approvalStatus: (user['approvalStatus'] ?? '').toString(),
      coachingAssigned: coaching.isNotEmpty,
      rewardCredits: ((profile['rewardCredits'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.tryParse((user['createdAt'] ?? '').toString()),
    );
  }
}

class AdminPayoutRequestSummary {
  const AdminPayoutRequestSummary({
    required this.id,
    required this.status,
    required this.teacherUserId,
    required this.teacherName,
    required this.teacherEmail,
    required this.rewardCredits,
    required this.estimatedAmount,
    required this.createdAt,
    required this.resolvedAt,
    required this.approvalNote,
    required this.rejectionReason,
  });

  final String id;
  final String status;
  final String teacherUserId;
  final String teacherName;
  final String teacherEmail;
  final double rewardCredits;
  final double estimatedAmount;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String approvalNote;
  final String rejectionReason;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory AdminPayoutRequestSummary.fromJson(Map<String, dynamic> json) {
    final teacher = (json['teacher'] as Map<String, dynamic>?) ?? const {};

    return AdminPayoutRequestSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      teacherUserId: (teacher['id'] ?? teacher['_id'] ?? '').toString(),
      teacherName: (teacher['name'] ?? 'Unknown').toString(),
      teacherEmail: (teacher['email'] ?? '').toString(),
      rewardCredits: ((json['rewardCredits'] as num?) ?? 0).toDouble(),
      estimatedAmount: ((json['estimatedAmount'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      resolvedAt: DateTime.tryParse((json['resolvedAt'] ?? '').toString()),
      approvalNote: (json['approvalNote'] ?? '').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
    );
  }
}
