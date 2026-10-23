/// Helpers for Odoo `fields.Html` values (e.g. `res.partner.comment`).
///
/// Odoo stores these as sanitized HTML: plain text written over RPC comes
/// back wrapped as `<p>…</p>`, and notes typed in the web client carry
/// `<p>`, `<br>` and entities. The app edits them as plain text.

final RegExp _tagPattern = RegExp(r'<\s*/?\s*[a-zA-Z][^>]*>');

const Map<String, String> _namedEntities = {
  '&nbsp;': ' ',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
};

/// Converts an Odoo HTML value to plain text for display or editing.
///
/// Block ends (`</p>`, `</div>`, `</li>`, headings) and `<br>` become line
/// breaks, other tags are dropped and entities decoded. A value with no tags
/// is returned unchanged (trimmed), so already-plain text round-trips.
/// Returns `''` for `null`, `false` or empty input.
String odooHtmlToText(dynamic value) {
  if (value is! String || value.isEmpty || value == 'false') return '';
  if (!_tagPattern.hasMatch(value)) return value.trim();

  var text = value
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'<\s*/\s*(p|div|li|h[1-6]|blockquote|pre)\s*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(_tagPattern, '');

  _namedEntities.forEach((entity, char) {
    text = text.replaceAll(entity, char);
  });
  text = text.replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
    return code == null ? m[0]! : String.fromCharCode(code);
  });
  // Last, so an escaped entity like `&amp;lt;` decodes to `&lt;`, not `<`.
  text = text.replaceAll('&amp;', '&');

  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Converts plain text from a form field into Odoo HTML, keeping line breaks
/// (which would otherwise collapse when the web client renders the note).
/// Returns `''` for blank input.
String textToOdooHtml(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  final escaped = trimmed
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<p>${escaped.replaceAll(RegExp(r'\r?\n'), '<br>')}</p>';
}
