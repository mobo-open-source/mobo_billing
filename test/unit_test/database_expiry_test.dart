import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/services/odoo_session_manager.dart';

void main() {
  group('OdooSessionManager.isSessionInfoExpired', () {
    final now = DateTime.utc(2026, 10, 14, 12);

    bool expired(Object? expirationDate) =>
        OdooSessionManager.isSessionInfoExpired({
          'expiration_date': expirationDate,
        }, now: now);

    test('a database with no expiry (Community) never expires', () {
      expect(OdooSessionManager.isSessionInfoExpired({}, now: now), isFalse);
      expect(expired(null), isFalse);
      expect(expired(false), isFalse);
      expect(expired(''), isFalse);
      expect(expired('not a date'), isFalse);
    });

    test('a past expiration date is expired', () {
      expect(expired('2026-10-01 00:00:00'), isTrue);
    });

    test('a date well in the future is not expired', () {
      expect(expired('2026-11-13 12:00:00'), isFalse);
    });

    test('follows the web client: blocked once under half a day is left', () {
      // 0.4 days left rounds to 0, which Odoo already treats as expired.
      expect(expired('2026-10-14 21:36:00'), isTrue);
      // 0.6 days left rounds to 1.
      expect(expired('2026-10-15 02:24:00'), isFalse);
    });

    test('reads the stored date as UTC', () {
      expect(expired('2026-10-14T12:00:00Z'), isTrue);
      expect(expired('2026-10-20T12:00:00Z'), isFalse);
    });
  });
}
