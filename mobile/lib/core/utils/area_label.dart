/// `POS-UTAMA • Pos Parkir Utama` → `POS-UTAMA`.
/// Digunakan sebagai [areaShortLabel] untuk label lahan gabungan.
String areaShortLabel(String label) => _codeOf(label);

/// `POS-UTAMA • Pos Parkir Utama` → `Pos Parkir Utama`.
String areaFullLabel(String label) => _nameOf(label);

String _codeOf(String label) {
  if (!label.contains('•')) return label;
  return label.split('•').first.trim();
}

String _nameOf(String label) {
  if (!label.contains('•')) return label;
  return label.split('•').last.trim();
}