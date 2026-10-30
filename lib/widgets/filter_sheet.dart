import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// The Filter & Group By sheet and its parts, shared by the invoice,
/// credit-note, payment, customer and product lists so every one of them is
/// laid out, spaced and coloured the same way.
///
/// A sheet is a [FilterSheetShell] around two tabs: a [FilterTabBody] holding
/// [FilterActiveFilters], [FilterSectionTitle]s, [FilterChoiceChip]s and the
/// date fields, and a [FilterGroupByTab].
class FilterSheetShell extends StatelessWidget {
  /// Side inset shared by everything in the sheet — the Filter / Group By
  /// switch's margin — so the title, chips, date fields and buttons all start
  /// and end on the same line.
  static const double inset = 16;

  final Widget filterTab;
  final Widget groupByTab;
  final VoidCallback onClear;
  final VoidCallback onApply;

  const FilterSheetShell({
    super.key,
    required this.filterTab,
    required this.groupByTab,
    required this.onClear,
    required this.onApply,
  });

  static Color sheetColor(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: sheetColor(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(isDark),
            _buildHeader(context, isDark),
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(children: [filterTab, groupByTab]),
            ),
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: inset, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Filter & Group By',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: inset),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(height: 48, text: 'Filter'),
          Tab(height: 48, text: 'Group By'),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        inset,
        20,
        inset,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: sheetColor(isDark),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Clear All',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrolling body of the Filter tab.
class FilterTabBody extends StatelessWidget {
  final List<Widget> children;

  const FilterTabBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        FilterSheetShell.inset,
        10,
        FilterSheetShell.inset,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Section heading ("Status", "Date Range"…), on the same left edge as the
/// options beneath it.
class FilterSectionTitle extends StatelessWidget {
  final String title;

  const FilterSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }
}

/// An option chip: brand-filled when on; when off, a faint Mobo tint with a
/// grey outline (light) or a neutral grey box with white text (dark).
class FilterChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FilterChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 13,
          fontWeight: selected || isDark ? FontWeight.w600 : FontWeight.w400,
          color: selected || isDark ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: AppTheme.primaryColor,
      // Solid: a translucent tint shows the chip's canvas through it, which
      // the dark theme leaves light.
      backgroundColor: isDark
          ? AppTheme.darkOptionFill
          : AppTheme.primaryTintSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? AppTheme.primaryColor
              : (isDark ? AppTheme.darkOptionBorder : Colors.grey[300]!),
        ),
      ),
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

/// "Active Filters" heading over brand-tinted [FilterActiveChip]s summarising
/// what is switched on. Renders nothing when [chips] is empty.
class FilterActiveFilters extends StatelessWidget {
  final List<Widget> chips;

  const FilterActiveFilters({super.key, required this.chips});

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Filters',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

/// A removable summary chip inside [FilterActiveFilters].
class FilterActiveChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const FilterActiveChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkActiveFill : AppTheme.primaryTintSolid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppTheme.darkActiveBorder
              : AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.darkActiveText : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: isDark ? AppTheme.darkActiveText : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Group By tab: a "None" row, then one radio row per grouping.
class FilterGroupByTab extends StatelessWidget {
  /// Lead-in text, e.g. "Group invoices by".
  final String heading;

  /// Grouping field → label.
  final Map<String, String> options;

  /// The chosen field, or null for no grouping.
  final String? selected;

  final ValueChanged<String?> onChanged;

  /// Shows a "Loading options…" line while [options] is still empty.
  final bool loadingWhenEmpty;

  const FilterGroupByTab({
    super.key,
    required this.heading,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.loadingWhenEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: FilterSheetShell.inset,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),
          _option(
            title: 'None',
            description: 'Display as a simple list',
            selected: selected == null,
            isDark: isDark,
            onTap: () => onChanged(null),
          ),
          const SizedBox(height: 10),
          Divider(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            thickness: 1,
            height: 1,
          ),
          const SizedBox(height: 10),
          for (final entry in options.entries)
            _option(
              title: entry.value,
              description: 'Group by ${entry.value.toLowerCase()}',
              selected: selected == entry.key,
              isDark: isDark,
              onTap: () => onChanged(entry.key),
            ),
          if (options.isEmpty && loadingWhenEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Loading options...',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A single-choice row: title, a one-line description and a radio.
  Widget _option({
    required String title,
    required String description,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: RadioListTile<bool>(
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        value: true,
        groupValue: selected,
        onChanged: (_) => onTap(),
        activeColor: AppTheme.primaryColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
