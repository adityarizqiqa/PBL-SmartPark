import 'parking_session.dart';

/// Kandidat yang ditampilkan saat pencarian tidak eksak.
class LookupCandidate {
  final int sessionId;
  final String plateIn;
  final DateTime checkedInAt;
  final String areaName;

  const LookupCandidate({
    required this.sessionId,
    required this.plateIn,
    required this.checkedInAt,
    required this.areaName,
  });

  factory LookupCandidate.fromJson(Map<String, dynamic> json) {
    return LookupCandidate(
      sessionId: json['session_id'] as int,
      plateIn: json['plate_in'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
      areaName: json['area_name'] as String,
    );
  }
}

/// Hasil pencarian sesi aktif saat check-out.
class LookupResult {
  final String? matchMethod;
  final SessionDetail? session;
  final List<LookupCandidate> candidates;
  final String? message;

  const LookupResult({
    required this.matchMethod,
    required this.session,
    required this.candidates,
    required this.message,
  });

  factory LookupResult.fromJson(Map<String, dynamic> json) {
    return LookupResult(
      matchMethod: json['match_method'] as String?,
      session: json['session'] == null
          ? null
          : SessionDetail.fromJson(
              (json['session'] as Map).cast<String, dynamic>()),
      candidates: ((json['candidates'] as List?) ?? const [])
          .map((e) =>
              LookupCandidate.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      message: json['message'] as String?,
    );
  }
}
