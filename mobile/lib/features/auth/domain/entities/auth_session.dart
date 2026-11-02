import '../../../../core/entities/area.dart';
import '../../../../core/entities/officer.dart';

/// Hasil masuk sebagai pengawas (SPV): token sesi petugas + identitasnya.
class AuthSession {
  const AuthSession({required this.token, required this.officer});

  final String token;
  final Officer officer;
}

/// Data yang dibutuhkan formulir masuk sebelum petugas memilih.
class LoginOptions {
  const LoginOptions({required this.officers, required this.areas});

  final List<Officer> officers;
  final List<Area> areas;

  bool get isEmpty => officers.isEmpty;
}
