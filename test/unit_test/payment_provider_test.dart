import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/payment_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late PaymentProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    provider = PaymentProvider(apiService: mockApiService);
  });

  group('PaymentProvider Tests', () {
    test('loadPayments should load payments and count', () async {

      when(() => mockApiService.searchRead('account.payment', any(), any(), any(), any(), any()))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'PAY/2026/001', 'amount': 100.0, 'state': 'posted'},
                {'id': 2, 'name': 'PAY/2026/002', 'amount': 200.0, 'state': 'draft'},
              ]);
      

      when(() => mockApiService.getCount('account.payment', domain: any(named: 'domain')))
          .thenAnswer((_) async => 2);

      await provider.loadPayments();

      expect(provider.payments.length, 2);
      expect(provider.totalCount, 2);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('searchPayments should trigger search with query', () async {
      when(() => mockApiService.searchRead('account.payment', any(), any(), any(), any()))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'SEARCH/001', 'amount': 50.0, 'state': 'posted'},
              ]);
      
      when(() => mockApiService.getCount('account.payment', domain: any(named: 'domain')))
          .thenAnswer((_) async => 1);

      await provider.searchPayments('test');

      expect(provider.payments.length, 1);
      expect(provider.payments[0].name, 'SEARCH/001');
    });

    test('confirmPayment should call api action_post', () async {
      when(() => mockApiService.call('account.payment', 'action_post', [[1]]))
          .thenAnswer((_) async => true);
      

      when(() => mockApiService.searchRead(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => []);
      when(() => mockApiService.getCount(any(), domain: any(named: 'domain'))).thenAnswer((_) async => 0);

      final result = await provider.confirmPayment(1);

      expect(result, true);
      verify(() => mockApiService.call('account.payment', 'action_post', [[1]])).called(1);
    });

    test('deletePayment should call api unlink and remove from list', () async {
      when(() => mockApiService.unlink('account.payment', [1]))
          .thenAnswer((_) async => true);
      

      when(() => mockApiService.searchRead(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => []);
      when(() => mockApiService.getCount(any(), domain: any(named: 'domain'))).thenAnswer((_) async => 0);

      final result = await provider.deletePayment(1);

      expect(result, true);
      verify(() => mockApiService.unlink('account.payment', [1])).called(1);
    });
  });
}
