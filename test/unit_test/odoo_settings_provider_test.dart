import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/odoo_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late OdooSettingsProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApiService = MockOdooApiService();
    provider = OdooSettingsProvider(apiService: mockApiService);
  });

  group('OdooSettingsProvider Tests', () {
    test('fetchInvoiceSettings should load settings from network', () async {

      when(() => mockApiService.searchRead('res.company', any(), any(), 0, 1))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'Test Company', 'currency_id': [1, 'USD']}
              ]);
      
      when(() => mockApiService.searchRead('res.currency', any(), any(), 0, 1))
          .thenAnswer((_) async => [
                {'name': 'USD', 'symbol': '\$', 'position': 'before', 'decimal_places': 2}
              ]);

      when(() => mockApiService.searchRead('account.tax', any(), any()))
          .thenAnswer((_) async => []);

      when(() => mockApiService.searchRead('account.payment.term', any(), any()))
          .thenAnswer((_) async => []);

      when(() => mockApiService.searchRead('account.journal', any(), any()))
          .thenAnswer((_) async => []);

      when(() => mockApiService.searchRead('res.config.settings', any(), any(), 0, 1))
          .thenAnswer((_) async => []);

      await provider.fetchInvoiceSettings(forceRefresh: true);

      expect(provider.settings, isNotNull);
      expect(provider.settings!.companyName, 'Test Company');
      expect(provider.settings!.companyCurrency, 'USD');
      expect(provider.isLoading, false);
    });

    test('clearData should reset settings and remove from cache', () async {

      when(() => mockApiService.searchRead('res.company', any(), any(), 0, 1))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'Test Company', 'currency_id': [1, 'USD']}
              ]);
      when(() => mockApiService.searchRead(any(), any(), any(), any(), any())).thenAnswer((_) async => []);
      
      await provider.fetchInvoiceSettings(forceRefresh: true);

      await provider.clearData();

      expect(provider.settings, isNull);
      expect(provider.errorMessage, isEmpty);
    });
  });
}
