import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/utils/form_snapshot.dart';

void main() {
  group('FormSnapshot', () {
    test('reports no changes before a baseline is captured', () {
      final snapshot = FormSnapshot();
      expect(snapshot.hasChanges({'name': 'Acme'}), isFalse);
    });

    test('reports no changes for identical values', () {
      final snapshot = FormSnapshot()
        ..capture({
          'name': 'Acme',
          'lines': [
            {'id': 1, 'quantity': 15.0, 'tax_ids': <int>[]},
          ],
        });

      expect(
        snapshot.hasChanges({
          'name': 'Acme',
          'lines': [
            {'id': 1, 'quantity': 15.0, 'tax_ids': <int>[]},
          ],
        }),
        isFalse,
      );
    });

    test('detects a changed field, including one nested in a line', () {
      final snapshot = FormSnapshot()
        ..capture({
          'name': 'Acme',
          'lines': [
            {'id': 1, 'quantity': 15.0},
          ],
        });

      expect(
        snapshot.hasChanges({
          'name': 'Acme Ltd',
          'lines': [
            {'id': 1, 'quantity': 15.0},
          ],
        }),
        isTrue,
      );
      expect(
        snapshot.hasChanges({
          'name': 'Acme',
          'lines': [
            {'id': 1, 'quantity': 16.0},
          ],
        }),
        isTrue,
      );
    });

    test('detects an added or removed line', () {
      final snapshot = FormSnapshot()
        ..capture({
          'lines': [
            {'id': 1},
          ],
        });

      expect(snapshot.hasChanges({'lines': <Map<String, dynamic>>[]}), isTrue);
      expect(
        snapshot.hasChanges({
          'lines': [
            {'id': 1},
            {'id': null},
          ],
        }),
        isTrue,
      );
    });

    test('reverting an edit counts as no changes again', () {
      final snapshot = FormSnapshot()..capture({'memo': 'Rent'});

      expect(snapshot.hasChanges({'memo': 'Rent for May'}), isTrue);
      expect(snapshot.hasChanges({'memo': 'Rent'}), isFalse);
    });

    test('distinguishes null from an empty value', () {
      final snapshot = FormSnapshot()..capture({'journal_id': null});

      expect(snapshot.hasChanges({'journal_id': 0}), isTrue);
      expect(snapshot.hasChanges({'journal_id': null}), isFalse);
    });
  });
}
