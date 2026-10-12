/// Bentuk seragam respons galat dari backend.
class ApiErrorBody {
  final String code;
  final String message;
  final Map<String, dynamic> details;

  const ApiErrorBody({
    required this.code,
    required this.message,
    required this.details,
  });

  factory ApiErrorBody.fromJson(Map<String, dynamic> json) {
    return ApiErrorBody(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? 'Terjadi kesalahan.',
      details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

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
