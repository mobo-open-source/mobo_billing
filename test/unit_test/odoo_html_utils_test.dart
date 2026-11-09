import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/odoo_html_utils.dart';

void main() {
  group('odooHtmlToText', () {
    test('unwraps the <p> Odoo adds around plain text written over RPC', () {
      expect(
        odooHtmlToText('<p>hagyejbhhehhwjjej\nhejjejeje\nhahb</p>'),
        'hagyejbhhehhwjjej\nhejjejeje\nhahb',
      );
    });

    test('turns <br> and paragraph ends into line breaks', () {
      expect(
        odooHtmlToText('<p>one<br>two</p><p>three</p>'),
        'one\ntwo\nthree',
      );
    });

    test('decodes entities, including an escaped ampersand last', () {
      expect(
        odooHtmlToText(
          '<p>a &lt; b &amp;&amp; c&nbsp;&gt; d &#39;x&#39; &amp;lt;</p>',
        ),
        "a < b && c > d 'x' &lt;",
      );
    });

    test('returns plain text unchanged and empty values as empty', () {
      expect(odooHtmlToText('just a note'), 'just a note');
      expect(odooHtmlToText(false), '');
      expect(odooHtmlToText(null), '');
      expect(odooHtmlToText('<p><br></p>'), '');
    });
  });

  group('textToOdooHtml', () {
    test('escapes markup and keeps line breaks', () {
      expect(
        textToOdooHtml('a < b & c\nnext'),
        '<p>a &lt; b &amp; c<br>next</p>',
      );
    });

    test('blank input stays blank', () {
      expect(textToOdooHtml('   '), '');
    });

    test('round-trips through odooHtmlToText', () {
      const note = 'Line one\nLine <two> & three';
      expect(odooHtmlToText(textToOdooHtml(note)), note);
    });
  });
}
