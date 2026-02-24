import 'dart:io';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

import 'odoo_session_manager.dart';

HttpClient _getHttpClient() {
  final client = HttpClient()
    ..badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
  return client;
}

/// global HTTP client configured to accept self-signed certificates for development/local Odoo servers.
http.BaseClient ioClient = IOClient(_getHttpClient());
