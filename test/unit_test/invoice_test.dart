import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/models/invoice.dart';
import 'package:mobo_billing/models/invoice_line.dart';

void main() {
  group('Invoice Model Tests', () {
    test('Invoice.fromJson should parse valid data correctly', () {
      final json = {
        'id': 101,
        'name': 'INV/2024/0001',
        'invoice_date': '2024-02-11',
        'partner_id': [10, 'Test Customer'],
        'state': 'posted',
        'payment_state': 'not_paid',
        'amount_untaxed': 100.0,
        'amount_tax': 15.0,
        'amount_total': 115.0,
        'amount_residual': 115.0,
        'currency_id': [1, 'USD'],
        'move_type': 'out_invoice',
      };

      final invoice = Invoice.fromJson(json);

      expect(invoice.id, 101);
      expect(invoice.name, 'INV/2024/0001');
      expect(invoice.customerName, 'Test Customer');
      expect(invoice.customerId, 10);
      expect(invoice.state, 'posted');
      expect(invoice.amountTotal, 115.0);
      expect(invoice.currencySymbol, 'USD');
    });

    test('Invoice.fromJson should handle null/false values gracefully', () {
      final json = {
        'id': 102,
        'name': false,
        'partner_id': false,
        'state': null,
        'amount_total': null,
      };

      final invoice = Invoice.fromJson(json);

      expect(invoice.name, '');
      expect(invoice.customerName, '');
      expect(invoice.customerId, isNull);
      expect(invoice.state, 'draft');
      expect(invoice.amountTotal, 0.0);
    });

    test('InvoiceLine.fromJson should parse line data correctly', () {
      final lineJson = {
        'id': 1,
        'product_id': [50, 'Test Product'],
        'quantity': 2.0,
        'price_unit': 50.0,
        'price_subtotal': 100.0,
        'tax_ids': [[1, 'VAT 15%']],
      };

      final line = InvoiceLine.fromJson(lineJson);

      expect(line.productId, 50);
      expect(line.productName, 'Test Product');
      expect(line.quantity, 2.0);
      expect(line.priceSubtotal, 100.0);
      expect(line.taxIds, [1]);
      expect(line.taxNames, ['VAT 15%']);
    });

    test('Invoice.toJson should return correct map', () {
      final invoice = Invoice(
        id: 101,
        name: 'INV/2024/0001',
        customerName: 'Test Customer',
        customerId: 10,
        state: 'posted',
        amountUntaxed: 100.0,
        amountTax: 15.0,
        amountTotal: 115.0,
        amountResidual: 115.0,
        currencySymbol: 'USD',
        moveType: 'out_invoice',
        invoiceLineIds: [1],
      );

      final json = invoice.toJson();

      expect(json['id'], 101);
      expect(json['name'], 'INV/2024/0001');
      expect(json['partner_id'], [10, 'Test Customer']);
      expect(json['amount_total'], 115.0);
    });
  });
}
