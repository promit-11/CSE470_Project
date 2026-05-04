class CoachingCenterOption {
  const CoachingCenterOption({
    required this.id,
    required this.name,
    required this.description,
    required this.address,
    required this.contactEmail,
    required this.contactPhone,
  });

  final String id;
  final String name;
  final String description;
  final String address;
  final String contactEmail;
  final String contactPhone;

  factory CoachingCenterOption.fromJson(Map<String, dynamic> json) {
    return CoachingCenterOption(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      contactEmail: (json['contactEmail'] ?? '').toString(),
      contactPhone: (json['contactPhone'] ?? '').toString(),
    );
  }
}

class CoachingAssignmentPrefilled {
  const CoachingAssignmentPrefilled({
    required this.userId,
    required this.name,
    required this.email,
    required this.profileId,
    required this.coachingId,
    required this.studentMode,
  });

  final String userId;
  final String name;
  final String email;
  final String profileId;
  final String? coachingId;
  final String studentMode;

  factory CoachingAssignmentPrefilled.fromJson(Map<String, dynamic> json) {
    final user =
        (json['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final profile =
        (json['profile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    return CoachingAssignmentPrefilled(
      userId: (user['id'] ?? '').toString(),
      name: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      profileId: (profile['id'] ?? '').toString(),
      coachingId: profile['coachingId']?.toString(),
      studentMode: (profile['studentMode'] ?? 'independent').toString(),
    );
  }
}

class CoachingAssignmentRequestStatus {
  const CoachingAssignmentRequestStatus({
    required this.id,
    required this.status,
    required this.coachingId,
    required this.admissionCode,
    required this.createdAt,
    required this.resolvedAt,
    required this.decisionNote,
  });

  final String id;
  final String status;
  final String coachingId;
  final String admissionCode;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String decisionNote;

  factory CoachingAssignmentRequestStatus.fromJson(Map<String, dynamic> json) {
    return CoachingAssignmentRequestStatus(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      coachingId: (json['coachingId'] ?? '').toString(),
      admissionCode: (json['admissionCode'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      resolvedAt: DateTime.tryParse((json['resolvedAt'] ?? '').toString()),
      decisionNote: (json['decisionNote'] ?? '').toString(),
    );
  }
}

class StudentAssignmentStateInfo {
  const StudentAssignmentStateInfo({
    required this.hasActiveAssignment,
    required this.activeCoachingId,
    required this.pendingRequestId,
    required this.requestStatus,
    required this.currentRequest,
    required this.activeCoaching,
  });

  final bool hasActiveAssignment;
  final String? activeCoachingId;
  final String? pendingRequestId;
  final String? requestStatus;
  final CoachingAssignmentRequestStatus? currentRequest;
  final CoachingCenterOption? activeCoaching;

  factory StudentAssignmentStateInfo.fromJson(Map<String, dynamic> json) {
    final currentRequestJson = json['currentRequest'];
    final activeCoachingJson = json['activeCoaching'];

    return StudentAssignmentStateInfo(
      hasActiveAssignment: (json['hasActiveAssignment'] ?? false) as bool,
      activeCoachingId: json['activeCoachingId']?.toString(),
      pendingRequestId: json['pendingRequestId']?.toString(),
      requestStatus: json['requestStatus']?.toString(),
      currentRequest: currentRequestJson is Map<String, dynamic>
          ? CoachingAssignmentRequestStatus.fromJson(currentRequestJson)
          : null,
      activeCoaching: activeCoachingJson is Map<String, dynamic>
          ? CoachingCenterOption.fromJson(activeCoachingJson)
          : null,
    );
  }
}

class CoachingAssignmentFormData {
  const CoachingAssignmentFormData({
    required this.prefilled,
    required this.assignment,
    required this.coachings,
  });

  final CoachingAssignmentPrefilled prefilled;
  final StudentAssignmentStateInfo assignment;
  final List<CoachingCenterOption> coachings;

  factory CoachingAssignmentFormData.fromJson(Map<String, dynamic> json) {
    return CoachingAssignmentFormData(
      prefilled: CoachingAssignmentPrefilled.fromJson(
        (json['prefilled'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      assignment: StudentAssignmentStateInfo.fromJson(
        (json['assignment'] as Map<String, dynamic>?) ??
            const <String, dynamic>{},
      ),
      coachings: (json['coachings'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CoachingCenterOption.fromJson)
          .toList(),
    );
  }
}
