import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// A customizable [TextFormField] wrapper with a label above the field,
/// used throughout the Invoice, Credit Note and Payment forms.
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final bool isDark;
  final bool showBorder;
  final TextInputType? keyboardType;
  final int? maxLines;
  final Widget? suffixIcon;
  final bool enabled;

  /// Appends the red required-field star to [labelText].
  final bool isRequired;

  /// Text shown inside the field ahead of the input — e.g. a currency symbol
  /// before an amount. Unlike `prefixText`, it stays visible while the field
  /// is empty and unfocused.
  final String? prefix;

  const CustomTextField({
    required this.controller,
    required this.labelText,
    this.hintText,
    this.validator,
    this.isDark = false,
    this.showBorder = false,
    this.keyboardType,
    this.maxLines = 1,
    this.suffixIcon,
    this.enabled = true,
    this.isRequired = false,
    this.prefix,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(
          labelText,
          isRequired: isRequired,
          style: TextStyle(
            fontFamily: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
            ).fontFamily,
            color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          style: TextStyle(
            fontFamily: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
            ).fontFamily,
            color: isDark ? Colors.white70 : const Color(0xff000000),
          ),
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType ?? TextInputType.text,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: GoogleFonts.manrope(
                fontWeight: FontWeight.w400,
              ).fontFamily,
              color: isDark ? Colors.white38 : Colors.grey[500],
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      prefix!,
                      style: TextStyle(
                        fontFamily: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                        ).fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showBorder
                  ? BorderSide(color: _getBorderColor(), width: 2)
                  : AppFormTheme.restingBorderSide(isDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: showBorder
                  ? const BorderSide(color: AppTheme.primaryColor, width: 1)
                  : AppFormTheme.restingBorderSide(isDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 1,
              ),
            ),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xffF8FAFB),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Color _getBorderColor() {
    return isDark ? Colors.grey[700]! : Colors.grey[400]!;
  }
}
