import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/currency_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockCurrencyService mockCurrencyService;
  late CurrencyProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'userLogin': 'admin',
      'password': 'admin_password',
      'sessionId': 'test_sid',
      'serverUrl': 'https://test.odoo.com',
      'database': 'test_db',
    });
    mockCurrencyService = MockCurrencyService();
  });

  group('CurrencyProvider Tests', () {
    test('Initial state is correct and fetchCompanyCurrency is called', () async {
      when(() => mockCurrencyService.fetchUserCompany(any()))
          .thenAnswer((_) async => [{'company_id': [1, 'Test Company']}]);
      when(() => mockCurrencyService.fetchCompanyCurrency(any()))
          .thenAnswer((_) async => [{'currency_id': [3, 'EUR']}]);
      when(() => mockCurrencyService.fetchCurrencyDetails(any()))
          .thenAnswer((_) async => [{'symbol': '€', 'position': 'after', 'decimal_places': 2}]);
      when(() => mockCurrencyService.fetchAllActiveCurrencies())
          .thenAnswer((_) async => []);

      provider = CurrencyProvider(currencyService: mockCurrencyService);
      

      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(provider.currency, 'EUR');
      expect(provider.symbol, '€');
      expect(provider.position, 'after');
      expect(provider.isLoading, false);
    });

    test('formatAmount should respect currency formats', () async {

      when(() => mockCurrencyService.fetchUserCompany(any())).thenAnswer((_) async => []);
      provider = CurrencyProvider(currencyService: mockCurrencyService);
      

      expect(provider.formatAmount(100.0, currency: 'GBP'), contains('£'));
      

      final formattedEur = provider.formatAmount(100.50, currency: 'EUR');
      expect(formattedEur, contains('€'));
    });

    test('fetchCompanyCurrency error handling', () async {
      when(() => mockCurrencyService.fetchUserCompany(any()))
          .thenThrow(Exception('Network Error'));

      provider = CurrencyProvider(currencyService: mockCurrencyService);
      
      await Future.delayed(Duration.zero);

      expect(provider.error, isNotNull);
      expect(provider.isLoading, false);
    });
  });
}
