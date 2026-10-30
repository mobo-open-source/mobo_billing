import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// Filled, rounded numeric field shared by the quantity and unit-price inputs
/// of a product line, so the two sit side by side as one matched pair.
InputDecoration _lineNumberDecoration(
  bool isDark, {
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.segment),
    borderSide: side,
  );

  return InputDecoration(
    hintText: hintText,
    hintStyle: AppFormTheme.fieldHintStyle(isDark),
    prefixIcon: prefixIcon,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    isDense: true,
    filled: true,
    fillColor: AppFormTheme.inputFill(isDark),
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: border(AppFormTheme.restingBorderSide(isDark)),
    enabledBorder: border(AppFormTheme.restingBorderSide(isDark)),
    focusedBorder: border(
      const BorderSide(color: AppTheme.primaryColor, width: 2),
    ),
  );
}

/// Quantity field for a product line on the invoice and credit-note forms:
/// a rounded numeric box (style guide §6), optionally with − / + buttons
/// inside it that step the quantity by 1.
///
/// Holds its own text, so the line card that hosts it must be keyed by the
/// line — otherwise inserting a line above it hands this state (and the
/// quantity it shows) to a different line.
class LineQuantityInput extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  final bool isDark;

  /// Shows − / + buttons at either end of the field.
  final bool showStepper;

  const LineQuantityInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
    this.showStepper = false,
    super.key,
  });

  @override
  State<LineQuantityInput> createState() => _LineQuantityInputState();
}

class _LineQuantityInputState extends State<LineQuantityInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.initialValue));
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// `2.0` → `2`, `2.5` → `2.5`: whole quantities read without a decimal,
  /// fractional ones (kg, hours) keep theirs.
  static String _format(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  double? get _parsed => double.tryParse(_controller.text.trim());

  double get _current {
    final value = _parsed;
    return value != null && value > 0 ? value : 1.0;
  }

  /// An empty or zero quantity counts as 1 on the line, so show that once
  /// the user leaves the field rather than a value the total doesn't use.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      final value = _parsed;
      if (value == null || value <= 0) _setQuantity(1);
    }
  }

  /// Sets the text with the caret at the end — a bare `text =` leaves the
  /// selection invalid, and a focused field then loses its caret.
  void _setQuantity(double value) {
    final text = _format(value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Steps by whole units but never below 1, the smallest quantity a line
  /// counts — so − on 1.5 lands on 1, not 0.5.
  void _step(int delta) {
    final next = _current + delta;
    setState(() => _setQuantity(next < 1 ? 1 : next));
    widget.onChanged(_current);
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    final isDark = widget.isDark;

    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      color: AppTheme.primaryColor,
      disabledColor: isDark ? Colors.grey[600] : Colors.grey[400],
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 40),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    var decoration = _lineNumberDecoration(isDark, hintText: '1');
    if (widget.showStepper) {
      decoration = decoration.copyWith(
        prefixIcon: _stepButton(
          Icons.remove,
          'Decrease quantity',
          _current > 1 ? () => _step(-1) : null,
        ),
        suffixIcon: _stepButton(
          Icons.add,
          'Increase quantity',
          () => _step(1),
        ),
        // The buttons already pad the number off the edges.
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      );
    }

    return SizedBox(
      height: 44,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        cursorColor: AppTheme.primaryColor,
        style: AppFormTheme.fieldValueStyle(isDark),
        decoration: decoration,
        onChanged: (_) {
          // Rebuild so − disables once a typed quantity reaches 1.
          setState(() {});
          widget.onChanged(_current);
        },
        // Select the whole number so typing replaces it.
        onTap: () => _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        ),
        // A touch outside doesn't unfocus a text field on mobile, and the
        // empty-means-1 correction waits for the field to lose focus.
        onTapOutside: (_) => _focusNode.unfocus(),
      ),
    );
  }
}

/// Unit-price field for a product line, prefixed with the currency symbol.
class LinePriceInput extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  final bool isDark;
  final String currencySymbol;

  const LinePriceInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
    required this.currencySymbol,
    super.key,
  });

  @override
  State<LinePriceInput> createState() => _LinePriceInputState();
}

class _LinePriceInputState extends State<LinePriceInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue.toStringAsFixed(2),
    );
    _controller.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onPriceChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPriceChanged() {
    final cleanText = _controller.text.replaceAll(RegExp(r'[^\d.]'), '');
    widget.onChanged(double.tryParse(cleanText) ?? 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return SizedBox(
      height: 44,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppFormTheme.fieldValueStyle(isDark),
        decoration: _lineNumberDecoration(
          isDark,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Text(
              widget.currencySymbol,
              style: TextStyle(
                fontSize: 15,
                color: AppFormTheme.hintColor(isDark),
              ),
            ),
          ),
        ),
        onTap: () {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        },
      ),
    );
  }
}
