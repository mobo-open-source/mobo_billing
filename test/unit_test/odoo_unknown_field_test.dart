import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/services/odoo_api_service.dart';
import 'package:mobo_billing/services/odoo_session_manager.dart';

void main() {
  group('unknownFieldFromError', () {
    test('reads the quoted field of read/search_read/create/order errors', () {
      for (final error in [
        "Exception: Invalid field 'mobile' on 'res.partner'",
        "Exception: Invalid field 'mobile' in 'res.partner'",
        "Exception: Invalid field 'mobile' on model 'res.partner'",
      ]) {
        expect(OdooApiService.unknownFieldFromError(error), 'mobile');
      }
    });

    test('reads the leaf field path of domain errors (Odoo 17-20)', () {
      expect(
        OdooApiService.unknownFieldFromError(
          "Exception: Invalid field res.partner.company_name in condition "
          "('company_name', 'ilike', 'acme')",
        ),
        'company_name',
      );
      expect(
        OdooApiService.unknownFieldFromError(
          "Exception: Invalid field res.partner.mobile in leaf "
          "('partner_id.mobile', '!=', False)",
        ),
        'partner_id.mobile',
      );
    });

    test('reads the bare KeyError Odoo 20 raises for write', () {
      expect(
        OdooApiService.unknownFieldFromError("Exception: 'mobile'"),
        'mobile',
      );
    });

    test('ignores unrelated errors', () {
      expect(
        OdooApiService.unknownFieldFromError('Exception: Access Denied'),
        isNull,
      );
      expect(
        OdooApiService.unknownFieldFromError(
          "Exception: You cannot delete 'INV/1'",
        ),
        isNull,
      );
    });
  });

  group('withoutField', () {
    test('drops the field from search_read fields and order', () {
      final result = OdooApiService.withoutField(
        'search_read',
        [[]],
        {
          'fields': ['name', 'mobile'],
          'order': 'mobile desc, name',
        },
        'mobile',
      );
      expect(result!.$2, {
        'fields': ['name'],
        'order': 'name',
      });
    });

    test('drops the field from read args and write/create values', () {
      expect(
        OdooApiService.withoutField(
          'read',
          [
            [1],
            ['name', 'mobile'],
          ],
          null,
          'mobile',
        )!.$1,
        [
          [1],
          ['name'],
        ],
      );
      expect(
        OdooApiService.withoutField(
          'write',
          [
            [1],
            {'name': 'A', 'mobile': false},
          ],
          null,
          'mobile',
        )!.$1,
        [
          [1],
          {'name': 'A'},
        ],
      );
      expect(
        OdooApiService.withoutField(
          'create',
          [
            {'name': 'A', 'title': 3},
          ],
          null,
          'title',
        )!.$1,
        [
          {'name': 'A'},
        ],
      );
    });

    test('keeps prefix operators balanced when neutralizing a domain', () {
      final result = OdooApiService.withoutField(
        'search_count',
        [
          [
            '|',
            ['name', 'ilike', 'acme'],
            '|',
            ['email', 'ilike', 'acme'],
            ['company_name', 'ilike', 'acme'],
          ],
        ],
        null,
        'company_name',
      );
      expect(result!.$1.first, [
        '|',
        ['name', 'ilike', 'acme'],
        '|',
        ['email', 'ilike', 'acme'],
        [0, '=', 1],
      ]);
    });

    test('neutralizes a condition to what a missing value would give', () {
      List neutral(List condition) =>
          OdooApiService.withoutField(
                'search',
                [
                  [condition],
                ],
                null,
                'mobile',
              )!.$1.first.first
              as List;

      expect(neutral(['mobile', '=', false]), [1, '=', 1]);
      expect(neutral(['mobile', '!=', false]), [0, '=', 1]);
      expect(neutral(['mobile', 'not ilike', '9']), [1, '=', 1]);
      expect(neutral(['mobile', 'ilike', '9']), [0, '=', 1]);
    });

    test('returns null when the field is unused or the only one requested', () {
      expect(
        OdooApiService.withoutField(
          'search_read',
          [[]],
          {
            'fields': ['name'],
          },
          'mobile',
        ),
        isNull,
      );
      // An empty `fields` list means "every field" to Odoo.
      expect(
        OdooApiService.withoutField(
          'search_read',
          [[]],
          {
            'fields': ['default_invoice_policy'],
          },
          'default_invoice_policy',
        ),
        isNull,
      );
      // Record ids of a read are never mistaken for a domain.
      expect(
        OdooApiService.withoutField(
          'read',
          [
            [1, 2],
          ],
          null,
          'mobile',
        ),
        isNull,
      );
    });
  });

  group('OdooSessionManager.parseMajorVersion', () {
    test('parses final, enterprise and saas version strings', () {
      expect(OdooSessionManager.parseMajorVersion('17.0'), 17);
      expect(OdooSessionManager.parseMajorVersion('20.0+e'), 20);
      expect(OdooSessionManager.parseMajorVersion('saas~18.3'), 18);
      expect(OdooSessionManager.parseMajorVersion(''), 0);
    });
  });
}
