import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/invoice_narration.dart';

void main() {
  group('splitInvoiceNarration', () {
    test('shows the HTML Odoo stored as plain text', () {
      expect(splitInvoiceNarration('<p>ghj</p>').notes, 'ghj');
      // Saved from the field while it still showed the raw tags.
      expect(splitInvoiceNarration('<p>ghj</p>jjj').notes, 'ghj\njjj');
    });

    test('a narration without the terms heading is all notes', () {
      final split = splitInvoiceNarration('<p>Pay within 30 days</p>');
      expect(split.notes, 'Pay within 30 days');
      expect(split.terms, '');
    });

    test('treats an empty or false narration as blank', () {
      for (final value in [false, null, '']) {
        final split = splitInvoiceNarration(value);
        expect(split.notes, '', reason: '$value');
        expect(split.terms, '', reason: '$value');
      }
    });
  });

  group('joinInvoiceNarration', () {
    test('is empty when both fields are blank', () {
      expect(joinInvoiceNarration('  ', ''), '');
    });

    test('writes notes alone as a plain paragraph', () {
      expect(joinInvoiceNarration('Thanks!', ''), '<p>Thanks!</p>');
    });

    test('escapes text that looks like markup', () {
      expect(joinInvoiceNarration('a <b> c', ''), '<p>a &lt;b&gt; c</p>');
    });
  });

  test('notes and terms survive a save and reload', () {
    const cases = [
      ('ghj', 'yyh'),
      ('', 'Net 30'),
      ('Line one\nLine two', 'No refunds\nGoods stay ours until paid'),
      ('Fish & chips <3', ''),
    ];
    for (final (notes, terms) in cases) {
      final split = splitInvoiceNarration(joinInvoiceNarration(notes, terms));
      expect((split.notes, split.terms), (notes, terms));
    }
  });
}
