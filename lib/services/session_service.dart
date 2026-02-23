import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../providers/auth_provider.dart';
import 'odoo_session_manager.dart';
import 'odoo_api_service.dart';
import 'package:mobo_billing/main.dart';
import '../providers/invoice_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/credit_note_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/last_opened_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/odoo_settings_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/company_provider.dart';
import '../screens/main_app_screen.dart';

/// High-level service responsible for managing app-wide session state, account switching, and data synchronization.
class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();

  factory SessionService() => instance;

  SessionService._internal() {
    _init();
  }

  static const String _accountsKey = 'stored_odoo_accounts';
  static const String _passwordsKey = 'stored_odoo_passwords';

  List<Map<String, dynamic>> _storedAccounts = [];
  OdooSessionModel? _currentSession;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  bool _isCheckingSession = false;
  bool _isServerUnreachable = false;
  bool _isLoggingOut = false;

  bool get isInitialized => _isInitialized;

  bool get hasValidSession => _currentSession != null;

  bool get isCheckingSession => _isCheckingSession;

  bool get isServerUnreachable => _isServerUnreachable;

  bool get isLoggingOut => _isLoggingOut;

  Future<OdooClient?> get client => OdooSessionManager.getClient();

  Future<void> _init() async {
    _currentSession = await OdooSessionManager.getCurrentSession();
    await _loadStoredAccounts();

    OdooSessionManager.setSessionCallbacks(
      onSessionUpdated: (session) {
        _currentSession = session;

        OdooApiService().updateSession(session);
        _storeCurrentSessionIfNeeded();
        notifyListeners();
      },
      onSessionCleared: () {
        _currentSession = null;
        notifyListeners();
      },
    );

    await checkSession();

    _isInitialized = true;

    notifyListeners();
  }

  /// Validates the current session and updates the server reachability status.
  Future<bool> checkSession() async {
    if (_isCheckingSession) {
      return hasValidSession;
    }

    _isCheckingSession = true;
    _isServerUnreachable = false;

    notifyListeners();

    try {
      _currentSession = await OdooSessionManager.getCurrentSession();

      if (_currentSession != null) {
        try {
          final client = await OdooSessionManager.getClient().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Session validation timed out after 15 seconds',
              );
            },
          );
          if (client == null) {
            _currentSession = null;
          } else {}
        } on TimeoutException catch (e) {
        } catch (e) {
          if (_isServerUnreachableError(e) || _isHtmlResponseError(e)) {
          } else if (_isAuthenticationError(e)) {
            _currentSession = null;
          } else {}
        }
      } else {}
    } catch (e) {
      _currentSession = null;
      if (_isServerUnreachableError(e)) {
        _isServerUnreachable = true;
      }
    } finally {
      _isCheckingSession = false;

      notifyListeners();
    }

    return hasValidSession;
  }

  /// Returns an [OdooClient] if a valid session exists, otherwise handles errors and returns `null`.
  Future<OdooClient?> getClient() async {
    if (!hasValidSession) {
      return null;
    }

    try {
      final client = await OdooSessionManager.getClient();

      return client;
    } catch (e) {
      if (_isServerUnreachableError(e) || _isHtmlResponseError(e)) {
        _isServerUnreachable = true;
        notifyListeners();
        return null;
      }

      if (_isAuthenticationError(e)) {
        _currentSession = null;
        notifyListeners();
        return null;
      }
      return null;
    }
  }

  bool _isServerUnreachableError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timeout') ||
        errorString.contains('host unreachable') ||
        errorString.contains('no route to host') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('failed to connect') ||
        errorString.contains('connection failed');
  }

  bool _isHtmlResponseError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('<html>') ||
        errorString.contains('server returned html instead of json') ||
        errorString.contains('unexpected character (at character 1)') ||
        errorString.contains('formatexception');
  }

  bool _isAuthenticationError(dynamic error) {
    final s = error.toString().toLowerCase();

    return s.contains('wrong login/password') ||
        s.contains('invalid database') ||
        s.contains('invalid db') ||
        s.contains('bad credentials') ||
        s.contains('login or password');
  }

  List<Map<String, dynamic>> get storedAccounts =>
      List.unmodifiable(_storedAccounts);

  OdooSessionModel? get currentSession => _currentSession;

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? accountsJson = prefs.getString(_accountsKey);
      if (accountsJson != null) {
        final List<dynamic> decoded = json.decode(accountsJson);
        _storedAccounts = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _storedAccounts = [];
    }
    notifyListeners();
  }

  /// Persistently stores an Odoo account's details and (optionally) its password.
  Future<void> storeAccount(
    OdooSessionModel session, [
    String? password,
  ]) async {
    final Map<String, dynamic> accountData = {
      'serverUrl': session.serverUrl,
      'database': session.database,
      'userLogin': session.userLogin,
      'userId': session.userId,
      'userName': session.userName ?? session.userLogin,
      'sessionId': session.sessionId,
      'lastUsed': DateTime.now().toIso8601String(),
    };

    final int index = _storedAccounts.indexWhere((acc) {
      if (acc['userId'] != null && session.userId != null) {
        return acc['userId'].toString() == session.userId.toString() &&
            acc['serverUrl'] == session.serverUrl &&
            acc['database'] == session.database;
      }

      return acc['serverUrl'] == session.serverUrl &&
          acc['database'] == session.database &&
          acc['userLogin'] == session.userLogin;
    });

    if (index != -1) {
      _storedAccounts[index] = accountData;
    } else {
      _storedAccounts.add(accountData);
    }

    await _saveStoredAccounts();

    final pwdToStore = password ?? session.password;
    if (pwdToStore.isNotEmpty) {
      await _storePassword(session, pwdToStore);
    }

    notifyListeners();
  }

  Future<void> _saveStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accountsKey, json.encode(_storedAccounts));
    } catch (e) {}
  }

  /// Removes a stored account and its associated password from persistent storage.
  Future<void> removeStoredAccount(Map<String, dynamic> account) async {
    _storedAccounts.removeWhere((acc) {
      if (acc['userId'] != null && account['userId'] != null) {
        return acc['userId'].toString() == account['userId'].toString() &&
            acc['serverUrl'] == account['serverUrl'] &&
            acc['database'] == account['database'];
      }

      return acc['serverUrl'] == account['serverUrl'] &&
          acc['database'] == account['database'] &&
          acc['userLogin'] == account['userLogin'];
    });
    await _saveStoredAccounts();

    final prefs = await SharedPreferences.getInstance();
    final String passwordKey = _getPasswordKey(
      account['serverUrl'],
      account['database'],
      account['userLogin'],
    );
    await prefs.remove(passwordKey);

    notifyListeners();
  }

  String _getPasswordKey(String url, String db, String login) {
    return '${_passwordsKey}_${url}_${db}_$login';
  }

  Future<void> _storePassword(OdooSessionModel session, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getPasswordKey(
      session.serverUrl,
      session.database,
      session.userLogin,
    );
    await prefs.setString(key, password);
  }

  /// Retrieves the stored password for a given account.
  Future<String?> getStoredPassword(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final String key = _getPasswordKey(
      account['serverUrl'],
      account['database'],
      account['userLogin'],
    );
    return prefs.getString(key);
  }

  /// Switches the active session to a different account and refreshes app data.
  Future<bool> switchToAccount(OdooSessionModel newSession) async {
    try {
      if (_currentSession != null &&
          (_currentSession!.userId != newSession.userId ||
              _currentSession!.serverUrl != newSession.serverUrl ||
              _currentSession!.database != newSession.database)) {
        final currentExists = _storedAccounts.any(
          (account) =>
              account['userId']?.toString() ==
                  _currentSession!.userId?.toString() &&
              account['serverUrl'] == _currentSession!.serverUrl &&
              account['database'] == _currentSession!.database,
        );

        if (!currentExists) {
          await storeAccount(_currentSession!);
        }
      }

      _currentSession = newSession.copyWith(
        selectedCompanyId: null,
        allowedCompanyIds: [],
      );

      await OdooSessionManager.updateSession(newSession);

      OdooApiService().updateSession(newSession);

      try {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.loginWithSessionId(
            serverUrl: newSession.serverUrl,
            database: newSession.database,
            username: newSession.userLogin,
            password: newSession.password,
            sessionId: newSession.sessionId,
            sessionInfo: {
              'uid': newSession.userId,
              'name': newSession.userName ?? newSession.userLogin,
            },
          );
        }
      } catch (e) {}

      await refreshAllData();

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _storeCurrentSessionIfNeeded() async {
    if (_currentSession != null) {
      await storeAccount(_currentSession!);
    }
  }

  /// Logs out the current user, clears the session, and resets all provider data.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await OdooSessionManager.logout();

      await clearAllProviderData(isLogout: true);

      _storedAccounts.clear();
      await _saveStoredAccounts();

      _currentSession = null;
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers a full data refresh by clearing provider data and reloading from the server.
  Future<void> refreshAllData() async {
    _isRefreshing = true;
    notifyListeners();

    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    if (!context.mounted) return;

    try {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) =>
              const MainAppScreen(key: ValueKey('global_refresh')),
        ),
        (route) => false,
      );

      await Future.delayed(Duration.zero);

      await clearAllProviderData(isLogout: false);

      if (!context.mounted) return;

      final invoiceProvider = Provider.of<InvoiceProvider>(
        context,
        listen: false,
      );
      final customerProvider = Provider.of<CustomerProvider>(
        context,
        listen: false,
      );
      final productProvider = Provider.of<ProductProvider>(
        context,
        listen: false,
      );
      final creditNoteProvider = Provider.of<CreditNoteProvider>(
        context,
        listen: false,
      );
      final paymentProvider = Provider.of<PaymentProvider>(
        context,
        listen: false,
      );
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );
      final settingsProvider = Provider.of<OdooSettingsProvider>(
        context,
        listen: false,
      );
      final currencyProvider = Provider.of<CurrencyProvider>(
        context,
        listen: false,
      );

      await Future.wait<dynamic>([
        invoiceProvider.loadDashboardData().catchError((e) {}),
        invoiceProvider.loadInvoices().catchError((e) {}),
        customerProvider.loadCustomers().catchError((e) {}),
        productProvider.loadProducts().catchError((e) {}),
        creditNoteProvider.loadCreditNotes().catchError((e) {}),
        paymentProvider.loadPayments().catchError((e) {}),
        profileProvider.loadProfile().catchError((e) {}),
        settingsProvider
            .fetchInvoiceSettings(forceRefresh: true)
            .catchError((e) {}),
        currencyProvider.fetchCompanyCurrency().catchError((e) {}),
        Provider.of<CompanyProvider>(
          context,
          listen: false,
        ).initialize().catchError((e) {}),
      ]);
    } catch (e) {
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Clears data across all providers and (optionally) wipes the local cache.
  Future<void> clearAllProviderData({bool isLogout = false}) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    if (!context.mounted) return;

    try {
      try {
        await Provider.of<AuthProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<InvoiceProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<CustomerProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<ProductProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<CreditNoteProvider>(
          context,
          listen: false,
        ).clearData();
      } catch (e) {}

      try {
        await Provider.of<PaymentProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<LastOpenedProvider>(
          context,
          listen: false,
        ).clearData();
      } catch (e) {}

      try {
        await Provider.of<ProfileProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<OdooSettingsProvider>(
          context,
          listen: false,
        ).clearData();
      } catch (e) {}

      try {
        await Provider.of<CurrencyProvider>(context, listen: false).clearData();
      } catch (e) {}

      try {
        await Provider.of<CompanyProvider>(context, listen: false).clearData();
      } catch (e) {}

      await _clearSharedPreferencesCache(isLogout: isLogout);
    } catch (e, stackTrace) {}
  }

  Future<void> _clearSharedPreferencesCache({bool isLogout = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();

      final keysToPreserve = {
        'theme_mode',
        'permissions_asked',
        'first_launch',
        'app_version',
        'reduce_motion',
        'enable_notifications',
        'enable_sound_effects',
        'enable_haptic_feedback',
        'compact_view_mode',
        'auto_sync_enabled',
        'offline_mode_enabled',
        'sync_interval_minutes',
        'biometric_enabled',
        'hasSeenGetStarted',
        'previous_server_urls',
      };

      final keysToClear = allKeys
          .where(
            (key) =>
                !keysToPreserve.contains(key) &&
                (isLogout ||
                    (!key.startsWith('password_') &&
                        !key.startsWith(_passwordsKey))) &&
                key != 'previous_server_urls' &&
                (key.startsWith('user_') ||
                    key.startsWith('cached_') ||
                    key.startsWith('dashboard_') ||
                    key.contains('profile') ||
                    (isLogout
                        ? key.contains('company')
                        : (key.startsWith('cached_') ||
                              key == 'company_info')) ||
                    key.contains('customer') ||
                    key.contains('invoice') ||
                    key.contains('credit_note') ||
                    key.contains('product') ||
                    key.contains('payment') ||
                    key.contains('currency') ||
                    key == 'user_profile' ||
                    key == 'user_profile_write_date' ||
                    key == 'company_info' ||
                    key == 'available_languages' ||
                    key == 'available_currencies' ||
                    key == 'available_timezones' ||
                    key == 'last_opened_items' ||
                    key == 'langs_updated_at' ||
                    key == 'currs_updated_at' ||
                    key == 'tz_updated_at' ||
                    (isLogout && key == _accountsKey)) &&
                (isLogout ||
                    (key != 'selected_company_id' &&
                        key != 'selected_allowed_company_ids' &&
                        key != 'isLoggedIn')),
          )
          .toList();

      for (final key in keysToClear) {
        await prefs.remove(key);
      }
    } catch (e) {}
  }
}
