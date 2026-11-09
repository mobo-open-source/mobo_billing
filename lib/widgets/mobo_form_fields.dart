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

  /// Height of the divider under the title. Null keeps the theme's 16px
  /// breathing room; pass 1 for the tight hairline the CRM forms use.
  final double? dividerHeight;

  const MoboFormCard({
    required this.title,
    required this.children,
    this.dividerHeight,
    Key? key,
  }) : super(key: key);

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
            height: dividerHeight,
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

  /// Shown in place of [leadingIcon] — e.g. a currency symbol before an
  /// amount.
  final Widget? leading;
  final bool isRequired;
  final int? maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  /// When [validator] runs. Defaults to only on form submit; pass
  /// [AutovalidateMode.onUserInteraction] to flag bad input while typing.
  final AutovalidateMode? autovalidateMode;
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
    this.leading,
    this.isRequired = false,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
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

    final icon =
        leading ??
        (leadingIcon == null
            ? null
            : HugeIcon(
                icon: leadingIcon!,
                color: AppFormTheme.iconColor(isDark),
                size: AppFormTheme.iconSize,
              ));

    // `InputDecorator` centres `prefixIcon` vertically, which leaves the icon
    // floating mid-box on a multiline field. There it is pinned beside the
    // first line instead, with the text indented to where a prefix would
    // have put it.
    final pinIconToFirstLine = icon != null && maxLines != 1;

    var decoration = AppFormTheme.inputDecoration(
      isDark: isDark,
      hintText: hintText,
      prefixIcon: pinIconToFirstLine ? null : icon,
      suffixIcon: suffixIcon,
    );
    if (pinIconToFirstLine) {
      decoration = decoration.copyWith(
        contentPadding: const EdgeInsets.fromLTRB(
          AppFormTheme.fieldGutter * 2 + AppFormTheme.iconSize,
          14,
          AppFormTheme.fieldGutter,
          14,
        ),
      );
    }

    final field = TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      style: AppFormTheme.fieldValueStyle(isDark),
      decoration: decoration,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildFieldLabel(
          label,
          isRequired: isRequired,
          style: AppFormTheme.fieldLabelStyle(isDark),
        ),
        const SizedBox(height: 10),
        if (pinIconToFirstLine)
          Stack(
            children: [
              field,
              // The 14px top padding, nudged up 1px so the 22px icon and the
              // ~20px first line share a centre line.
              Positioned(
                left: AppFormTheme.fieldGutter,
                top: 13,
                child: IgnorePointer(child: icon),
              ),
            ],
          )
        else
          field,
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
            // field lines up with the text fields and dropdowns above it. The
            // Container pads its child by the 1px border, so the padding here
            // is 1px short of theirs to land on the same size.
            padding: const EdgeInsets.symmetric(
              vertical: 13,
              horizontal: AppFormTheme.fieldGutter - 1,
            ),
            decoration: BoxDecoration(
              color: AppFormTheme.inputFill(isDark),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppFormTheme.restingBorderColor(isDark),
              ),
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

  /// Told when the result panel opens (`true`) or closes (`false`), so a form
  /// can keep content that belongs under the field out of the way while the
  /// panel is up.
  final ValueChanged<bool>? onOpenChanged;

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
    this.onOpenChanged,
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

class _MoboInlineDropdownState<T> extends State<MoboInlineDropdown<T>>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isOpen = false;
  bool _isLoading = false;
  List<T> _results = const [];

  /// The last search threw — shown as a retry row, not as "no results".
  bool _searchFailed = false;

  /// Bumped per search, so a slow response can't overwrite a newer one.
  int _searchGeneration = 0;
  bool _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selectedLabel ?? '';
    WidgetsBinding.instance.addObserver(this);
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
    // A parent mirroring the open state would otherwise be left on "open" if
    // this field is torn down with its panel showing. Deferred, because the
    // parent can't be rebuilt while the tree is being unmounted.
    final onOpenChanged = widget.onOpenChanged;
    if (_isOpen && onOpenChanged != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onOpenChanged(false));
    }
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The keyboard is sliding in (or out) — keep the open panel in view.
  @override
  void didChangeMetrics() {
    if (_isOpen) _revealPanel(animate: false);
  }

  void _open() {
    if (!widget.enabled || _isOpen) return;
    setState(() {
      _isOpen = true;
      _controller.clear();
    });
    widget.onOpenChanged?.call(true);
    _showKeyboard();
    _search('');
    _revealPanel();
  }

  /// Scrolls the enclosing form so the open panel is on screen.
  ///
  /// A field tapped low on the page is otherwise left sitting just above the
  /// keyboard — the text field only scrolls its own caret into view — with
  /// the panel opened out of sight beneath it, so the list looks like it
  /// never loaded.
  void _revealPanel({bool animate = true}) {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !_isOpen) return;
      final box = context.findRenderObject() as RenderBox?;
      final position = Scrollable.maybeOf(context)?.position;
      if (box == null ||
          !box.hasSize ||
          position == null ||
          !position.hasViewportDimension) {
        return;
      }
      // Bring the field and panel fully on screen when they fit; on a
      // viewport too short for both, pin the field to the top so the panel
      // gets the rest.
      final fits = box.size.height <= position.viewportDimension;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: fits
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.explicit,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        curve: Curves.easeInOut,
      );
    });
  }

  /// Opening from the trailing arrow bypasses the text field's own tap
  /// handling, so focus it here — the panel is a search box and should come
  /// up typeable. A field that kept focus after the keyboard was dismissed
  /// only needs the keyboard shown again.
  void _showKeyboard() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  /// Closes the panel and drops focus with it. A touch outside doesn't
  /// unfocus a text field on mobile, so the keyboard would otherwise stay up
  /// over a closed field that ignores typing, and the next tap would land as
  /// a repeat tap on a focused field instead of a fresh open.
  void _close() {
    if (!_isOpen) return;
    _debounce?.cancel();
    setState(() {
      _isOpen = false;
      _controller.text = widget.selectedLabel ?? '';
    });
    _focusNode.unfocus();
    widget.onOpenChanged?.call(false);
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

    final generation = ++_searchGeneration;
    setState(() {
      _isLoading = true;
      _searchFailed = false;
    });
    try {
      final results = await search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
      // The panel just grew from the loading row to the full list.
      _revealPanel();
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = const [];
        _isLoading = false;
        _searchFailed = true;
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
                focusNode: _focusNode,
                enabled: widget.enabled,
                onTap: _open,
                // By default a quick second tap counts as a double-tap and
                // skips onTap, leaving the panel shut.
                onTapAlwaysCalled: true,
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
                            _focusNode.unfocus();
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
                // Sized to its rows up to a cap, so a one-option list is a
                // one-row panel rather than a mostly empty box.
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 240),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppFormTheme.surface(isDark),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    ),
                    boxShadow: AppShadows.card,
                  ),
                  child: _buildPanelBody(isDark),
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
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_searchFailed) {
      return SizedBox(
        height: 72,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Couldn't load results",
              style: TextStyle(
                fontSize: 14,
                color: AppFormTheme.secondaryLabelColor(isDark),
              ),
            ),
            TextButton(
              onPressed: () => _search(_controller.text),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(
          child: Text(
            widget.emptyText,
            style: TextStyle(
              fontSize: 14,
              color: AppFormTheme.secondaryLabelColor(isDark),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
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
        : (isDark ? Colors.grey[700]! : AppTheme.disabledButtonFill);
    final foreground = isFilled ? Colors.white : AppTheme.disabledButtonText;

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
