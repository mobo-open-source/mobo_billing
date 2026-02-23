import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/product.dart';

void main() {
  group('Product Model Tests', () {
    test('Product.fromJson should parse valid data correctly', () {
      final json = {
        'id': 501,
        'name': 'Laptop Pro',
        'standard_price': 800.0,
        'list_price': 1200.0,
        'image_128': 'base64_image_data',
        'barcode': '123456789',
        'default_code': 'LP-001',
        'uom_id': [1, 'Units'],
        'qty_available': 15.0,
        'categ_id': [5, 'Electronics'],
        'active': true,
      };

      final product = Product.fromJson(json);

      expect(product.id, 501);
      expect(product.name, 'Laptop Pro');
      expect(product.cost, 800.0);
      expect(product.listPrice, 1200.0);
      expect(product.image128, 'base64_image_data');
      expect(product.defaultCode, 'LP-001');
      expect(product.uomId, 1);
      expect(product.uomName, 'Units');
      expect(product.qtyAvailable, 15.0);
      expect(product.categoryId, 5);
      expect(product.categoryName, 'Electronics');
    });

    test('Product.fromJson should handle null/false values using _parseString', () {
      final json = {
        'id': 502,
        'name': false,
        'description': null,
        'default_code': '',
        'list_price': null,
      };

      final product = Product.fromJson(json);

      expect(product.name, 'Unknown Product');
      expect(product.description, isNull);
      expect(product.defaultCode, isNull);
      expect(product.listPrice, isNull);
    });

    test('Product.toJson should return correct map', () {
      final product = Product(
        id: 501,
        name: 'Laptop Pro',
        cost: 800.0,
        listPrice: 1200.0,
        defaultCode: 'LP-001',
        uomId: 1,
        uomName: 'Units',
      );

      final json = product.toJson();

      expect(json['id'], 501);
      expect(json['name'], 'Laptop Pro');
      expect(json['uom_id'], [1, 'Units']);
      expect(json['standard_price'], 800.0);
    });

    test('copyWith should return a new instance with updated values', () {
      final product = Product(id: 1, name: 'Old Name');
      final updated = product.copyWith(name: 'New Name', listPrice: 10.0);

      expect(updated.id, 1);
      expect(updated.name, 'New Name');
      expect(updated.listPrice, 10.0);
      expect(product.name, 'Old Name');
    });
  });
}
