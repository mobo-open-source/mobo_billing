import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/invoice_export_provider.dart';
import 'package:flutter/material.dart';
import '../mocks/mock_services.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockBuildContext());
  });

  group('InvoiceExportProvider Tests', () {
    late MockOdooApiService mockApiService;
    late MockRuntimePermissionService mockPermissionService;
    late InvoiceExportProvider provider;

    setUp(() {
      mockApiService = MockOdooApiService();
      mockPermissionService = MockRuntimePermissionService();
      provider = InvoiceExportProvider(
        apiService: mockApiService,
        permissionService: mockPermissionService,
      );
    });

    test('exportInvoices should fail with exception when no invoices found', () async {
      when(() => mockApiService.searchRead('account.move', any(), any()))
          .thenAnswer((_) async => []);
      
      when(() => mockPermissionService.requestStoragePermissionInstance(any()))
          .thenAnswer((_) async => true);

      await provider.exportInvoices(
        MockBuildContext(),
        fromDate: DateTime(2024, 1, 1),
        toDate: DateTime(2024, 1, 31),
        format: 'Excel',
        status: 'all',
      );

      expect(provider.errorMessage, contains('No invoices found'));
      expect(provider.isExporting, false);
    });

    test('exportInvoices should correctly build domain for status filters', () async {

       List<dynamic>? capturedDomain;
       when(() => mockApiService.searchRead('account.move', any(), any()))
          .thenAnswer((invocation) async {
            capturedDomain = invocation.positionalArguments[1] as List<dynamic>;
            return [];
          });

      when(() => mockPermissionService.requestStoragePermissionInstance(any()))
          .thenAnswer((_) async => true);

      await provider.exportInvoices(
        MockBuildContext(),
        fromDate: DateTime(2024, 1, 1),
        toDate: DateTime(2024, 1, 31),
        format: 'Excel',
        status: 'paid',
      );

      expect(capturedDomain, isNotNull);

      final hasPaidFilter = capturedDomain!.any((filter) => 
        filter is List && filter[0] == 'payment_state' && filter[2] == 'paid');
      expect(hasPaidFilter, true);
    });
  });
}
