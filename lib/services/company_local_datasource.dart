import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local data source for caching company information using SharedPreferences.
class CompanyLocalDataSource {
  static const String _companiesKey = 'cached_companies';

  const CompanyLocalDataSource();

  /// Caches a list of companies for a specific user and database.
  Future<void> putAllCompanies(
    List<Map<String, dynamic>> companies, {
    int? userId,
    String? database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = companies.map((c) => jsonEncode(c)).toList();
    await prefs.setStringList(_getCacheKey(userId, database), jsonList);
  }

  /// Retrieves the cached list of companies for a specific user and database.
  Future<List<Map<String, dynamic>>> getAllCompanies({
    int? userId,
    String? database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_getCacheKey(userId, database));

    if (jsonList == null) return [];

    return jsonList.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  String _getCacheKey(int? userId, String? database) {
    if (userId == null || database == null) return _companiesKey;
    return '${_companiesKey}_${database}_$userId';
  }

  /// Clears the cached company data for a specific user and database.
  Future<void> clear({int? userId, String? database}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getCacheKey(userId, database));
  }
}
