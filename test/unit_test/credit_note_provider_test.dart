import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/credit_note_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  late MockOdooApiService mockApiService;
  late CreditNoteProvider provider;

  setUp(() {
    mockApiService = MockOdooApiService();
    provider = CreditNoteProvider(apiService: mockApiService);
  });

  group('CreditNoteProvider Tests', () {
    test('loadCreditNotes should load credit notes and count', () async {

      when(() => mockApiService.searchRead('account.move', any(), any(), any(), any(), any()))
          .thenAnswer((_) async => [
                {'id': 1, 'name': 'RINV/2026/001', 'amount_total': 100.0, 'state': 'posted', 'move_type': 'out_refund'},
              ]);
      

      when(() => mockApiService.getInvoiceCount(domain: any(named: 'domain')))
          .thenAnswer((_) async => 1);

      await provider.loadCreditNotes();

      expect(provider.creditNotes.length, 1);
      expect(provider.totalCount, 1);
      expect(provider.isLoading, false);
      expect(provider.error, isNull);
    });

    test('confirmCreditNote should call api confirmInvoice', () async {
      when(() => mockApiService.confirmInvoice(1)).thenAnswer((_) async => true);
      

      when(() => mockApiService.searchRead(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => []);
      when(() => mockApiService.getInvoiceCount(domain: any(named: 'domain'))).thenAnswer((_) async => 0);

      final result = await provider.confirmCreditNote(1);

      expect(result, true);
      verify(() => mockApiService.confirmInvoice(1)).called(1);
    });

    test('deleteCreditNote should call api unlink and remove from list', () async {
      when(() => mockApiService.unlink('account.move', [1]))
          .thenAnswer((_) async => true);
      

      when(() => mockApiService.searchRead(any(), any(), any(), any(), any(), any())).thenAnswer((_) async => []);
      when(() => mockApiService.getInvoiceCount(domain: any(named: 'domain'))).thenAnswer((_) async => 0);

      final result = await provider.deleteCreditNote(1);

      expect(result, true);
      verify(() => mockApiService.unlink('account.move', [1])).called(1);
    });
  });
}
