import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/odoo_session.dart';
import 'self_signed.dart';
export '../models/odoo_session.dart';

/// Manages Odoo user sessions, including authentication, persistence, and RPC client state.
class OdooSessionManager {
  static OdooClient? _client;
  static const String USER_AGENT =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

  static OdooSessionModel? _cachedSession;

  static OdooSessionModel? get cachedSession => _cachedSession;
  static bool _isRefreshing = false;
  static DateTime? _lastAuthTime;

  static const int _maxRetries = 3;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  static const Duration _sessionCacheValidDuration = Duration(minutes: 5);

  static Function(OdooSessionModel)? _onSessionUpdated;
  static Function()? _onSessionCleared;

  /// Sets callback functions for session update and clear events.
  static void setSessionCallbacks({
    Function(OdooSessionModel)? onSessionUpdated,
    Function()? onSessionCleared,
  }) {
    _onSessionUpdated = onSessionUpdated;
    _onSessionCleared = onSessionCleared;
  }

  /// Sets the internal [OdooClient] manually (primarily for testing).
  @visibleForTesting
  static void setClient(OdooClient client) {
    _client = client;
    _lastAuthTime = DateTime.now();
  }

  /// Clears the in-memory session and client cache.
  @visibleForTesting
  static void clearCache() {
    _cachedSession = null;
    _client = null;
    _lastAuthTime = null;
  }

  static bool _isRetryableError(Object e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is http.ClientException) return true;

    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('connection reset') ||
        errorStr.contains('timed out') ||
        errorStr.contains('connection refused');
  }

  static bool _isAuthError(Object e) {
    final errorStr = e.toString().toLowerCase();
    return errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('access denied') ||
        errorStr.contains('invalid session') ||
        errorStr.contains('session expired') ||
        errorStr.contains('authentication') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('403');
  }

  /// Retrieves the current active session from memory or persistent storage.
  static Future<OdooSessionModel?> getCurrentSession() async {
    if (_cachedSession != null) return _cachedSession;

    try {
      final saved = await OdooSessionModel.fromPrefs();
      if (saved == null) return null;

      _cachedSession = saved;
      return saved;
    } catch (e) {
      return null;
    }
  }

  /// Checks if a session is currently considered valid based on persistent login state.
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  /// Performs login and saves the resulting session to persistent storage.
  static Future<bool> loginAndSaveSession({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    bool autoLoadCompanies = true,
  }) async {
    try {
      final sessionModel = await authenticate(
        serverUrl: serverUrl,
        database: database,
        username: userLogin,
        password: password,
        autoLoadCompanies: autoLoadCompanies,
      );

      if (sessionModel == null) return false;

      await sessionModel.saveToPrefs();

      _cachedSession = sessionModel;
      _lastAuthTime = DateTime.now();

      _onSessionUpdated?.call(sessionModel);

      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Initializes a session using an existing Odoo session ID.
  static Future<bool> loginWithSessionId({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
    required String sessionId,
    Map<String, dynamic>? sessionInfo,
  }) async {
    try {
      String normalizedUrl = serverUrl.trim();
      if (!normalizedUrl.startsWith('http://') &&
          !normalizedUrl.startsWith('https://')) {
        normalizedUrl = 'https://$normalizedUrl';
      }
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      if (normalizedUrl.endsWith('/odoo')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 5);
      }

      final Map<String, dynamic> info =
          sessionInfo ?? await getSessionInfo(normalizedUrl, sessionId);

      if (info['uid'] == null || info['uid'] is bool) {
        throw Exception('Failed to get valid session info');
      }

      final int userId = info['uid'];
      final String serverVersion = info['server_version']?.toString() ?? '17.0';
      final int majorVersion = parseMajorVersion(serverVersion);

      final userData = await callKwWithSession(
        url: normalizedUrl,
        sessionId: sessionId,
        payload: {
          "jsonrpc": "2.0",
          "method": "call",
          "params": {
            "model": "res.users",
            "method": "read",
            "args": [
              [userId],
              ["company_id"],
            ],
            "kwargs": {},
          },
          "id": 1,
        },
      );

      final company = _parseCompany(userData[0]['company_id']);
      int? selectedCompanyId = company?['id'];

      bool isSystem = false;
      if (majorVersion >= 18) {
        isSystem =
            await callKwWithSession(
              url: normalizedUrl,
              sessionId: sessionId,
              payload: {
                "jsonrpc": "2.0",
                "method": "call",
                "params": {
                  "model": "res.users",
                  "method": "has_group",
                  "args": [userId, "base.group_system"],
                  "kwargs": {},
                },
                "id": 1,
              },
            ) ==
            true;
      } else {
        isSystem =
            await callKwWithSession(
              url: normalizedUrl,
              sessionId: sessionId,
              payload: {
                "jsonrpc": "2.0",
                "method": "call",
                "params": {
                  "model": "res.users",
                  "method": "has_group",
                  "args": ["base.group_system"],
                  "kwargs": {},
                },
                "id": 1,
              },
            ) ==
            true;
      }

      List<int> allowedCompanyIds = [];
      if (majorVersion >= 13) {
        final companiesRes = await callKwWithSession(
          url: normalizedUrl,
          sessionId: sessionId,
          payload: {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {
              "model": "res.users",
              "method": "read",
              "args": [
                [userId],
                ["company_ids"],
              ],
              "kwargs": {},
            },
            "id": 1,
          },
        );
        if (companiesRes is List && companiesRes.isNotEmpty) {
          allowedCompanyIds =
              (companiesRes[0]['company_ids'] as List?)?.cast<int>() ?? [];
        }
      }

      if (selectedCompanyId == null) {
        selectedCompanyId = info['company_id'];
      }
      if (allowedCompanyIds.isEmpty) {
        allowedCompanyIds = [selectedCompanyId ?? 1];
      }

      final client = OdooClient(
        normalizedUrl,
        sessionId: OdooSession(
          id: sessionId,
          userId: userId,
          partnerId: info['partner_id'] ?? 1,
          userLogin: userLogin,
          userName: info['name'] ?? userLogin,
          userLang: info['user_context']?['lang'] ?? 'en_US',
          userTz: info['user_context']?['tz'] ?? 'UTC',
          isSystem: isSystem,
          dbName: database,
          serverVersion: serverVersion,
          companyId: selectedCompanyId ?? 1,
          allowedCompanies: [],
        ),
        httpClient: ioClient,
      );

      final sessionModel = OdooSessionModel(
        sessionId: sessionId,
        userLogin: userLogin,
        password: password,
        serverUrl: normalizedUrl,
        database: database,
        userId: userId,
        userName: info['name'] ?? userLogin,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        selectedCompanyId: selectedCompanyId,
        allowedCompanyIds: allowedCompanyIds,
        serverVersion: serverVersion,
      );

      await sessionModel.saveToPrefs();
      _cachedSession = sessionModel;
      _lastAuthTime = DateTime.now();
      _client = client;

      _onSessionUpdated?.call(sessionModel);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Fetches basic session information (UID, company, context) from Odoo.
  static Future<Map<String, dynamic>> getSessionInfo(
    String url,
    String sessionId,
  ) async {
    final response = await ioClient.post(
      Uri.parse('$url/web/session/get_session_info'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent': USER_AGENT,
        'Origin': url,
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {},
        "id": 1,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get session info: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    if (data['error'] != null) {
      throw Exception(data['error']['message'] ?? 'Session info error');
    }
    return Map<String, dynamic>.from(data['result']);
  }

  /// Executes a low-level keyword-based RPC call using a specific session ID.
  static Future<dynamic> callKwWithSession({
    required String url,
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await ioClient.post(
      Uri.parse('$url/web/dataset/call_kw'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'User-Agent': USER_AGENT,
        'Origin': url,
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(res.body);

    if (data['error'] != null)
      throw Exception(data['error']['message'] ?? 'RPC Error');
    return data['result'];
  }

  /// Parses the major version number from an Odoo version string.
  static int parseMajorVersion(String version) {
    try {
      final parts = version.split('.');
      if (parts.isNotEmpty) {
        return int.parse(parts[0]);
      }
    } catch (e) {}
    return 0;
  }

  static Map<String, dynamic>? _parseCompany(dynamic value) {
    if (value == null) return null;
    if (value is List && value.length >= 2) {
      return {'id': value[0], 'name': value[1]};
    }
    if (value is Map) {
      return {
        'id': value['id'],
        'name': value['display_name'] ?? value['name'],
      };
    }
    return null;
  }

  /// Authenticates with Odoo using username/password and returns a session model.
  static Future<OdooSessionModel?> authenticate({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
    bool autoLoadCompanies = true,
  }) async {
    if (serverUrl.isEmpty || database.isEmpty || username.isEmpty) {
      throw Exception('Invalid login parameters');
    }

    String normalizedUrl = serverUrl.trim();
    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = 'https://$normalizedUrl';
    }
    if (normalizedUrl.endsWith('/')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
    }
    if (normalizedUrl.endsWith('/odoo')) {
      normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 5);
    }

    final client = OdooClient(normalizedUrl);

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        OdooSession? odooSession;
        try {
          odooSession = await client.authenticate(database, username, password);
        } catch (e) {
          if (e.toString().contains(
            "type 'Null' is not a subtype of type 'Map<String, dynamic>'",
          )) {
            try {
              final uri = Uri.parse('$normalizedUrl/web/session/authenticate');
              final response = await http.post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'jsonrpc': '2.0',
                  'method': 'call',
                  'params': {
                    'db': database,
                    'login': username,
                    'password': password,
                  },
                  'id': DateTime.now().millisecondsSinceEpoch,
                }),
              );

              if (response.statusCode == 200) {
                final authBody = jsonDecode(response.body);
                final result = authBody['result'];
                final error = authBody['error'];

                if (error != null) {
                  throw Exception(error['message'] ?? 'Authentication error');
                }

                if (result != null) {
                  var uid = result['uid'];
                  if (uid is bool) uid = null;

                  String? sessionId;
                  if (result['session_id'] != null) {
                    sessionId = result['session_id'];
                  } else if (response.headers['set-cookie'] != null) {
                    final cookies = response.headers['set-cookie']!;
                    final sessionMatch = RegExp(
                      r'session_id=([^;]+)',
                    ).firstMatch(cookies);
                    sessionId = sessionMatch?.group(1);
                  }

                  if (sessionId != null) {
                    if (uid == null) {
                      throw Exception('two factor authentication required');
                    }
                    odooSession = OdooSession(
                      id: sessionId,
                      userId: uid,
                      partnerId: result['partner_id'] ?? 0,
                      userLogin: result['username'] ?? username,
                      userName: result['name'] ?? '',
                      userLang: result['user_context']?['lang'] ?? 'en_US',
                      userTz: result['user_context']?['tz'] ?? 'UTC',
                      isSystem: result['is_system'] ?? false,
                      dbName: result['db'] ?? database,
                      serverVersion: result['server_version'] ?? '',
                      companyId: result['company_id'] ?? 0,
                      allowedCompanies: [],
                    );

                    try {
                      (client as dynamic).sessionId = odooSession;
                    } catch (clientEx) {}
                  } else {
                    throw Exception('No session_id found in auth response');
                  }
                } else {
                  throw Exception('Authentication returned null result');
                }
              }
            } catch (manualEx) {
              rethrow;
            }
          }

          if (odooSession == null) rethrow;
        }

        int? selectedCompanyId;
        List<int> allowedCompanyIds = [];

        if (autoLoadCompanies) {
          try {
            final userInfo = await _fetchUserCompanies(
              client,
              odooSession.userId,
            );

            selectedCompanyId = userInfo['company_id'];
            allowedCompanyIds = (userInfo['company_ids'] as List<int>?) ?? [];

            if (selectedCompanyId != null &&
                !allowedCompanyIds.contains(selectedCompanyId)) {
              allowedCompanyIds.add(selectedCompanyId);
            }
          } catch (e) {}
        }

        final sessionData = OdooSessionModel(
          sessionId: odooSession.id,
          userLogin: username,
          password: password,
          serverUrl: normalizedUrl,
          database: database,
          userId: odooSession.userId,
          userName: odooSession.userName,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          selectedCompanyId: selectedCompanyId,
          allowedCompanyIds: allowedCompanyIds,
          serverVersion: odooSession.serverVersion,
        );

        _client = client;

        return sessionData;
      } catch (e) {
        if (e is FormatException && e.toString().contains('<html>')) {
          throw Exception(
            'Server returned HTML instead of JSON. Please check server URL.',
          );
        }

        if (e.toString().toLowerCase().contains('access denied') ||
            e.toString().toLowerCase().contains('wrong login/password') ||
            e.toString().toLowerCase().contains('invalid database')) {
          rethrow;
        }

        if (attempt < _maxRetries && _isRetryableError(e)) {
          final delay = _baseDelay * attempt;
          await Future.delayed(delay);
          continue;
        }

        rethrow;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _fetchUserCompanies(
    OdooClient client,
    int userId,
  ) async {
    try {
      final result = await safeCallKwWithoutCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      if (result is List && result.isNotEmpty) {
        final userData = result[0];

        int? companyId;
        if (userData['company_id'] is int) {
          companyId = userData['company_id'];
        } else if (userData['company_id'] is List &&
            userData['company_id'].isNotEmpty) {
          companyId = userData['company_id'][0];
        }

        List<int> companyIds = [];
        if (userData['company_ids'] is List) {
          companyIds = (userData['company_ids'] as List)
              .map((e) => e is int ? e : null)
              .whereType<int>()
              .toList();
        }

        return {'company_id': companyId, 'company_ids': companyIds};
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  /// Refreshes the current session, re-authenticating if necessary.
  static Future<bool> refreshSession() async {
    if (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 500));
      return await isSessionValid();
    }

    _isRefreshing = true;
    try {
      final session = await getCurrentSession();

      if (session == null) {
        throw StateError('No Odoo session available. Please login.');
      }

      try {
        final info = await getSessionInfo(session.serverUrl, session.sessionId);
        if (info['uid'] != null && info['uid'] is int) {
          _lastAuthTime = DateTime.now();

          final client = OdooClient(session.serverUrl, httpClient: ioClient);
          try {
            (client as dynamic).sessionId = session.odooSession;
          } catch (_) {}
          _client = client;

          return true;
        }
      } catch (e) {}

      try {
        final newSession = await authenticate(
          serverUrl: session.serverUrl,
          database: session.database,
          username: session.userLogin,
          password: session.password,
          autoLoadCompanies: true,
        );

        if (newSession == null) {
          throw Exception('Authentication returned null');
        }

        OdooSessionModel updatedSession = newSession;
        if (session.selectedCompanyId != null &&
            newSession.allowedCompanyIds.contains(session.selectedCompanyId)) {
          updatedSession = newSession.copyWith(
            selectedCompanyId: session.selectedCompanyId,
          );
        }

        _cachedSession = updatedSession;
        _lastAuthTime = DateTime.now();
        await updatedSession.saveToPrefs();
        _onSessionUpdated?.call(updatedSession);

        return true;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('two factor') || msg.contains('2fa')) {
          return false;
        }
        rethrow;
      }
    } catch (e) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Returns an [OdooClient], ensuring the session is refreshed if expired.
  static Future<OdooClient> getClientEnsured() async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    if (session.isExpired) {
      final refreshed = await refreshSession();
      if (!refreshed) {
        if (_client == null) {
          _client = OdooClient(session.serverUrl, httpClient: ioClient);
        }
        return _client!;
      }
    }

    if (_client != null &&
        _lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            _sessionCacheValidDuration) {
      return _client!;
    }

    try {
      final client = OdooClient(session.serverUrl, httpClient: ioClient);

      bool boundWithCookie = false;
      try {
        (client as dynamic).sessionId = session.odooSession;
        boundWithCookie = true;
      } catch (_) {}

      if (!boundWithCookie) {
        for (int attempt = 1; attempt <= _maxRetries; attempt++) {
          try {
            await client.authenticate(
              session.database,
              session.userLogin,
              session.password,
            );
            break;
          } catch (e) {
            if (attempt >= _maxRetries || !_isRetryableError(e)) rethrow;
            await Future.delayed(_baseDelay * attempt);
          }
        }
      }

      _client = client;
      _lastAuthTime = DateTime.now();

      return client;
    } catch (e) {
      final client = OdooClient(session.serverUrl, httpClient: ioClient);
      _client = client;
      return client;
    }
  }

  /// Returns an [OdooClient] or `null` if the session is invalid.
  static Future<OdooClient?> getClient() async {
    try {
      return await getClientEnsured();
    } catch (e) {
      return null;
    }
  }


  /// Executes a keyword-based RPC call with the current company context.
  static Future<dynamic> callKwWithCompany(Map<String, dynamic> payload) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    final kwargs = Map<String, dynamic>.from(payload['kwargs'] ?? {});
    final context = Map<String, dynamic>.from(kwargs['context'] ?? {});

    if (session.allowedCompanyIds.isNotEmpty) {
      context['allowed_company_ids'] = session.allowedCompanyIds;
    }

    if (session.selectedCompanyId != null && session.selectedCompanyId != 0) {
      context['company_id'] = session.selectedCompanyId;
    }

    context['db'] = session.database;

    kwargs['context'] = context;
    final newPayload = Map<String, dynamic>.from(payload);
    newPayload['kwargs'] = kwargs;

    Future<http.Response> _post() async {
      final current = await getCurrentSession();
      final effective = current ?? session;
      return ioClient
          .post(
            Uri.parse('${effective.serverUrl}/web/dataset/call_kw'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
              'User-Agent': USER_AGENT,
              'Origin': effective.serverUrl,
              'Referer': '${effective.serverUrl}/web',
              'Cookie': 'session_id=${effective.sessionId}',
              'X-Openerp-Session-Id': effective.sessionId,
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': newPayload,
              'id': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 30));
    }

    http.Response response = await _post();
    if (response.statusCode != 200) {
      throw Exception('RPC HTTP ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    if (data['error'] != null) {
      final message = data['error']['message']?.toString() ?? 'RPC Error';
      final lower = message.toLowerCase();
      if (lower.contains('session expired')) {
        try {
          await getSessionInfo(session.serverUrl, session.sessionId);
          response = await _post();
          if (response.statusCode != 200) {
            throw Exception(
              'RPC HTTP ${response.statusCode}: ${response.body}',
            );
          }
          final retryData = jsonDecode(response.body);
          if (retryData['error'] != null) {
            throw Exception(
              retryData['error']['message']?.toString() ?? 'RPC Error',
            );
          }
          return retryData['result'];
        } catch (_) {
          try {
            final refreshed = await refreshSession();
            if (refreshed) {
              response = await _post();
              if (response.statusCode != 200) {
                throw Exception(
                  'RPC HTTP ${response.statusCode}: ${response.body}',
                );
              }
              final retryData = jsonDecode(response.body);
              if (retryData['error'] != null) {
                throw Exception(
                  retryData['error']['message']?.toString() ?? 'RPC Error',
                );
              }
              return retryData['result'];
            }
          } catch (_) {}
        }
      }
      String detailedMessage = message;
      if (data['error']['data'] != null &&
          data['error']['data']['message'] != null) {
        detailedMessage = '${data['error']['data']['message']}';
      }
      throw Exception(detailedMessage);
    }
    return data['result'];
  }


  /// Executes a keyword-based RPC call without adding company context.
  static Future<dynamic> callKwWithoutCompany(
    Map<String, dynamic> payload,
  ) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No Odoo session available. Please login.');
    }

    Future<http.Response> _post() async {
      final current = await getCurrentSession();
      final effective = current ?? session;
      return ioClient
          .post(
            Uri.parse('${effective.serverUrl}/web/dataset/call_kw'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'X-Requested-With': 'XMLHttpRequest',
              'User-Agent': USER_AGENT,
              'Origin': effective.serverUrl,
              'Referer': '${effective.serverUrl}/web',
              'Cookie': 'session_id=${effective.sessionId}',
              'X-Openerp-Session-Id': effective.sessionId,
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': payload,
              'id': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 30));
    }

    http.Response response = await _post();
    if (response.statusCode != 200) {
      throw Exception('RPC HTTP ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    if (data['error'] != null) {
      final message = data['error']['message']?.toString() ?? 'RPC Error';

      if (message.toLowerCase().contains('session expired')) {
        try {
          final refreshed = await refreshSession();
          if (refreshed) {
            response = await _post();
            final retryData = jsonDecode(response.body);
            if (retryData['error'] == null) return retryData['result'];
          }
        } catch (_) {}
      }

      throw Exception(message);
    }
    return data['result'];
  }

  /// Executes a keyword-based RPC call without company context, with built-in retry logic.
  static Future<dynamic> safeCallKwWithoutCompany(
    Map<String, dynamic> payload,
  ) {
    return getCurrentSession().then((session) async {
      if (session == null) {
        throw StateError('No Odoo session available. Please login.');
      }
      Future<http.Response> _post() async {
        final current = await getCurrentSession();
        final effective = current ?? session;
        return ioClient
            .post(
              Uri.parse('${effective.serverUrl}/web/dataset/call_kw'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
                'User-Agent': USER_AGENT,
                'Origin': effective.serverUrl,
                'Referer': '${effective.serverUrl}/web',
                'Cookie': 'session_id=${effective.sessionId}',
                'X-Openerp-Session-Id': effective.sessionId,
              },
              body: jsonEncode({
                'jsonrpc': '2.0',
                'method': 'call',
                'params': payload,
                'id': DateTime.now().millisecondsSinceEpoch,
              }),
            )
            .timeout(const Duration(seconds: 30));
      }

      http.Response response = await _post();
      if (response.statusCode != 200) {
        throw Exception('RPC HTTP ${response.statusCode}: ${response.body}');
      }
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        final message = data['error']['message']?.toString() ?? 'RPC Error';
        final lower = message.toLowerCase();
        if (lower.contains('session expired')) {
          try {
            await getSessionInfo(session.serverUrl, session.sessionId);
            response = await _post();
            if (response.statusCode != 200) {
              throw Exception(
                'RPC HTTP ${response.statusCode}: ${response.body}',
              );
            }
            final retryData = jsonDecode(response.body);
            if (retryData['error'] != null) {
              throw Exception(
                retryData['error']['message']?.toString() ?? 'RPC Error',
              );
            }
            return retryData['result'];
          } catch (_) {
            try {
              final refreshed = await refreshSession();
              if (refreshed) {
                response = await _post();
                if (response.statusCode != 200) {
                  throw Exception(
                    'RPC HTTP ${response.statusCode}: ${response.body}',
                  );
                }
                final retryData = jsonDecode(response.body);
                if (retryData['error'] != null) {
                  throw Exception(
                    retryData['error']['message']?.toString() ?? 'RPC Error',
                  );
                }
                return retryData['result'];
              }
            } catch (_) {}
          }
        }
        throw Exception(message);
      }
      return data['result'];
    });
  }

  /// Updates the selected company and allowed company list in the current session.
  static Future<void> updateCompanySelection({
    required int companyId,
    required List<int> allowedCompanyIds,
  }) async {
    final session = await getCurrentSession();
    if (session == null) return;

    final updatedSession = session.copyWith(
      selectedCompanyId: companyId,
      allowedCompanyIds: allowedCompanyIds,
    );

    await updatedSession.saveToPrefs();
    _cachedSession = updatedSession;
    _onSessionUpdated?.call(updatedSession);
  }

  /// Restores a session for a specific company by updating the local state.
  static Future<bool> restoreSession({required int companyId}) async {
    final session = await getCurrentSession();
    if (session == null) return false;

    await refreshSession();
    return true;
  }


  /// Logs out the user and clears all local session data.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('sessionId');
    await prefs.remove('userLogin');
    await prefs.remove('password');
    await prefs.remove('serverUrl');
    await prefs.remove('database');
    await prefs.remove('userId');
    await prefs.remove('selectedCompanyId');
    await prefs.remove('allowedCompanyIds');

    _cachedSession = null;
    _client = null;
    _onSessionCleared?.call();
  }

  /// Updates the cached session model and persists it to storage.
  static Future<void> updateSession(OdooSessionModel sessionModel) async {
    await sessionModel.saveToPrefs();
    _cachedSession = sessionModel;

    _client = null;
    _lastAuthTime = null;
    _onSessionUpdated?.call(sessionModel);
  }

  /// Makes an authenticated HTTP request to an Odoo endpoint with retries.
  static Future<http.Response> makeAuthenticatedRequest(
    String url, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
    int maxRetries = 3,
  }) async {
    final session = await getCurrentSession();
    if (session == null) {
      throw StateError('No active session');
    }

    await getClientEnsured();

    final uri = Uri.parse(url);
    final requestHeaders = {
      'Cookie': 'session_id=${session.sessionId}',
      ...?headers,
    };

    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final client = http.Client();
        try {
          final response = await client
              .get(uri, headers: requestHeaders)
              .timeout(timeout ?? const Duration(seconds: 30));

          if (response.statusCode == 404) {}

          return response;
        } finally {
          client.close();
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < maxRetries && _isRetryableError(e)) {
          await Future.delayed(_baseDelay * attempt);
          continue;
        }
        rethrow;
      }
    }

    throw lastError ?? Exception('Request failed');
  }

  static OdooClient? get client => _client;
}
