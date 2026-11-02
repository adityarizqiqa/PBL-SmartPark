/// Metadata paginasi dari `GET /api/sessions/history/meta`.
class PageMeta {
  final int total;
  final int limit;
  final int offset;

  const PageMeta({
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PageMeta.fromJson(Map<String, dynamic> json) {
    return PageMeta(
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
