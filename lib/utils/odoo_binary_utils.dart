/// Helpers for Odoo binary fields (image_1920, image_128, avatar_128, ...).
///
/// Odoo 17-19 return a binary field as a base64 string, or `false` when empty.
/// Odoo 20 returns `{"content": "<base64>", "size": 123, "filename": "me.png"}`
/// (filename only if set), or `false` when empty.

/// Returns the base64 content of an Odoo binary field value, or `''` when the
/// value is empty or not a binary value.
String odooBinaryToBase64(dynamic value) {
  if (value is String) return value;
  if (value is Map && value['content'] is String) {
    return value['content'] as String;
  }
  return '';
}

bool _isOdooBinaryMap(dynamic value) =>
    value is Map && value['content'] is String && value['size'] is num;

/// Replaces every Odoo 20 binary map inside [data] with its base64 string, so
/// callers keep seeing the pre-Odoo 20 format. Updates maps and lists in place
/// and returns [data]. Other values, including `false`, are left unchanged.
dynamic normalizeOdooBinaries(dynamic data) {
  if (_isOdooBinaryMap(data)) return odooBinaryToBase64(data);
  if (data is Map) {
    for (final key in data.keys.toList()) {
      final value = data[key];
      if (value is Map || value is List) {
        data[key] = normalizeOdooBinaries(value);
      }
    }
  } else if (data is List) {
    for (var i = 0; i < data.length; i++) {
      final value = data[i];
      if (value is Map || value is List) {
        data[i] = normalizeOdooBinaries(value);
      }
    }
  }
  return data;
}
