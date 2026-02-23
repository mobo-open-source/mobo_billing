import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/profile_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late ProfileProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    provider = ProfileProvider(apiService: mockApiService);
    

    when(() => mockApiService.userInfo).thenReturn({
      'uid': 1,
      'name': 'Admin',
    });
  });

  group('ProfileProvider Tests', () {
    test('loadProfile should fetch user and partner info', () async {

      when(() => mockApiService.read('res.users', [1], any()))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'name': 'Test User',
                  'login': 'test@example.com',
                  'partner_id': [10, 'Test Partner'],
                  'company_id': [1, 'Test Company'],
                }
              ]);
      

      when(() => mockApiService.read('res.partner', [10], any()))
          .thenAnswer((_) async => [
                {
                  'id': 10,
                  'phone': '123456789',
                  'city': 'Test City',
                }
              ]);


      when(() => mockApiService.call('res.users', 'fields_get', any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockApiService.searchRead('res.country', any(), any(), any(), any()))
          .thenAnswer((_) async => []);

      await provider.loadProfile();

      expect(provider.profile, isNotNull);
      expect(provider.profile!['name'], 'Test User');
      expect(provider.profile!['phone'], '123456789');
      expect(provider.isLoading, false);
    });

    test('updateProfile should call api write and reload', () async {
      when(() => mockApiService.write('res.users', [1], any()))
          .thenAnswer((_) async => true);
      

      when(() => mockApiService.read('res.users', [1], any())).thenAnswer((_) async => [{'id': 1, 'partner_id': [10]}]);
      when(() => mockApiService.read('res.partner', [10], any())).thenAnswer((_) async => [{}]);
      when(() => mockApiService.call(any(), any(), any(), any())).thenAnswer((_) async => {});
      when(() => mockApiService.searchRead(any(), any(), any(), any(), any())).thenAnswer((_) async => []);

      final result = await provider.updateProfile(name: 'New Name', email: 'new@test.com');

      expect(result, true);
      verify(() => mockApiService.write('res.users', [1], any())).called(1);
    });
  });
}
