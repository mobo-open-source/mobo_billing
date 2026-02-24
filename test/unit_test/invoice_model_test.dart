import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/invoice.dart';

void main() {
  group('Invoice Model Tests', () {
    test('Invoice.fromJson should create a valid Invoice from Odoo JSON', () {
      final json = {
        'id': 1001,
        'name': 'INV/2024/0001',
        'invoice_date': '2024-02-11',
        'partner_id': [10, 'Test Customer'],
        'state': 'posted',
        'amount_total': 120.0,
        'amount_residual': 0.0,
        'currency_id': [1, '\$'],
        'move_type': 'out_invoice',
        'invoice_line_ids': [1, 2],
      };

      final invoice = Invoice.fromJson(json);

      expect(invoice.id, 1001);
      expect(invoice.name, 'INV/2024/0001');
      expect(invoice.customerName, 'Test Customer');
      expect(invoice.customerId, 10);
      expect(invoice.state, 'posted');
      expect(invoice.amountTotal, 120.0);
      expect(invoice.currencySymbol, '\$');
      expect(invoice.invoiceLineIds, [1, 2]);
    });

    test('Invoice.fromJson should handle List formats for fields', () {
      final json = {
        'id': 1002,
        'name': ['INV/002', 'INV/002'],
        'partner_id': [20, 'Another Partner'],
        'currency_id': [2, '€'],
      };

      final invoice = Invoice.fromJson(json);

      expect(invoice.name, 'INV/002');
      expect(invoice.currencySymbol, '€');
    });

    test('Invoice.toJson should include all relevant fields for export', () {
      final invoice = Invoice(
        id: 2001,
        name: 'INV/EXPORT/01',
        customerName: 'Export Target',
        customerId: 50,
        state: 'draft',
        amountUntaxed: 100.0,
        amountTax: 15.0,
        amountTotal: 115.0,
        amountResidual: 115.0,
        currencySymbol: 'AED',
        invoiceLineIds: [5, 6],
        moveType: 'out_invoice',
      );

      final json = invoice.toJson();

      expect(json['id'], 2001);
      expect(json['name'], 'INV/EXPORT/01');
      expect(json['partner_id'], [50, 'Export Target']);
      expect(json['amount_total'], 115.0);
    });
  });
}
