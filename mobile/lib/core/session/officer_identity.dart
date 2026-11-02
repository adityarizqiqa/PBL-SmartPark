import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

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

  /// `POS-UTAMA • Pos Parkir Utama`
  String get areaLabel => areaCode.isEmpty ? areaName : '$areaCode • $areaName';
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
    areaCode: _codeOf(areaName),
    areaName: _nameOf(areaName),
    isSupervisor: store.isSupervisor,
  );
});

/// `POS-UTAMA • Pos Parkir Utama` → `POS-UTAMA`
String _codeOf(String label) {
  if (!label.contains('•')) return label;
  return label.split('•').first.trim();
}

/// `POS-UTAMA • Pos Parkir Utama` → `Pos Parkir Utama`
String _nameOf(String label) {
  if (!label.contains('•')) return label;
  return label.split('•').last.trim();
}
