import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'package:mobo_billing/models/product.dart';
import 'package:mobo_billing/models/customer.dart';
import 'package:mobo_billing/models/invoice.dart';

void main() {
  late LastOpenedProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = LastOpenedProvider();
  });

  group('LastOpenedProvider Tests', () {
    test('addItem should add item and keep max 10', () async {
      for (int i = 0; i < 12; i++) {
        await provider.addItem(
          LastOpenedItem(
            id: 'id_$i',
            type: 'product',
            title: 'Title $i',
            subtitle: 'Subtitle $i',
            route: '/route',
            lastAccessed: DateTime.now(),
            iconKey: 'page',
          ),
        );
      }

      expect(provider.items.length, 10);
      expect(provider.items.first.id, 'id_11');
    });

    test('trackProductAccess should add product item', () async {
      final product = Product(id: 1, name: 'Test Product', listPrice: 100.0);

      await provider.trackProductAccess(product: product);

      expect(provider.items.length, 1);
      expect(provider.items.first.type, 'product');
      expect(provider.items.first.id, 'product_1');
    });

    test('clearData should remove all items', () async {
      await provider.addItem(
        LastOpenedItem(
          id: '1',
          type: 'product',
          title: 'T',
          subtitle: 'S',
          route: '/R',
          lastAccessed: DateTime.now(),
          iconKey: 'page',
        ),
      );

      await provider.clearData();

      expect(provider.items, isEmpty);
    });
  });

  group('Draft document titles', () {
    Invoice invoiceNamed(dynamic name) => Invoice.fromJson({
      'id': 7,
      'name': name,
      'partner_id': [3, 'Abigail Peterson'],
      'state': 'draft',
      'move_type': 'out_invoice',
    });

    test('an unnumbered draft invoice is titled "Draft Invoice"', () async {
      // Odoo 17+ sends `false` for a draft's name; older versions send '/'.
      for (final name in [false, '/', '']) {
        await provider.trackInvoiceAccess(invoice: invoiceNamed(name));
        expect(provider.items.first.title, 'Draft Invoice', reason: '$name');
      }
    });

    test('a posted invoice keeps its number', () async {
      await provider.trackInvoiceAccess(
        invoice: invoiceNamed('INV/2026/00014'),
      );

      expect(provider.items.first.title, 'INV/2026/00014');
      expect(provider.items.first.subtitle, 'Invoice for Abigail Peterson');
    });

    test(
      'an unnumbered draft credit note is titled "Draft Credit Note"',
      () async {
        await provider.trackCreditNoteAccess(
          creditNoteId: '9',
          creditNoteName: '',
          customerName: 'Wood Corner',
        );

        expect(provider.items.first.title, 'Draft Credit Note');
      },
    );

    test('entries saved as "Untitled" are relabelled on load', () async {
      LastOpenedItem stored(
        String id,
        String type,
        Map<String, dynamic> data,
      ) => LastOpenedItem(
        id: id,
        type: type,
        title: 'Untitled',
        subtitle: 'Saved earlier',
        route: '/x',
        data: data,
        lastAccessed: DateTime(2026, 10, 1),
        iconKey: 'receipt_outlined',
      );

      SharedPreferences.setMockInitialValues({
        'last_opened_items': jsonEncode([
          stored('invoice_1', 'invoice', {'name': ''}).toJson(),
          stored('invoice_2', 'invoice', {'name': 'INV/2026/00002'}).toJson(),
          stored('credit_note_3', 'credit_note', {'name': false}).toJson(),
          stored('product_4', 'product', {'name': ''}).toJson(),
        ]),
      });
      final reloaded = LastOpenedProvider();
      for (var i = 0; i < 20 && !reloaded.hasLoaded; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final titles = {for (final item in reloaded.items) item.id: item.title};
      expect(titles, {
        'invoice_1': 'Draft Invoice',
        'invoice_2': 'INV/2026/00002',
        'credit_note_3': 'Draft Credit Note',
        // Only invoices and credit notes have a draft state to name.
        'product_4': 'Untitled',
      });
    });
  });

  group('refreshDocuments', () {
    test('relabels a draft entry once the invoice is posted', () async {
      final draft = Invoice.fromJson({
        'id': 7,
        'name': false,
        'state': 'draft',
        'partner_id': [3, 'Abigail Peterson'],
        'move_type': 'out_invoice',
      });
      await provider.trackInvoiceAccess(invoice: draft);
      final before = provider.items.single;
      expect(before.title, 'Draft Invoice');
      expect(provider.documentIds, [7]);

      await provider.refreshDocuments([
        {
          'id': 7,
          'name': 'INV/2026/00014',
          'state': 'posted',
          'partner_id': [3, 'Abigail Peterson'],
        },
      ]);

      final after = provider.items.single;
      expect(after.title, 'INV/2026/00014');
      expect(after.data?['state'], 'posted');
      expect(after.lastAccessed, before.lastAccessed);
    });

    test('leaves entries without a matching record alone', () async {
      await provider.trackCreditNoteAccess(
        creditNoteId: '9',
        creditNoteName: '',
        customerName: 'Cust',
      );

      await provider.refreshDocuments([
        {'id': 10, 'name': 'RINV/2026/00001', 'state': 'posted'},
      ]);

      expect(provider.items.single.title, 'Draft Credit Note');
    });
  });
}
