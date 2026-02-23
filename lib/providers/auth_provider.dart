import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_session_manager.dart';
import '../services/session_service.dart';

/// Provider for managing user authentication state, login, and logout operations.
class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  final OdooApiService _apiService;
  final SessionService _sessionService;
  bool _sessionExpired = false;

  AuthProvider({
    OdooApiService? apiService,
    SessionService? sessionService,
  })  : _apiService = apiService ?? OdooApiService(),
        _sessionService = sessionService ?? SessionService.instance;

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get sessionExpired => _sessionExpired;

  bool get isAuthenticated => _user != null;


  /// authenticates the user using username and password.
  Future<bool> login(
    String serverUrl,
    String database,
    String username,
    String password,
  ) async {
    _setLoading(true);
    _setError(null);

    try {

      _apiService.initialize(serverUrl, database);


      final result = await _apiService.authenticate(username, password);

      if (result['success'] == true) {
        _user = UserModel(
          uid: result['uid'],
          username: username,
          name: _apiService.userInfo['name'] ?? username,
          serverUrl: serverUrl,
          database: database,
          sessionId: result['session_id'],
          context: _apiService.userInfo['context'] ?? {},
          profileImage: _apiService.userInfo['image_128'],
        );
        _sessionExpired = false;
        await _saveUserSession();


        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('odoo_name', _user!.name);
        if (_user!.profileImage != null) {
          await prefs.setString('odoo_profile_image', _user!.profileImage!);
        }

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('null') || errorStr.contains('two factor') || errorStr.contains('2fa')) {

        _setLoading(false);
        rethrow;
      }
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }


  /// authenticates the user using a pre-existing session ID.
  Future<bool> loginWithSessionId({
    required String serverUrl,
    required String database,
    required String username,
    required String password,
    required String sessionId,
    Map<String, dynamic>? sessionInfo,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await OdooSessionManager.loginWithSessionId(
        serverUrl: serverUrl,
        database: database,
        userLogin: username,
        password: password,
        sessionId: sessionId,
        sessionInfo: sessionInfo,
      );

      

      if (success) {
        final session = await OdooSessionManager.getCurrentSession();
        if (session != null) {
          _user = UserModel(
            uid: session.userId ?? 0,
            username: username,
            name: session.userName ?? username,
            serverUrl: serverUrl,
            database: database,
            sessionId: sessionId,
            context: {},
          );
          _sessionExpired = false;
          await _saveUserSession();

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('odoo_name', _user!.name);

          _setLoading(false);
          notifyListeners();
          

          if (session.userId != null) {
            _refreshUserDataInBackground(session.userId!);
          }
          
          return true;
        }
      }
      throw Exception('Failed to initialize session from ID');
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }


  /// Attempts to restore a session from local storage.
  Future<bool> autoLogin() async {
    _setLoading(true);
    try {

      final session = await OdooSessionManager.getCurrentSession();

      if (session != null) {

        _apiService.initialize(session.serverUrl, session.database);


        _user = UserModel(
          uid: session.userId ?? 0,
          username: session.userLogin,
          name: session.userLogin,

          serverUrl: session.serverUrl,
          database: session.database,
          sessionId: session.sessionId,
          context: {},
        );

        _sessionExpired = false;
        _setLoading(false);
        notifyListeners();


        if (session.userId != null) {
          _refreshUserDataInBackground(session.userId!);
        }

        return true;
      }

      _setLoading(false);
      return false;
    } catch (e) {

      _setLoading(false);
      return false;
    }
  }


  /// Refreshes the user's name and image from the server without blocking the UI.
  Future<void> _refreshUserDataInBackground(int uid) async {
    try {
      final userData = await _apiService.call(
        'res.users',
        'read',
        [uid],
        {
          'fields': ['name', 'login', 'image_128'],
        },
      );

      if (userData is List && userData.isNotEmpty && userData[0] != null) {
        final userInfo = userData[0] as Map<String, dynamic>;
        final newName = userInfo['name'] ?? _user!.name;
        var newImage = userInfo['image_128'];
        if (newImage is bool && newImage == false) {
          newImage = null;
        }

        if (newName != _user!.name || newImage != _user!.profileImage) {
          _user = _user!.copyWith(name: newName, profileImage: newImage);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('odoo_name', newName);
          if (newImage != null) {
            await prefs.setString('odoo_profile_image', newImage);
          }

          await _saveUserSession();
          notifyListeners();

        }
      }
    } catch (e) {


    }
  }


  /// Logs out the user and clears all session-related data.
  Future<void> logout() async {

    try {
      
      await _sessionService.logout();
    } catch (e) {
      

      await _apiService.logout();
      await OdooSessionManager.logout();
    }
    
    _user = null;
    _sessionExpired = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_session');
    await prefs.setBool('isLoggedIn', false);

    notifyListeners();
  }


  /// Serializes and saves the current user's session to SharedPreferences.
  Future<void> _saveUserSession() async {
    if (_user != null) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = _user!.toJson();
      await prefs.setString(
        'user_session',
        Uri(
          queryParameters: userJson.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        ).query,
      );
    }
  }


  /// Returns a list of saved server configurations.
  Future<List<Map<String, String>>> getSavedConfigurations() async {
    final prefs = await SharedPreferences.getInstance();
    final configs = prefs.getStringList('saved_configs') ?? [];

    return configs.map((config) {
      final parts = config.split('|');
      return {
        'name': parts.length > 0 ? parts[0] : '',
        'url': parts.length > 1 ? parts[1] : '',
        'database': parts.length > 2 ? parts[2] : '',
      };
    }).toList();
  }


  /// Saves a server configuration (name, URL, database) for future logins.
  Future<void> saveConfiguration(
    String name,
    String url,
    String database,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = prefs.getStringList('saved_configs') ?? [];

    final newConfig = '$name|$url|$database';
    if (!configs.contains(newConfig)) {
      configs.add(newConfig);
      await prefs.setStringList('saved_configs', configs);
    }
  }


  /// Removes a previously saved server configuration.
  Future<void> removeConfiguration(
    String name,
    String url,
    String database,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final configs = prefs.getStringList('saved_configs') ?? [];

    final configToRemove = '$name|$url|$database';
    configs.remove(configToRemove);
    await prefs.setStringList('saved_configs', configs);
  }

  /// Internal helper to update the loading state and notify listeners.
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Internal helper to set an error message and notify listeners.
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }


  /// Refreshes the current user's name and profile image from the server.
  Future<void> refreshUserName() async {
    if (_user != null) {
      try {
        final userData = await _apiService.call(
          'res.users',
          'read',
          [_user!.uid],
          {
            'fields': ['name', 'login', 'image_128'],
          },
        );
        if (userData is List && userData.isNotEmpty && userData[0] != null) {
          final userInfo = userData[0] as Map<String, dynamic>;
          final newName =
              userInfo['name'] ?? userInfo['login'] ?? _user!.username;
          var newImage = userInfo['image_128'];
          if (newImage is bool && newImage == false) {
            newImage = null;
          }

          bool needsUpdate = false;
          if (newName != _user!.name) {
            needsUpdate = true;
          }
          if (newImage != _user!.profileImage) {
            needsUpdate = true;
          }

          if (needsUpdate) {
            _user = _user!.copyWith(name: newName, profileImage: newImage);
            await _saveUserSession();
            notifyListeners();

          }
        }
      } catch (e) {

      }
    }
  }

  /// Resets the authentication state to its initial values.
  Future<void> clearData() async {
    _user = null;
    _error = null;
    _sessionExpired = false;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }


  /// Checks if the 'account' module is installed on the Odoo server.
  Future<bool> checkRequiredModules() async {

    return await _apiService.isModuleInstalled('account');
  }
}
