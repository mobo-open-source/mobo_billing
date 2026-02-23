import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OdooSessionModel {
  final String sessionId;
  final String userLogin;
  final String password;
  final String serverUrl;
  final String database;
  final int? userId;
  final String? userName;
  final DateTime? expiresAt;
  final int? selectedCompanyId;
  final List<int> allowedCompanyIds;
  final String? serverVersion;

  OdooSessionModel({
    required this.sessionId,
    required this.userLogin,
    required this.password,
    required this.serverUrl,
    required this.database,
    this.userId,
    this.userName,
    this.expiresAt,
    this.selectedCompanyId,
    this.allowedCompanyIds = const [],
    this.serverVersion,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  OdooSession get odooSession {
    return OdooSession(
      id: sessionId,
      userId: userId ?? 0,
      partnerId: 0,
      userLogin: userLogin,
      userName: userName ?? '',
      userLang: '',
      userTz: '',
      isSystem: false,
      dbName: database,
      serverVersion: serverVersion ?? '',
      companyId: selectedCompanyId ?? 0,
      allowedCompanies: allowedCompanyIds
          .map((id) => Company(id: id, name: 'Company $id'))
          .toList(),
    );
  }

  /// Converts a raw OdooSession into the enriched OdooSessionModel.
  factory OdooSessionModel.fromOdooSession(
      OdooSession session, String userLogin, String password, String serverUrl, String database,
      [String? userName]) {
    return OdooSessionModel(
      sessionId: session.id,
      userLogin: userLogin,
      password: password,
      serverUrl: serverUrl,
      database: database,
      userId: session.userId,
      userName: userName,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      serverVersion: session.serverVersion,
    );
  }

  OdooSessionModel copyWith({
    String? sessionId,
    String? userLogin,
    String? password,
    String? serverUrl,
    String? database,
    int? userId,
    String? userName,
    DateTime? expiresAt,
    int? selectedCompanyId,
    List<int>? allowedCompanyIds,
    String? serverVersion,
  }) {
    return OdooSessionModel(
      sessionId: sessionId ?? this.sessionId,
      userLogin: userLogin ?? this.userLogin,
      password: password ?? this.password,
      serverUrl: serverUrl ?? this.serverUrl,
      database: database ?? this.database,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      expiresAt: expiresAt ?? this.expiresAt,
      selectedCompanyId: selectedCompanyId ?? this.selectedCompanyId,
      allowedCompanyIds: allowedCompanyIds ?? this.allowedCompanyIds,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  /// Persists the current session details to local SharedPreferences.
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    

    final biometricEnabled = prefs.getBool('biometric_enabled');

    await prefs.setString('sessionId', sessionId);
    await prefs.setString('userLogin', userLogin);
    await prefs.setString('password', password);
    await prefs.setString('database', database);
    await prefs.setString('serverUrl', serverUrl);
    if (userId != null) await prefs.setInt('userId', userId!);
    if (userName != null) await prefs.setString('userName', userName!);
    if (expiresAt != null) await prefs.setString('expiresAt', expiresAt!.toIso8601String());
    if (selectedCompanyId != null) await prefs.setInt('selectedCompanyId', selectedCompanyId!);
    if (serverVersion != null) await prefs.setString('serverVersion', serverVersion!);
    
    await prefs.setStringList('allowedCompanyIds', allowedCompanyIds.map((e) => e.toString()).toList());
    
    await prefs.setBool('isLoggedIn', true);

    if (biometricEnabled != null) {
      await prefs.setBool('biometric_enabled', biometricEnabled);
    }
  }

  /// Restores a previously saved session from SharedPreferences.
  static Future<OdooSessionModel?> fromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) return null;

    final sessionId = prefs.getString('sessionId');
    final userLogin = prefs.getString('userLogin');
    final password = prefs.getString('password');
    final rawServerUrl = prefs.getString('serverUrl');
    final database = prefs.getString('database');
    final userId = prefs.getInt('userId');
    final userName = prefs.getString('userName');
    final expiresAtStr = prefs.getString('expiresAt');
    final selectedCompanyId = prefs.getInt('selectedCompanyId');
    final serverVersion = prefs.getString('serverVersion');
    final allowedCompanyIdsStr = prefs.getStringList('allowedCompanyIds') ?? [];

    if ([sessionId, userLogin, password, rawServerUrl, database].contains(null)) {
      return null;
    }

    String serverUrl = rawServerUrl!.trim();
    if (!serverUrl.startsWith('http://') && !serverUrl.startsWith('https://')) {
      serverUrl = 'https://' + serverUrl;
    }

    DateTime? expiresAt;
    if (expiresAtStr != null) {
      expiresAt = DateTime.tryParse(expiresAtStr);
    }

    final allowedCompanyIds = allowedCompanyIdsStr
        .map((e) => int.tryParse(e))
        .where((e) => e != null)
        .cast<int>()
        .toList();

    return OdooSessionModel(
      sessionId: sessionId!,
      userLogin: userLogin!,
      password: password!,
      serverUrl: serverUrl,
      database: database!,
      userId: userId,
      userName: userName,
      expiresAt: expiresAt,
      selectedCompanyId: selectedCompanyId,
      allowedCompanyIds: allowedCompanyIds,
      serverVersion: serverVersion,
    );
  }
}
