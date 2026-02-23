import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/customer.dart';

void main() {
  group('Customer Model Tests', () {
    test('Customer.fromJson should parse valid data correctly', () {
      final json = {
        'id': 1001,
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '123456789',
        'is_company': false,
        'customer_rank': 1,
        'city': 'New York',
        'country_id': [1, 'United States'],
        'state_id': [2, 'New York'],
        'create_date': '2024-01-01 10:00:00',
      };

      final customer = Customer.fromJson(json);

      expect(customer.id, 1001);
      expect(customer.name, 'John Doe');
      expect(customer.email, 'john@example.com');
      expect(customer.isCompany, false);
      expect(customer.city, 'New York');
      expect(customer.countryId, 1);
      expect(customer.countryName, 'United States');
      expect(customer.stateId, 2);
      expect(customer.stateName, 'New York');
    });

    test('Customer.fromJson should handle null/false values using getString/getInt', () {
      final json = {
        'id': 1002,
        'name': false,
        'email': null,
        'country_id': false,
      };

      final customer = Customer.fromJson(json);

      expect(customer.name, '');
      expect(customer.email, isNull);
      expect(customer.countryId, isNull);
    });

    test('Customer.toJson should return correct map', () {
      final customer = Customer(
        id: 1001,
        name: 'John Doe',
        email: 'john@example.com',
        isCompany: false,
        city: 'New York',
      );

      final json = customer.toJson();

      expect(json['id'], 1001);
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['is_company'], false);
      expect(json['city'], 'New York');
    });

    test('copyWith should return a new instance with updated values', () {
      final customer = Customer(id: 1, name: 'Old Name');
      final updated = customer.copyWith(name: 'New Name', email: 'new@example.com');

      expect(updated.id, 1);
      expect(updated.name, 'New Name');
      expect(updated.email, 'new@example.com');
      expect(customer.name, 'Old Name');
    });

    test('equality and hashcode should work based on id and name', () {
      final c1 = Customer(id: 1, name: 'Customer');
      final c2 = Customer(id: 1, name: 'Customer');
      final c3 = Customer(id: 2, name: 'Customer');

      expect(c1, equals(c2));
      expect(c1, isNot(equals(c3)));
      expect(c1.hashCode, equals(c2.hashCode));
    });
  });
}
