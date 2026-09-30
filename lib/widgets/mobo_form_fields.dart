import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// Card that groups a set of form fields under a heading.
class MoboFormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const MoboFormCard({required this.title, required this.children, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppFormTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppFormTheme.cardBorder(isDark), width: 0.5),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Divider(
            color: isDark ? Colors.grey[700] : Colors.grey.shade200,
            indent: 10,
            endIndent: 10,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labelled, filled text field used throughout the create/edit forms.
class MoboTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final List<List<dynamic>>? leadingIcon;
  final bool isRequired;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const MoboTextField({
    required this.controller,
    required this.label,
    this.hintText,
    this.leadingIcon,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(
          label,
          isRequired: isRequired,
          style: AppFormTheme.fieldLabelStyle(isDark),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          style: AppFormTheme.fieldValueStyle(isDark),
          decoration: AppFormTheme.inputDecoration(
            isDark: isDark,
            hintText: hintText,
            prefixIcon: leadingIcon == null
                ? null
                : HugeIcon(
                    icon: leadingIcon!,
                    color: AppFormTheme.iconColor(isDark),
                    size: AppFormTheme.iconSize,
                  ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Read-only field that opens a date picker, styled like [MoboTextField].
class MoboDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String hintText;
  final VoidCallback onTap;
  final bool isRequired;
  final String Function(DateTime) formatter;

  const MoboDateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.formatter,
    this.hintText = 'Select date',
    this.isRequired = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(
          label,
          isRequired: isRequired,
          style: AppFormTheme.fieldLabelStyle(isDark),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            // Same gutter/icon/gap as AppFormTheme.inputDecoration, so a date
            // field lines up with the text fields and dropdowns above it.
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: AppFormTheme.fieldGutter,
            ),
            decoration: BoxDecoration(
              color: AppFormTheme.inputFill(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  color: AppFormTheme.iconColor(isDark),
                  size: AppFormTheme.iconSize,
                ),
                const SizedBox(width: AppFormTheme.fieldGutter),
                Expanded(
                  child: Text(
                    value == null ? hintText : formatter(value!),
                    style: value == null
                        ? AppFormTheme.fieldHintStyle(isDark)
                        : AppFormTheme.fieldValueStyle(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One option row inside a [MoboInlineDropdown].
///
/// The selected option reads in the brand colour with a trailing check and a
/// faint primary wash, so the current value is obvious in a long list.
class MoboDropdownOptionTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool isSelected;
  final VoidCallback onTap;

  const MoboDropdownOptionTile({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isSelected = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? AppTheme.primaryColor.withOpacity(0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppFormTheme.valueColor(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppFormTheme.secondaryLabelColor(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 18, color: AppTheme.primaryColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// Searchable selector whose result list expands inline beneath the field
/// rather than in an overlay or a bottom sheet.
///
/// Supply [items] for a list already in memory, or [asyncSearch] to query the
/// server as the user types. Tapping outside closes the panel and restores the
/// current selection's label to the field.
class MoboInlineDropdown<T> extends StatefulWidget {
  final String label;
  final String hintText;
  final bool isRequired;
  final List<List<dynamic>>? leadingIcon;

  /// Text shown in the closed field — the current selection.
  final String? selectedLabel;

  /// Options held in memory. Typing filters them on [titleBuilder].
  final List<T> items;

  /// Server-side search. Called with an empty query when the panel opens.
  final Future<List<T>> Function(String query)? asyncSearch;

  final String Function(T item) titleBuilder;
  final String? Function(T item)? subtitleBuilder;
  final Widget Function(T item)? leadingBuilder;
  final bool Function(T item)? isItemSelected;
  final ValueChanged<T> onItemTap;

  /// Shown as a trailing clear button when there is a selection.
  final VoidCallback? onClear;

  final String emptyText;
  final String? Function(String?)? validator;
  final bool enabled;

  const MoboInlineDropdown({
    required this.label,
    required this.hintText,
    required this.titleBuilder,
    required this.onItemTap,
    this.items = const [],
    this.asyncSearch,
    this.selectedLabel,
    this.subtitleBuilder,
    this.leadingBuilder,
    this.isItemSelected,
    this.onClear,
    this.leadingIcon,
    this.isRequired = false,
    this.emptyText = 'No records found',
    this.validator,
    this.enabled = true,
    Key? key,
  }) : super(key: key);

  @override
  State<MoboInlineDropdown<T>> createState() => _MoboInlineDropdownState<T>();
}

class _MoboInlineDropdownState<T> extends State<MoboInlineDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  bool _isOpen = false;
  bool _isLoading = false;
  List<T> _results = const [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedLabel ?? '';
  }

  @override
  void didUpdateWidget(covariant MoboInlineDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the panel is open the field holds the search text, so only sync
    // the selection back into it once the panel has closed.
    if (!_isOpen && widget.selectedLabel != oldWidget.selectedLabel) {
      _controller.text = widget.selectedLabel ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (!widget.enabled || _isOpen) return;
    setState(() {
      _isOpen = true;
      _controller.clear();
    });
    _search('');
  }

  void _close() {
    if (!_isOpen) return;
    _debounce?.cancel();
    setState(() {
      _isOpen = false;
      _controller.text = widget.selectedLabel ?? '';
    });
  }

  void _onChanged(String query) {
    if (!_isOpen) return;
    _debounce?.cancel();
    if (widget.asyncSearch == null) {
      _search(query);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final search = widget.asyncSearch;

    if (search == null) {
      final needle = query.trim().toLowerCase();
      setState(() {
        _results = needle.isEmpty
            ? widget.items
            : widget.items
                  .where(
                    (item) => widget
                        .titleBuilder(item)
                        .toLowerCase()
                        .contains(needle),
                  )
                  .toList();
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSelection = (widget.selectedLabel ?? '').isNotEmpty;

    return TapRegion(
      onTapOutside: (_) => _close(),
      child: FormField<String>(
        validator: widget.validator,
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFieldLabel(
                widget.label,
                isRequired: widget.isRequired,
                style: AppFormTheme.fieldLabelStyle(isDark),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _controller,
                enabled: widget.enabled,
                onTap: _open,
                onChanged: _onChanged,
                style: AppFormTheme.fieldValueStyle(isDark),
                decoration: AppFormTheme.inputDecoration(
                  isDark: isDark,
                  hintText: widget.hintText,
                  prefixIcon: widget.leadingIcon == null
                      ? null
                      : HugeIcon(
                          icon: widget.leadingIcon!,
                          color: AppFormTheme.iconColor(isDark),
                          size: AppFormTheme.iconSize,
                        ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasSelection && widget.onClear != null)
                        GestureDetector(
                          onTap: () {
                            _close();
                            _controller.clear();
                            widget.onClear!();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppFormTheme.iconColor(isDark),
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _isOpen ? _close : _open,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: HugeIcon(
                            icon: _isOpen
                                ? HugeIcons.strokeRoundedArrowUp01
                                : HugeIcons.strokeRoundedArrowDown01,
                            color: AppFormTheme.iconColor(isDark),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOpen)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppFormTheme.surface(isDark),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(AppRadius.md),
                        bottomRight: Radius.circular(AppRadius.md),
                      ),
                      border: Border.all(
                        color: AppFormTheme.cardBorder(isDark),
                      ),
                    ),
                    child: _buildPanelBody(isDark),
                  ),
                ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    field.errorText!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanelBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          widget.emptyText,
          style: TextStyle(
            fontSize: 14,
            color: AppFormTheme.secondaryLabelColor(isDark),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _results.length,
      separatorBuilder: (context, index) => const SizedBox(height: 5),
      itemBuilder: (context, index) {
        final item = _results[index];
        return MoboDropdownOptionTile(
          title: widget.titleBuilder(item),
          subtitle: widget.subtitleBuilder?.call(item),
          leading: widget.leadingBuilder?.call(item),
          isSelected: widget.isItemSelected?.call(item) ?? false,
          onTap: () {
            widget.onItemTap(item);
            _close();
          },
        );
      },
    );
  }
}

/// The full-width button that closes every create/edit form.
///
/// [isReady] drives the look only — [onPressed] still fires so the form can
/// run its own validation and say which field is missing, rather than leaving
/// a dead tap.
class MoboSubmitButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final bool isReady;
  final VoidCallback? onPressed;
  final List<List<dynamic>>? icon;

  const MoboSubmitButton({
    required this.label,
    required this.loadingLabel,
    required this.isReady,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Loading keeps the brand fill — the work is under way, so the button is
    // not "unavailable", it is busy.
    final isFilled = isLoading || isReady;

    final background = isFilled
        ? AppTheme.primaryColor
        : (isDark ? Colors.grey[700]! : Colors.grey[300]!);
    final foreground = isFilled
        ? Colors.white
        : (isDark ? Colors.grey[400]! : Colors.grey[500]!);

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              LoadingAnimationWidget.staggeredDotsWave(
                color: foreground,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                loadingLabel,
                style: TextStyle(
                  fontSize: 16,
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              HugeIcon(
                icon: icon ?? HugeIcons.strokeRoundedFileAdd,
                color: foreground,
                size: 25,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
