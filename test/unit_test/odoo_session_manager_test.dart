import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/services/odoo_session_manager.dart';
import '../mocks/mock_odoo.dart';

void main() {
  group('OdooSessionManager Tests', () {
    late MockOdooClient mockClient;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockOdooClient();
      OdooSessionManager.clearCache();
    });

    test('getCurrentSession should return null if nothing in prefs', () async {
      final session = await OdooSessionManager.getCurrentSession();
      expect(session, isNull);
    });

    test('getCurrentSession should restore session from prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('sessionId', 'test_sid');
      await prefs.setString('userLogin', 'test_user');
      await prefs.setString('password', 'test_pass');
      await prefs.setString('serverUrl', 'https://test.com');
      await prefs.setString('database', 'test_db');
      await prefs.setInt('userId', 1);

      final session = await OdooSessionManager.getCurrentSession();

      expect(session, isNotNull);
      expect(session!.sessionId, 'test_sid');
      expect(session.userLogin, 'test_user');
    });

    test('isSessionValid should return true if isLoggedIn in prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      final isValid = await OdooSessionManager.isSessionValid();
      expect(isValid, true);
    });

    test('logout should clear prefs and cache', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('sessionId', 'some_sid');

      await OdooSessionManager.logout();

      expect(prefs.getBool('isLoggedIn'), isNull);
      expect(prefs.getString('sessionId'), isNull);
      
      final session = await OdooSessionManager.getCurrentSession();
      expect(session, isNull);
    });

    test('setClient should work and be used for calls', () async {
      OdooSessionManager.clearCache();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('sessionId', 'test_sid');
      await prefs.setString('userLogin', 'test_user');
      await prefs.setString('password', 'test_pass');
      await prefs.setString('serverUrl', 'https://test.com');
      await prefs.setString('database', 'test_db');
      await prefs.setInt('userId', 1);
      final futureDate = DateTime.now().add(const Duration(days: 1)).toIso8601String();
      await prefs.setString('expiresAt', futureDate);
      
      OdooSessionManager.setClient(mockClient);
      

      final client = await OdooSessionManager.getClientEnsured();
      expect(client, equals(mockClient));
    });
  });
}
