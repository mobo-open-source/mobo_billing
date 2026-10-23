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
            prefixText: '',
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showBorder ? _getBorderColor() : Colors.transparent,
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showBorder ? AppTheme.primaryColor : Colors.transparent,
                width: 1,
              ),
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
