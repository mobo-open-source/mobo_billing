import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/odoo_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OdooSessionModel Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('OdooSessionModel should handle expiration correctly', () {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));

      final activeSession = OdooSessionModel(
        sessionId: '123',
        userLogin: 'admin',
        password: 'password',
        serverUrl: 'http://localhost',
        database: 'test',
        expiresAt: futureDate,
      );

      final expiredSession = OdooSessionModel(
        sessionId: '123',
        userLogin: 'admin',
        password: 'password',
        serverUrl: 'http://localhost',
        database: 'test',
        expiresAt: pastDate,
      );

      expect(activeSession.isExpired, false);
      expect(expiredSession.isExpired, true);
    });

    test('saveToPrefs and fromPrefs should work correctly', () async {
      final session = OdooSessionModel(
        sessionId: 'test_session_id',
        userLogin: 'test_user',
        password: 'test_password',
        serverUrl: 'http://test.com',
        database: 'test_db',
        userId: 1,
        userName: 'Test User',
      );

      await session.saveToPrefs();
      final loadedSession = await OdooSessionModel.fromPrefs();

      expect(loadedSession, isNotNull);
      expect(loadedSession!.sessionId, 'test_session_id');
      expect(loadedSession.userLogin, 'test_user');
      expect(loadedSession.userId, 1);
      expect(loadedSession.userName, 'Test User');
    });

    test('fromPrefs should return null if not logged in', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);

      final session = await OdooSessionModel.fromPrefs();
      expect(session, isNull);
    });

    test('copyWith should create a new instance with updated values', () {
      final session = OdooSessionModel(
        sessionId: '1',
        userLogin: 'u1',
        password: 'p1',
        serverUrl: 's1',
        database: 'd1',
      );

      final updated = session.copyWith(sessionId: '2', userLogin: 'u2');

      expect(updated.sessionId, '2');
      expect(updated.userLogin, 'u2');
      expect(updated.password, 'p1');
    });
  });
}
