import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/models/odoo_session.dart';

void main() {
  group('OdooSessionModel Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('OdooSessionModel should save and restore from prefs', () async {
      final session = OdooSessionModel(
        sessionId: 'test_sid',
        userLogin: 'admin',
        password: 'password123',
        serverUrl: 'https://demo.odoo.com',
        database: 'demo_db',
        userId: 1,
        userName: 'Administrator',
      );

      await session.saveToPrefs();

      final restored = await OdooSessionModel.fromPrefs();

      expect(restored, isNotNull);
      expect(restored!.sessionId, 'test_sid');
      expect(restored.userLogin, 'admin');
      expect(restored.serverUrl, 'https://demo.odoo.com');
      expect(restored.userId, 1);
    });

    test('fromPrefs should return null if no session stored', () async {
      final session = await OdooSessionModel.fromPrefs();
      expect(session, isNull);
    });

    test('isExpired should return false if no expiresAt set', () {
      final session = OdooSessionModel(
        sessionId: 'sid',
        userLogin: 'u',
        password: 'p',
        serverUrl: 's',
        database: 'd',
      );
      expect(session.isExpired, false);
    });

    test('isExpired should return true if past expiration date', () {
      final session = OdooSessionModel(
        sessionId: 'sid',
        userLogin: 'u',
        password: 'p',
        serverUrl: 's',
        database: 'd',
        expiresAt: DateTime.now().subtract(Duration(hours: 1)),
      );
      expect(session.isExpired, true);
    });
  });
}
