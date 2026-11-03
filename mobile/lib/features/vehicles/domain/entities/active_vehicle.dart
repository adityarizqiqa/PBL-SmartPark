import '../../../../core/entities/parking_session.dart';

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

  /// Mengonversi objek kendaraan aktif menjadi objek sesi lengkap (`SessionDetail`)
  /// untuk diteruskan ke alur check-out tanpa memerlukan lookup ulang ke API.
  SessionDetail toSessionDetail() {
    return SessionDetail(
      id: id,
      nim: nim,
      plateIn: plateIn,
      plateOut: null,
      checkedInAt: checkedInAt,
      checkedOutAt: null,
      status: 'active',
      matchMethod: 'plate_exact',
      verificationNote: null,
      plateInPhotoPath: null,
      plateOutPhotoPath: null,
      areaId: areaId,
      areaName: areaName,
      checkedInBy: SessionOfficer(
        assignmentId: 0,
        officerId: 0,
        officerName: checkedInBy,
      ),
      checkedOutBy: null,
      events: const [],
    );
  }
}
