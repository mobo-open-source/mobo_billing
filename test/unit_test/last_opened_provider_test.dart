import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'package:mobo_billing/models/product.dart';
import 'package:mobo_billing/models/customer.dart';
import 'package:mobo_billing/models/invoice.dart';

void main() {
  late LastOpenedProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = LastOpenedProvider();
  });

  group('LastOpenedProvider Tests', () {
    test('addItem should add item and keep max 10', () async {
      for (int i = 0; i < 12; i++) {
        await provider.addItem(LastOpenedItem(
          id: 'id_$i',
          type: 'product',
          title: 'Title $i',
          subtitle: 'Subtitle $i',
          route: '/route',
          lastAccessed: DateTime.now(),
          iconKey: 'page',
        ));
      }

      expect(provider.items.length, 10);
      expect(provider.items.first.id, 'id_11');
    });

    test('trackProductAccess should add product item', () async {
      final product = Product(
        id: 1,
        name: 'Test Product',
        listPrice: 100.0,
      );

      await provider.trackProductAccess(product: product);

      expect(provider.items.length, 1);
      expect(provider.items.first.type, 'product');
      expect(provider.items.first.id, 'product_1');
    });

    test('clearData should remove all items', () async {
      await provider.addItem(LastOpenedItem(
        id: '1',
        type: 'product',
        title: 'T',
        subtitle: 'S',
        route: '/R',
        lastAccessed: DateTime.now(),
        iconKey: 'page',
      ));

      await provider.clearData();

      expect(provider.items, isEmpty);
    });
  });
}
