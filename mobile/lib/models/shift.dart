class Assignment {
  final int id;
  final int shiftId;
  final int officerId;
  final String officerName;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? leftNote;

  const Assignment({
    required this.id,
    required this.shiftId,
    required this.officerId,
    required this.officerName,
    required this.joinedAt,
    required this.leftAt,
    required this.leftNote,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: json['id'] as int,
      shiftId: json['shift_id'] as int,
      officerId: json['officer_id'] as int,
      officerName: json['officer_name'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] == null
          ? null
          : DateTime.parse(json['left_at'] as String),
      leftNote: json['left_note'] as String?,
    );
  }
}

class Shift {
  final int id;
  final int parkingAreaId;
  final String areaName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? endNote;
  final bool isOpen;
  final List<Assignment> assignments;

  const Shift({
    required this.id,
    required this.parkingAreaId,
    required this.areaName,
    required this.startedAt,
    required this.endedAt,
    required this.endNote,
    required this.isOpen,
    required this.assignments,
  });

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'] as int,
      parkingAreaId: json['parking_area_id'] as int,
      areaName: json['area_name'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      endNote: json['end_note'] as String?,
      isOpen: json['is_open'] as bool,
      assignments: ((json['assignments'] as List?) ?? const [])
          .map((e) => Assignment.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Respons `POST /api/shifts/join` — token penugasan jaga.
class ShiftLogin {
  final String token;
  final Assignment assignment;
  final Shift shift;

  const ShiftLogin({
    required this.token,
    required this.assignment,
    required this.shift,
  });

  factory ShiftLogin.fromJson(Map<String, dynamic> json) {
    return ShiftLogin(
      token: json['token'] as String,
      assignment:
          Assignment.fromJson((json['assignment'] as Map).cast<String, dynamic>()),
      shift: Shift.fromJson((json['shift'] as Map).cast<String, dynamic>()),
    );
  }
}
