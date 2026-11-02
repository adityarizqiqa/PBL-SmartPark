import '../network/api_exception.dart';

/// Galat yang sudah dipahami lapisan domain.
///
/// `message` selalu berisi kalimat siap tampil (berasal dari backend atau
/// pesan bawaan aplikasi). UI memilih reaksi berdasarkan jenisnya, bukan
/// berdasarkan kode HTTP.
sealed class Failure {
  const Failure(this.message, {this.code});

  final String message;

  /// Kode asli dari backend, dipertahankan untuk log dan pengujian.
  final String? code;

  /// Memetakan galat transport menjadi galat domain.
  ///
  /// Pemetaan memakai kode backend lebih dulu karena satu status HTTP bisa
  /// berarti banyak hal (`422` bisa `invalid_nim` atau `note_required`).
  factory Failure.fromApiException(ApiException error) {
    final code = error.code;
    final message = error.message;

    if (error.statusCode == 0) {
      return code == 'timeout'
          ? TimeoutFailure(message, code: code)
          : NetworkFailure(message, code: code);
    }

    switch (code) {
      case 'unauthorized':
      case 'invalid_credentials':
      case 'password_not_set':
      case 'officer_inactive':
      case 'area_inactive':
        return UnauthorizedFailure(message, code: code);
      case 'forbidden':
      case 'not_spv':
        return ForbiddenFailure(message, code: code);
      case 'not_found':
      case 'session_not_found':
      case 'shift_not_found':
      case 'area_not_found':
      case 'officer_not_found':
        return NotFoundFailure(message, code: code);
      case 'conflict':
      case 'duplicate_active_session':
      case 'duplicate_active_assignment':
      case 'shift_already_open':
        return ConflictFailure(message, code: code);
      case 'validation_error':
      case 'invalid_plate':
      case 'invalid_nim':
      case 'note_required':
      case 'session_not_active':
      case 'assignment_not_active':
        return ValidationFailure(
          message,
          code: code,
          field: _fieldOf(code, error.details),
        );
      case 'too_many_requests':
        return RateLimitFailure(message, code: code);
    }

    return switch (error.statusCode) {
      401 => UnauthorizedFailure(message, code: code),
      403 => ForbiddenFailure(message, code: code),
      404 => NotFoundFailure(message, code: code),
      409 => ConflictFailure(message, code: code),
      422 => ValidationFailure(
          message,
          code: code,
          field: _fieldOf(code, error.details),
        ),
      429 => RateLimitFailure(message, code: code),
      _ => ServerFailure(message, code: code, statusCode: error.statusCode),
    };
  }

  /// Field bermasalah diambil dari `details.field`, dari nama field langsung
  /// (`details.plate`, `details.nim`), atau dari kodenya sendiri karena
  /// backend kadang hanya mengirim panjang nilai (`details.length`).
  static String? _fieldOf(String code, Map<String, dynamic> details) {
    final field = details['field'];
    if (field is String) return field;
    for (final key in const ['nim', 'plate', 'client_request_id']) {
      if (details.containsKey(key)) return key;
    }
    return switch (code) {
      'invalid_nim' => 'nim',
      'invalid_plate' => 'plate',
      _ => null,
    };
  }
}

/// Permintaan tidak sampai ke server.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

/// Server tidak menjawab dalam batas waktu.
final class TimeoutFailure extends Failure {
  const TimeoutFailure(super.message, {super.code});
}

/// Sesi/token tidak berlaku; pengguna harus masuk ulang.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message, {super.code});
}

/// Terautentikasi tetapi perannya tidak berwenang.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message, {super.code});
}

/// Data yang dituju tidak ada.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

/// Bentrok keadaan, misalnya plat sudah punya sesi aktif.
final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

/// Masukan ditolak; [field] menunjuk kolom yang perlu diperbaiki.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, this.field});

  final String? field;
}

/// Terlalu banyak permintaan.
final class RateLimitFailure extends Failure {
  const RateLimitFailure(super.message, {super.code});
}

/// Galat tak terduga di sisi server.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, required this.statusCode});

  final int statusCode;
}
