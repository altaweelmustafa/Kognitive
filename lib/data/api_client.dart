import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'session.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});
  final String message;
  final int? status;
}

/// JSON over HTTP to the Kognitiv backend, as the logged-in player.
/// Failures surface as [ApiException] with a message that can be shown.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? httpOverride ?? http.Client(),
      _base = baseUrl ?? ApiConfig.baseUrl;

  /// Tests set this to answer requests without a server.
  static http.Client? httpOverride;

  final http.Client _client;
  final String _base;
  static const _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _send('POST', path, body ?? const {});

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _send('PUT', path, body);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _send('PATCH', path, body);

  Future<Map<String, dynamic>> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final token = Session.instance.token;
    final request = http.Request(method, Uri.parse('$_base$path'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response r;
    try {
      r = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } catch (_) {
      throw ApiException("Can't reach the Kognitiv server.");
    }
    // The server no longer accepts this login.
    if (r.statusCode == 401 && token != null) Session.instance.expire();

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      throw ApiException(
        'Server error (${r.statusCode}).',
        status: r.statusCode,
      );
    }
    if (r.statusCode >= 400 || decoded is! Map<String, dynamic>) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiException(
        detail is String ? detail : 'Server error (${r.statusCode}).',
        status: r.statusCode,
      );
    }
    return decoded;
  }
}
