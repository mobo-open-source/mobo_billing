import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'odoo_session_manager.dart';

/// Service for interacting with the Odoo JSON-RPC API.
class OdooApiService {
  static final OdooApiService _instance = OdooApiService._internal();

  factory OdooApiService() => _instance;

  OdooApiService._internal();

  String? _baseUrl;
  String? _database;
  String? _password;
  int? _uid;
  String? _sessionId;
  Map<String, dynamic> _context = {};

  int? get uid => _uid;

  String? get database => _database;

  /// Initializes the service with a base URL and database name.
  void initialize(String baseUrl, String database) {
    _baseUrl = _stripOdooSuffix(baseUrl);
    if (_baseUrl!.endsWith('/')) {
      _baseUrl = _baseUrl!.substring(0, _baseUrl!.length - 1);
    }
    _database = database;
  }

  /// Fetches the list of available databases from the Odoo server.
  static Future<List<String>> getDatabases(String baseUrl) async {
    String cleanUrl = _stripOdooSuffix(baseUrl);
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    final client = OdooClient(cleanUrl);

    List<String> dbs = [];

    try {
      final response = await client.callRPC('/web/database/list', 'call', {});
      if (response is List) {
        return List<String>.from(response);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('access denied') ||
          msg.contains('forbidden') ||
          msg.contains('403')) {
        throw Exception('ACCESS_DENIED_DB_LIST');
      }
    }

    try {
      final rpcDbs = await _getDatabasesRpc(cleanUrl, client);
      if (rpcDbs.isNotEmpty) dbs.addAll(rpcDbs);
    } catch (e) {}

    if (dbs.isEmpty) {
      final discoveredDb = await _scrapeDatabaseName(cleanUrl);
      if (discoveredDb != null) {
        return [discoveredDb];
      }
    }

    return dbs;
  }

  static String _stripOdooSuffix(String url) {
    if (url.endsWith('/odoo')) {
      return url.substring(0, url.length - 5);
    }
    if (url.endsWith('/odoo/')) {
      return url.substring(0, url.length - 6);
    }
    return url;
  }

  static Future<String?> _scrapeDatabaseName(String baseUrl) async {
    try {
      final uri = Uri.parse(baseUrl + '/web/login');

      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        },
      );

      final dbFromCookie = _extractDbFromCookies(
        response.headers['set-cookie'],
      );
      if (dbFromCookie != null) {
        return dbFromCookie;
      }

      return _extractDbFromHtml(response.body);
    } catch (e) {}
    return null;
  }

  static Future<List<String>> _getDatabasesRpc(
    String cleanUrl,
    OdooClient client,
  ) async {
    try {
      final response = await client.callRPC('/jsonrpc', 'call', {
        'service': 'db',
        'method': 'list',
        'args': [],
      });
      if (response is List) {
        return List<String>.from(response);
      }
      return [];
    } catch (e) {
      final msg = e.toString().toLowerCase();

      if (msg.contains('access denied') ||
          msg.contains('forbidden') ||
          msg.contains('403')) {
        throw Exception('ACCESS_DENIED_DB_LIST');
      }

      rethrow;
    }
  }

  /// Authenticates the user and saves the session if successful.
  Future<Map<String, dynamic>> authenticate(
    String username,
    String password,
  ) async {
    try {
      final success = await OdooSessionManager.loginAndSaveSession(
        serverUrl: _baseUrl!,
        database: _database!,
        userLogin: username,
        password: password,
      );

      if (!success) throw Exception('Login failed via SessionManager');

      final session = await OdooSessionManager.getCurrentSession();
      if (session != null) {
        updateSession(session);

        return {'success': true, 'uid': _uid, 'session_id': _sessionId};
      } else {
        throw Exception('Session not found after login');
      }
    } catch (e) {
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }

  /// Updates the local service state with new session details.
  void updateSession(OdooSessionModel session) {
    _uid = session.userId;
    _password = session.password;
    _sessionId = session.sessionId;
    _context = {};
    initialize(session.serverUrl, session.database);
  }

  /// Performs a generic Odoo JSON-RPC call to the specified model and method.
  Future<dynamic> call(
    String model,
    String method,
    List args, [
    Map<String, dynamic>? kwargs,
  ]) async {
    final client = await OdooSessionManager.getClient();
    if (client == null) {
      throw Exception('Not authenticated. Please login first.');
    }

    try {
      return await OdooSessionManager.callKwWithCompany({
        'model': model,
        'method': method,
        'args': args,
        'kwargs': kwargs ?? {},
      }).timeout(const Duration(seconds: 30));
    } catch (e) {
      if (e.toString().contains('two factor authentication required')) {
        throw Exception('two factor authentication required');
      }

      String errorStr = e.toString();

      if (e is OdooException) {
        errorStr += " ${e.message}";
      }

      if (errorStr.contains("Invalid field")) {
        final errorStr = e.toString();
        final match = RegExp(r"Invalid field '([^']+)'").firstMatch(errorStr);
        if (match != null) {
          final invalidField = match.group(1);
          if (invalidField == null) rethrow;

          if (kwargs != null &&
              kwargs.containsKey('fields') &&
              kwargs['fields'] is List) {
            final fields = List<dynamic>.from(kwargs['fields']);
            if (fields.contains(invalidField)) {
              fields.remove(invalidField);
              final updatedKwargs = Map<String, dynamic>.from(kwargs);
              updatedKwargs['fields'] = fields;
              return await call(model, method, args, updatedKwargs);
            }
          }

          if (method == 'read' && args.length >= 2 && args[1] is List) {
            final fields = List<dynamic>.from(args[1]);
            if (fields.contains(invalidField)) {
              fields.remove(invalidField);
              final newArgs = List.from(args);
              newArgs[1] = fields;
              return await call(model, method, newArgs, kwargs);
            }
          }

          if (method == 'write' && args.length >= 2 && args[1] is Map) {
            final values = Map<String, dynamic>.from(args[1]);
            if (values.containsKey(invalidField)) {
              values.remove(invalidField);
              final newArgs = List.from(args);
              newArgs[1] = values;
              return await call(model, method, newArgs, kwargs);
            }
          }

          if (method == 'create' && args.length >= 1 && args[0] is Map) {
            final values = Map<String, dynamic>.from(args[0]);
            if (values.containsKey(invalidField)) {
              values.remove(invalidField);
              final newArgs = List.from(args);
              newArgs[0] = values;
              return await call(model, method, newArgs, kwargs);
            }
          }

          if (kwargs != null &&
              kwargs.containsKey('order') &&
              kwargs['order'] is String) {
            final order = kwargs['order'] as String;
            if (order.contains(invalidField!)) {
              final parts = order.split(',').map((e) => e.trim()).toList();
              parts.removeWhere(
                (p) =>
                    p.startsWith(invalidField!) ||
                    p.contains(' $invalidField') ||
                    p.contains('$invalidField '),
              );
              final updatedKwargs = Map<String, dynamic>.from(kwargs);
              updatedKwargs['order'] = parts.join(', ');
              return await call(model, method, args, updatedKwargs);
            }
          }

          if (args.isNotEmpty && args[0] is List) {
            final domain = args[0] as List;
            if (_containsFieldInDomain(domain, invalidField!)) {
              final newArgs = List.from(args);
              newArgs[0] = _cleanDomain(domain, invalidField!);
              return await call(model, method, newArgs, kwargs);
            }
          }
        }
      }

      if (e is OdooException) {
        throw Exception(e.message);
      }
      rethrow;
    }
  }

  /// Executes a keyword-based Odoo RPC call (callKw) with company context.
  Future<dynamic> callKw(Map<String, dynamic> params) async {
    return await OdooSessionManager.callKwWithCompany(params);
  }

  /// Executes a keyword-based Odoo RPC call without adding company context.
  Future<dynamic> callKwWithoutCompany(Map<String, dynamic> params) async {
    return await OdooSessionManager.callKwWithoutCompany(params);
  }

  /// Alias for [getDatabases] to fetch available databases for a URL.
  Future<List<String>> listDatabasesForUrl(String serverUrl) async {
    return getDatabases(serverUrl);
  }

  /// Attempts to automatically discover the default database name from an Odoo server.
  static Future<String?> getDefaultDatabase(String baseUrl) async {
    try {
      String cleanUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      if (cleanUrl.endsWith('/odoo')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 5);
      }

      final client = http.Client();

      String cookieHeader = '';

      try {
        Future<String?> _tryCustomDbEndpoint(String base) async {
          final uri = Uri.parse('$base/mobo/db');

          try {
            final resp = await client.get(
              uri,
              headers: {
                'Accept': 'application/json',
                'Accept': 'application/json',
                'User-Agent': _userAgent,
                'X-Requested-With': 'XMLHttpRequest',
              },
            );
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              final body = resp.body;
              final json = convert.jsonDecode(body);
              if (json is Map &&
                  json['db'] is String &&
                  (json['db'] as String).isNotEmpty) {
                return json['db'] as String;
              }
            }
          } catch (_) {}
          return null;
        }

        final customDb =
            await _tryCustomDbEndpoint(cleanUrl) ??
            await _tryCustomDbEndpoint('$cleanUrl/odoo');
        if (customDb != null && customDb.isNotEmpty) {
          return customDb;
        }

        String _mergeCookies(String? setCookie, String current) {
          if (setCookie == null || setCookie.isEmpty) return current;

          final Map<String, String> cookiesMap = {};

          if (current.isNotEmpty) {
            final split = current.split(';');
            for (var part in split) {
              final pair = part.trim().split('=');
              if (pair.length >= 2) {
                cookiesMap[pair[0].trim()] = pair[1].trim();
              }
            }
          }

          final newCookies = setCookie.split(RegExp(r',(?=[^;]+?=)'));
          for (var cookie in newCookies) {
            final firstPart = cookie.split(';')[0].trim();
            final pair = firstPart.split('=');
            if (pair.length >= 2) {
              final name = pair[0].trim();
              final value = pair[1].trim();

              if (name == 'session_id' ||
                  name == 'db' ||
                  name == 'last_used_database') {
                cookiesMap[name] = value;
              }
            }
          }

          return cookiesMap.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; ');
        }

        final warmRoot = await client.get(
          Uri.parse('$cleanUrl/'),
          headers: {'User-Agent': _userAgent},
        );

        cookieHeader = _mergeCookies(
          warmRoot.headers['set-cookie'],
          cookieHeader,
        );

        final dbFromRoot =
            _extractDbFromHtml(warmRoot.body) ??
            _extractDbFromCookies(warmRoot.headers['set-cookie']);
        if (dbFromRoot != null) return dbFromRoot;

        final warmOdoo = await client.get(
          Uri.parse('$cleanUrl/odoo'),
          headers: {'User-Agent': _userAgent},
        );

        cookieHeader = _mergeCookies(
          warmOdoo.headers['set-cookie'],
          cookieHeader,
        );

        final dbFromOdoo =
            _extractDbFromHtml(warmOdoo.body) ??
            _extractDbFromCookies(warmOdoo.headers['set-cookie']);
        if (dbFromOdoo != null) return dbFromOdoo;

        final warmLogin = await client.get(
          Uri.parse('$cleanUrl/web/login'),
          headers: {'User-Agent': _userAgent},
        );

        cookieHeader = _mergeCookies(
          warmLogin.headers['set-cookie'],
          cookieHeader,
        );

        final dbFromLogin =
            _extractDbFromHtml(warmLogin.body) ??
            _extractDbFromCookies(warmLogin.headers['set-cookie']);
        if (dbFromLogin != null) return dbFromLogin;

        Future<String?> _tryRedirectProbe(String path, String cookies) async {
          final uri = Uri.parse('$cleanUrl$path');

          final req = http.Request('GET', uri)
            ..followRedirects = false
            ..headers.addAll({
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'User-Agent': _userAgent,
            });
          final streamed = await client.send(req);
          final status = streamed.statusCode;
          final loc =
              streamed.headers['location'] ?? streamed.headers['Location'];

          if ((status == 302 ||
                  status == 303 ||
                  status == 307 ||
                  status == 308) &&
              loc != null) {
            try {
              final locUri = Uri.parse(
                loc.startsWith('http') ? loc : ('$cleanUrl$loc'),
              );
              final redirectParam = locUri.queryParameters['redirect'];
              if (redirectParam != null && redirectParam.isNotEmpty) {
                final inner = Uri.parse(redirectParam);
                final dbParam = inner.queryParameters['db'];
                if (dbParam != null && dbParam.isNotEmpty) {
                  return dbParam;
                }
              }

              final dbParam = locUri.queryParameters['db'];
              if (dbParam != null && dbParam.isNotEmpty) {
                return dbParam;
              }

              if (locUri.path.contains('/web/login')) {
                final loginResp = await client.get(
                  locUri,
                  headers: {
                    if (cookies.isNotEmpty) 'Cookie': cookies,
                    'Accept':
                        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'Accept':
                        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                    'User-Agent': _userAgent,
                  },
                );
                if (loginResp.statusCode >= 200 && loginResp.statusCode < 300) {
                  final body = loginResp.body;
                  final db = _extractDbFromHtml(body);
                  if (db != null) {
                    return db;
                  }
                }
              }
            } catch (_) {}
          } else if (status >= 200 && status < 300) {
            try {
              final resp = await http.Response.fromStream(streamed);
              final body = resp.body;

              final db = _extractDbFromHtml(body);
              if (db != null) {
                return db;
              }
            } catch (e) {}
          }
          return null;
        }

        final dbFromRedirect =
            await _tryRedirectProbe('/web/database/selector', cookieHeader) ??
            await _tryRedirectProbe('/odoo', cookieHeader) ??
            await _tryRedirectProbe('/', cookieHeader);
        if (dbFromRedirect != null && dbFromRedirect.isNotEmpty) {
          return dbFromRedirect;
        }

        Future<String?> _trySessionInfo(String base, String cookies) async {
          final uri = Uri.parse('$base/web/session/get_session_info');

          final resp = await client.post(
            uri,
            headers: {
              if (cookies.isNotEmpty) 'Cookie': cookies,
              'Content-Type': 'application/json',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer': '$base/web/login',
              'User-Agent': _userAgent,
            },
            body: convert.jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {},
            }),
          );

          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            try {
              final json = convert.jsonDecode(resp.body);
              if (json is Map) {
                final result = json['result'];
                final sessionInfo = (result is Map
                    ? (result['session_info'] ?? result)
                    : null);
                final direct = (sessionInfo is Map
                    ? sessionInfo['db']
                    : (json['db'] ?? json['session_info']?['db']));
                if (direct is String && direct.isNotEmpty) {
                  return direct;
                }

                final scraped = _extractDbFromHtml(resp.body);
                if (scraped != null) return scraped;
              }
            } catch (e) {
              final scraped = _extractDbFromHtml(resp.body);
              if (scraped != null) return scraped;
            }
          }
          return null;
        }

        String? dbFromSession = await _trySessionInfo(cleanUrl, cookieHeader);
        if (dbFromSession == null) {
          dbFromSession = await _trySessionInfo('$cleanUrl/odoo', cookieHeader);
        }
        if (dbFromSession == null) {
          Future<String?> trySessionInfoGet(String base, String cookies) async {
            final uri = Uri.parse('$base/web/session/get_session_info');

            final resp = await client.get(
              uri,
              headers: {
                if (cookies.isNotEmpty) 'Cookie': cookies,
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'X-Requested-With': 'XMLHttpRequest',
                'Referer': '$base/web/login',
                'User-Agent': _userAgent,
              },
            );

            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              try {
                final json = convert.jsonDecode(resp.body);
                if (json is Map) {
                  final direct = (json['db'] ?? json['session_info']?['db']);
                  if (direct is String && direct.isNotEmpty) {
                    return direct;
                  }
                  final scraped = _extractDbFromHtml(resp.body);
                  if (scraped != null) return scraped;
                }
              } catch (e) {
                final scraped = _extractDbFromHtml(resp.body);
                if (scraped != null) return scraped;
              }
            }
            return null;
          }

          dbFromSession =
              await trySessionInfoGet(cleanUrl, cookieHeader) ??
              await trySessionInfoGet('$cleanUrl/odoo', cookieHeader);
        }
        if (dbFromSession != null && dbFromSession.isNotEmpty) {
          return dbFromSession;
        }
      } finally {
        client.close();
      }

      try {
        final rpcClient = OdooClient(cleanUrl);

        final info = await rpcClient.callRPC(
          '/web/session/get_session_info',
          'call',
          {},
        );
        if (info is Map &&
            info['db'] is String &&
            (info['db'] as String).isNotEmpty) {
          return info['db'] as String;
        }
      } catch (_) {}

      final probeDb = await _probeDbWithRpc(cleanUrl, cookies: cookieHeader);
      if (probeDb != null) return probeDb;
    } catch (e) {
      try {
        final probeDb = await _probeDbWithRpc(baseUrl);
        if (probeDb != null) return probeDb;
      } catch (_) {}
    }
    return null;
  }


  /// Reads specified fields for a list of record IDs from an Odoo model.
  Future<List<Map<String, dynamic>>> read(
    String model,
    List<int> ids, [
    List<String>? fields,
  ]) async {
    final result = await call(
      model,
      'read',
      [ids],
      {if (fields != null) 'fields': fields},
    );
    return List<Map<String, dynamic>>.from(result);
  }

  /// Searches for records matching a domain and reads specified fields for them.
  Future<List<Map<String, dynamic>>> searchRead(
    String model, [
    List domain = const [],
    List<String>? fields,
    int offset = 0,
    int limit = 80,
    String? order,
  ]) async {
    final kwargs = <String, dynamic>{'offset': offset, 'limit': limit};
    if (fields != null) {
      kwargs['fields'] = fields;
    }
    if (order != null) {
      kwargs['order'] = order;
    }

    final result = await call(model, 'search_read', [domain], kwargs);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Creates a new record in an Odoo model with the provided values.
  Future<int> create(String model, Map<String, dynamic> values) async {
    final result = await call(model, 'create', [values]);
    if (result is List && result.isNotEmpty) {
      return result[0] as int;
    }
    return result as int;
  }

  /// Updates one or more records in an Odoo model with the provided values.
  Future<bool> write(
    String model,
    List<int> ids,
    Map<String, dynamic> values,
  ) async {
    final result = await call(model, 'write', [ids, values]);

    return result as bool;
  }

  /// Deletes one or more records from an Odoo model.
  Future<bool> unlink(String model, List<int> ids) async {
    final result = await call(model, 'unlink', [ids]);
    return result as bool;
  }

  /// Fetches the count of customer invoices (`out_invoice`) matching an optional domain.
  Future<int> getInvoiceCount({List? domain}) async {
    final invoiceDomain =
        domain ??
        [
          ['move_type', '=', 'out_invoice'],
        ];

    final result = await call('account.move', 'search_count', [invoiceDomain]);
    return result as int;
  }

  /// Fetches the count of records in a model matching an optional domain.
  Future<int> getCount(String model, {List<dynamic>? domain}) async {
    final result = await call(model, 'search_count', [domain ?? []]);
    return result as int;
  }

  /// Checks if a specific Odoo module is installed and active.
  Future<bool> isModuleInstalled(String moduleName) async {
    try {
      final count = await getCount(
        'ir.module.module',
        domain: [
          ['name', '=', moduleName],
          ['state', '=', 'installed'],
        ],
      );
      final isInstalled = count > 0;

      return isInstalled;
    } catch (e) {
      try {
        await call('account.move', 'search_count', [[]], {'limit': 1});

        return true;
      } catch (fallbackError) {
        return false;
      }
    }
  }

  /// Fetches a list of customer invoices with standard fields and pagination.
  Future<List<Map<String, dynamic>>> getInvoices({
    List? domain,
    int offset = 0,
    int limit = 20,
  }) async {
    final invoiceDomain =
        domain ??
        [
          ['move_type', '=', 'out_invoice'],
        ];

    return await searchRead(
      'account.move',
      invoiceDomain,
      [
        'name',
        'partner_id',
        'invoice_date',
        'invoice_date_due',
        'amount_total',
        'amount_residual',
        'state',
        'payment_state',
        'move_type',
        'currency_id',
        'company_id',
      ],
      offset,
      limit,
    );
  }

  /// Fetches comprehensive details for a specific invoice, including lines and taxes.
  Future<Map<String, dynamic>> getInvoiceDetails(int invoiceId) async {
    final List<String> primaryFields = [
      'name',
      'partner_id',
      'invoice_date',
      'invoice_date_due',
      'amount_total',
      'amount_untaxed',
      'amount_tax',
      'amount_residual',
      'state',
      'payment_state',
      'move_type',
      'currency_id',
      'company_id',
      'journal_id',
      'ref',
      'invoice_origin',
      'narration',
      'invoice_line_ids',
      'line_ids',
      'create_date',
      'write_date',
      'invoice_user_id',
      'team_id',
      'partner_bank_id',
      'delivery_date',
      'invoice_incoterm_id',
      'incoterm_location',
      'fiscal_position_id',
      'secured',
      'auto_post',
      'campaign_id',
      'medium_id',
      'source_id',
      'invoice_payment_term_id',
      'preferred_payment_method_line_id',
    ];

    final List<String> fallbackFields = [
      'name',
      'partner_id',
      'invoice_date',
      'invoice_date_due',
      'amount_total',
      'amount_untaxed',
      'amount_tax',
      'amount_residual',
      'state',
      'payment_state',
      'move_type',
      'currency_id',
      'company_id',
      'journal_id',
      'ref',
      'invoice_origin',
      'narration',
      'invoice_line_ids',
      'create_date',
      'write_date',
    ];

    Map<String, dynamic>? header;

    try {
      final res = await read('account.move', [invoiceId], primaryFields);
      if (res.isNotEmpty) header = res.first;
    } catch (e) {}

    header ??= (() {
      return null;
    })();
    if (header == null) {
      final res = await read('account.move', [invoiceId], fallbackFields);
      if (res.isEmpty) throw Exception('Invoice not found');
      header = res.first;
    }

    try {
      final ids = List<int>.from(header['invoice_line_ids'] ?? const []);
      if (ids.isNotEmpty) {
        final lines = await read('account.move.line', ids, [
          'name',
          'product_id',
          'quantity',
          'price_unit',
          'price_subtotal',
          'price_total',
          'discount',
          'product_uom_id',
          'tax_ids',
        ]);

        final Set<int> allTaxIds = {};
        for (var line in lines) {
          if (line['tax_ids'] != null && line['tax_ids'] is List) {
            allTaxIds.addAll(List<int>.from(line['tax_ids']));
          }
        }
        if (allTaxIds.isNotEmpty) {
          final taxes = await read('account.tax', allTaxIds.toList(), [
            'name',
            'amount',
            'description',
          ]);
          final taxMap = {for (var t in taxes) t['id']: t};
          for (var line in lines) {
            if (line['tax_ids'] != null && line['tax_ids'] is List) {
              final lineTaxIds = List<int>.from(line['tax_ids']);
              final lineTaxDetails = lineTaxIds
                  .map((id) => taxMap[id])
                  .where((t) => t != null)
                  .toList();
              line['tax_details'] = lineTaxDetails;
            }
          }
        }
        header['invoice_lines'] = lines;
      } else {
        header['invoice_lines'] = <Map<String, dynamic>>[];
      }
    } catch (e) {
      header['invoice_lines'] = <Map<String, dynamic>>[];
    }

    try {
      final jids = List<int>.from(header['line_ids'] ?? const []);
      if (jids.isNotEmpty) {
        final journalItems = await read('account.move.line', jids, [
          'account_id',
          'name',
          'partner_id',
          'debit',
          'credit',
          'balance',
          'amount_currency',
          'currency_id',
        ]);
        header['journal_items'] = journalItems;
      }
    } catch (e) {}

    return header;
  }

  /// Fetches all payments associated with a specific invoice.
  Future<List<Map<String, dynamic>>> getInvoicePayments(int invoiceId) async {
    try {
      final payments = await searchRead(
        'account.payment',
        [
          [
            'reconciled_invoice_ids',
            'in',
            [invoiceId],
          ],
        ],
        [
          'date',
          'amount',
          'payment_method_line_id',
          'partner_id',
          'state',
          'ref',
        ],
        0,
        50,
      );

      return payments;
    } catch (e) {
      return [];
    }
  }

  /// Fetches available payment journals for a given company.
  Future<List<Map<String, dynamic>>> getPaymentJournals({
    int? companyId,
  }) async {
    final domain = [
      [
        'type',
        'in',
        ['bank', 'cash'],
      ],
      ['active', '=', true],
    ];

    if (companyId != null) {
      domain.add(['company_id', '=', companyId]);
    }

    final journals = await searchRead(
      'account.journal',
      domain,
      ['name', 'type', 'inbound_payment_method_line_ids', 'company_id'],
      0,
      200,
    );
    return journals;
  }

  /// Fetches payment method lines for a specific journal.
  Future<List<Map<String, dynamic>>> getPaymentMethodLines(
    int journalId,
  ) async {
    try {
      final jrnl = await read(
        'account.journal',
        [journalId],
        ['inbound_payment_method_line_ids'],
      );
      if (jrnl.isEmpty) return [];
      final List ids = jrnl.first['inbound_payment_method_line_ids'] ?? [];
      if (ids.isEmpty) return [];

      final methods = await read(
        'account.payment.method.line',
        List<int>.from(ids),
        ['name', 'payment_method_id', 'payment_type', 'journal_id'],
      );
      return methods;
    } catch (e) {
      return [];
    }
  }

  /// Creates a draft customer invoice in Odoo.
  Future<int> createInvoice(Map<String, dynamic> invoiceData) async {
    final result = await call('account.move', 'create', [invoiceData]);
    final int invoiceId;
    if (result is List && result.isNotEmpty) {
      invoiceId = result[0] as int;
    } else {
      invoiceId = result as int;
    }

    final createdInvoice = await read(
      'account.move',
      [invoiceId],
      ['partner_id', 'journal_id', 'move_type', 'state', 'invoice_line_ids'],
    );

    return invoiceId;
  }

  /// Updates an existing draft invoice with new data.
  Future<bool> updateInvoice(
    int invoiceId,
    Map<String, dynamic> invoiceData,
  ) async {
    return await write('account.move', [invoiceId], invoiceData);
  }

  /// Confirms a draft invoice (posts it) in Odoo.
  Future<bool> confirmInvoice(int invoiceId) async {
    try {
      final recs = await read(
        'account.move',
        [invoiceId],
        [
          'state',
          'partner_id',
          'invoice_line_ids',
          'journal_id',
          'move_type',
          'amount_total',
        ],
      );
      if (recs.isEmpty) {
        throw Exception('Invoice not found');
      }

      final invoiceData = recs.first;
      final state = invoiceData['state'];

      if (state == 'posted') {
        return true;
      }
      if (state != 'draft') {
        throw Exception(
          'Invoice must be in draft to confirm. Current state: $state',
        );
      }

      if (invoiceData['partner_id'] == null ||
          (invoiceData['partner_id'] is List &&
              invoiceData['partner_id'].isEmpty) ||
          (invoiceData['partner_id'] is bool &&
              invoiceData['partner_id'] == false)) {
        await Future.delayed(const Duration(milliseconds: 200));
        final refreshedRecs = await read(
          'account.move',
          [invoiceId],
          ['partner_id'],
        );
        if (refreshedRecs.isNotEmpty) {
          final refreshedPartnerId = refreshedRecs.first['partner_id'];

          if (refreshedPartnerId != null &&
              !(refreshedPartnerId is bool && refreshedPartnerId == false) &&
              !(refreshedPartnerId is List && refreshedPartnerId.isEmpty)) {
          } else {
            throw Exception(
              'The field \'Customer\' is required, please complete it to validate the Customer Invoice.',
            );
          }
        } else {
          throw Exception(
            'The field \'Customer\' is required, please complete it to validate the Customer Invoice.',
          );
        }
      }

      if (invoiceData['journal_id'] == null ||
          (invoiceData['journal_id'] is List &&
              invoiceData['journal_id'].isEmpty) ||
          (invoiceData['journal_id'] is bool &&
              invoiceData['journal_id'] == false)) {
        throw Exception(
          'The field \'Journal\' is required, please complete it to validate the Customer Invoice.',
        );
      }

      if (invoiceData['invoice_line_ids'] == null ||
          (invoiceData['invoice_line_ids'] is List &&
              invoiceData['invoice_line_ids'].isEmpty)) {
        throw Exception(
          'You need to add at least one invoice line to validate the Customer Invoice.',
        );
      }

      final lineIds = List<int>.from(invoiceData['invoice_line_ids'] ?? []);
      if (lineIds.isNotEmpty) {
        final lines = await read('account.move.line', lineIds, [
          'name',
          'account_id',
          'quantity',
          'price_unit',
        ]);

        for (final line in lines) {
          if (line['name'] == null || line['name'].toString().trim().isEmpty) {
            throw Exception('All invoice lines must have a description.');
          }
          if (line['account_id'] == null ||
              (line['account_id'] is List && line['account_id'].isEmpty) ||
              (line['account_id'] is bool && line['account_id'] == false)) {
            throw Exception('All invoice lines must have an account assigned.');
          }
          if ((line['quantity'] ?? 0.0) <= 0) {
            throw Exception(
              'All invoice lines must have a quantity greater than 0.',
            );
          }
        }
      }

      var result = await call('account.move', 'action_post', [
        [invoiceId],
      ]);

      if (result != true) {
        await Future.delayed(const Duration(milliseconds: 1000));

        final retryRecs = await read(
          'account.move',
          [invoiceId],
          ['state', 'partner_id'],
        );

        if (retryRecs.isNotEmpty && retryRecs.first['state'] == 'draft') {
          result = await call('account.move', 'action_post', [
            [invoiceId],
          ]);
        } else if (retryRecs.isNotEmpty &&
            retryRecs.first['state'] == 'posted') {
          result = true;
        }
      }

      if (result != true) {
        final finalCheck = await read('account.move', [invoiceId], ['state']);
        if (finalCheck.isNotEmpty && finalCheck.first['state'] == 'posted') {
          result = true;
        }
      }

      return result == true;
    } catch (e) {
      rethrow;
    }
  }

  /// Cancels an existing invoice in Odoo.
  Future<bool> cancelInvoice(int invoiceId) async {
    try {
      final result = await call('account.move', 'button_cancel', [
        [invoiceId],
      ]);

      final verification = await read('account.move', [invoiceId], ['state']);
      if (verification.isNotEmpty) {
        final state = verification.first['state'];

        return state == 'cancel';
      }

      return result == true;
    } catch (e) {
      rethrow;
    }
  }

  /// Resets a cancelled invoice back to draft state.
  Future<bool> resetInvoiceToDraft(int invoiceId) async {
    try {
      final currentState = await read('account.move', [invoiceId], ['state']);
      if (currentState.isNotEmpty) {
        final state = currentState.first['state'];

        if (state == 'draft') {
          return true;
        }

        if (state == 'cancel') {
          final result = await call('account.move', 'button_draft', [
            [invoiceId],
          ]);

          final verification = await read(
            'account.move',
            [invoiceId],
            ['state'],
          );
          if (verification.isNotEmpty) {
            final newState = verification.first['state'];

            return newState == 'draft';
          }
          return result == true;
        }
      }

      final result = await call('account.move', 'button_draft', [
        [invoiceId],
      ]);

      final verification = await read('account.move', [invoiceId], ['state']);
      if (verification.isNotEmpty) {
        final state = verification.first['state'];

        return state == 'draft';
      }

      return result == true;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> duplicateInvoice(int invoiceId) async {
    try {
      final result = await call('account.move', 'copy', [
        [invoiceId],
      ]);

      if (result is int) {
        return result;
      } else if (result is List && result.isNotEmpty && result[0] is int) {
        return result[0] as int;
      } else {
        throw Exception('Failed to duplicate invoice: Invalid response');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> registerPayment(
    int invoiceId,
    double amount,
    dynamic paymentMethod, {
    String? paymentReference,
    DateTime? paymentDate,
    String? notes,
    int? journalId,
    int? paymentMethodLineId,
  }) async {
    try {
      final inv = await read(
        'account.move',
        [invoiceId],
        [
          'state',
          'payment_state',
          'amount_residual',
          'partner_id',
          'currency_id',
          'company_id',
          'name',
        ],
      );
      if (inv.isEmpty) {
        throw Exception('Invoice not found');
      }
      final invData = inv.first;
      if (invData['state'] != 'posted') {
        throw Exception(
          'Invoice must be confirmed/posted before registering a payment.',
        );
      }
      final residual = (invData['amount_residual'] ?? 0.0).toDouble();
      if (residual <= 0) {
        throw Exception('Invoice is already fully paid.');
      }
      if (amount <= 0) {
        throw Exception('Payment amount must be greater than 0.');
      }
      if (amount > residual + 1e-6) {
        throw Exception(
          'Payment amount cannot exceed the remaining due (${residual.toStringAsFixed(2)}).',
        );
      }

      if (journalId == null) {
        throw Exception('Please select a payment journal.');
      }
      if (paymentMethodLineId == null) {
        throw Exception('Please select a payment method.');
      }

      final methodLine = await read(
        'account.payment.method.line',
        [paymentMethodLineId],
        ['journal_id', 'payment_type', 'name'],
      );
      if (methodLine.isEmpty) {
        throw Exception('Selected payment method is not available.');
      }
      final ml = methodLine.first;
      final mlJournalId =
          (ml['journal_id'] is List && ml['journal_id'].isNotEmpty)
          ? ml['journal_id'][0] as int
          : null;
      if (mlJournalId != journalId) {
        throw Exception(
          'Selected payment method does not belong to the chosen journal.',
        );
      }
      if (ml['payment_type'] != 'inbound') {
        throw Exception(
          'Selected payment method is not valid for customer payments.',
        );
      }

      final ctx = {
        'active_model': 'account.move',
        'active_ids': [invoiceId],
        'company_id':
            (invData['company_id'] is List && invData['company_id'].isNotEmpty)
            ? invData['company_id'][0] as int
            : null,
      };

      final wizardData = {
        'payment_type': 'inbound',
        'partner_type': 'customer',
        'partner_id': invData['partner_id'][0],
        'amount': amount,
        'currency_id': invData['currency_id'][0],
        'payment_date': (paymentDate ?? DateTime.now()).toIso8601String().split(
          'T',
        )[0],
        'communication':
            (notes ??
            paymentReference ??
            'Payment for ${invData['name'] ?? 'invoice'}'),
        'payment_method_line_id': paymentMethodLineId,
        'journal_id': journalId,
      };

      final wizardId = await call(
        'account.payment.register',
        'create',
        [wizardData],
        {'context': ctx},
      );

      await call(
        'account.payment.register',
        'action_create_payments',
        [
          [wizardId],
        ],
        {'context': ctx},
      );

      return true;
    } catch (e) {
      throw Exception('Payment registration failed: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getJournals({
    String? journalType,
    int? companyId,
  }) async {
    List<dynamic> domain = [];
    if (journalType != null) {
      domain.add(['type', '=', journalType]);
    }
    if (companyId != null) {
      domain.add(['company_id', '=', companyId]);
    }
    return await searchRead('account.journal', domain, [
      'name',
      'code',
      'type',
      'currency_id',
      'company_id',
    ]);
  }

  Future<List<Map<String, dynamic>>> getAccounts({String? accountType}) async {
    List<dynamic> domain = [];

    final version = await getServerVersion();

    bool useActiveField = false;
    bool useDeprecatedField = false;
    bool noFilter = false;

    if (version != null) {
      if (version.contains('19') || _isVersionAtLeast(version, '19.0')) {
        noFilter = true;
      } else if (version.contains('18') || _isVersionAtLeast(version, '18.0')) {
        noFilter = true;
      } else if (version.contains('17') || _isVersionAtLeast(version, '17.0')) {
        useActiveField = true;
      } else {
        useDeprecatedField = true;
      }
    }

    if (useActiveField) {
      domain.add(['active', '=', true]);
    } else if (useDeprecatedField) {
      domain.add(['deprecated', '=', false]);
    }

    if (accountType != null) {
      domain.add([
        version != null && (useActiveField || noFilter)
            ? 'account_type'
            : 'user_type_id',
        '=',
        accountType,
      ]);
    }

    try {
      return await searchRead('account.account', domain, [
        'name',
        'code',
        version != null && (useActiveField || noFilter)
            ? 'account_type'
            : 'user_type_id',
        'reconcile',
        'currency_id',
      ]);
    } catch (e) {
      try {
        List<dynamic> fallbackDomain = [];
        if (accountType != null) {
          fallbackDomain.add([
            version != null && (useActiveField || noFilter)
                ? 'account_type'
                : 'user_type_id',
            '=',
            accountType,
          ]);
        }

        return await searchRead('account.account', fallbackDomain, [
          'name',
          'code',
          version != null && (useActiveField || noFilter)
              ? 'account_type'
              : 'user_type_id',
          'reconcile',
          'currency_id',
        ]);
      } catch (fallbackError) {
        throw Exception(
          'Failed to load accounts. Please check your Odoo server configuration.',
        );
      }
    }
  }

  Future<String?> getServerVersion() async {
    final session = await OdooSessionManager.getCurrentSession();
    return session?.serverVersion;
  }

  bool _isVersionAtLeast(String currentVersion, String targetVersion) {
    try {
      final regExp = RegExp(r'(\d+(\.\d+)?)');
      final currentMatch = regExp.firstMatch(currentVersion);
      final targetMatch = regExp.firstMatch(targetVersion);

      if (currentMatch != null && targetMatch != null) {
        double current = double.parse(currentMatch.group(1)!);
        double target = double.parse(targetMatch.group(1)!);
        return current >= target;
      }
    } catch (e) {}
    return false;
  }

  Future<List<Map<String, dynamic>>> getTaxes({
    String? taxType,
    int? companyId,
  }) async {
    List<dynamic> domain = [
      ['active', '=', true],
    ];
    if (taxType != null) {
      domain.add(['type_tax_use', '=', taxType]);
    }
    if (companyId != null) {
      domain.add(['company_id', '=', companyId]);
    }
    return await searchRead('account.tax', domain, [
      'name',
      'amount',
      'type_tax_use',
      'amount_type',
      'description',
    ]);
  }

  Future<List<Map<String, dynamic>>> searchCustomers(
    String query, {
    int limit = 100,
  }) async {
    return await searchRead(
      'res.partner',
      [
        ['active', '=', true],
        '|',
        ['name', 'ilike', query],
        ['email', 'ilike', query],
      ],
      [
        'name',
        'display_name',
        'email',
        'phone',
        'vat',
        'street',
        'city',
        'image_128',
      ],
      0,
      limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(
    String query, {
    int limit = 100,
  }) async {
    return await searchRead(
      'product.product',
      [
        ['sale_ok', '=', true],
        ['active', '=', true],
        if (query.isNotEmpty) ...[
          '|',
          ['name', 'ilike', query],
          ['default_code', 'ilike', query],
        ],
      ],
      [
        'name',
        'list_price',
        'default_code',
        'uom_id',
        'taxes_id',
        'barcode',
        'image_128',
        'type',
        'qty_available',
      ],
      0,
      limit,
    );
  }

  Future<List<Map<String, dynamic>>> getCountries() async {
    return await searchRead('res.country', [], ['id', 'name', 'code'], 0, 300);
  }

  Future<List<Map<String, dynamic>>> getStatesByCountry(int countryId) async {
    return await searchRead(
      'res.country.state',
      [
        ['country_id', '=', countryId],
      ],
      ['id', 'name', 'code'],
      0,
      200,
    );
  }

  Future<List<Map<String, String>>> getTitleOptions() async {
    try {
      final titles = await searchRead(
        'res.partner.title',
        [],
        ['id', 'name', 'shortcut'],
        0,
        50,
      );
      return titles
          .map(
            (t) => {
              'id': t['id'].toString(),
              'name': t['name']?.toString() ?? '',
              'shortcut': t['shortcut']?.toString() ?? '',
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getCurrencies() async {
    return await searchRead(
      'res.currency',
      [
        ['active', '=', true],
      ],
      ['id', 'name', 'symbol'],
      0,
      100,
    );
  }

  Future<List<Map<String, dynamic>>> getLanguages() async {
    return await searchRead(
      'res.lang',
      [
        ['active', '=', true],
      ],
      ['id', 'name', 'code'],
      0,
      100,
    );
  }

  Future<bool> restoreFromPrefs() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session != null) {
      initialize(session.serverUrl, session.database);
      _uid = session.userId;
      _password = session.password;
      _sessionId = session.sessionId;
      return true;
    }
    return false;
  }

  bool get isAuthenticated => _uid != null;

  Map<String, dynamic> get userInfo => {
    'uid': _uid,
    'session_id': _sessionId,
    'context': _context,
  };

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('odoo_uid');
    await prefs.remove('odoo_password');
    await prefs.remove('odoo_session_id');

    _uid = null;
    _password = null;
    _sessionId = null;
    _context = {};
  }

  static String? _extractDbFromCookies(String? setCookie) {
    if (setCookie == null) return null;

    final matchLast = RegExp(
      r'last_used_database=([^;]+)',
    ).firstMatch(setCookie);
    if (matchLast != null) {
      final db = matchLast.group(1)?.trim();
      if (db != null && db.isNotEmpty && db != 'null' && db != 'false') {
        return db;
      }
    }

    final matchDb = RegExp(r'db=([^;]+)').firstMatch(setCookie);
    if (matchDb != null) {
      final db = matchDb.group(1)?.trim();
      if (db != null && db.isNotEmpty && db != 'null' && db != 'false') {
        return db;
      }
    }

    return null;
  }

  static String? _extractDbFromHtml(String body) {
    try {
      final assignmentMatch = RegExp(
        r'odoo\.__session_info__\s*=\s*(\{[\s\S]*?\});',
      ).firstMatch(body);
      if (assignmentMatch != null) {
        final jsonStr = assignmentMatch.group(1);
        if (jsonStr != null) {
          try {
            final data = convert.jsonDecode(jsonStr);
            if (data is Map) {
              if (data['db'] is String && (data['db'] as String).isNotEmpty) {
                return data['db'];
              }
            }
          } catch (e) {}
        }
      }

      final scriptRe = RegExp(r'<script[^>]*>([\s\S]*?)<\/script>');
      for (final match in scriptRe.allMatches(body)) {
        final content = match.group(1);
        if (content == null || content.isEmpty) continue;

        if (content.trim().startsWith('{')) {
          try {
            final data = convert.jsonDecode(content.trim());
            if (data is Map &&
                data['db'] is String &&
                (data['db'] as String).isNotEmpty) {
              return data['db'];
            }
          } catch (_) {}
        }

        final dbMatch = RegExp(
          r'''['"]db['"]\s*:\s*['"]([^'"]+)['"]''',
        ).firstMatch(content);
        if (dbMatch != null) {
          final db = dbMatch.group(1);
          if (db != null && db.isNotEmpty && db != 'null' && db != 'false') {
            return db;
          }
        }
      }

      final inputRe = RegExp(
        r'''<input[^>]*name=['"]db['"][^>]*value=['"]([^'"]+)['"]''',
        caseSensitive: false,
      );
      final inputMatch = inputRe.firstMatch(body);
      if (inputMatch != null) {
        final db = inputMatch.group(1);
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final inputRe2 = RegExp(
        r'''<input[^>]*value=['"]([^'"]+)['"][^>]*name=['"]db['"]''',
        caseSensitive: false,
      );
      final inputMatch2 = inputRe2.firstMatch(body);
      if (inputMatch2 != null) {
        final db = inputMatch2.group(1);
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final selectRe1 = RegExp(
        r'''<select[^>]*name=['"]db['"][\s\S]*?<option[^>]*selected[^>]*>([^<]+)</option>''',
        caseSensitive: false,
      );
      final selectMatch1 = selectRe1.firstMatch(body);
      if (selectMatch1 != null) {
        final db = selectMatch1.group(1)?.trim();
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final selectRe2 = RegExp(
        r'''<select[^>]*name=['"]db['"][\s\S]*?<option[^>]*value=['"]([^'"]+)['"][^>]*selected[^>]*>''',
        caseSensitive: false,
      );
      final selectMatch2 = selectRe2.firstMatch(body);
      if (selectMatch2 != null) {
        final db = selectMatch2.group(1)?.trim();
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final globalRe = RegExp(r'''['"]db['"]\s*:\s*['"]([^'"]+)['"]''');
      for (final match in globalRe.allMatches(body)) {
        final db = match.group(1);

        if (db != null &&
            db.isNotEmpty &&
            db != 'null' &&
            db != 'false' &&
            db.length < 64 &&
            !db.contains('{')) {
          return db;
        }
      }

      final hrefRe = RegExp(
        r'''href=['"]/web\?db=([^"&']+)['"]''',
        caseSensitive: false,
      );
      final hrefMatch = hrefRe.firstMatch(body);
      if (hrefMatch != null) {
        final db = hrefMatch.group(1)?.trim();
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final dataDbRe = RegExp(
        r'''data-db=['"]([^"']+)['"]''',
        caseSensitive: false,
      );
      final dataDbMatch = dataDbRe.firstMatch(body);
      if (dataDbMatch != null) {
        final db = dataDbMatch.group(1)?.trim();
        if (db != null && db.isNotEmpty) {
          return db;
        }
      }

      final sessionInfoIndex = body.indexOf('session_info');
      if (sessionInfoIndex != -1) {
        final start = (sessionInfoIndex - 200) < 0
            ? 0
            : (sessionInfoIndex - 200);
        final end = (sessionInfoIndex + 1000) > body.length
            ? body.length
            : (sessionInfoIndex + 1000);
      } else {}
    } catch (_) {}
    return null;
  }

  static Future<String?> _probeDbWithRpc(
    String baseUrl, {
    String? cookies,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$baseUrl/web/session/get_session_info');

      String? extractOdooCookies(String? setCookie, [String? current]) {
        if (setCookie == null) return current;

        final Map<String, String> cookiesMap = {};

        if (current != null && current.isNotEmpty) {
          for (var part in current.split(';')) {
            final pair = part.trim().split('=');
            if (pair.length >= 2) {
              cookiesMap[pair[0].trim()] = pair[1].trim();
            }
          }
        }

        final newCookies = setCookie.split(RegExp(r',(?=[^;]+?=)'));
        for (var cookie in newCookies) {
          final firstPart = cookie.split(';')[0].trim();
          final pair = firstPart.split('=');
          if (pair.length >= 2) {
            final name = pair[0].trim();
            final value = pair[1].trim();
            if (name == 'session_id' ||
                name == 'db' ||
                name == 'last_used_database') {
              cookiesMap[name] = value;
            }
          }
        }

        if (cookiesMap.isEmpty) return null;
        return cookiesMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      }

      Future<http.Response> doPost([String? cookie]) async {
        final merged = extractOdooCookies(cookie, cookies);

        final headers = {
          'Content-Type': 'application/json',
          'Accept':
              'application/json,application/pdf,application/octet-stream,*/*;q=0.8',
          'User-Agent': _userAgent,
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '$baseUrl/web',
          'Origin': baseUrl,
        };
        if (merged != null) {
          headers['Cookie'] = merged;
        }

        return client.post(
          uri,
          headers: headers,
          body: convert.jsonEncode({
            "jsonrpc": "2.0",
            "method": "call",
            "params": {},
            "id": 1,
          }),
        );
      }

      var response = await doPost();

      bool isSessionExpired = false;
      if (response.statusCode == 200) {
        try {
          final json = convert.jsonDecode(response.body);
          if (json is Map && json.containsKey('error')) {
            final error = json['error'];
            if (error is Map) {
              final code = error['code'];
              if (code == 100 ||
                  code == '100' ||
                  error['message']?.toString().contains('Session Expired') ==
                      true) {
                isSessionExpired = true;
              }
            }
          }
        } catch (_) {}
      }

      if (isSessionExpired) {
        final setCookie = response.headers['set-cookie'];
        final mergedCookies = extractOdooCookies(setCookie, cookies);

        if (mergedCookies != null) {
          try {
            final warmUri = Uri.parse('$baseUrl/web');
            await client
                .get(
                  warmUri,
                  headers: {
                    'User-Agent': _userAgent,
                    'Cookie': mergedCookies,
                    'X-Requested-With': 'XMLHttpRequest',
                  },
                )
                .timeout(const Duration(seconds: 5));
          } catch (e) {}

          response = await doPost(mergedCookies);
        } else {
          final cleanHeaders = {
            'Content-Type': 'application/json',
            'Accept':
                'application/json,application/pdf,application/octet-stream,*/*;q=0.8',
            'User-Agent': _userAgent,
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': '$baseUrl/web',
            'Origin': baseUrl,
          };
          response = await client.post(
            uri,
            headers: cleanHeaders,
            body: convert.jsonEncode({
              "jsonrpc": "2.0",
              "method": "call",
              "params": {},
              "id": 1,
            }),
          );
        }
      }

      if (response.statusCode == 200) {
        final body = response.body;
        final json = convert.jsonDecode(body);

        if (json is Map) {
          if (json.containsKey('result') && json['result'] is Map) {
            final result = json['result'] as Map;
            if (result['db'] is String && (result['db'] as String).isNotEmpty) {
              return result['db'];
            }

            if (result['session_info'] is Map &&
                result['session_info']['db'] is String) {
              final db = result['session_info']['db'] as String;
              if (db.isNotEmpty) {
                return db;
              }
            }
          }

          if (json['db'] is String && (json['db'] as String).isNotEmpty) {
            return json['db'];
          }
        }

        final scraped = _extractDbFromHtml(body);
        if (scraped != null) {
          return scraped;
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  static const String _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";

  static bool _containsFieldInDomain(List domain, String field) {
    for (var item in domain) {
      if (item is List) {
        if (item.isNotEmpty && item[0].toString() == field) return true;
        if (_containsFieldInDomain(item, field)) return true;
      }
    }
    return false;
  }

  static List _cleanDomain(List domain, String invalidField) {
    final List cleaned = [];
    for (int i = 0; i < domain.length; i++) {
      final item = domain[i];
      if (item is List) {
        if (item.isNotEmpty && item[0].toString() == invalidField) {
          if (cleaned.isNotEmpty &&
              (cleaned.last == '&' || cleaned.last == '|')) {
            cleaned.removeLast();
          }
          continue;
        } else {
          cleaned.add(_cleanDomain(item, invalidField));
        }
      } else {
        cleaned.add(item);
      }
    }
    return cleaned;
  }
}
