import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../models/odoo_settings.dart';
import '../services/odoo_api_service.dart';
import '../services/odoo_error_handler.dart';

/// Provider for fetching and caching Odoo-specific settings like taxes, journals, and company info.
class OdooSettingsProvider extends ChangeNotifier {
  OdooInvoiceSettings? _settings;
  bool _isLoading = false;
  String _errorMessage = '';

  OdooInvoiceSettings? get settings => _settings;

  bool get isLoading => _isLoading;

  String get errorMessage => _errorMessage;

  final OdooApiService _apiService;
  static const String _cacheKey = 'odoo_invoice_settings_cache';

  OdooSettingsProvider({OdooApiService? apiService})
    : _apiService = apiService ?? OdooApiService() {
    _loadFromCache();
  }

  /// Generates a unique cache key based on the current database and user ID.
  String _getEffectiveCacheKey() {
    final uid = _apiService.uid;
    final db = _apiService.database;
    if (uid == null || db == null) return _cacheKey;
    final cleanDb = db.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${_cacheKey}_${cleanDb}_$uid';
  }

  /// Resets the settings state and clears the local cache.
  Future<void> clearData() async {
    _settings = null;
    _isLoading = false;
    _errorMessage = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getEffectiveCacheKey());
    notifyListeners();
  }

  /// Loads cached invoice settings from persistent storage.
  Future<void> _loadFromCache() async {
    final key = _getEffectiveCacheKey();
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(key);
      if (cachedData != null) {
        final jsonMap = json.decode(cachedData);
        _settings = OdooInvoiceSettings.fromJson(jsonMap);
        notifyListeners();
      }
    } catch (e) {}
  }

  /// Persists the provided settings to the local cache.
  Future<void> _saveToCache(OdooInvoiceSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(settings.toJson());
      final key = _getEffectiveCacheKey();
      await prefs.setString(key, jsonString);
    } catch (e) {}
  }

  /// Fetches invoice-related settings from the Odoo server.
  Future<void> fetchInvoiceSettings({bool forceRefresh = false}) async {
    if (_settings != null && !forceRefresh) {
      _fetchFromNetwork();
      return;
    }

    _setLoading(true);
    await _fetchFromNetwork();
    _setLoading(false);
  }

  /// Internal method to fetch setting data (company, currency, taxes, etc.) from Odoo.
  Future<void> _fetchFromNetwork() async {
    try {
      await Future(() async {
        final companyData = await _apiService.searchRead(
          'res.company',
          [],
          ['name', 'currency_id', 'street', 'phone', 'email', 'website', 'vat'],
          0,
          1,
        );

        if (companyData.isEmpty) {
          throw Exception('No company found');
        }

        final company = companyData.first;
        final currencyId = company['currency_id'] is List
            ? company['currency_id'][0]
            : company['currency_id'];

        final currencyData = await _apiService.searchRead(
          'res.currency',
          [
            ['id', '=', currencyId],
          ],
          ['name', 'symbol', 'position', 'decimal_places'],
          0,
          1,
        );

        final currency = currencyData.isNotEmpty ? currencyData.first : {};

        final taxData = await _apiService.searchRead(
          'account.tax',
          [
            ['type_tax_use', '=', 'sale'],
            ['active', '=', true],
          ],
          [
            'name',
            'amount',
            'amount_type',
            'type_tax_use',
            'active',
            'description',
          ],
        );

        final taxes = taxData.map((tax) => OdooTax.fromJson(tax)).toList();

        final paymentTermData = await _apiService.searchRead(
          'account.payment.term',
          [
            ['active', '=', true],
          ],
          ['name', 'note', 'active'],
        );

        final paymentTerms = paymentTermData
            .map((term) => OdooPaymentTerm.fromJson(term))
            .toList();

        final journalData = await _apiService.searchRead(
          'account.journal',
          [
            ['type', '=', 'sale'],
            ['active', '=', true],
          ],
          ['name', 'code', 'type', 'active'],
        );

        final journals = journalData
            .map((journal) => OdooJournal.fromJson(journal))
            .toList();

        final configData = await _apiService.searchRead(
          'res.config.settings',
          [],
          ['default_invoice_policy'],
          0,
          1,
        );

        final config = configData.isNotEmpty ? configData.first : {};

        final newSettings = OdooInvoiceSettings(
          companyId: company['id'] ?? 0,
          companyName: company['name']?.toString() ?? '',
          companyCurrency: currency['name']?.toString() ?? 'USD',
          currencySymbol: currency['symbol']?.toString() ?? '',
          currencyPosition: currency['position']?.toString() ?? 'before',
          decimalPlaces: currency['decimal_places'] ?? 2,
          availableTaxes: taxes,
          defaultTaxIds: [],
          paymentTerms: paymentTerms,
          defaultPaymentTermId: paymentTerms.isNotEmpty
              ? paymentTerms.first.id
              : 0,
          invoiceSequence: 'INV',
          journals: journals,
          defaultJournalId: journals.isNotEmpty ? journals.first.id : 0,
          companyAddress: company['street']?.toString() ?? '',
          companyPhone: company['phone']?.toString() ?? '',
          companyEmail: company['email']?.toString() ?? '',
          companyWebsite: company['website']?.toString() ?? '',
          companyVat: company['vat']?.toString() ?? '',
          autoPostInvoices: false,
          defaultInvoicePolicy:
              config['default_invoice_policy']?.toString() ?? 'order',
        );

        _settings = newSettings;
        _errorMessage = '';

        await _saveToCache(newSettings);
        notifyListeners();
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Odoo settings request timed out');
        },
      );
    } catch (e) {
      if (_settings == null) {
        _errorMessage = OdooErrorHandler.toUserMessage(e);
      }
    }
  }

  /// Updates the default taxes stored in the settings.
  Future<void> updateDefaultTaxes(List<int> taxIds) async {
    if (_settings == null) return;

    _setLoading(true);
    try {
      final newSettings = OdooInvoiceSettings(
        companyId: _settings!.companyId,
        companyName: _settings!.companyName,
        companyCurrency: _settings!.companyCurrency,
        currencySymbol: _settings!.currencySymbol,
        currencyPosition: _settings!.currencyPosition,
        decimalPlaces: _settings!.decimalPlaces,
        availableTaxes: _settings!.availableTaxes,
        defaultTaxIds: taxIds,
        paymentTerms: _settings!.paymentTerms,
        defaultPaymentTermId: _settings!.defaultPaymentTermId,
        invoiceSequence: _settings!.invoiceSequence,
        journals: _settings!.journals,
        defaultJournalId: _settings!.defaultJournalId,
        companyAddress: _settings!.companyAddress,
        companyPhone: _settings!.companyPhone,
        companyEmail: _settings!.companyEmail,
        companyWebsite: _settings!.companyWebsite,
        companyVat: _settings!.companyVat,
        autoPostInvoices: _settings!.autoPostInvoices,
        defaultInvoicePolicy: _settings!.defaultInvoicePolicy,
      );

      _settings = newSettings;
      await _saveToCache(newSettings);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Failed to update taxes: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the default payment term on the Odoo company record.
  Future<void> updateDefaultPaymentTerm(int paymentTermId) async {
    if (_settings == null) return;

    _setLoading(true);
    try {
      await _apiService.write(
        'res.company',
        [_settings!.companyId],
        {'property_payment_term_id': paymentTermId},
      );

      final newSettings = OdooInvoiceSettings(
        companyId: _settings!.companyId,
        companyName: _settings!.companyName,
        companyCurrency: _settings!.companyCurrency,
        currencySymbol: _settings!.currencySymbol,
        currencyPosition: _settings!.currencyPosition,
        decimalPlaces: _settings!.decimalPlaces,
        availableTaxes: _settings!.availableTaxes,
        defaultTaxIds: _settings!.defaultTaxIds,
        paymentTerms: _settings!.paymentTerms,
        defaultPaymentTermId: paymentTermId,
        invoiceSequence: _settings!.invoiceSequence,
        journals: _settings!.journals,
        defaultJournalId: _settings!.defaultJournalId,
        companyAddress: _settings!.companyAddress,
        companyPhone: _settings!.companyPhone,
        companyEmail: _settings!.companyEmail,
        companyWebsite: _settings!.companyWebsite,
        companyVat: _settings!.companyVat,
        autoPostInvoices: _settings!.autoPostInvoices,
        defaultInvoicePolicy: _settings!.defaultInvoicePolicy,
      );

      _settings = newSettings;
      await _saveToCache(newSettings);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Failed to update payment term: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates the default sales journal in the local settings.
  Future<void> updateDefaultJournal(int journalId) async {
    if (_settings == null) return;

    _setLoading(true);
    try {
      final newSettings = OdooInvoiceSettings(
        companyId: _settings!.companyId,
        companyName: _settings!.companyName,
        companyCurrency: _settings!.companyCurrency,
        currencySymbol: _settings!.currencySymbol,
        currencyPosition: _settings!.currencyPosition,
        decimalPlaces: _settings!.decimalPlaces,
        availableTaxes: _settings!.availableTaxes,
        defaultTaxIds: _settings!.defaultTaxIds,
        paymentTerms: _settings!.paymentTerms,
        defaultPaymentTermId: _settings!.defaultPaymentTermId,
        invoiceSequence: _settings!.invoiceSequence,
        journals: _settings!.journals,
        defaultJournalId: journalId,
        companyAddress: _settings!.companyAddress,
        companyPhone: _settings!.companyPhone,
        companyEmail: _settings!.companyEmail,
        companyWebsite: _settings!.companyWebsite,
        companyVat: _settings!.companyVat,
        autoPostInvoices: _settings!.autoPostInvoices,
        defaultInvoicePolicy: _settings!.defaultInvoicePolicy,
      );

      _settings = newSettings;
      await _saveToCache(newSettings);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Failed to update journal: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Updates overall company metadata (name, address, VAT, etc.) in Odoo.
  Future<void> updateCompanyInfo({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? vat,
  }) async {
    if (_settings == null) return;

    _setLoading(true);
    try {
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (address != null) updateData['street'] = address;
      if (phone != null) updateData['phone'] = phone;
      if (email != null) updateData['email'] = email;
      if (website != null) updateData['website'] = website;
      if (vat != null) updateData['vat'] = vat;

      if (updateData.isNotEmpty) {
        await _apiService.write('res.company', [
          _settings!.companyId,
        ], updateData);
      }

      final newSettings = OdooInvoiceSettings(
        companyId: _settings!.companyId,
        companyName: name ?? _settings!.companyName,
        companyCurrency: _settings!.companyCurrency,
        currencySymbol: _settings!.currencySymbol,
        currencyPosition: _settings!.currencyPosition,
        decimalPlaces: _settings!.decimalPlaces,
        availableTaxes: _settings!.availableTaxes,
        defaultTaxIds: _settings!.defaultTaxIds,
        paymentTerms: _settings!.paymentTerms,
        defaultPaymentTermId: _settings!.defaultPaymentTermId,
        invoiceSequence: _settings!.invoiceSequence,
        journals: _settings!.journals,
        defaultJournalId: _settings!.defaultJournalId,
        companyAddress: address ?? _settings!.companyAddress,
        companyPhone: phone ?? _settings!.companyPhone,
        companyEmail: email ?? _settings!.companyEmail,
        companyWebsite: website ?? _settings!.companyWebsite,
        companyVat: vat ?? _settings!.companyVat,
        autoPostInvoices: _settings!.autoPostInvoices,
        defaultInvoicePolicy: _settings!.defaultInvoicePolicy,
      );

      _settings = newSettings;
      await _saveToCache(newSettings);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Failed to update company info: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Formats a numeric amount using company-specific currency settings.
  String formatCurrency(double amount) {
    if (_settings == null) return amount.toStringAsFixed(2);

    final formattedAmount = amount.toStringAsFixed(_settings!.decimalPlaces);

    if (_settings!.currencyPosition == 'before') {
      return '${_settings!.currencySymbol}$formattedAmount';
    } else {
      return '$formattedAmount ${_settings!.currencySymbol}';
    }
  }

  /// Returns the actual tax models matching the default tax IDs.
  List<OdooTax> getDefaultTaxes() {
    if (_settings == null) return [];

    return _settings!.availableTaxes
        .where((tax) => _settings!.defaultTaxIds.contains(tax.id))
        .toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
