import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/product_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late ProductProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    provider = ProductProvider(apiService: mockApiService);
  });

  group('ProductProvider Tests', () {
    test('loadProducts should load products and count', () async {

      when(
        () => mockApiService.call('product.template', 'search_count', any()),
      ).thenAnswer((_) async => 2);


      when(
        () => mockApiService.call(
          'product.template',
          'search_read',
          any(),
          any(),
        ),
      ).thenAnswer(
        (_) async => [
          {'id': 1, 'name': 'Product 1', 'list_price': 10.0},
          {'id': 2, 'name': 'Product 2', 'list_price': 20.0},
        ],
      );

      await provider.loadProducts();

      expect(provider.products.length, 2);
      expect(provider.totalCount, 2);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test(
      'searchProducts should trigger loadProducts with search query',
      () async {
        when(
          () => mockApiService.call('product.template', 'search_count', any()),
        ).thenAnswer((_) async => 1);

        when(
          () => mockApiService.call(
            'product.template',
            'search_read',
            any(),
            any(),
          ),
        ).thenAnswer(
          (_) async => [
            {'id': 1, 'name': 'Search Result', 'list_price': 15.0},
          ],
        );

        await provider.searchProducts('test');

        expect(provider.products.length, 1);
        expect(provider.products[0].name, 'Search Result');


        final captured = verify(
          () => mockApiService.call(
            'product.template',
            'search_count',
            captureAny(),
          ),
        ).captured;
        final domain = captured[0] as List;
        expect(domain.toString(), contains('test'));
      },
    );

    test('clearData should reset state', () async {

      when(
        () => mockApiService.call(any(), any(), any()),
      ).thenAnswer((_) async => 10);
      when(
        () => mockApiService.call(any(), any(), any(), any()),
      ).thenAnswer((_) async => []);
      await provider.loadProducts();

      await provider.clearData();

      expect(provider.products, isEmpty);
      expect(provider.totalCount, 0);
      expect(provider.error, isNull);
    });
  });
}
