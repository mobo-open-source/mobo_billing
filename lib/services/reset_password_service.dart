import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for handling Odoo password reset flows via web and RPC.
class ResetPasswordService {
  /// What a 404 from Odoo's reset route actually means.
  ///
  /// `/web/reset_password` is served by the optional `auth_signup` module,
  /// whose controller *deliberately* returns 404 when reset is switched off:
  ///
  /// ```python
  /// if not qcontext.get('token') and not qcontext.get('reset_password_enabled'):
  ///     raise werkzeug.exceptions.NotFound()
  /// ```
  ///
  /// `reset_password_enabled` is the `auth_signup.reset_password` system
  /// parameter — Settings → Permissions → "Enable password reset from Login
  /// page". So a 404 is not a transient fault or a wrong URL: it is the
  /// server answering "reset is not offered here", because either that
  /// setting is off or `auth_signup` isn't installed at all.
  ///
  /// Neither clears up by itself, which is why this replaces the old "please
  /// try again later" — that sent users into a retry loop that could never
  /// succeed, and hid the one action that actually resolves it.
  static const String _resetUnavailableMessage =
      'Password reset is not enabled on this server. '
      'Please contact your administrator to reset your password.';

  /// Initiates a password reset email request to the Odoo server.
  static Future<Map<String, dynamic>> sendResetPasswordEmail({
    required String serverUrl,
    required String database,
    required String login,
  }) async {
    try {
      String cleanUrl = serverUrl.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      /// The browser-aligned flow mirrors how Odoo's own web UI performs the
      /// reset, so it is tried first.
      final webFlowResult = await _tryWebInterfaceReset(
        cleanUrl,
        database,
        login,
      );

      /// Only a success short-circuits. Anything else falls through to the
      /// endpoint scan below — the browser-aligned flow failing does not mean
      /// the other reset endpoints will.
      if (webFlowResult['success'] == true) {
        return webFlowResult;
      }

      final possibleEndpoints = [
        '/web/reset_password',
        '/auth_signup/reset_password',
        '/web/signup',
        '/web/database/reset_password',
        '/auth_signup/signup',
      ];

      String? workingEndpoint;
      String? responseBody;
      Map<String, String>? cookies;
      bool requiresRecaptcha = false;

      /// A `?db=` alone is not enough here either: Odoo answers it with a
      /// redirect whose cookie the auto-follow discards, so every endpoint
      /// below would be probed against a database-less session and 404 on a
      /// multi-database host. Bind once, then probe with that session.
      final scanCookies = await _bindDatabaseSession(cleanUrl, database);

      for (final endpoint in possibleEndpoints) {
        try {
          final response = await http
              .get(
                Uri.parse(
                  '$cleanUrl$endpoint?db=${Uri.encodeQueryComponent(database)}',
                ),
                headers: {
                  ..._browserHeaders,
                  if (scanCookies.isNotEmpty)
                    'Cookie': _cookieHeader(scanCookies),
                },
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final body = response.body.toLowerCase();

            bool isValidResetForm = false;

            if (body.contains('password') &&
                (body.contains('reset') || body.contains('forgot'))) {
              /// Odoo's own error pages announce themselves with a
              /// `<code> | <reason>` title, which is what these match.
              ///
              /// A bare `contains('error')` used to sit alongside them and
              /// was actively harmful: Odoo's login layout ships markup and
              /// scripts mentioning "error" on the *successful* reset page
              /// too, so a perfectly good form was liable to be thrown away
              /// and the scan report that no endpoint works.
              if (!body.contains('400 |') && !body.contains('404 |')) {
                if (body.contains('<form') &&
                    (body.contains('name="login"') ||
                        body.contains('type="email"'))) {
                  isValidResetForm = true;
                }
              }
            }

            if (isValidResetForm) {
              workingEndpoint = endpoint;
              responseBody = response.body;

              requiresRecaptcha = _detectRecaptcha(response.body);

              cookies = {...scanCookies};
              final cookieHeader = response.headers['set-cookie'];
              if (cookieHeader != null) {
                cookies.addAll(_parseCookies(cookieHeader));
              }

              break;
            }
          }
        } catch (e) {
          continue;
        }
      }

      if (workingEndpoint == null) {
        return await _tryDirectApiReset(
          cleanUrl,
          database,
          login,
          webFlowResult: webFlowResult,
        );
      }

      /// reCAPTCHA cannot be satisfied from a plain HTTP POST.
      if (requiresRecaptcha) {
        return {
          'success': false,
          'message':
              'Unable to reset automatically due to server security (reCAPTCHA). Please try again later or contact your administrator.',
        };
      }

      final Map<String, String> formData = _extractAllFormData(
        responseBody!,
        login,
        database,
      );
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Origin': cleanUrl,
        'Referer': '$cleanUrl$workingEndpoint',
        'Upgrade-Insecure-Requests': '1',
      };

      if (cookies != null) {
        /// Names included, not just values: `values.join` produced a
        /// malformed `Cookie` header, so the session established above was
        /// never actually sent and this POST ran against a fresh, unbound
        /// session.
        headers['Cookie'] = _cookieHeader(cookies);
      }

      var response = await http
          .post(
            Uri.parse('$cleanUrl$workingEndpoint'),
            headers: headers,
            body: Uri(queryParameters: formData).query,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 400) {
        final simpleFormData = {
          'login': login,
          if (database.isNotEmpty) 'db': database,
          'redirect': '/web/login',
        };

        response = await http
            .post(
              Uri.parse('$cleanUrl$workingEndpoint'),
              headers: headers,
              body: Uri(queryParameters: simpleFormData).query,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 400 && database.isNotEmpty) {
          final urlWithDb = '$cleanUrl$workingEndpoint?db=$database';
          final formDataWithoutDb = Map<String, String>.from(formData);
          formDataWithoutDb.remove('db');

          response = await http
              .post(
                Uri.parse(urlWithDb),
                headers: {...headers, 'Referer': urlWithDb},
                body: Uri(queryParameters: formDataWithoutDb).query,
              )
              .timeout(const Duration(seconds: 30));

          if (response.statusCode == 400) {
            final minimalData = {'login': login};

            response = await http
                .post(
                  Uri.parse(urlWithDb),
                  headers: {...headers, 'Referer': urlWithDb},
                  body: Uri(queryParameters: minimalData).query,
                )
                .timeout(const Duration(seconds: 30));
          }
        }
      }

      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers['location'];

        if (location != null) {
          try {
            final redirectUrl = location.startsWith('http')
                ? location
                : '$cleanUrl$location';
            final redirectResponse = await http
                .get(
                  Uri.parse(redirectUrl),
                  headers: {
                    'User-Agent': headers['User-Agent']!,
                    'Accept': headers['Accept']!,
                    if (cookies != null) 'Cookie': _cookieHeader(cookies),
                  },
                )
                .timeout(const Duration(seconds: 30));

            final responseBody = redirectResponse.body.toLowerCase();
            if (_containsSuccessIndicators(responseBody)) {
              return {
                'success': true,
                'message':
                    'Password reset email sent successfully. Please check your email for reset instructions.',
              };
            } else if (_containsErrorIndicators(responseBody)) {
              return {
                'success': false,
                'message': 'User not found or invalid email address.',
              };
            }
          } catch (e) {
            /// The POST already succeeded; only the follow-up GET failed, so
            /// fall through to the redirect-means-success case below.
          }
        }

        return {
          'success': true,
          'message':
              'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase();

        if (_containsSuccessIndicators(responseBody)) {
          return {
            'success': true,
            'message':
                'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        } else if (_containsErrorIndicators(responseBody)) {
          return {
            'success': false,
            'message': 'User not found or invalid email address.',
          };
        } else {
          if (responseBody.contains('<form') &&
              responseBody.contains('reset') &&
              responseBody.contains('password')) {
            return {
              'success': false,
              'message':
                  'Unable to send reset email. Please verify the email address is correct.',
            };
          }

          return {
            'success': true,
            'message':
                'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        }
      } else if (response.statusCode == 400) {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('user not found') ||
            errorBody.contains('no user found')) {
          return {
            'success': false,
            'message': 'No user found with this email address.',
          };
        } else if (errorBody.contains('invalid email') ||
            errorBody.contains('invalid login')) {
          return {
            'success': false,
            'message': 'Please enter a valid email address.',
          };
        }

        return {
          'success': false,
          'message':
              'Unable to send reset email. Please verify your email address and try again.',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': _resetUnavailableMessage};
      } else {
        return {
          'success': false,
          'message':
              'Failed to send reset email. Server returned status: ${response.statusCode}',
        };
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return {
          'success': false,
          'message':
              'Request timeout. Please check your internet connection and try again.',
        };
      } else if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'message': 'Network error. Please check your internet connection.',
        };
      } else {
        return {
          'success': false,
          'message': 'An error occurred: ${e.toString()}',
        };
      }
    }
  }

  static bool _containsSuccessIndicators(String responseBody) {
    return responseBody.contains('password reset') ||
        responseBody.contains('email sent') ||
        responseBody.contains('check your email') ||
        responseBody.contains('reset link') ||
        responseBody.contains('instructions sent') ||
        responseBody.contains('email has been sent');
  }

  static bool _containsErrorIndicators(String responseBody) {
    return responseBody.contains('user not found') ||
        responseBody.contains('invalid email') ||
        responseBody.contains('error') ||
        responseBody.contains('not found') ||
        responseBody.contains('invalid user');
  }

  /// Validates a string as a properly formatted email address.
  static bool isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  static Map<String, String> _extractAllFormData(
    String html,
    String login,
    String database,
  ) {
    final Map<String, String> formData = {};

    formData['login'] = login;

    if (database.isNotEmpty) {
      formData['db'] = database;
    }

    formData['redirect'] = '/web/login';

    final inputPattern = RegExp(
      r'<input[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*(?:value=["\x27]([^"\x27]*)["\x27])?[^>]*>',
      caseSensitive: false,
    );

    final matches = inputPattern.allMatches(html);
    for (final match in matches) {
      final name = match.group(1);
      final value = match.group(2) ?? '';

      if (name != null && name.isNotEmpty) {
        if (name.toLowerCase() == 'login') continue;

        if (name.toLowerCase().contains('token') ||
            name.toLowerCase().contains('csrf') ||
            name.toLowerCase() == 'db' ||
            name.toLowerCase() == 'redirect') {
          formData[name] = value;
        }
      }
    }

    final metaCsrfPattern = RegExp(
      r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]*)["\x27]',
      caseSensitive: false,
    );
    final metaMatch = metaCsrfPattern.firstMatch(html);
    if (metaMatch != null && metaMatch.group(1) != null) {
      formData['csrf_token'] = metaMatch.group(1)!;
    }

    final jsTokenPatterns = [
      RegExp(
        r'csrf_token["\x27]?\s*:\s*["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      ),
      RegExp(r'"csrf_token"\s*:\s*"([^"]+)"', caseSensitive: false),
      RegExp(
        r'var\s+csrf_token\s*=\s*["\x27]([^"\x27]+)["\x27]',
        caseSensitive: false,
      ),
    ];

    for (final pattern in jsTokenPatterns) {
      final match = pattern.firstMatch(html);
      if (match != null &&
          match.group(1) != null &&
          match.group(1)!.isNotEmpty) {
        formData['csrf_token'] = match.group(1)!;

        break;
      }
    }

    return formData;
  }

  /// Pulls the CSRF token out of the reset page, which Odoo renders in one of
  /// several shapes depending on version and theme.
  static String? _extractCsrfToken(String html) {
    final patterns = [
      RegExp(
        r'<input[^>]*name=["\x27]csrf_token["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
      ),
      RegExp(
        r'<meta[^>]*name=["\x27]csrf-token["\x27][^>]*content=["\x27]([^"\x27]*)["\x27]',
      ),
      RegExp(r'csrf_token["\x27]?\s*:\s*["\x27]([^"\x27]*)'),
      RegExp(r'"csrf_token"\s*:\s*"([^"]*)"'),
      RegExp(
        r'name=["\x27]csrf_token["\x27]\s+value=["\x27]([^"\x27]*)["\x27]',
      ),
      RegExp(
        r'value=["\x27]([^"\x27]*)["\x27]\s+name=["\x27]csrf_token["\x27]',
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null &&
          match.group(1) != null &&
          match.group(1)!.isNotEmpty) {
        return match.group(1);
      }
    }

    return null;
  }

  /// A reCAPTCHA-protected form cannot be submitted from a plain HTTP POST,
  /// so detecting one lets the caller say so instead of silently failing.
  static bool _detectRecaptcha(String responseBody) {
    final body = responseBody.toLowerCase();

    final recaptchaIndicators = [
      'recaptcha',
      'grecaptcha',
      'google.com/recaptcha',
      'recaptcha_token_response',
      'data-sitekey',
      'g-recaptcha',
    ];

    for (String indicator in recaptchaIndicators) {
      if (body.contains(indicator)) {
        return true;
      }
    }

    return false;
  }

  /// [webFlowResult] is the outcome [_tryWebInterfaceReset] already produced
  /// for this same request. It is reused rather than recomputed: this method
  /// is only ever reached *after* that flow has run and failed, so calling it
  /// again repeats two HTTP requests that are known to fail — on a server
  /// with reset disabled that doubles an already slow dead end for a result
  /// that cannot have changed in the intervening milliseconds.
  static Future<Map<String, dynamic>> _tryDirectApiReset(
    String cleanUrl,
    String database,
    String login, {
    Map<String, dynamic>? webFlowResult,
  }) async {
    Future<Map<String, dynamic>> webFlowFallback() async =>
        webFlowResult ?? await _tryWebInterfaceReset(cleanUrl, database, login);

    try {
      /// The public signup endpoint, which needs no authenticated session —
      /// unlike `/web/dataset/call_kw`, which rejects an anonymous caller
      /// before `res.users.reset_password` is ever reached.
      final signupUrl = '$cleanUrl/auth_signup/signup';

      final signupBody = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'dbname': database,
          'login': login,
          'name': login,
          'password': '',
          'confirm_password': '',
          'redirect': '/web',
          'token': '',
          'type': 'reset',
        },
        'id': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http
          .post(
            Uri.parse(signupUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(signupBody),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData['error'] == null) {
          return {
            'success': true,
            'message':
                'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        }
      }

      /// The signup API didn't do it either — report what the web flow found.
      return await webFlowFallback();
    } catch (e) {
      return await webFlowFallback();
    }
  }

  static Future<Map<String, dynamic>> _tryWebInterfaceReset(
    String cleanUrl,
    String database,
    String login,
  ) async {
    try {
      final loginUrl = '$cleanUrl/web/login';
      final resetUrl = '$cleanUrl/web/reset_password';

      /// 1) Bind a session to the database before touching the reset route.
      ///
      /// This is the step whose absence produced a 404 even on servers where
      /// password reset is switched on. `/web/reset_password` is declared
      /// `auth='public'`, and Odoo only routes non-`auth='none'` endpoints
      /// once a database is resolved for the request. Resolution comes from
      /// the session or, failing that, from there being exactly one database
      /// on the host:
      ///
      /// ```python
      /// all_dbs = db_list(force=True, host=host)
      /// if len(all_dbs) == 1:
      ///     dbname = all_dbs[0]  # monodb
      /// ```
      ///
      /// On a single-database server that fallback silently rescued the old
      /// code. On a multi-database host it yields no database, the request
      /// falls back to the `auth='none'`-only router, `/web/reset_password`
      /// isn't in it, and werkzeug raises NotFound — a 404 that says nothing
      /// about whether reset is enabled, because Odoo never got far enough
      /// to look.
      ///
      /// `ensure_db()` is the documented way out: hand `/web/login` a `db`
      /// query parameter and it pins the session to that database, then 302s
      /// back to the same URL so the cookie is set.
      Map<String, String> cookies = {};

      cookies.addAll(await _bindDatabaseSession(cleanUrl, database));

      /// 2) Load the login page with whatever session we now hold, so any
      /// further cookies (CSRF material among them) are picked up.
      final initialGet = await http
          .get(
            Uri.parse('$loginUrl?redirect=/web/login'),
            headers: {
              ..._browserHeaders,
              if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
            },
          )
          .timeout(const Duration(seconds: 15));

      final initialSetCookie = initialGet.headers['set-cookie'];
      if (initialSetCookie != null) {
        cookies.addAll(_parseCookies(initialSetCookie));
      }

      /// 3) Load the reset form. The session now carries the database, so
      /// Odoo routes this through the normal dispatcher instead of the
      /// `auth='none'` one.
      final resetGet = await http
          .get(
            Uri.parse('$resetUrl?redirect=/web/login'),
            headers: {
              ..._browserHeaders,
              if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
              'Referer': '$loginUrl?redirect=/web/login',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resetGet.statusCode != 200) {
        return {
          'success': false,
          'message': resetGet.statusCode == 404
              ? _resetUnavailableMessage
              : 'Unable to load the reset form (status '
                    '${resetGet.statusCode}). Please try again later.',
        };
      }

      final resetSetCookie = resetGet.headers['set-cookie'];
      if (resetSetCookie != null) {
        cookies.addAll(_parseCookies(resetSetCookie));
      }

      final csrfToken = _extractCsrfToken(resetGet.body);
      final formData = _extractAllFormData(resetGet.body, login, database);
      if (csrfToken != null && csrfToken.isNotEmpty) {
        formData['csrf_token'] = csrfToken;
      }

      formData['login'] = login;
      formData['redirect'] = '/web/login';

      /// 4) Submit the reset form back to `/web/reset_password`.
      final postHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Origin': cleanUrl,
        'Referer': '$resetUrl?redirect=/web/login',
        if (cookies.isNotEmpty) 'Cookie': _cookieHeader(cookies),
      };

      final postResponse = await http
          .post(
            Uri.parse('$resetUrl?redirect=/web/login'),
            headers: postHeaders,
            body: Uri(queryParameters: formData).query,
          )
          .timeout(const Duration(seconds: 30));

      if (postResponse.statusCode == 302 || postResponse.statusCode == 303) {
        return {
          'success': true,
          'message':
              'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      if (postResponse.statusCode == 200) {
        final body = postResponse.body.toLowerCase();
        if (_containsSuccessIndicators(body)) {
          return {
            'success': true,
            'message':
                'Password reset email sent successfully. Please check your email for reset instructions.',
          };
        }
        if (_containsErrorIndicators(body)) {
          return {
            'success': false,
            'message': 'No user found with this email address.',
          };
        }

        /// If ambiguous, assume success like the browser flow
        return {
          'success': true,
          'message':
              'Password reset email sent successfully. Please check your email for reset instructions.',
        };
      }

      /// A failure here no longer claims success. The old code returned
      /// "request submitted" for every non-200, which told users an email was
      /// on its way when nothing had been sent — and stopped the endpoint
      /// scan in `sendResetPasswordEmail` from ever running.
      return {
        'success': false,
        'message':
            'Unable to reset password automatically. Please try again later or contact your administrator.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Unable to reset password automatically. Please try again later or contact your administrator.',
      };
    }
  }

  /// Returns cookies for a session already pinned to [database], or an empty
  /// map when that can't be established.
  ///
  /// `ensure_db()` pins the session when `/web/login` is given a `db` query
  /// parameter, and reports it by 302-ing back to the same URL with a
  /// `Set-Cookie`. The redirect is therefore *not* followed: Dart's `http`
  /// carries no cookie jar across hops, so letting it follow automatically
  /// would drop the cookie this call exists to capture and arrive at a
  /// database-less session — precisely the state that makes
  /// `/web/reset_password` 404 on a multi-database host.
  static Future<Map<String, String>> _bindDatabaseSession(
    String cleanUrl,
    String database,
  ) async {
    if (database.isEmpty) return const {};

    final client = http.Client();
    try {
      final uri = Uri.parse(
        '$cleanUrl/web/login?db=${Uri.encodeQueryComponent(database)}'
        '&redirect=${Uri.encodeQueryComponent('/web/login')}',
      );
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll(_browserHeaders);

      final response = await http.Response.fromStream(
        await client.send(request),
      ).timeout(const Duration(seconds: 15));

      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) return _parseCookies(setCookie);
      return const {};
    } catch (_) {
      /// Callers stay correct without this — a single-database server
      /// resolves the database on its own — so a failure here is not fatal.
      return const {};
    } finally {
      client.close();
    }
  }

  /// Odoo serves the login and reset pages through its website stack, which
  /// varies its response by user agent and accepted types; these are the
  /// values a real browser sends.
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,'
        'image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
  };

  static String _cookieHeader(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  static Map<String, String> _parseCookies(String cookieHeader) {
    /// Parse multiple cookies from a combined Set-Cookie header value.
    /// Strategy: capture name=value pairs that occur at the beginning or just
    /// after ", " and stop at the first semicolon (attributes come after
    /// semicolons).
    ///
    /// The previous `split(',')` split *inside* cookie attributes too — an
    /// `Expires=Wed, 21 Oct 2026 ...` alone was enough to turn one cookie
    /// into several bogus entries.
    final cookies = <String, String>{};
    final cookiePattern = RegExp(
      r'(?:(?<=^)|(?<=,\s))([^=;,\s]+)=([^;\r\n,]+)',
    );
    for (final match in cookiePattern.allMatches(cookieHeader)) {
      final name = match.group(1);
      final value = match.group(2);
      if (name != null && value != null) {
        cookies[name.trim()] = value.trim();
      }
    }
    return cookies;
  }
}
