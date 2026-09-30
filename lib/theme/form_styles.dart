import 'package:flutter/material.dart';

import 'app_theme.dart';

// `AppRadius` (§4) and `AppShadows` (§3) live in app_theme.dart, the single
// source of truth. Re-exported so form code can keep importing this file alone.
export 'app_theme.dart' show AppRadius, AppShadows;

/// Surfaces and typography for form fields, so every create/edit screen
/// renders its labels, inputs and dropdowns identically.
class AppFormTheme {
  const AppFormTheme._();

  /// Filled input surface.
  static const Color inputFillLight = Color(0xFFF2F4F6);
  static final Color inputFillDark = Colors.grey[850]!;

  static Color inputFill(bool isDark) =>
      isDark ? inputFillDark : inputFillLight;

  static Color surface(bool isDark) =>
      isDark ? Colors.grey[850]! : Colors.white;

  static Color cardBorder(bool isDark) =>
      isDark ? Colors.grey[850]! : Colors.grey[200]!;

  static Color iconColor(bool isDark) =>
      isDark ? Colors.white : Colors.grey[700]!;

  static Color hintColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;

  static Color secondaryLabelColor(bool isDark) =>
      AppTheme.secondaryLabelColor(isDark);

  static Color valueColor(bool isDark) =>
      isDark ? Colors.white : const Color(0xFF101010);

  /// The hint is the same size as the value it stands in for, so a field does
  /// not appear to resize once it is filled — only the weight changes.
  static TextStyle fieldValueStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: valueColor(isDark),
  );

  static TextStyle fieldHintStyle(bool isDark) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: isDark ? Colors.white54 : Colors.grey[600],
  );

  /// The grey label that sits above a field.
  static TextStyle fieldLabelStyle(bool isDark) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: isDark ? Colors.white70 : const Color(0xFF7F7F7F),
  );

  /// Leading-icon metrics, shared by the `InputDecoration` fields and the
  /// container-built ones (date/dropdown rows) so a column of fields lines up.
  ///
  /// `InputDecorator` gives `prefixIcon` its own box and starts the text after
  /// it, so the gutter has to live inside that box — with `minWidth` at the
  /// icon's own size the icon sits flush against the field's left edge while
  /// every container-built field indents its icon by [fieldGutter].
  static const double iconSize = 22;
  static const double fieldGutter = 12;

  /// 12px gutter + a 22px icon. With [fieldGutter] of `contentPadding` after
  /// it, text begins at 46 — the same x as `gutter + icon + gap` in a Row.
  static const double _prefixBoxWidth = fieldGutter + iconSize;

  /// Shared decoration for the filled form inputs.
  static InputDecoration inputDecoration({
    required bool isDark,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: fieldHintStyle(isDark),
      prefixIcon: prefixIcon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: fieldGutter),
              child: prefixIcon,
            ),
      prefixIconConstraints: const BoxConstraints(
        minWidth: _prefixBoxWidth,
        minHeight: iconSize,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: fieldGutter,
      ),
      filled: true,
      fillColor: inputFill(isDark),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppTheme.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
    );
  }
}

/// The required-field marker: a red bold `" *"` appended to the label.
///
/// Only colour and weight are set, so the marker inherits the label's font
/// size and family and stays visually attached to it.
const TextSpan kRequiredMarker = TextSpan(
  text: ' *',
  style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold),
);

/// Builds a field label, appending the required marker when [isRequired].
Widget buildFieldLabel(
  String text, {
  required TextStyle style,
  bool isRequired = false,
}) {
  if (!isRequired) return Text(text, style: style);

  return Text.rich(
    TextSpan(
      text: text,
      style: style,
      children: const <InlineSpan>[kRequiredMarker],
    ),
  );
}
