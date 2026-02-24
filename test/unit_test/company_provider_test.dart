import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/company_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/models/odoo_session.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late MockSessionService mockSessionService;
  late MockCompanyLocalDataSource mockLocalDataSource;
  late CompanyProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApiService = MockOdooApiService();
    mockSessionService = MockSessionService();
    mockLocalDataSource = MockCompanyLocalDataSource();
    provider = CompanyProvider(
      apiService: mockApiService,
      sessionService: mockSessionService,
      localDataSource: mockLocalDataSource,
    );
  });

  group('CompanyProvider Tests', () {
    test('initialize should load companies from API and save to local', () async {
      final mockSession = OdooSessionModel(
        serverUrl: 'https://test.com',
        database: 'db',
        userLogin: 'admin',
        userId: 1,
        sessionId: 'sid',
        password: 'password',
      );

      when(() => mockSessionService.currentSession).thenReturn(mockSession);
      when(() => mockLocalDataSource.getAllCompanies(
            userId: any(named: 'userId'),
            database: any(named: 'database'),
          )).thenAnswer((_) async => []);

      final uid = mockSession.userId!;
      final db = mockSession.database;

      when(() => mockApiService.callKwWithoutCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [uid],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      })).thenAnswer((_) async => [
        {'company_id': 1, 'company_ids': [1, 2]}
      ]);

      when(() => mockApiService.callKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', [1, 2]],
          ],
        ],
        'kwargs': {'fields': ['id', 'name'], 'order': 'name asc'},
      })).thenAnswer((_) async => [
        {'id': 1, 'name': 'Company 1'},
        {'id': 2, 'name': 'Company 2'},
      ]);

      when(() => mockLocalDataSource.putAllCompanies(
        any(),
        userId: any(named: 'userId'),
        database: any(named: 'database'),
      )).thenAnswer((_) async => {});

      await provider.initialize();

      expect(provider.companies.length, 2);
      expect(provider.selectedCompanyId, 1);
      verify(() => mockLocalDataSource.putAllCompanies(
        any(),
        userId: uid,
        database: db,
      )).called(1);
    });

    test('switchCompany should apply company on server and refresh', () async {
      final mockSession = OdooSessionModel(
        serverUrl: 'https://test.com',
        database: 'db',
        userLogin: 'admin',
        userId: 1,
        sessionId: 'sid',
        password: 'password',
      );
      when(() => mockSessionService.currentSession).thenReturn(mockSession);

      final uid = mockSession.userId!;
      final db = mockSession.database;

      when(() => mockApiService.callKwWithoutCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [uid],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      })).thenAnswer((_) async => [
        {'company_id': 1, 'company_ids': [1, 2]}
      ]);

      when(() => mockApiService.callKwWithoutCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [uid],
          {'company_id': 2},
        ],
        'kwargs': {},
      })).thenAnswer((_) async => true);

      when(() => mockApiService.callKwWithoutCompany({
        'model': 'res.company',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {'fields': ['id', 'name']},
      })).thenAnswer((_) async => [
        {'id': 1, 'name': 'C1'},
        {'id': 2, 'name': 'C2'},
      ]);

      when(() => mockLocalDataSource.putAllCompanies(
        any(),
        userId: any(named: 'userId'),
        database: any(named: 'database'),
      )).thenAnswer((_) async => {});

      final result = await provider.switchCompany(2);

      expect(provider.selectedCompanyId, 2);
    });
  });
}
