/// Baris daftar kendaraan yang masih parkir.
///
/// `durationMinutes` dihitung backend saat dibaca, bukan disimpan.
class ActiveVehicle {
  final int id;
  final String nim;
  final String plateIn;
  final DateTime checkedInAt;
  final int durationMinutes;
  final int areaId;
  final String areaName;
  final String checkedInBy;

  const ActiveVehicle({
    required this.id,
    required this.nim,
    required this.plateIn,
    required this.checkedInAt,
    required this.durationMinutes,
    required this.areaId,
    required this.areaName,
    required this.checkedInBy,
  });

  factory ActiveVehicle.fromJson(Map<String, dynamic> json) {
    return ActiveVehicle(
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
