import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product.fromJson should create a valid Product from Odoo JSON', () {
      final json = {
        'id': 101,
        'name': 'Test Product',
        'standard_price': 50.0,
        'list_price': 100.0,
        'qty_available': 10.5,
        'uom_id': [1, 'Units'],
        'categ_id': [5, 'All / Services'],
        'active': true,
      };

      final product = Product.fromJson(json);

      expect(product.id, 101);
      expect(product.name, 'Test Product');
      expect(product.cost, 50.0);
      expect(product.listPrice, 100.0);
      expect(product.qtyAvailable, 10.5);
      expect(product.uomId, 1);
      expect(product.uomName, 'Units');
      expect(product.categoryId, 5);
      expect(product.categoryName, 'All / Services');
      expect(product.active, true);
    });

    test('Product.fromJson should handle null/false values from Odoo', () {
      final json = {
        'id': 102,
        'name': false,
        'standard_price': null,
        'list_price': 0,
        'uom_id': false,
      };

      final product = Product.fromJson(json);

      expect(product.id, 102);
      expect(product.name, 'Unknown Product');
      expect(product.cost, isNull);
      expect(product.listPrice, 0.0);
      expect(product.uomId, isNull);
    });

    test('Product.toJson should return a valid Map', () {
      final product = Product(
        id: 201,
        name: 'Json Product',
        listPrice: 99.9,
        uomId: 1,
        uomName: 'Units',
      );

      final json = product.toJson();

      expect(json['id'], 201);
      expect(json['name'], 'Json Product');
      expect(json['list_price'], 99.9);
      expect(json['uom_id'], [1, 'Units']);
    });
  });
}
