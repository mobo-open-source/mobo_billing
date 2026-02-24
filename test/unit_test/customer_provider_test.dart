import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/customer_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late CustomerProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    provider = CustomerProvider(apiService: mockApiService);
  });

  group('CustomerProvider Tests', () {
    test('loadCustomers should load customers and count', () async {

      when(
        () => mockApiService.call('res.partner', 'search_count', any()),
      ).thenAnswer((_) async => 2);


      when(
        () => mockApiService.call('res.partner', 'search_read', any(), any()),
      ).thenAnswer(
        (_) async => [
          {'id': 1, 'name': 'Customer 1', 'email': 'c1@test.com'},
          {'id': 2, 'name': 'Customer 2', 'email': 'c2@test.com'},
        ],
      );

      await provider.loadCustomers();

      expect(provider.customers.length, 2);
      expect(provider.totalCount, 2);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test(
      'searchCustomers should trigger loadCustomers with search query',
      () async {
        when(
          () => mockApiService.call('res.partner', 'search_count', any()),
        ).thenAnswer((_) async => 1);

        when(
          () => mockApiService.call('res.partner', 'search_read', any(), any()),
        ).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Search Result'},
          ],
        );

        await provider.searchCustomers('test');

        expect(provider.customers.length, 1);
        expect(provider.customers[0].name, 'Search Result');
      },
    );

    test('createCustomer should call api create and refresh list', () async {
      final customerData = {'name': 'New Customer'};
      when(
        () => mockApiService.create('res.partner', customerData),
      ).thenAnswer((_) async => 3);


      when(
        () => mockApiService.call(any(), any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockApiService.call(any(), any(), any(), any()),
      ).thenAnswer((_) async => []);

      final id = await provider.createCustomer(customerData);

      expect(id, 3);
      verify(
        () => mockApiService.create('res.partner', customerData),
      ).called(1);
    });

    test(
      'deleteCustomer should call api unlink and remove from list',
      () async {

        when(
          () => mockApiService.call('res.partner', 'search_count', any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockApiService.call('res.partner', 'search_read', any(), any()),
        ).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Customer to delete'},
          ],
        );

        await provider.loadCustomers();
        expect(provider.totalCount, 1);

        when(
          () => mockApiService.unlink('res.partner', [1]),
        ).thenAnswer((_) async => true);

        final result = await provider.deleteCustomer(1);

        expect(result, true);
        expect(provider.customers, isEmpty);
        expect(provider.totalCount, 0);
      },
    );
  });
}
