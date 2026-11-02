import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/failures/failure.dart';
import 'package:mobile/core/network/api_exception.dart';

void main() {
  Failure map(int status, String code, {Map<String, dynamic> details = const {}}) {
    return Failure.fromApiException(
      ApiException(
        statusCode: status,
        code: code,
        message: 'pesan',
        details: details,
      ),
    );
  }

  test('galat jaringan dan waktu tunggu dipisah', () {
    expect(
      Failure.fromApiException(ApiException.network(cause: 'socket')),
      isA<NetworkFailure>(),
    );
    expect(
      Failure.fromApiException(
        ApiException.network(cause: 'timeout', code: 'timeout'),
      ),
      isA<TimeoutFailure>(),
    );
  });

  test('kode backend dipetakan lebih dulu daripada status HTTP', () {
    // 422 dari backend bisa berarti banyak hal; kode yang menentukan jenisnya.
    final plate = map(422, 'invalid_plate', details: {'plate': 'B1'});
    expect(plate, isA<ValidationFailure>());
    expect((plate as ValidationFailure).field, 'plate');

    final nim = map(422, 'invalid_nim', details: {'length': 3});
    expect((nim as ValidationFailure).field, 'nim');
  });

  test('bentrok sesi aktif menjadi ConflictFailure', () {
    expect(map(409, 'duplicate_active_session'), isA<ConflictFailure>());
    expect(map(409, 'shift_already_open'), isA<ConflictFailure>());
  });

  test('kegagalan login menjadi UnauthorizedFailure, bukan Forbidden', () {
    expect(map(401, 'invalid_credentials'), isA<UnauthorizedFailure>());
    expect(map(403, 'not_spv'), isA<ForbiddenFailure>());
  });

  test('kode tak dikenal jatuh ke jenis berdasarkan status', () {
    expect(map(404, 'mystery'), isA<NotFoundFailure>());
    expect(map(500, 'mystery'), isA<ServerFailure>());
    expect(
      (map(500, 'mystery') as ServerFailure).statusCode,
      500,
    );
    expect(map(429, 'mystery'), isA<RateLimitFailure>());
  });

  test('pesan backend dipertahankan apa adanya', () {
    final failure = map(409, 'duplicate_active_session');
    expect(failure.message, 'pesan');
    expect(failure.code, 'duplicate_active_session');
  });
}
