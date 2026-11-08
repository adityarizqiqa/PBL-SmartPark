import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../utils/area_label.dart';

/// Identitas yang tampil di layar petugas maupun pengawas.
class OfficerIdentity {
  const OfficerIdentity({
    required this.name,
    required this.roleLabel,
    required this.areaCode,
    required this.areaName,
    required this.isSupervisor,
  });

  final String name;
  final String roleLabel;

  /// Kode pos, mis. `POS-UTAMA`; kosong bila sesi belum punya lahan.
  final String areaCode;
  final String areaName;
  final bool isSupervisor;

  /// Kode pendek untuk lencana/ringkasan, mis. `POS-UTAMA`.
  String get shortLabel => areaCode.isEmpty ? areaName : areaCode;

  /// Label lengkap untuk judul, mis. `POS-UTAMA • Pos Parkir Utama`.
  String get fullLabel => areaCode.isEmpty ? areaName : '$areaCode • $areaName';

  /// `POS-UTAMA • Pos Parkir Utama` → `POS-UTAMA`
  static String codeOf(String label) => areaShortLabel(label);

  /// `POS-UTAMA • Pos Parkir Utama` → `Pos Parkir Utama`
  static String nameOf(String label) => areaFullLabel(label);
}

/// Membaca identitas dari sesi aktif. `null` berarti belum masuk.
final officerIdentityProvider = Provider<OfficerIdentity?>((ref) {
  final store = ref.watch(sessionStoreProvider);
  final name = store.officerName;
  if (name == null) return null;

  final areaName = store.areaName ?? '';
  return OfficerIdentity(
    name: name,
    roleLabel: store.isSupervisor ? 'Pengawas (SPV)' : 'Petugas Gerbang',
    areaCode: areaShortLabel(areaName),
    areaName: areaFullLabel(areaName),
    isSupervisor: store.isSupervisor,
  );
});