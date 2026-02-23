import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_session_manager.dart';

/// Provider for managing application-wide settings, user preferences, and local storage.
class SettingsProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoadingLanguages = false;
  bool _isLoadingCurrencies = false;
  bool _isLoadingTimezones = false;
  bool _isLoadingUserProfile = false;
  String? _error;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _companyInfo;

  List<Map<String, dynamic>> _availableLanguages = [];
  List<Map<String, dynamic>> _availableCurrencies = [];
  List<Map<String, dynamic>> _availableTimezones = [];
  DateTime? _languagesUpdatedAt;
  DateTime? _currenciesUpdatedAt;
  DateTime? _timezonesUpdatedAt;

  bool _isDarkMode = false;
  bool _enableNotifications = true;
  bool _enableSoundEffects = true;
  bool _enableHapticFeedback = true;
  bool _autoSyncData = true;
  bool _compactView = false;
  bool _offlineMode = false;
  String _selectedLanguage = 'en_US';
  String _selectedCurrency = 'USD';
  String _selectedTimezone = 'UTC';
  int _syncInterval = 30;
  double _cacheSize = 0.0;

  bool get isLoading => _isLoading;

  bool get isLoadingLanguages => _isLoadingLanguages;

  bool get isLoadingCurrencies => _isLoadingCurrencies;

  bool get isLoadingTimezones => _isLoadingTimezones;

  bool get isLoadingUserProfile => _isLoadingUserProfile;

  String? get error => _error;

  Map<String, dynamic>? get userProfile => _userProfile;

  Map<String, dynamic>? get companyInfo => _companyInfo;

  List<Map<String, dynamic>> get availableLanguages => _availableLanguages;

  List<Map<String, dynamic>> get availableCurrencies => _availableCurrencies;

  List<Map<String, dynamic>> get availableTimezones => _availableTimezones;

  DateTime? get languagesUpdatedAt => _languagesUpdatedAt;

  DateTime? get currenciesUpdatedAt => _currenciesUpdatedAt;

  DateTime? get timezonesUpdatedAt => _timezonesUpdatedAt;

  bool get isDarkMode => _isDarkMode;

  bool get enableNotifications => _enableNotifications;

  bool get enableSoundEffects => _enableSoundEffects;

  bool get enableHapticFeedback => _enableHapticFeedback;

  bool get autoSyncData => _autoSyncData;

  bool get compactView => _compactView;

  bool get offlineMode => _offlineMode;

  String get selectedLanguage => _selectedLanguage;

  String get selectedCurrency => _selectedCurrency;

  String get selectedTimezone => _selectedTimezone;

  int get syncInterval => _syncInterval;

  double get cacheSize => _cacheSize;

  /// Initializes the provider by loading local settings and refreshing Odoo data.
  Future<void> initialize() async {
    await loadLocalSettings(computeCacheSize: false);

    fetchAllOdooData();
  }

  /// Loads application settings from local persistent storage (SharedPreferences).
  Future<void> loadLocalSettings({bool computeCacheSize = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _enableNotifications = prefs.getBool('enable_notifications') ?? true;
      _enableSoundEffects = prefs.getBool('enable_sound_effects') ?? true;
      _enableHapticFeedback = prefs.getBool('enable_haptic_feedback') ?? true;
      _autoSyncData = prefs.getBool('auto_sync_data') ?? true;
      _compactView = prefs.getBool('compact_view') ?? false;
      _offlineMode = prefs.getBool('offline_mode') ?? false;
      _selectedLanguage = prefs.getString('selected_language') ?? 'en_US';
      _selectedCurrency = prefs.getString('selected_currency') ?? 'USD';
      _selectedTimezone = prefs.getString('selected_timezone') ?? 'UTC';
      _syncInterval = prefs.getInt('sync_interval') ?? 30;

      final session = await OdooSessionManager.getCurrentSession();
      final uid = session?.userId;
      final db = session?.database;

      String profileKey = 'user_profile';
      String companyKey = 'company_info';
      if (uid != null && db != null) {
        final cleanDb = db.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        profileKey = 'user_profile_${cleanDb}_$uid';
        companyKey = 'company_info_${cleanDb}_$uid';
      }

      final cachedUser = prefs.getString(profileKey);
      final cachedCompany = prefs.getString(companyKey);

      final cachedLangs = prefs.getString('available_languages');
      final cachedCurrencies = prefs.getString('available_currencies');
      final cachedTimezones = prefs.getString('available_timezones');
      final langsTs = prefs.getInt('langs_updated_at');
      final currsTs = prefs.getInt('currs_updated_at');
      final tzTs = prefs.getInt('tz_updated_at');
      if (cachedUser != null && cachedUser.isNotEmpty) {
        try {
          _userProfile = Map<String, dynamic>.from(jsonDecode(cachedUser));
        } catch (_) {
          _userProfile = null;
        }
      }
      if (cachedCompany != null && cachedCompany.isNotEmpty) {
        try {
          _companyInfo = Map<String, dynamic>.from(jsonDecode(cachedCompany));
        } catch (_) {
          _companyInfo = null;
        }
      }

      if (cachedLangs != null && cachedLangs.isNotEmpty) {
        try {
          final list = List<Map<String, dynamic>>.from(jsonDecode(cachedLangs));
          _availableLanguages = list;
        } catch (_) {}
      }
      if (cachedCurrencies != null && cachedCurrencies.isNotEmpty) {
        try {
          final list = List<Map<String, dynamic>>.from(
            jsonDecode(cachedCurrencies),
          );
          _availableCurrencies = list;
        } catch (_) {}
      }
      if (cachedTimezones != null && cachedTimezones.isNotEmpty) {
        try {
          final list = List<Map<String, dynamic>>.from(
            jsonDecode(cachedTimezones),
          );
          _availableTimezones = list;
        } catch (_) {}
      }

      if (langsTs != null && langsTs > 0) {
        _languagesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(langsTs);
      }
      if (currsTs != null && currsTs > 0) {
        _currenciesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(currsTs);
      }
      if (tzTs != null && tzTs > 0) {
        _timezonesUpdatedAt = DateTime.fromMillisecondsSinceEpoch(tzTs);
      }

      if (computeCacheSize) {
        await calculateCacheSize();
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to load local settings: $e';
    }
  }

  /// Persists the current in-memory settings to local storage.
  Future<void> saveLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('enable_notifications', _enableNotifications);
      await prefs.setBool('enable_sound_effects', _enableSoundEffects);
      await prefs.setBool('enable_haptic_feedback', _enableHapticFeedback);
      await prefs.setBool('auto_sync_data', _autoSyncData);
      await prefs.setBool('compact_view', _compactView);
      await prefs.setBool('offline_mode', _offlineMode);
      await prefs.setString('selected_language', _selectedLanguage);
      await prefs.setString('selected_currency', _selectedCurrency);
      await prefs.setString('selected_timezone', _selectedTimezone);
      await prefs.setInt('sync_interval', _syncInterval);

      await prefs.setString(
        'available_languages',
        jsonEncode(_availableLanguages),
      );
      await prefs.setString(
        'available_currencies',
        jsonEncode(_availableCurrencies),
      );
      await prefs.setString(
        'available_timezones',
        jsonEncode(_availableTimezones),
      );

      if (_languagesUpdatedAt != null) {
        await prefs.setInt(
          'langs_updated_at',
          _languagesUpdatedAt!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove('langs_updated_at');
      }
      if (_currenciesUpdatedAt != null) {
        await prefs.setInt(
          'currs_updated_at',
          _currenciesUpdatedAt!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove('currs_updated_at');
      }
      if (_timezonesUpdatedAt != null) {
        await prefs.setInt(
          'tz_updated_at',
          _timezonesUpdatedAt!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove('tz_updated_at');
      }
    } catch (e) {
      _error = 'Failed to save settings: $e';
    }
  }

  /// Triggers a refresh of all relevant user and company data from Odoo.
  Future<void> fetchAllOdooData() async {
    _isLoading = true;
    _error = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      await Future.wait([
        fetchUserProfile(),
        fetchAvailableLanguages(),
        fetchAvailableCurrencies(),
        fetchAvailableTimezones(),
      ]);
    } catch (e) {
      _error = 'Failed to fetch Odoo data: $e';
    } finally {
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Fetches the authenticated user's profile and company details.
  Future<void> fetchUserProfile() async {
    _isLoadingUserProfile = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final apiService = OdooApiService();
      final uid = apiService.uid;

      if (uid == null) {
        throw Exception('No active user session');
      }

      final userResult = await apiService.searchRead(
        'res.users',
        [
          ['id', '=', uid],
        ],
        [
          'name',
          'email',
          'login',
          'lang',
          'tz',
          'company_id',
          'partner_id',
          'image_1920',
        ],
      );

      if (userResult != null &&
          userResult.isNotEmpty &&
          userResult[0] != null) {
        _userProfile = userResult[0];

        if (_userProfile!['lang'] != null) {
          _selectedLanguage = _userProfile!['lang'];
        }
        if (_userProfile!['tz'] != null) {
          _selectedTimezone = _userProfile!['tz'];
        }

        if (_userProfile!['company_id'] != null) {
          final companyId = _userProfile!['company_id'][0];
          final companyResult = await apiService.searchRead(
            'res.company',
            [
              ['id', '=', companyId],
            ],
            [
              'name',
              'email',
              'phone',
              'website',
              'currency_id',
              'country_id',
              'state_id',
              'city',
              'street',
              'zip',
            ],
          );

          if (companyResult != null &&
              companyResult.isNotEmpty &&
              companyResult[0] != null) {
            _companyInfo = companyResult[0];

            if (_companyInfo!['currency_id'] != null) {
              _selectedCurrency = _companyInfo!['currency_id'][1];
            }
          }
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          final session = await OdooSessionManager.getCurrentSession();
          final uid = session?.userId;
          final db = session?.database;

          String profileKey = 'user_profile';
          String companyKey = 'company_info';
          if (uid != null && db != null) {
            final cleanDb = db.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            profileKey = 'user_profile_${cleanDb}_$uid';
            companyKey = 'company_info_${cleanDb}_$uid';
          }

          final Map<String, dynamic> userForCache = Map<String, dynamic>.from(
            _userProfile!,
          );
          final dynamic imageField = userForCache['image_1920'];
          if (imageField is List<int>) {
            userForCache['image_1920'] = base64Encode(imageField);
          }

          await prefs.setString(profileKey, jsonEncode(userForCache));
          if (_companyInfo != null) {
            await prefs.setString(companyKey, jsonEncode(_companyInfo));
          }
        } catch (e) {}
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
    } finally {
      _isLoadingUserProfile = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Fetches the list of active languages available on the server.
  Future<void> fetchAvailableLanguages({bool markManual = false}) async {
    _isLoadingLanguages = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final apiService = OdooApiService();

      final result = await apiService.searchRead(
        'res.lang',
        [
          ['active', '=', true],
        ],
        ['code', 'name', 'iso_code', 'direction'],
      );

      if (result != null) {
        final newList = List<Map<String, dynamic>>.from(result);
        final oldJson = jsonEncode(_availableLanguages);
        final newJson = jsonEncode(newList);
        if (newJson != oldJson) {
          _availableLanguages = newList;
        }

        if (markManual || _languagesUpdatedAt == null || newJson != oldJson) {
          _languagesUpdatedAt = DateTime.now();
        }
        await saveLocalSettings();
      }
    } catch (e) {
      if (_availableLanguages.isEmpty) {
        _availableLanguages = [
          {'code': 'en_US', 'name': 'English (US)', 'iso_code': 'en'},
          {'code': 'es_ES', 'name': 'Spanish', 'iso_code': 'es'},
          {'code': 'fr_FR', 'name': 'French', 'iso_code': 'fr'},
          {'code': 'de_DE', 'name': 'German', 'iso_code': 'de'},
          {'code': 'ar_001', 'name': 'Arabic', 'iso_code': 'ar'},
          {'code': 'zh_CN', 'name': 'Chinese (Simplified)', 'iso_code': 'zh'},
          {'code': 'ja_JP', 'name': 'Japanese', 'iso_code': 'ja'},
        ];
      }
    } finally {
      _isLoadingLanguages = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Fetches the list of active currencies available on the server.
  Future<void> fetchAvailableCurrencies({bool markManual = false}) async {
    _isLoadingCurrencies = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      final apiService = OdooApiService();

      final result = await apiService.searchRead(
        'res.currency',
        [
          ['active', '=', true],
        ],
        ['name', 'full_name', 'symbol', 'position', 'rounding'],
      );

      if (result != null) {
        final newList = List<Map<String, dynamic>>.from(result);
        final oldJson = jsonEncode(_availableCurrencies);
        final newJson = jsonEncode(newList);
        if (newJson != oldJson) {
          _availableCurrencies = newList;
        }

        if (markManual || _currenciesUpdatedAt == null || newJson != oldJson) {
          _currenciesUpdatedAt = DateTime.now();
        }

        try {} catch (e) {}

        await saveLocalSettings();
      }
    } catch (e) {
      if (_availableCurrencies.isEmpty) {
        _availableCurrencies = [
          {'name': 'USD', 'full_name': 'US Dollar', 'symbol': '\$'},
          {'name': 'EUR', 'full_name': 'Euro', 'symbol': '€'},
          {'name': 'GBP', 'full_name': 'British Pound', 'symbol': '£'},
          {'name': 'JPY', 'full_name': 'Japanese Yen', 'symbol': '¥'},
          {'name': 'INR', 'full_name': 'Indian Rupee', 'symbol': '₹'},
          {'name': 'AUD', 'full_name': 'Australian Dollar', 'symbol': 'A\$'},
          {'name': 'CAD', 'full_name': 'Canadian Dollar', 'symbol': 'C\$'},
        ];
      }
    } finally {
      _isLoadingCurrencies = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Fetches the list of available timezones from Odoo.
  Future<void> fetchAvailableTimezones({bool markManual = false}) async {
    _isLoadingTimezones = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    try {
      final apiService = OdooApiService();

      final result = await apiService.call(
        'res.users',
        'fields_get',
        [
          ['tz'],
        ],
        {
          'attributes': ['selection', 'string'],
        },
      );

      final tzField = (result != null)
          ? result['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      if (selection != null && selection.isNotEmpty) {
        final newList = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
        final oldJson = jsonEncode(_availableTimezones);
        final newJson = jsonEncode(newList);
        if (newJson != oldJson) {
          _availableTimezones = newList;
        }

        if (markManual || _timezonesUpdatedAt == null || newJson != oldJson) {
          _timezonesUpdatedAt = DateTime.now();
        }
        await saveLocalSettings();
      } else {
        _availableTimezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'Europe/Brussels', 'name': 'Europe/Brussels'},
          {'code': 'Asia/Kolkata', 'name': 'Asia/Kolkata'},
          {'code': 'America/New_York', 'name': 'America/New_York'},
        ];
      }
    } catch (e) {
      if (_availableTimezones.isEmpty) {
        _availableTimezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
          {'code': 'America/Chicago', 'name': 'Central Time (US & Canada)'},
          {'code': 'America/Denver', 'name': 'Mountain Time (US & Canada)'},
          {'code': 'America/Los_Angeles', 'name': 'Pacific Time (US & Canada)'},
          {'code': 'Europe/London', 'name': 'London'},
          {'code': 'Europe/Paris', 'name': 'Paris'},
          {'code': 'Europe/Berlin', 'name': 'Berlin'},
          {'code': 'Asia/Tokyo', 'name': 'Tokyo'},
          {'code': 'Asia/Shanghai', 'name': 'Shanghai'},
          {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
          {'code': 'Asia/Dubai', 'name': 'Dubai'},
          {'code': 'Australia/Sydney', 'name': 'Sydney'},
        ];
      }
    } finally {
      _isLoadingTimezones = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Estimates total cache size (storage strings + temporary files).
  Future<void> calculateCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double totalSize = 0.0;

      final preserveKeys = {
        'enable_notifications',
        'enable_sound_effects',
        'enable_haptic_feedback',
        'auto_sync_data',
        'compact_view',
        'offline_mode',
        'selected_language',
        'selected_currency',
        'selected_timezone',
        'sync_interval',
        'isDarkMode',
        'previous_server_urls',

        'isLoggedIn',
        'sessionId',
        'userLogin',
        'password',
        'serverUrl',
        'database',
      };

      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (!preserveKeys.contains(key)) {
          final value = prefs.get(key);
          if (value != null) {
            final stringValue = value.toString();
            totalSize += (stringValue.length * 2) / (1024 * 1024);
          }
        }
      }

      try {
        final Directory tempDir = await getTemporaryDirectory();
        totalSize += (await _getDirectorySize(tempDir)) / (1024 * 1024);
      } catch (e) {}

      _cacheSize = double.parse(totalSize.toStringAsFixed(1));
    } catch (e) {
      _cacheSize = 0.0;
    }
  }

  /// Clears temporary app data, images, and non-essential local storage keys.
  Future<void> clearCache({Function? onClearProviderCaches}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final allKeys = prefs.getKeys();

      final preserveKeys = {
        'enable_notifications',
        'enable_sound_effects',
        'enable_haptic_feedback',
        'auto_sync_data',
        'compact_view',
        'offline_mode',
        'selected_language',
        'selected_currency',
        'selected_timezone',
        'sync_interval',
        'isDarkMode',
        'previous_server_urls',
        'hasSeenGetStarted',

        'app_lock_enabled',
        'biometric_enabled',
        'last_auth_time',
        'last_successful_auth',
        'auth_attempts_count',
        'last_failed_auth',

        'isLoggedIn',
        'sessionId',
        'userLogin',
        'password',
        'serverUrl',
        'database',
      };

      int clearedCount = 0;
      for (final key in allKeys) {
        final isExplicitPreserve = preserveKeys.contains(key);
        final isStoredAccountsKey =
            key == 'stored_accounts' ||
            key == 'stored_accounts_backup' ||
            key == 'stored_accounts_timestamp';
        final isPasswordCacheKey = key.startsWith('password_');

        if (isExplicitPreserve || isStoredAccountsKey || isPasswordCacheKey) {
          continue;
        }

        await prefs.remove(key);
        clearedCount++;
      }

      _userProfile = null;
      _companyInfo = null;
      _availableLanguages.clear();
      _availableCurrencies.clear();
      _availableTimezones.clear();
      _languagesUpdatedAt = null;
      _currenciesUpdatedAt = null;
      _timezonesUpdatedAt = null;

      if (onClearProviderCaches != null) {
        try {
          await onClearProviderCaches();
        } catch (e) {}
      }

      try {
        await DefaultCacheManager().emptyCache();
      } catch (e) {}

      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (e) {}

      try {
        final Directory tempDir = await getTemporaryDirectory();
        final sizeBefore = await _getDirectorySize(tempDir);
        await _deleteDirectoryContents(tempDir);
        final sizeAfter = await _getDirectorySize(tempDir);
        final clearedMB = (sizeBefore - sizeAfter) / (1024 * 1024);
      } catch (e) {}

      await calculateCacheSize();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear cache: $e';

      rethrow;
    }
  }

  Future<int> _getDirectorySize(Directory directory) async {
    int size = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            size += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  Future<void> _deleteDirectoryContents(Directory directory) async {
    if (!await directory.exists()) return;
    await for (final entity in directory.list(
      recursive: false,
      followLinks: false,
    )) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Updates user-specific language/timezone preferences on the Odoo server.
  Future<void> updateUserPreferences({
    String? language,
    String? timezone,
  }) async {
    _error = null;
    try {
      final apiService = OdooApiService();

      if (_userProfile == null) return;

      final updateData = <String, dynamic>{};
      if (language != null) updateData['lang'] = language;
      if (timezone != null) updateData['tz'] = timezone;

      if (updateData.isNotEmpty) {
        await apiService.write('res.users', [_userProfile!['id']], updateData);

        if (language != null) {
          _selectedLanguage = language;
          _userProfile!['lang'] = language;
        }
        if (timezone != null) {
          _selectedTimezone = timezone;
          _userProfile!['tz'] = timezone;
        }

        await saveLocalSettings();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to update user preferences: $e';

      notifyListeners();
    }
  }

  /// Updates the local dark mode setting.
  Future<void> updateDarkMode(bool value) async {
    _isDarkMode = value;
    await saveLocalSettings();
    notifyListeners();
  }

  /// Toggles push notifications setting.
  Future<void> updateNotifications(bool value) async {
    _enableNotifications = value;
    await saveLocalSettings();
    notifyListeners();
  }

  /// Toggles interface sound effects.
  Future<void> updateSoundEffects(bool value) async {
    _enableSoundEffects = value;
    await saveLocalSettings();
    notifyListeners();
  }

  /// Toggles haptic feedback setting.
  Future<void> updateHapticFeedback(bool value) async {
    _enableHapticFeedback = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateAutoSync(bool value) async {
    _autoSyncData = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateCompactView(bool value) async {
    _compactView = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateOfflineMode(bool value) async {
    _offlineMode = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateLanguage(String value) async {
    await updateUserPreferences(language: value);
  }

  Future<void> updateCurrency(String value) async {
    _selectedCurrency = value;
    await saveLocalSettings();
    notifyListeners();
  }

  Future<void> updateTimezone(String value) async {
    await updateUserPreferences(timezone: value);
  }

  Future<void> updateSyncInterval(int value) async {
    _syncInterval = value;
    await saveLocalSettings();
    notifyListeners();
  }

  String getLanguageDisplayName(String code) {
    final language = _availableLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'name': code},
    );
    return language['name'] ?? code;
  }

  String getCurrencyDisplayName(String code) {
    final currency = _availableCurrencies.firstWhere(
      (curr) => curr['name'] == code,
      orElse: () => {'full_name': code},
    );
    return currency['full_name'] ?? code;
  }

  String getTimezoneDisplayName(String code) {
    final timezone = _availableTimezones.firstWhere(
      (tz) => tz['code'] == code,
      orElse: () => {'name': code},
    );
    return timezone['name'] ?? code;
  }

  Future<void> clearData() async {
    _userProfile = null;
    _companyInfo = null;
    _availableLanguages.clear();
    _availableCurrencies.clear();
    _availableTimezones.clear();
    _isLoading = false;
    _isLoadingLanguages = false;
    _isLoadingCurrencies = false;
    _isLoadingUserProfile = false;
    _error = null;

    _enableNotifications = true;
    _enableSoundEffects = true;
    _enableHapticFeedback = true;
    _autoSyncData = true;
    _compactView = false;
    _offlineMode = false;
    _selectedLanguage = 'en_US';
    _selectedCurrency = 'USD';
    _selectedTimezone = 'UTC';
    _syncInterval = 30;
    _cacheSize = 0.0;

    notifyListeners();
  }

  Future<void> refresh() async {
    await fetchAllOdooData();
  }
}
