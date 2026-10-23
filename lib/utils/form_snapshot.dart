import 'dart:convert';

/// Remembers the values an edit form opened with, so its submit button can
/// stay disabled until the user actually changes something.
///
/// Values are compared by content, so editing a field and then putting the
/// original value back counts as "no changes" again. Pass only JSON-encodable
/// values (ids, strings, numbers, bools, lists and maps of those) — and build
/// them the same way the form builds its save payload, so a change that would
/// not alter what gets written (trailing spaces, `50` vs `50.0`) is ignored.
class FormSnapshot {
  String? _baseline;

  /// Records [values] as the unchanged state. Call once the record has
  /// finished loading into the form.
  void capture(Object? values) => _baseline = jsonEncode(values);

  /// Whether [values] differ from the captured baseline. False until
  /// [capture] has run, so a form that is still loading stays locked.
  bool hasChanges(Object? values) =>
      _baseline != null && jsonEncode(values) != _baseline;
}
