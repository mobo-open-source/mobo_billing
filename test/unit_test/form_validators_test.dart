import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/form_validators.dart';

void main() {
  group('validateEmail', () {
    test('accepts blank (the field is optional) and real addresses', () {
      expect(validateEmail(null), isNull);
      expect(validateEmail('  '), isNull);
      expect(validateEmail('anagha@cybrosys.com'), isNull);
      expect(validateEmail(' first.last+tag@mail.example.co.in '), isNull);
    });

    test('rejects typos', () {
      for (final bad in [
        'plainaddress',
        'missing-at.com',
        'user@',
        'user@domain',
        'user@domain.c',
        'user@@domain.com',
        'user name@domain.com',
        'user@domain.com extra',
        'user@-domain.com',
      ]) {
        expect(validateEmail(bad), 'Enter a valid email address', reason: bad);
      }
    });
  });

  group('requiredField', () {
    test('rejects empty and whitespace-only values, naming the field', () {
      final validate = requiredField('Name');
      expect(validate(null), 'Name is required');
      expect(validate('   '), 'Name is required');
      expect(validate('Mitchell Admin'), isNull);
    });
  });
}
