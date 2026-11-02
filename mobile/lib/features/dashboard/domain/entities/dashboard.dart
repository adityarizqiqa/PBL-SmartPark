import '../../../../core/entities/parking_session.dart';

class Dashboard {
  final int activeNow;
  final int checkedInToday;
  final int checkedOutToday;
  final List<SessionDetail> recent;

  const Dashboard({
    required this.activeNow,
    required this.checkedInToday,
    required this.checkedOutToday,
    required this.recent,
  });

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      activeNow: json['active_now'] as int,
      checkedInToday: json['checked_in_today'] as int,
      checkedOutToday: json['checked_out_today'] as int,
      recent: ((json['recent'] as List?) ?? const [])
          .map((e) => SessionDetail.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
