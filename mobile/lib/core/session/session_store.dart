import 'package:flutter/foundation.dart';

import '../entities/entities.dart';

/// Sumber token untuk header otomatis pada [ApiClient].
abstract class TokenProvider {
  String? get shiftToken;
  String? get officerToken;
}

/// Menyimpan token dan identitas sesi aktif selama aplikasi berjalan.
///
/// Instance tunggal disediakan lewat `sessionStoreProvider`; kelas ini tidak
/// memakai singleton statis agar dapat diganti pada pengujian. Sebagai
/// [ChangeNotifier], perubahan peran bisa memicu pengalihan rute.
class SessionStore extends ChangeNotifier implements TokenProvider {
  /// Token penugasan jaga (`X-Shift-Token`) untuk operasi sesi parkir.
  @override
  String? shiftToken;

  /// Token sesi petugas (`X-Officer-Token`) untuk operasi pengelolaan SPV.
  @override
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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
  }
}
