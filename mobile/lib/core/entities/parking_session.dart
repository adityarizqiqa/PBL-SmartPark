/// Ringkasan petugas penanggung jawab sebuah sesi.
class SessionOfficer {
  final int assignmentId;
  final int officerId;
  final String officerName;

  const SessionOfficer({
    required this.assignmentId,
    required this.officerId,
    required this.officerName,
  });

  factory SessionOfficer.fromJson(Map<String, dynamic> json) {
    return SessionOfficer(
      assignmentId: json['assignment_id'] as int,
      officerId: json['officer_id'] as int,
      officerName: json['officer_name'] as String,
    );
  }
}

class SessionEvent {
  final int id;
  final String eventType;
  final String? note;
  final String actorName;
  final DateTime? createdAt;

  const SessionEvent({
    required this.id,
    required this.eventType,
    required this.note,
    required this.actorName,
    required this.createdAt,
  });

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      id: json['id'] as int,
      eventType: json['event_type'] as String,
      note: json['note'] as String?,
      actorName: json['actor_name'] as String,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }
}

class SessionDetail {
  final int id;
  final String nim;
  final String plateIn;
  final String? plateOut;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String status;
  final String? matchMethod;
  final String? verificationNote;
  final String? plateInPhotoPath;
  final String? plateOutPhotoPath;
  final int areaId;
  final String areaName;
  final SessionOfficer checkedInBy;
  final SessionOfficer? checkedOutBy;
  final List<SessionEvent> events;

  const SessionDetail({
    required this.id,
    required this.nim,
    required this.plateIn,
    required this.plateOut,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.status,
    required this.matchMethod,
    required this.verificationNote,
    required this.plateInPhotoPath,
    required this.plateOutPhotoPath,
    required this.areaId,
    required this.areaName,
    required this.checkedInBy,
    required this.checkedOutBy,
    required this.events,
  });

  factory SessionDetail.fromJson(Map<String, dynamic> json) {
    return SessionDetail(
      id: json['id'] as int,
      nim: json['nim'] as String,
      plateIn: json['plate_in'] as String,
      plateOut: json['plate_out'] as String?,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      checkedOutAt: json['checked_out_at'] == null
          ? null
          : DateTime.parse(json['checked_out_at'] as String),
      status: json['status'] as String,
      matchMethod: json['match_method'] as String?,
      verificationNote: json['verification_note'] as String?,
      plateInPhotoPath: json['plate_in_photo_path'] as String?,
      plateOutPhotoPath: json['plate_out_photo_path'] as String?,
      areaId: json['area_id'] as int,
      areaName: json['area_name'] as String,
      checkedInBy: SessionOfficer.fromJson(
          (json['checked_in_by'] as Map).cast<String, dynamic>()),
      checkedOutBy: json['checked_out_by'] == null
          ? null
          : SessionOfficer.fromJson(
              (json['checked_out_by'] as Map).cast<String, dynamic>()),
      events: ((json['events'] as List?) ?? const [])
          .map((e) => SessionEvent.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
