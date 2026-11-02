import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../entities/api_error_body.dart';
import '../session/session_store.dart';
import 'api_exception.dart';

/// Klien HTTP tunggal ke backend SmartPark.
///
/// Tidak menyimpan state sesi sendiri: token dibaca dari [TokenProvider] yang
/// di-inject, sehingga satu instance bisa dipakai bersama dan mudah diganti
/// pada pengujian.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    TokenProvider? tokens,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? defaultBaseUrl,
        _tokens = tokens;

  static const String _defaultRemoteBaseUrl = 'http://4.213.226.116:9876';

  /// Alamat dasar efektif: `--dart-define=API_BASE_URL` bila ada, jika tidak
  /// alamat remote backend SmartPark.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return fromEnv.isEmpty ? _defaultRemoteBaseUrl : fromEnv;
  }

  final http.Client _client;
  final String baseUrl;
  final TokenProvider? _tokens;

  static const Duration _timeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalized');
    if (query == null || query.isEmpty) return uri;
    final params = <String, String>{};
    query.forEach((key, value) {
      if (value != null) params[key] = value.toString();
    });
    return uri.replace(queryParameters: params);
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    // Backend hanya membaca header yang relevan untuk tiap endpoint, jadi
    // mengirim keduanya sekaligus aman.
    final shiftToken = _tokens?.shiftToken;
    if (shiftToken != null) headers['X-Shift-Token'] = shiftToken;
    final officerToken = _tokens?.officerToken;
    if (officerToken != null) headers['X-Officer-Token'] = officerToken;
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => _client.get(_uri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _send(() => _client.post(
          _uri(path),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _send(() => _client.patch(
          _uri(path),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        ));
  }

  /// Mengirim `multipart/form-data` — dipakai check-in dan check-out yang
  /// menyertakan foto plat. Nilai `null` dilewati.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String?> fields = const {},
    String? photoPath,
    String photoField = 'photo',
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path));
      request.headers.addAll(_headers(json: false));
      fields.forEach((key, value) {
        if (value != null) request.fields[key] = value;
      });
      if (photoPath != null && photoPath.isNotEmpty) {
        request.files
            .add(await http.MultipartFile.fromPath(photoField, photoPath));
      }
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    late http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException catch (e) {
      throw ApiException.network(cause: e, code: 'timeout');
    } on SocketException catch (e) {
      throw ApiException.network(cause: e);
    } on http.ClientException catch (e) {
      throw ApiException.network(cause: e);
    }

    final status = response.statusCode;
    final raw = response.body;

    if (status >= 200 && status < 300) {
      if (raw.isEmpty) return null;
      return jsonDecode(raw);
    }

    throw _errorFrom(status, raw);
  }

  ApiException _errorFrom(int status, String raw) {
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['code'] != null) {
          return ApiException.fromResponse(
            status,
            ApiErrorBody.fromJson(decoded.cast<String, dynamic>()),
          );
        }
      } catch (_) {
        // jatuh ke galat tak terduga di bawah
      }
    }
    return ApiException.unexpected(status, raw);
  }
}
