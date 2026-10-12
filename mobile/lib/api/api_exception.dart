import '../models/common.dart';

/// Galat terpadu untuk seluruh panggilan API.
///
/// Membungkus dua sumber galat:
/// - respons backend non-2xx, dengan `{code, message, details}`;
/// - kegagalan jaringan (server mati, alamat salah), dengan pesan ramah.
class ApiException implements Exception {
  /// Kode HTTP; `0` bila permintaan tidak sampai ke server.
  final int statusCode;
  final String code;
  final String message;
  final Map<String, dynamic> details;

  const ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details = const {},
  });

  /// Galat dari body JSON backend.
  factory ApiException.fromResponse(int statusCode, ApiErrorBody body) {
    return ApiException(
      statusCode: statusCode,
      code: body.code,
      message: body.message,
      details: body.details,
    );
  }

  /// Galat jaringan atau waktu tunggu habis.
  factory ApiException.network([Object? cause]) {
    return ApiException(
      statusCode: 0,
      code: 'network_error',
      message: 'Tidak bisa menghubungi server. Periksa koneksi dan alamat '
          'backend.',
      details: cause == null ? const {} : {'cause': cause.toString()},
    );
  }

  /// Respons galat tanpa body JSON yang bisa dibaca.
  factory ApiException.unexpected(int statusCode, String rawBody) {
    return ApiException(
      statusCode: statusCode,
      code: 'unexpected_response',
      message: 'Server membalas dengan kode $statusCode.',
      details: {'body': rawBody},
    );
  }

  bool get isNetwork => statusCode == 0;

  /// Sesi/token tidak berlaku lagi — layar sebaiknya mengarahkan ke login.
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
