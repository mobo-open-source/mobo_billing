import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/invoice_provider.dart';
import 'package:mobo_billing/models/odoo_session.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late MockSessionService mockSessionService;
  late InvoiceProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    mockSessionService = MockSessionService();
    

    final mockSession = OdooSessionModel(
      sessionId: 'sid',
      userLogin: 'admin',
      password: 'pwd',
      serverUrl: 'https://test.com',
      database: 'db',
      allowedCompanyIds: [1],
    );
    when(() => mockSessionService.currentSession).thenReturn(mockSession);
    
    provider = InvoiceProvider(
      apiService: mockApiService,
      sessionService: mockSessionService,
    );
  });

  group('InvoiceProvider Dashboard Tests', () {
    test('loadDashboardData should load statistics and recent invoices', () async {

      when(() => mockApiService.getInvoices(domain: any(named: 'domain'), limit: any(named: 'limit')))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'INV/001', 'amount_total': 100.0, 'state': 'posted'},
              ]);


      when(() => mockApiService.searchRead(any(), any(), any(), any(), any(), any()))
          .thenAnswer((_) async => [
                {'name': 'PAY/001', 'amount': 50.0, 'date': '2024-01-01'},
              ]);


      when(() => mockApiService.getInvoiceCount(domain: any(named: 'domain')))
          .thenAnswer((_) async => 10);


      when(() => mockApiService.call(any(), any(that: equals('read_group')), any()))
          .thenAnswer((_) async => [{'amount_total': 1000.0, 'amount_residual': 500.0}]);
      

      when(() => mockApiService.call(any(), any(that: equals('search_count')), any()))
          .thenAnswer((_) async => 5);

      await provider.loadDashboardData();

      expect(provider.recentInvoices.length, 1);
      expect(provider.recentInvoices[0].name, 'INV/001');
      expect(provider.totalInvoices, 10);
      expect(provider.totalRevenue, 1000.0);
      expect(provider.totalCustomers, 5);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('loadDashboardData should handle errors gracefully', () async {
      when(() => mockApiService.getInvoices(domain: any(named: 'domain'), limit: any(named: 'limit')))
          .thenThrow(Exception('API Error'));

      await provider.loadDashboardData();

      expect(provider.error, contains('API Error'));
      expect(provider.isLoading, false);
    });

    group('Invoice List Tests', () {
      test('loadInvoices should load invoice list with pagination', () async {
        when(() => mockApiService.getInvoices(
          domain: any(named: 'domain'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => [
          {'id': 1, 'name': 'INV/001'},
          {'id': 2, 'name': 'INV/002'},
        ]);

        when(() => mockApiService.getInvoiceCount(domain: any(named: 'domain')))
            .thenAnswer((_) async => 2);

        await provider.loadInvoices();

        expect(provider.invoices.length, 2);
        expect(provider.totalCount, 2);
        expect(provider.isLoading, false);
      });
    });
  });
}
