import 'dart:async';
import './odoo_session_manager.dart';

/// Service for fetching currency-related data from Odoo.
class CurrencyService {
  /// Fetches the default company assigned to a specific user.
  Future<dynamic> fetchUserCompany(String login) async {
    return await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'search_read',
      'args': [
        [
          ['login', '=', login],
        ],
        ['company_id'],
      ],
      'kwargs': {},
    });
  }

  /// Fetches the default currency for a specific company.
  Future<dynamic> fetchCompanyCurrency(int companyId) async {
    return await OdooSessionManager.callKwWithCompany({
      'model': 'res.company',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', companyId],
        ],
        ['currency_id'],
      ],
      'kwargs': {},
    });
  }

  /// Fetches full details (name, symbol, decimal places) for a specific currency.
  Future<dynamic> fetchCurrencyDetails(int currencyId) async {
    return await OdooSessionManager.callKwWithCompany({
      'model': 'res.currency',
      'method': 'read',
      'args': [
        [currencyId],
      ],
      'kwargs': {
        'fields': ['name', 'symbol', 'position', 'decimal_places'],
      },
    });
  }

  /// Fetches all active currencies available in the Odoo instance.
  Future<dynamic> fetchAllActiveCurrencies() async {
    return await OdooSessionManager.callKwWithCompany({
      'model': 'res.currency',
      'method': 'search_read',
      'args': [
        [
          ['active', '=', true],
        ],
      ],
      'kwargs': {
        'fields': ['name', 'symbol', 'position', 'decimal_places'],
      },
    });
  }
}
