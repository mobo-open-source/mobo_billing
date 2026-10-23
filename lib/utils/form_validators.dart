/// Shared `TextFormField` validators, so every form accepts and rejects the
/// same input with the same message.

/// local@domain.tld — at least one dot in the domain, a 2+ letter TLD, and no
/// spaces anywhere. Deliberately simpler than RFC 5322: it catches typos
/// (missing `@`, missing TLD, stray spaces) without rejecting real addresses.
final RegExp _emailPattern = RegExp(
  r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+"
  r'@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?'
  r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)*'
  r'\.[A-Za-z]{2,}$',
);

/// Validates an optional email field: blank passes, anything else must look
/// like an address.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return null;
  if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
  return null;
}

/// Validates a required field, naming it in the message.
String? Function(String?) requiredField(String fieldName) {
  return (value) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  };
}
