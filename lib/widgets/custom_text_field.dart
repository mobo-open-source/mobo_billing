import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';

/// A highly customizable [TextFormField] wrapper with support for icons, 
/// labels above the field, and minimal styling options.
class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String name;
  final String? labelText;
  final String? hintText;
  final String? initialValue;
  final dynamic prefixIcon;
  final dynamic suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String?)? onChanged;
  final void Function()? onSuffixIconPressed;
  final bool enabled;
  final int maxLines;
  final TextInputAction textInputAction;
  final bool showLabelAbove;
  final bool isMinimal;

  const CustomTextField({
    Key? key,
    this.controller,
    required this.name,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onSuffixIconPressed,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction = TextInputAction.next,
    this.showLabelAbove = false,
    this.isMinimal = false,
  }) : super(key: key);

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _isObscured = true;
  final FocusNode _focusNode = FocusNode();
  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    if (widget.controller != null) {
      _controllerListener = () {
        if (mounted) {
          setState(() {});
        }
      };
      widget.controller!.addListener(_controllerListener!);

      if (widget.initialValue != null && widget.controller!.text.isEmpty) {
        widget.controller!.text = widget.initialValue!;
      }
    }
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();

    if (widget.controller != null && _controllerListener != null) {
      widget.controller!.removeListener(_controllerListener!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = widget.isMinimal
        ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB))
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);
    final borderColor = widget.isMinimal
        ? Colors.transparent
        : (isDark ? Colors.grey[700]! : Colors.grey[300]!);
    final focusBorderColor = Theme.of(context).primaryColor;
    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
    final hintColor = isDark ? Colors.grey[500]! : Colors.grey[500]!;

    return FormField<String>(
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showLabelAbove && widget.labelText != null)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.isMinimal ? 0 : 10,
                  bottom: 8,
                ),
                child: Text(
                  widget.labelText!,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    fontSize: 14,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isMinimal ? 0 : 10,
              ),
              child: Container(
                height: widget.isMinimal ? null : 50,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: _focusNode.hasFocus
                      ? Border.all(color: focusBorderColor, width: 2)
                      : field.hasError
                      ? Border.all(color: Colors.red, width: 1)
                      : Border.all(color: borderColor, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      if (widget.prefixIcon != null)
                        Padding(
                          padding: EdgeInsets.only(
                            left: widget.isMinimal ? 16 : 12,
                            right: widget.isMinimal ? 12 : 8,
                          ),
                          child: _buildIcon(
                            widget.prefixIcon,
                            iconColor,
                            widget.isMinimal ? 20 : 17,
                          ),
                        ),
                      Expanded(
                        child: TextFormField(
                          controller: widget.controller,
                          initialValue: widget.controller == null
                              ? widget.initialValue
                              : null,
                          focusNode: _focusNode,
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.hintText,
                            hintStyle: GoogleFonts.manrope(
                              fontSize: 14,
                              color: hintColor,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.only(
                              top: 16,
                              bottom: 16,
                              left:
                                  (widget.prefixIcon == null &&
                                      widget.isMinimal)
                                  ? 16
                                  : 0,
                              right: widget.suffixIcon != null ? 0 : 16,
                            ),
                          ),
                          obscureText: widget.obscureText ? _isObscured : false,
                          keyboardType: widget.keyboardType,
                          onChanged: (value) {
                            field.didChange(value);

                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (mounted && field.value == value) {
                                  field.validate();
                                }
                              },
                            );
                            if (widget.onChanged != null) {
                              widget.onChanged!(value);
                            }
                          },
                          enabled: widget.enabled,
                          maxLines: widget.maxLines,
                        ),
                      ),
                      if (widget.suffixIcon != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, right: 12),
                          child: widget.obscureText
                              ? IconButton(
                                  icon: _buildIcon(
                                    _isObscured
                                        ? HugeIcons.strokeRoundedView
                                        : HugeIcons.strokeRoundedViewOff,
                                    iconColor,
                                    20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isObscured = !_isObscured;
                                    });
                                  },
                                )
                              : widget.onSuffixIconPressed != null
                              ? IconButton(
                                  icon: _buildIcon(
                                    widget.suffixIcon,
                                    iconColor,
                                    20,
                                  ),
                                  onPressed: widget.onSuffixIconPressed,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              : _buildIcon(widget.suffixIcon, iconColor, 20),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIcon(dynamic icon, Color color, double size) {
    if (icon is IconData) {
      return Icon(icon, color: color, size: size);
    } else {
      return Transform.scale(
        scale: size / 24.0,
        child: HugeIcon(icon: icon, color: color, size: 24),
      );
    }
  }
}
