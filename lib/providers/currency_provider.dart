import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/odoo_session_manager.dart';
import '../services/odoo_error_handler.dart';
import '../services/currency_service.dart';
import 'dart:async';

/// Provider for managing currency conversion, formatting, and company currency state.
class CurrencyProvider extends ChangeNotifier {
  final CurrencyService _currencyService;
  String _currency = 'USD';
  String _symbol = '\$';
  String _position = 'before';
  int _decimalDigits = 2;
  late NumberFormat _currencyFormat;
  bool _isLoading = false;
  String? _error;
  List<dynamic>? _lastCurrencyIdList;
  Map<String, Map<String, dynamic>> _allCurrencies = {};

  final Map<String, String> currencyToLocale = {
    'USD': 'en_US',
    'EUR': 'de_DE',
    'GBP': 'en_GB',
    'INR': 'en_IN',
    'JPY': 'ja_JP',
    'CNY': 'zh_CN',
    'AUD': 'en_AU',
    'CAD': 'en_CA',
    'CHF': 'de_CH',
    'SGD': 'en_SG',
    'AED': 'ar_AE',
    'SAR': 'ar_SA',
    'QAR': 'ar_QA',
    'KWD': 'ar_KW',
    'BHD': 'ar_BH',
    'OMR': 'ar_OM',
    'MYR': 'ms_MY',
    'THB': 'th_TH',
    'IDR': 'id_ID',
    'PHP': 'fil_PH',
    'VND': 'vi_VN',
    'KRW': 'ko_KR',
    'TWD': 'zh_TW',
    'HKD': 'zh_HK',
    'NZD': 'en_NZ',
    'ZAR': 'en_ZA',
    'BRL': 'pt_BR',
    'MXN': 'es_MX',
    'ARS': 'es_AR',
    'CLP': 'es_CL',
    'COP': 'es_CO',
    'PEN': 'es_PE',
    'UYU': 'es_UY',
    'TRY': 'tr_TR',
    'ILS': 'he_IL',
    'EGP': 'ar_EG',
    'PKR': 'ur_PK',
    'BDT': 'bn_BD',
    'LKR': 'si_LK',
    'NPR': 'ne_NP',
    'MMK': 'my_MM',
    'KHR': 'km_KH',
    'LAK': 'lo_LA',
  };

  CurrencyProvider({CurrencyService? currencyService})
    : _currencyService = currencyService ?? CurrencyService() {
    final locale = currencyToLocale['USD'] ?? 'en_US';
    _currencyFormat = NumberFormat.currency(locale: locale, decimalDigits: 2);
    fetchCompanyCurrency();
  }

  String get currency => _currency;

  String get symbol => _symbol;

  String get position => _position;

  int get decimalDigits => _decimalDigits;

  NumberFormat get currencyFormat => _currencyFormat;

  bool get isLoading => _isLoading;

  String? get error => _error;

  String get companyCurrencyId => _currency;

  List<dynamic>? get companyCurrencyIdList => _lastCurrencyIdList;

  /// Fetches the user's company currency and its formatting details.
  Future<void> fetchCompanyCurrency() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future(() async {
        final session = await OdooSessionManager.getCurrentSession();
        if (session == null) {
          throw Exception('No active session');
        }

        final userResult = await _currencyService.fetchUserCompany(
          session.userLogin,
        );

        if (userResult == null || userResult.isEmpty) {
          throw Exception('User data not found');
        }

        final companyId = userResult[0]['company_id'][0];

        final companyResult = await _currencyService.fetchCompanyCurrency(
          companyId,
        );

        if (companyResult == null || companyResult.isEmpty) {
          throw Exception('Company data not found');
        }

        final currencyId = companyResult[0]['currency_id'];
        if (currencyId is List && currencyId.length > 1) {
          _currency = currencyId[1].toString();
          _lastCurrencyIdList = currencyId;

          final currencyDetails = await _currencyService.fetchCurrencyDetails(
            currencyId[0],
          );

          if (currencyDetails != null && currencyDetails.isNotEmpty) {
            final details = currencyDetails[0];
            _symbol = details['symbol']?.toString() ?? '\$';
            _position = details['position']?.toString() ?? 'before';
            _decimalDigits = details['decimal_places'] ?? 2;
          }

          final locale = currencyToLocale[_currency] ?? 'en_US';
          _currencyFormat = NumberFormat.currency(
            locale: locale,
            symbol: _symbol,
            decimalDigits: _decimalDigits,
          );
        }

        await fetchAllCurrencies();
      }).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Currency request timed out');
        },
      );
    } catch (e) {
      _error = OdooErrorHandler.toUserMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches all active currencies and their metadata from the server.
  Future<void> fetchAllCurrencies() async {
    try {
      final result = await _currencyService.fetchAllActiveCurrencies();

      if (result is List) {
        _allCurrencies.clear();
        for (var item in result) {
          final code = item['name'].toString();
          _allCurrencies[code] = {
            'symbol': item['symbol']?.toString() ?? code,
            'position': item['position']?.toString() ?? 'before',
            'decimal_places': item['decimal_places'] ?? 2,
          };
        }
      }
    } catch (e) {}
  }

  /// Updates the internal currency metadata from Odoo settings.
  void updateFromSettings(List<Map<String, dynamic>> currencies) {
    for (var item in currencies) {
      final code = item['name'].toString();
      _allCurrencies[code] = {
        'symbol': item['symbol']?.toString() ?? code,
        'position': item['position']?.toString() ?? 'before',
        'decimal_places': item['rounding'] != null
            ? _getDecimalPlaces(item['rounding'])
            : 2,
      };
    }
    notifyListeners();
  }

  int _getDecimalPlaces(dynamic rounding) {
    if (rounding is num) {
      final s = rounding.toString();
      if (s.contains('.')) {
        return s.split('.')[1].length;
      }
    }
    return 2;
  }

  /// Returns the currency symbol for a given 3-letter currency code.
  String getCurrencySymbol(String currencyCode) {
    if (_allCurrencies.containsKey(currencyCode)) {
      return _allCurrencies[currencyCode]!['symbol'] ?? currencyCode;
    }

    final Map<String, String> currencySymbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'INR': '₹',
      'JPY': '¥',
      'CNY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'CHF': 'CHF',
      'SGD': 'S\$',
      'AED': 'AED',
      'SAR': 'SR',
      'QAR': 'QR',
      'KWD': 'KD',
      'BHD': 'BD',
      'OMR': 'OMR',
      'MYR': 'RM',
      'THB': '฿',
      'IDR': 'Rp',
      'PHP': '₱',
      'VND': '₫',
      'KRW': '₩',
      'TWD': 'NT\$',
      'HKD': 'HK\$',
      'NZD': 'NZ\$',
      'ZAR': 'R',
      'BRL': 'R\$',
      'MXN': 'MX\$',
      'ARS': '\$',
      'CLP': '\$',
      'COP': '\$',
      'PEN': 'S/',
      'UYU': '\$U',
      'TRY': '₺',
      'ILS': '₪',
      'EGP': 'E£',
      'PKR': '₨',
      'BDT': '৳',
      'LKR': 'Rs',
      'NPR': 'रु',
      'MMK': 'K',
      'KHR': '៛',
      'LAK': '₭',
    };

    return currencySymbols[currencyCode] ?? currencyCode;
  }

  /// Formats a numeric amount into a localized currency string.
  String formatAmount(double amount, {String? currency}) {
    final currencyCode = currency ?? _currency;
    final symbol = getCurrencySymbol(currencyCode);
    final locale = currencyToLocale[currencyCode] ?? 'en_US';

    String position = _position;
    int decimalDigits = _decimalDigits;

    if (currency != null && _allCurrencies.containsKey(currency)) {
      position = _allCurrencies[currency]!['position'] ?? 'before';
      decimalDigits = _allCurrencies[currency]!['decimal_places'] ?? 2;
    }

    final formattedAmount = NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: decimalDigits,
    ).format(amount);

    if (position == 'before') {
      return '$symbol $formattedAmount';
    } else {
      return '$formattedAmount $symbol';
    }
  }

  /// Resets the currency state to its initial values.
  Future<void> clearData() async {
    _currency = 'USD';
    final locale = currencyToLocale['USD'] ?? 'en_US';
    _currencyFormat = NumberFormat.currency(locale: locale, decimalDigits: 2);
    _isLoading = false;
    _error = null;
    _lastCurrencyIdList = null;
    notifyListeners();
  }

  void debugCurrencyFormatting() {
    final testAmount = 1234.56;
    final testCurrencies = ['USD', 'INR', 'EUR', 'GBP'];
    for (final currency in testCurrencies) {
      final locale = currencyToLocale[currency] ?? 'en_US';
      try {
        final formatter = NumberFormat.currency(
          locale: locale,
          decimalDigits: 2,
        );
        final formatted = formatter.format(testAmount);
      } catch (e) {}
    }
  }
}
