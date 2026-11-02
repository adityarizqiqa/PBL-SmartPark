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
