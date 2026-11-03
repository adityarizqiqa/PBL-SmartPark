/// Format nama orang yang dipakai lintas fitur.
class NameFormats {
  const NameFormats._();

  /// `Budi Santoso` → `BS`; satu kata → huruf pertamanya.
  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final clean = parts.where((part) => part.isNotEmpty).toList();
    if (clean.isEmpty) return '?';
    if (clean.length == 1) return clean.first.substring(0, 1).toUpperCase();
    return (clean[0].substring(0, 1) + clean[1].substring(0, 1)).toUpperCase();
  }

  /// `Budi Santoso` → `Budi`.
  static String firstName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
