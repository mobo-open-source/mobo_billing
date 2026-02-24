import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/odoo_session_manager.dart';
import '../services/company_local_datasource.dart';
import '../services/session_service.dart';
import '../services/odoo_api_service.dart';

/// Provider for managing company selection and multi-company access.
class CompanyProvider extends ChangeNotifier {
  final OdooApiService _apiService;
  final SessionService _sessionService;
  final CompanyLocalDataSource _localDataSource;

  CompanyProvider({
    OdooApiService? apiService,
    SessionService? sessionService,
    CompanyLocalDataSource? localDataSource,
  }) : _apiService = apiService ?? OdooApiService(),
       _sessionService = sessionService ?? SessionService.instance,
       _localDataSource = localDataSource ?? const CompanyLocalDataSource();

  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;

  List<int> _selectedAllowedCompanyIds = [];
  bool _loading = true;
  bool _switching = false;
  String? _error;

  List<Map<String, dynamic>> get companies => _companies;

  int? get selectedCompanyId => _selectedCompanyId;

  List<int> get selectedAllowedCompanyIds => _selectedAllowedCompanyIds;

  bool get isLoading => _loading;

  bool get isSwitching => _switching;

  String? get error => _error;

  Map<String, dynamic>? get selectedCompany {
    if (_selectedCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c['id'] == _selectedCompanyId);
    } catch (e) {
      return null;
    }
  }

  /// Resets the company state to its initial values.
  Future<void> clearData() async {
    _companies = [];
    _selectedCompanyId = null;
    _selectedAllowedCompanyIds = [];
    _loading = false;
    _switching = false;
    _error = null;
    notifyListeners();
  }

  /// Updates the list of allowed companies for the current session.
  Future<void> setAllowedCompanies(List<int> allowedIds) async {
    final availableIds = _companies.map((c) => c['id'] as int).toSet();
    final filtered = allowedIds
        .where((id) => availableIds.contains(id))
        .toList();

    if (_selectedCompanyId != null && !filtered.contains(_selectedCompanyId)) {
      filtered.add(_selectedCompanyId!);
    }
    _selectedAllowedCompanyIds = filtered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
    notifyListeners();
  }

  /// Loads the list of accessible companies and restores the previous selection.
  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await Future(() async {
        final session = _sessionService.currentSession;
        if (session == null || session.userId == null) {
          _companies = await _localDataSource.getAllCompanies();
          _selectedCompanyId = null;
          await _ensureSelection(currentCompanyIdFromSession: null);
          _loading = false;
          notifyListeners();
          return;
        }

        final uid = session.userId!;
        final db = session.database;

        final userRes = await _apiService.callKwWithoutCompany({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [uid],
            ['company_id', 'company_ids'],
          ],
          'kwargs': {},
        });

        List<int> companyIds = [];
        int? currentCompanyId;
        if (userRes is List && userRes.isNotEmpty && userRes.first != null) {
          final row = userRes.first as Map<String, dynamic>;
          if (row['company_ids'] is List) {
            final raw = row['company_ids'] as List;
            companyIds = raw.whereType<int>().toList();
          }
          if (row['company_id'] is List &&
              (row['company_id'] as List).isNotEmpty) {
            currentCompanyId = (row['company_id'] as List).first as int?;
          } else if (row['company_id'] is int) {
            currentCompanyId = row['company_id'];
          }
        }

        if (companyIds.isEmpty) {
          _companies = [];
          _selectedCompanyId = currentCompanyId;

          await _localDataSource.clear(userId: uid, database: db);
          _loading = false;
          notifyListeners();
          return;
        }

        final companiesRes = await _apiService.callKwWithoutCompany({
          'model': 'res.company',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', companyIds],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'name asc',
          },
        });

        final serverCompanies = (companiesRes is List)
            ? companiesRes.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

        if (serverCompanies.isNotEmpty) {
          _companies = serverCompanies;

          await _localDataSource.putAllCompanies(
            _companies,
            userId: uid,
            database: db,
          );
        } else {
          _companies = await _localDataSource.getAllCompanies(
            userId: uid,
            database: db,
          );
        }

        await _ensureSelection(currentCompanyIdFromSession: currentCompanyId);

        final prefs = await SharedPreferences.getInstance();
        final pendingId = prefs.getInt('pending_company_id');

        if (pendingId != null && companyIds.contains(pendingId)) {
          try {
            await _applyCompanyOnServer(uid, pendingId);
            await OdooSessionManager.refreshSession();
            await OdooSessionManager.restoreSession(companyId: pendingId);
            await prefs.remove('pending_company_id');
          } catch (_) {}
        } else if (_selectedCompanyId != null &&
            currentCompanyId != _selectedCompanyId &&
            companyIds.contains(_selectedCompanyId)) {
          try {
            await _applyCompanyOnServer(uid, _selectedCompanyId!);
            await OdooSessionManager.refreshSession();
            await OdooSessionManager.restoreSession(
              companyId: _selectedCompanyId!,
            );
          } catch (_) {}
        }
      }).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException(
            'Loading companies timed out after 15 seconds',
          );
        },
      );
    } on TimeoutException catch (e) {
      try {
        final session = _sessionService.currentSession;
        _companies = await _localDataSource.getAllCompanies(
          userId: session?.userId,
          database: session?.database,
        );
        await _ensureSelection(currentCompanyIdFromSession: null);
        if (_companies.isEmpty) {
          _error =
              'Request timed out. Please check your connection and try again.';
        }
      } catch (_) {
        _error =
            'Request timed out. Please check your connection and try again.';
      }
    } catch (e) {
      try {
        final session = _sessionService.currentSession;
        _companies = await _localDataSource.getAllCompanies(
          userId: session?.userId,
          database: session?.database,
        );
        await _ensureSelection(currentCompanyIdFromSession: null);
        if (_companies.isEmpty) {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _ensureSelection({int? currentCompanyIdFromSession}) async {
    if (_companies.isEmpty) {
      _selectedCompanyId = null;
      return;
    }

    final companyIds = _companies.map((c) => c['id'] as int).toList();
    final prefs = await SharedPreferences.getInstance();
    final restoredId = prefs.getInt('selected_company_id');
    final pendingId = prefs.getInt('pending_company_id');
    final restoredAllowed =
        prefs
            .getStringList('selected_allowed_company_ids')
            ?.map((e) => int.tryParse(e) ?? -1)
            .where((e) => e > 0)
            .toList() ??
        [];

    int? desiredId =
        pendingId ??
        restoredId ??
        currentCompanyIdFromSession ??
        (companyIds.isNotEmpty ? companyIds.first : null);

    if (desiredId != null && !companyIds.contains(desiredId)) {
      desiredId = null;
    }

    if (desiredId == null && companyIds.isNotEmpty) {
      desiredId = companyIds.first;
    }

    _selectedCompanyId = desiredId;

    List<int> defaultAllowed = companyIds;
    final restoredValid = restoredAllowed
        .where((id) => companyIds.contains(id))
        .toList();
    _selectedAllowedCompanyIds = restoredValid.isNotEmpty
        ? restoredValid
        : defaultAllowed;

    if (_selectedCompanyId != null &&
        !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
      _selectedAllowedCompanyIds = [
        ..._selectedAllowedCompanyIds,
        _selectedCompanyId!,
      ];
    }

    if (_selectedCompanyId != null) {
      await prefs.setInt('selected_company_id', _selectedCompanyId!);
    }
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
  }

  /// Refetch the company list from the server and updates the local cache.
  Future<void> refreshCompaniesList() async {
    _loading = true;
    notifyListeners();
    try {
      final session = _sessionService.currentSession;
      final uid = session?.userId;
      final db = session?.database;

      final list = await _apiService.callKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });
      if (list is List && list.isNotEmpty) {
        _companies = list.cast<Map<String, dynamic>>();
        await _localDataSource.putAllCompanies(
          _companies,
          userId: uid,
          database: db,
        );
      } else {
        _companies = await _localDataSource.getAllCompanies(
          userId: uid,
          database: db,
        );
      }
    } catch (_) {
      try {
        final session = _sessionService.currentSession;
        _companies = await _localDataSource.getAllCompanies(
          userId: session?.userId,
          database: session?.database,
        );
      } catch (_) {}
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Switches the active company on the server and refreshes application data.
  Future<bool> switchCompany(
    int companyId, {
    List<int>? allowedCompanyIds,
  }) async {
    if (_selectedCompanyId == companyId) return true;
    bool appliedImmediately = false;
    try {
      _switching = true;
      _error = null;
      notifyListeners();
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('selected_company_id', companyId);
        await prefs.setInt('pending_company_id', companyId);
        _selectedCompanyId = companyId;

        _selectedAllowedCompanyIds = allowedCompanyIds ?? [companyId];
        await prefs.setStringList(
          'selected_allowed_company_ids',
          _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
        );
        notifyListeners();
        return false;
      }

      try {
        await _applyCompanyOnServer(session.userId!, companyId);

        await OdooSessionManager.refreshSession();
        await OdooSessionManager.restoreSession(companyId: companyId);

        List<int> allowed = allowedCompanyIds ?? [companyId];
        await OdooSessionManager.updateCompanySelection(
          companyId: companyId,
          allowedCompanyIds: allowed,
        );

        appliedImmediately = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_company_id');
      } catch (_) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pending_company_id', companyId);
        appliedImmediately = false;

        List<int> allowed = allowedCompanyIds ?? [companyId];
        await OdooSessionManager.updateCompanySelection(
          companyId: companyId,
          allowedCompanyIds: allowed,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_company_id', companyId);

      _selectedAllowedCompanyIds = allowedCompanyIds ?? [companyId];
      await prefs.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      _selectedCompanyId = companyId;
      notifyListeners();

      await refreshCompaniesList();

      await SessionService().refreshAllData();

      return appliedImmediately;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  Future<void> _applyCompanyOnServer(int userId, int companyId) async {
    await _apiService.callKwWithoutCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {'company_id': companyId},
      ],
      'kwargs': {},
    });
  }

  /// Toggles a company's inclusion in the allowed companies list.
  Future<void> toggleAllowedCompany(int companyId) async {
    if (_selectedAllowedCompanyIds.contains(companyId)) {
      if (companyId == _selectedCompanyId) {
        return;
      }
      _selectedAllowedCompanyIds = _selectedAllowedCompanyIds
          .where((id) => id != companyId)
          .toList();
    } else {
      _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }

    notifyListeners();
  }
}
