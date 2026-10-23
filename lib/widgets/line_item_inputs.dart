import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// Quantity stepper for a product line on the invoice and credit-note forms.
///
/// Holds its own text, so the line card that hosts it must be keyed by the
/// line — otherwise inserting a line above it hands this state (and the
/// quantity it shows) to a different line.
class LineQuantityInput extends StatefulWidget {
  final double initialValue;
  final ValueChanged<double> onChanged;
  final bool isDark;

  const LineQuantityInput({
    required this.initialValue,
    required this.onChanged,
    required this.isDark,
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
    _controller.addListener(_onQuantityChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQuantityChanged);
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

  void _onQuantityChanged() {
    widget.onChanged(_current);
    // Rebuild so − dims/undims as the quantity crosses 1.
    setState(() {});
  }

  /// An empty or zero quantity counts as 1 on the line, so show that once
  /// the user leaves the field rather than a value the total doesn't use.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      final value = _parsed;
      if (value == null || value <= 0) _setQuantity(1);
    }
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final canDecrement = _current > 1;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: 44,
      decoration: BoxDecoration(
        color: AppFormTheme.inputFill(isDark),
        borderRadius: BorderRadius.circular(AppRadius.segment),
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppTheme.primaryColor
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _QuantityStepButton(
            icon: Icons.remove,
            isDark: isDark,
            onTap: canDecrement
                ? () => _setQuantity(_current - 1 < 1 ? 1 : _current - 1)
                : null,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppFormTheme.fieldValueStyle(isDark),
              decoration: const InputDecoration.collapsed(hintText: '1'),
            ),
          ),
          _QuantityStepButton(
            icon: Icons.add,
            isDark: isDark,
            onTap: () => _setQuantity(_current + 1),
          ),
        ],
      ),
    );
  }
}

/// A −/+ tap target inside [LineQuantityInput]; dims when [onTap] is null
/// (e.g. − at a quantity of 1).
class _QuantityStepButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;

  const _QuantityStepButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.segment),
      child: SizedBox(
        width: 36,
        height: double.infinity,
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? (isDark ? Colors.white : AppTheme.primaryColor)
              : (isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
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
        decoration: InputDecoration(
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
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          filled: true,
          fillColor: AppFormTheme.inputFill(isDark),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.segment),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.segment),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.segment),
            borderSide: const BorderSide(
              color: AppTheme.primaryColor,
              width: 2,
            ),
          ),
          isDense: true,
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
