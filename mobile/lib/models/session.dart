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

/// Baris daftar kendaraan yang masih parkir.
class ActiveSession {
  final int id;
  final String nim;
  final String plateIn;
  final DateTime checkedInAt;
  final int durationMinutes;
  final int areaId;
  final String areaName;
  final String checkedInBy;

  const ActiveSession({
    required this.id,
    required this.nim,
    required this.plateIn,
    required this.checkedInAt,
    required this.durationMinutes,
    required this.areaId,
    required this.areaName,
    required this.checkedInBy,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['id'] as int,
      nim: json['nim'] as String,
      plateIn: json['plate_in'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      durationMinutes: json['duration_minutes'] as int,
      areaId: json['area_id'] as int,
      areaName: json['area_name'] as String,
      checkedInBy: json['checked_in_by'] as String,
    );
  }
}

class HistoryItem {
  final int id;
  final String nim;
  final String plateIn;
  final String? plateOut;
  final DateTime checkedInAt;
  final DateTime? checkedOutAt;
  final String status;
  final String? verificationNote;

  const HistoryItem({
    required this.id,
    required this.nim,
    required this.plateIn,
    required this.plateOut,
    required this.checkedInAt,
    required this.checkedOutAt,
    required this.status,
    required this.verificationNote,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as int,
      nim: json['nim'] as String,
      plateIn: json['plate_in'] as String,
      plateOut: json['plate_out'] as String?,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      checkedOutAt: json['checked_out_at'] == null
          ? null
          : DateTime.parse(json['checked_out_at'] as String),
      status: json['status'] as String,
      verificationNote: json['verification_note'] as String?,
    );
  }
}

class Dashboard {
  final int activeNow;
  final int checkedInToday;
  final int checkedOutToday;
  final List<SessionDetail> recent;

  const Dashboard({
    required this.activeNow,
    required this.checkedInToday,
    required this.checkedOutToday,
    required this.recent,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      activeNow: json['active_now'] as int,
      checkedInToday: json['checked_in_today'] as int,
      checkedOutToday: json['checked_out_today'] as int,
      recent: ((json['recent'] as List?) ?? const [])
          .map((e) => SessionDetail.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Kandidat yang ditampilkan saat pencarian tidak eksak.
class LookupCandidate {
  final int sessionId;
  final String plateIn;
  final DateTime checkedInAt;
  final String areaName;

  const LookupCandidate({
    required this.sessionId,
    required this.plateIn,
    required this.checkedInAt,
    required this.areaName,
  });

  factory LookupCandidate.fromJson(Map<String, dynamic> json) {
    return LookupCandidate(
      sessionId: json['session_id'] as int,
      plateIn: json['plate_in'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      areaName: json['area_name'] as String,
    );
  }
}

/// Hasil pencarian sesi aktif saat check-out.
class LookupResult {
  final String? matchMethod;
  final SessionDetail? session;
  final List<LookupCandidate> candidates;
  final String? message;

  const LookupResult({
    required this.matchMethod,
    required this.session,
    required this.candidates,
    required this.message,
  });

  factory LookupResult.fromJson(Map<String, dynamic> json) {
    return LookupResult(
      matchMethod: json['match_method'] as String?,
      session: json['session'] == null
          ? null
          : SessionDetail.fromJson(
              (json['session'] as Map).cast<String, dynamic>()),
      candidates: ((json['candidates'] as List?) ?? const [])
          .map((e) =>
              LookupCandidate.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      message: json['message'] as String?,
    );
  }
}
