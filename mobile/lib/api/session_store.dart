import '../models/models.dart';

/// Menyimpan token dan identitas sesi aktif selama aplikasi berjalan.
///
/// Satu instance dipakai bersama (`SessionStore.instance`). `ApiClient`
/// membaca token dari sini untuk menyusun header otomatis.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  /// Token penugasan jaga (`X-Shift-Token`) untuk operasi sesi parkir.
  String? shiftToken;

  /// Token sesi petugas (`X-Officer-Token`) untuk operasi pengelolaan SPV.
  String? officerToken;

  int? officerId;
  String? officerName;

  /// `'officer'` atau `'spv'`.
  String? role;

  int? areaId;
  String? areaName;

  int? shiftId;
  int? assignmentId;

  bool get isSupervisor => role == 'spv';

  bool get hasShift => shiftToken != null;
  bool get hasOfficerSession => officerToken != null;

  /// Mengisi sesi setelah `POST /api/shifts/join`.
  ///
  /// `userRole` diisi dari data petugas pada layar masuk, karena respons
  /// join tidak memuat peran.
  void setShiftSession(ShiftLogin login, {String? userRole}) {
    shiftToken = login.token;
    assignmentId = login.assignment.id;
    shiftId = login.shift.id;
    officerId = login.assignment.officerId;
    officerName = login.assignment.officerName;
    areaId = login.shift.parkingAreaId;
    areaName = login.shift.areaName;
    if (userRole != null) role = userRole;
  }

  /// Mengisi sesi setelah `POST /api/auth/sign-in`.
  void setOfficerSession({
    required String token,
    required int id,
    required String name,
    required String userRole,
  }) {
    officerToken = token;
    officerId = id;
    officerName = name;
    role = userRole;
  }

  void clear() {
    shiftToken = null;
    officerToken = null;
    officerId = null;
    officerName = null;
    role = null;
    areaId = null;
    areaName = null;
    shiftId = null;
    assignmentId = null;
  }
}
