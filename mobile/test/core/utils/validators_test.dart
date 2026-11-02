import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/validators.dart';

void main() {
  group('plate', () {
    test('normalisasi membuang spasi, tanda hubung, dan kapitalisasi', () {
      expect(Validators.normalizePlate(' n 1234-xyz '), 'N1234XYZ');
    });

    test('plat kosong ditolak', () {
      expect(Validators.plate('   '), isNotNull);
      expect(Validators.plate('N 1234 ABC'), isNull);
    });

    test('dipotong pada batas 12 karakter seperti backend', () {
      expect(
        Validators.normalizePlate('B1234XYZEXTRA'),
        hasLength(Validators.plateMaxLength),
      );
    });
  });

  group('nim', () {
    test('hanya angka', () {
      expect(Validators.nim('244107020204'), isNull);
      expect(Validators.nim('2441A'), isNotNull);
      expect(Validators.nim(''), isNotNull);
    });

    test('melebihi batas kolom ditolak', () {
      expect(Validators.nim('1' * 33), isNotNull);
    });
  });

  test('password minimal 6 karakter', () {
    expect(Validators.password('12345'), isNotNull);
    expect(Validators.password('123456'), isNull);
  });
}
