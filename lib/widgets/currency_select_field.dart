import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// Compact currency picker, sized for a narrow column such as the one beside
/// a payment amount.
///
/// A company has a handful of active currencies at most, so there is no
/// search box (and no keyboard): the field shows the chosen ISO code and
/// opens a menu anchored beneath it, over the form rather than inside it.
///
/// [currencies] are `res.currency` rows with `id`, `name` (the ISO code) and
/// `symbol`.
class CurrencySelectField extends StatefulWidget {
  final List<Map<String, dynamic>> currencies;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  const CurrencySelectField({
    required this.currencies,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  @override
  State<CurrencySelectField> createState() => _CurrencySelectFieldState();
}

class _CurrencySelectFieldState extends State<CurrencySelectField> {
  bool _isOpen = false;

  String? get _selectedCode => widget.currencies
      .where((c) => c['id'] == widget.selectedId)
      .firstOrNull?['name']
      ?.toString();

  /// The symbol, unless it just repeats the code (e.g. `CHF`).
  static String _symbolOf(Map<String, dynamic> currency) {
    final symbol = currency['symbol'];
    if (symbol is! String || symbol == currency['name']?.toString()) return '';
    return symbol;
  }

  Future<void> _openMenu(BuildContext fieldContext, bool isDark) async {
    // Otherwise a text field focused before the menu (the amount, say) takes
    // focus back when it closes, and the keyboard comes up again.
    FocusManager.instance.primaryFocus?.unfocus();

    final field = fieldContext.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final below = field.localToGlobal(
      Offset(0, field.size.height + 6),
      ancestor: overlay,
    );

    setState(() => _isOpen = true);
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(below.dx, below.dy, field.size.width, 0),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(
        minWidth: field.size.width,
        maxWidth: field.size.width,
        maxHeight: 320,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      items: [
        for (final currency in widget.currencies)
          _buildOption(currency, isDark),
      ],
    );
    if (!mounted) return;
    setState(() => _isOpen = false);
    if (selected != null && selected != widget.selectedId) {
      widget.onSelected(selected);
    }
  }

  PopupMenuItem<int> _buildOption(Map<String, dynamic> currency, bool isDark) {
    final isSelected = currency['id'] == widget.selectedId;
    final symbol = _symbolOf(currency);

    return PopupMenuItem<int>(
      value: currency['id'] as int,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            Text(
              currency['name']?.toString() ?? '',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppFormTheme.valueColor(isDark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                symbol,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppFormTheme.secondaryLabelColor(isDark),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = _selectedCode;
    final enabled = widget.currencies.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(
          'Currency',
          style: AppFormTheme.fieldLabelStyle(isDark),
        ),
        const SizedBox(height: 10),
        Builder(
          builder: (fieldContext) => InkWell(
            onTap: enabled ? () => _openMenu(fieldContext, isDark) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              // Border + padding always total 14px around a 22px row: the same
              // 50px as a MoboTextField, so the boxes line up beside one. The
              // 1px resting border thickens to 2px while the menu is open.
              padding: EdgeInsets.symmetric(
                vertical: _isOpen ? 12 : 13,
                horizontal: AppFormTheme.fieldGutter + (_isOpen ? 0 : 1),
              ),
              decoration: BoxDecoration(
                color: AppFormTheme.inputFill(isDark),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _isOpen
                      ? AppTheme.primaryColor
                      : AppFormTheme.restingBorderColor(isDark),
                  width: _isOpen ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code ?? 'Select',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: code == null
                          ? AppFormTheme.fieldHintStyle(isDark)
                          : AppFormTheme.fieldValueStyle(isDark),
                    ),
                  ),
                  HugeIcon(
                    icon: _isOpen
                        ? HugeIcons.strokeRoundedArrowUp01
                        : HugeIcons.strokeRoundedArrowDown01,
                    color: AppFormTheme.iconColor(isDark),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
