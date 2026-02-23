import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late MockSessionService mockSessionService;
  late AuthProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApiService = MockOdooApiService();
    mockSessionService = MockSessionService();
    

    when(() => mockApiService.initialize(any(), any())).thenReturn(null);
    when(() => mockApiService.userInfo).thenReturn(<String, dynamic>{
      'name': 'Test User',
      'image_128': null,
      'context': <String, dynamic>{}
    });
    
    provider = AuthProvider(
      apiService: mockApiService,
      sessionService: mockSessionService,
    );
  });

  group('AuthProvider Tests', () {
    test('login should succeed with valid credentials', () async {
      when(() => mockApiService.authenticate('admin', 'password'))
          .thenAnswer((_) async => <String, dynamic>{'success': true, 'uid': 1, 'session_id': 'sid'});

      final result = await provider.login('https://test.com', 'db', 'admin', 'password');

      expect(result, true);
      expect(provider.isAuthenticated, true);
      expect(provider.user!.username, 'admin');
      expect(provider.error, isNull);
    });

    test('login should fail with invalid credentials', () async {
      when(() => mockApiService.authenticate('bad', 'bad'))
          .thenAnswer((_) async => <String, dynamic>{'success': false});

      final result = await provider.login('https://test.com', 'db', 'bad', 'bad');

      expect(result, false);
      expect(provider.isAuthenticated, false);
      expect(provider.error, isNotNull);
    });

    test('logout should clear user and call session logout', () async {

      when(() => mockApiService.authenticate(any(), any()))
          .thenAnswer((_) async => <String, dynamic>{'success': true, 'uid': 1, 'session_id': 'sid'});
      await provider.login('url', 'db', 'user', 'pass');

      when(() => mockSessionService.logout()).thenAnswer((_) async => {});

      await provider.logout();

      expect(provider.isAuthenticated, false);
      expect(provider.user, isNull);
      verify(() => mockSessionService.logout()).called(1);
    });

    test('checkRequiredModules should return true if account module is installed', () async {
      when(() => mockApiService.isModuleInstalled('account')).thenAnswer((_) async => true);

      final result = await provider.checkRequiredModules();

      expect(result, true);
      verify(() => mockApiService.isModuleInstalled('account')).called(1);
    });
  });
}
