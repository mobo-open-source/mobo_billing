import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/form_styles.dart';

/// The app's list search bar.
///
/// Two separate card-like surfaces sitting side by side: the search field,
/// and a square filter button to its right. Both share a 10px corner radius,
/// are borderless at rest and carry the same soft drop shadow. Focus brings
/// up a brand-coloured ring on the field only.
///
/// The filter button is always rendered, with or without [onFilterTap], so
/// the toolbar never changes shape between screens; it simply doesn't respond
/// to taps when no handler is wired up.
class MoboSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called after the field is cleared, so the caller can reload its list.
  final VoidCallback? onClear;

  final VoidCallback? onFilterTap;

  /// Shows the small primary dot on the filter button.
  final bool hasActiveFilters;

  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  const MoboSearchField({
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.onFilterTap,
    this.hasActiveFilters = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    Key? key,
  }) : super(key: key);

  @override
  State<MoboSearchField> createState() => _MoboSearchFieldState();
}

class _MoboSearchFieldState extends State<MoboSearchField> {
  /// Plain nullable field, lazily created — deliberately not `late final` set
  /// from [initState]. Hot reload doesn't re-run `initState` for a `State`
  /// object that already existed before the reload, so a `late` field left
  /// unset by the old `initState` body throws on first access; a nullable
  /// field with a `??=` getter just heals itself instead.
  FocusNode? _internalFocusNode;
  bool _hasFocus = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  /// Only the clear affordance depends on emptiness, so rebuild on that edge.
  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
  }

  static const double _height = 48;

  /// Field and button share one corner radius so the two surfaces read as a
  /// matched pair.
  static const double _fieldRadius = 10;
  static const double _buttonRadius = 10;

  /// A field still focused after the keyboard was dismissed (Back) ignores
  /// `requestFocus`, so bring the keyboard back explicitly in that case.
  void _focusInput() {
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildField(isDark)),
        const SizedBox(width: 12),
        _buildFilterButton(isDark),
      ],
    );
  }

  Widget _buildField(bool isDark) {
    final hasText = widget.controller.text.isNotEmpty;
    final iconColor = AppFormTheme.hintColor(isDark);

    // Shadow lives on this outer, unclipped box — clipping a decoration also
    // clips its own boxShadow, which is what makes the field lose definition
    // against the page background.
    //
    // The fill and focus ring live one level in, but deliberately as a bare
    // `DecoratedBox`, not a second `Container`: giving a `Container` a border
    // makes it auto-pad its child by the border's width, even a fully
    // transparent one — which would shift the contents by 2px on focus.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_fieldRadius),
        boxShadow: AppShadows.search,
      ),
      child: SizedBox(
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(_fieldRadius),
            // The drop shadow doesn't show on the dark page, so dark mode
            // also gets the resting outline the form fields use.
            border: Border.all(
              color: _hasFocus
                  ? AppTheme.primaryColor
                  : AppFormTheme.restingBorderColor(isDark),
              width: _hasFocus ? 2 : 1,
            ),
          ),
          // The icon and the input are laid out by this Row rather than by
          // `InputDecoration`'s prefixIcon: `InputDecorator` derives its
          // content height from the tallest of (prefix, input, suffix) and
          // distributes `contentPadding` around that, so a 22px icon against a
          // ~21px line box never shares a centre line with the text.
          child: GestureDetector(
            // The Row only fills the field's width, not its tap target — so
            // focus the input when the gaps and the icon are tapped too.
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _focusInput : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search, size: 22, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    enabled: widget.enabled,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,

                    // No `height: 1.0` on either style: forcing the line box
                    // down to exactly the font size clips descenders and
                    // throws the optical centre off.
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                      fontWeight: FontWeight.w400,
                      fontSize: 15,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: iconColor,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        letterSpacing: 0,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,

                      // Fully collapsed: the field contributes nothing but its
                      // own line height, leaving the Row free to centre it.
                      isDense: true,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasText)
                  IconButton(
                    icon: Icon(Icons.clear_rounded, color: iconColor, size: 18),
                    tooltip: 'Clear search',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: widget.enabled
                        ? () {
                            widget.controller.clear();
                            widget.onChanged?.call('');
                            widget.onClear?.call();
                          }
                        : null,
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_buttonRadius),
        boxShadow: AppShadows.search,
      ),
      child: Material(
        color: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
          side: AppFormTheme.restingBorderSide(isDark),
        ),
        child: InkWell(
          onTap: widget.enabled ? widget.onFilterTap : null,
          borderRadius: BorderRadius.circular(_buttonRadius),
          child: SizedBox(
            width: _height,
            height: _height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.filter_alt_outlined,
                  size: 22,
                  color: isDark ? Colors.white70 : const Color(0xFF5F5F5F),
                ),
                if (widget.hasActiveFilters)
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 7, height: 7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
