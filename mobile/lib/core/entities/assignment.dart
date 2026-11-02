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
