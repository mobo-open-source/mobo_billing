import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/customer.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromJson should create a valid Customer from Odoo JSON', () {
      final json = {
        'id': 501,
        'name': 'Customer One',
        'email': 'customer@test.com',
        'phone': '123456789',
        'is_company': true,
        'country_id': [1, 'United States'],
        'state_id': [5, 'California'],
        'total_invoiced': 1500.25,
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, 501);
      expect(customer.name, 'Customer One');
      expect(customer.email, 'customer@test.com');
      expect(customer.isCompany, true);
      expect(customer.countryId, 1);
      expect(customer.countryName, 'United States');
      expect(customer.stateId, 5);
      expect(customer.stateName, 'California');
      expect(customer.totalInvoiced, 1500.25);
    });

    test('Customer.fromJson should handle empty or false Odoo fields', () {
      final json = {
        'id': 502,
        'name': 'Minor User',
        'country_id': false,
        'email': '',
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, 502);
      expect(customer.countryId, isNull);
      expect(customer.email, isNull);
    });

    test('Customer.toJson should return a Map with populated fields', () {
      final customer = Customer(
        id: 601,
        name: 'Export Customer',
        email: 'export@test.com',
        isCompany: false,
      );

      final json = customer.toJson();

      expect(json['id'], 601);
      expect(json['name'], 'Export Customer');
      expect(json['email'], 'export@test.com');
      expect(json['is_company'], false);
    });

    test('Customer equality should work based on ID and Name', () {
      final c1 = Customer(id: 1, name: 'Same');
      final c2 = Customer(id: 1, name: 'Same');
      final c3 = Customer(id: 2, name: 'Different');

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
    });
  });
}
