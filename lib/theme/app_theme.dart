import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The single source of truth for the palette in §1 of the UI style guide.
///
/// Anything colour-, shadow- or radius-shaped belongs here, in [StatusColors],
/// [AppShadows] or [AppRadius] — never as a raw `Colors.*` literal in a widget.
class AppTheme {
  // --- Brand -------------------------------------------------------------
  static const Color primaryColor = Color(0xFFC03355);
  static const Color secondary = Color(0xFFFFFFFF);

  static const Color vivaMagentaLight = Color(0xFFC03355);
  static const Color vivaMagentaDark = Color(0xFFC03355);
  static const Color vivaMagentaAccent = Color(0xFFC03355);

  // --- Surfaces ----------------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);

  /// Scaffold background (light theme).
  static const Color scaffoldBackground = Color(0xFFFAFAFA);
  static const Color offWhite = scaffoldBackground;

  /// Generic light background.
  static const Color background = Color(0xFFF3F3F3);
  static const Color lightGrey = background;

  /// Scaffold background (dark theme).
  static const Color darkScaffold = Color(0xFF181A20);

  /// Card/sheet/dialog surface (dark theme).
  static const Color darkSurface = Color(0xFF1E1E1E);

  // --- Text & hairlines --------------------------------------------------
  static const Color dark = Color(0xFF101010);
  static const Color textPrimary = dark;
  static const Color textSecondary = Color(0xFF666666);

  static const Color textDark = textPrimary;
  static const Color textMedium = Color(0xFF424242);
  static const Color textLight = textSecondary;

  static const Color divider = Color(0xFFE0E0E0);
  static const Color mediumGrey = divider;
  static const Color darkGrey = Color(0xFF757575);

  /// Reference shadow colour constant — black @ ~10%.
  static const Color shadow = Color(0x1A000000);

  /// Text-field caret and selection handles. Dark mode swaps to white, since
  /// a black caret disappears on the dark field fill.
  static const Color cursor = Color(0xFF000000);
  static const Color cursorDark = Color(0xFFFFFFFF);

  /// Gold used by the star rating control. Named here rather than reaching for
  /// `Colors.amber` in a widget (§1).
  static const Color ratingStar = Color(0xFFFFC107);

  /// Convenience label helpers so widgets don't re-derive them.
  static Color labelColor(bool isDark) => isDark ? Colors.white : dark;
  static Color secondaryLabelColor(bool isDark) =>
      isDark ? Colors.grey[400]! : Colors.grey[600]!;

  // --- Semantic ----------------------------------------------------------
  static const Color success = StatusColors.green;
  static const Color warning = StatusColors.orange;
  static const Color error = StatusColors.red;
  static const Color info = StatusColors.blue;

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: offWhite,
      useMaterial3: true,
      fontFamily: GoogleFonts.manrope().fontFamily,

      appBarTheme: AppBarTheme(
        backgroundColor: offWhite,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),

      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Buttons swap in this style instead of inheriting the theme's
          // font, so name Manrope here or labels fall back to Roboto.
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Black caret and drag handles on every text field, rather than the
      // brand colour Flutter derives from `colorScheme.primary`.
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: cursor,
        selectionHandleColor: cursor,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mediumGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mediumGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: textMedium),
        hintStyle: const TextStyle(color: textLight),
        prefixIconColor: primaryColor,
        suffixIconColor: primaryColor,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textLight,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: primaryColor.withOpacity(0.1),
        // Chips swap in this style rather than inheriting the theme font.
        labelStyle: GoogleFonts.manrope(color: primaryColor),
        selectedColor: primaryColor,
        secondarySelectedColor: vivaMagentaLight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: mediumGrey,
        circularTrackColor: mediumGrey,
      ),

      dividerTheme: const DividerThemeData(
        color: mediumGrey,
        thickness: 1,
        space: 16,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textDark,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMedium,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textMedium,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textLight,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMedium,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textLight,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: white,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints(maxWidth: double.infinity),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: vivaMagentaAccent,
        tertiary: vivaMagentaLight,
        surface: white,
        background: white,
        onPrimary: white,
        onSecondary: white,
        onSurface: textDark,
        onBackground: textDark,
      ),
    );
  }

  static ThemeData get darkTheme {
    const Color darkBackground = darkScaffold;
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: cursorDark,
        selectionHandleColor: cursorDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: vivaMagentaAccent,
        surface: darkSurface,
        background: darkBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF2C2C2E),
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        constraints: BoxConstraints(maxWidth: double.infinity),
      ),
    );
  }

  /// The canonical flat card from §8 — flat fill, hairline border, [AppShadows.cardShadow].
  static BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : white,
    borderRadius: BorderRadius.circular(AppRadius.md),
    border: Border.all(
      color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
      width: 0.5,
    ),
    boxShadow: AppShadows.card,
  );

  /// Larger dashboard/section container — §8's "panel" variant.
  static BoxDecoration panelDecoration(bool isDark) => BoxDecoration(
    color: isDark ? Colors.grey[850] : white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: [AppShadows.panelShadow(isDark)],
  );

  static BoxDecoration get accentCardDecoration => BoxDecoration(
    color: primaryColor.withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
  );
}

/// §4 — the radius scale. Default to [md] when unsure.
class AppRadius {
  const AppRadius._();

  /// Small chip corner, tiny inner accents.
  static const double xs = 4;

  /// Compact/status dropdown, icon-button container.
  static const double sm = 5;

  /// Small tab/segment chip.
  static const double chip = 6;

  /// Dropdown/filter control, popup menus, inner input border.
  static const double control = 8;

  /// Segmented view-selector, quantity/numeric field variant.
  static const double segment = 10;

  /// Default — cards, list tiles, buttons, text fields, tag chips.
  static const double md = 12;

  /// Kanban column, bottom sheet (top corners), panel/section container.
  static const double lg = 16;

  /// Canonical status badge.
  static const double badge = 18;

  /// Pill buttons/chips, dialogs, pagination counter, active-filters pill.
  static const double pill = 20;

  /// Tall/full bottom-sheet variant (rare).
  static const double sheet = 28;
}

/// §3 — depth comes from these explicit shadows, never from Material `elevation`.
class AppShadows {
  const AppShadows._();

  /// Standard "flat card" shadow — list items, list-style cards, form cards.
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x0D000000), // black @ 5%
    offset: Offset(0, 6),
    blurRadius: 16,
    spreadRadius: 2,
  );

  /// "Panel" shadow — bigger surfaces like chart containers, dashboard sections.
  static BoxShadow panelShadow(bool isDark) => BoxShadow(
    color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  /// Soft shadow for pill-shaped search bars only.
  static const BoxShadow searchShadow = BoxShadow(
    color: Color(0x0A000000), // black @ 4%
    offset: Offset(3, 11),
    blurRadius: 8.5,
    spreadRadius: -3,
  );

  static const List<BoxShadow> card = <BoxShadow>[cardShadow];
  static const List<BoxShadow> search = <BoxShadow>[searchShadow];
  static List<BoxShadow> panel(bool isDark) => <BoxShadow>[panelShadow(isDark)];
}

/// §1/§10 — the semantic status map, and the one badge that renders it.
///
/// Every status/stage indicator resolves its colour through [forState] rather
/// than reaching for `Colors.green`/`Colors.orange` and drifting per screen.
class StatusColors {
  const StatusColors._();

  /// approved, done, posted, won, paid, planned
  static const Color green = Color(0xFF00A63E);

  /// sent, qualified, in-progress/proposal
  static const Color blue = Color(0xFF3B82F6);

  /// draft
  static const Color orange = Color(0xFFF97316);

  /// cancelled, lost
  static const Color red = Color(0xFFEF4444);

  /// locked/done (secondary "complete" state)
  static const Color teal = Color(0xFF14B8A6);

  /// unknown/default fallback
  static const Color grey = Color(0xFF6B7280);

  // --- Tinted icon/background pairs (§16) --------------------------------
  static const Color infoIcon = Color(0xFF60A5FA);
  static const Color successIcon = Color(0xFF4ADE80);
  static const Color warningIcon = Color(0xFFFBBF24);
  static const Color errorIcon = Color(0xFFF87171);

  static Color iconBackground(Color color) => color.withValues(alpha: 0.12);

  static Color backgroundLight(Color color) => color.withValues(alpha: 0.12);
  static Color backgroundDark(Color color) => color.withValues(alpha: 0.2);

  /// Resolves an Odoo `state` / `payment_state` value to its semantic colour.
  static Color forState(String? state) {
    switch (state?.toLowerCase().trim()) {
      case 'posted':
      case 'paid':
      case 'reconciled':
      case 'done':
      case 'approved':
        return green;
      case 'draft':
      case 'partial':
      case 'partially_paid':
        return orange;
      case 'cancel':
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'not_paid':
      case 'unpaid':
        return red;
      case 'sent':
      case 'in_payment':
      case 'in payment':
      case 'in_progress':
      case 'in_process':
        return blue;
      case 'locked':
        return teal;
      default:
        return grey;
    }
  }

  /// §10 — the canonical status badge. No border; tint comes from [color].
  static Widget buildStatusBadge(
    String label,
    Color color, {
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
