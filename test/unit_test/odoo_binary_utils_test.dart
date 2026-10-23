import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/odoo_binary_utils.dart';

void main() {
  group('odooBinaryToBase64', () {
    test('returns a base64 string unchanged (Odoo 17-19)', () {
      expect(odooBinaryToBase64('iVBORw0KGgo='), 'iVBORw0KGgo=');
    });

    test('returns content of an Odoo 20 binary map', () {
      expect(
        odooBinaryToBase64({
          'content': 'iVBORw0KGgo=',
          'size': 8,
          'filename': 'me.png',
        }),
        'iVBORw0KGgo=',
      );
      expect(
        odooBinaryToBase64({'content': 'iVBORw0KGgo=', 'size': 8}),
        'iVBORw0KGgo=',
      );
    });

    test('returns empty string for false, null or anything else', () {
      expect(odooBinaryToBase64(false), '');
      expect(odooBinaryToBase64(null), '');
      expect(odooBinaryToBase64(42), '');
      expect(odooBinaryToBase64({'size': 8}), '');
      expect(odooBinaryToBase64([1, 2]), '');
    });
  });

  group('normalizeOdooBinaries', () {
    test('converts binary maps inside RPC results', () {
      final result = normalizeOdooBinaries([
        {
          'id': 1,
          'name': 'Admin',
          'image_1920': {'content': 'AAAA', 'size': 3, 'filename': 'a.png'},
          'image_128': false,
          'partner_id': [3, 'Admin'],
        },
      ]);

      expect(result[0]['image_1920'], 'AAAA');
      expect(result[0]['image_128'], false);
      expect(result[0]['partner_id'], [3, 'Admin']);
    });

    test('converts nested maps such as web_search_read records', () {
      final result = normalizeOdooBinaries({
        'length': 1,
        'records': [
          // Typed like jsonDecode output, which is what the RPC layer passes.
          <String, dynamic>{
            'image_128': {'content': 'BBBB', 'size': 3},
          },
        ],
      });

      expect(result['records'][0]['image_128'], 'BBBB');
    });

    test('leaves non-binary values unchanged', () {
      expect(normalizeOdooBinaries(true), true);
      expect(normalizeOdooBinaries('text'), 'text');
      expect(normalizeOdooBinaries({'content': 'x'}), {'content': 'x'});
    });
  });
}
