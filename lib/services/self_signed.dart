import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

import 'odoo_session_manager.dart';

/// Maximum time to wait while establishing the TCP connection.
const Duration _connectionTimeout = Duration(seconds: 30);

/// Maximum time to wait for a server response before failing with a
/// [TimeoutException]. Kept generous since some Odoo operations (e.g.
/// creating a record) are heavy server-side, but bounded so a server that
/// accepts the connection and never replies can't hang the UI indefinitely.
const Duration _requestTimeout = Duration(seconds: 60);

HttpClient _getHttpClient() {
  final client = HttpClient()
    ..connectionTimeout = _connectionTimeout
    ..badCertificateCallback = (X509Certificate cert, String host, int port) =>
        true;
  return client;
}

/// Wraps an [http.Client] to enforce an overall timeout on every request —
/// bounding the wait for the server's response, which [HttpClient]'s
/// `connectionTimeout` alone does not cover.
class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request).timeout(_timeout);
  }

  @override
  void close() => _inner.close();
}

/// global HTTP client configured to accept self-signed certificates for development/local Odoo servers.
http.BaseClient ioClient = _TimeoutHttpClient(
  IOClient(_getHttpClient()),
  _requestTimeout,
);
