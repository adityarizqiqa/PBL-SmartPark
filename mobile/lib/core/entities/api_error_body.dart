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
