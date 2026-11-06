# Mobo UI Updates — Porting Guide (from mobo_billing)

Every UI change made in **mobo_billing** beyond the base Mobo style guide (`CLAUDE.md`), written
so another Mobo app (CRM, Inventory, Employee, …) can be brought to the same design.

- **Source app:** `mobo_billing` (Flutter, Odoo-backed), branch `development`.
- **State (2026-10-28):** all changes are uncommitted in the working tree. They were checked with
  IDE diagnostics only. Nothing was run on a device, and the unit tests that come with them were
  never run, because the shell had no Flutter SDK. Run the tests and check every changed screen on
  a device after porting.
- **Two passes:**
  1. **Components and layout** — pagination, filter sheet, pinned save bar, dialogs, dashboard,
     reports, settings. Most of it copies the **CRM app** (`mobo_CRM`).
  2. **Dark mode matches light mode** — anything Mobo-coloured in light mode is Mobo in dark mode
     too, status badges keep their colours, form fields get a visible outline, and the dark filter
     controls were restyled (§2).
- **Style guide:** `CLAUDE.md` still applies. §1.2 lists every place these updates deliberately
  differ from it.
- **(from CRM)** marks a change copied from the CRM app. When porting *into* the CRM app, skip it;
  it is already there.

---

## 0. How to port (order that avoids compile errors)

1. **Tokens** (§1): add them to the app's `app_theme.dart` and `form_styles.dart`.
2. **Shared widgets** (§3): copy the new files, then apply the changes to existing shared widgets.
3. **Dark-mode pass** (§2): an app-wide search-and-replace, then a manual check of what sits on
   Mobo fills.
4. **Per-area changes** (§4–§11), screen by screen. Each item says what to look for and what
   "done" looks like.
5. **Behaviour traps** (§12): these are bugs found during the UI work, not styling.
6. **Checklist** (§14).

Names below are billing's. Another app's screens will be named differently (invoice list →
quotation list, create invoice → quotation form, and so on), so find the equivalent by what it
does, not by file name.

---

## 1. Design tokens

### 1.1 Additions to `lib/theme/app_theme.dart`

```dart
class AppTheme {
  // --- Filter controls (§2.4, §5) ----------------------------------------

  /// Light Mobo wash — primary at 8%.
  static const Color primaryTint = Color(0x14C03355);

  /// primaryTint laid over white (≈ #FAEFF2) — light-mode fill of the filter
  /// option chips, Active Filters chips and date fields. Opaque on purpose (§12.5).
  static final Color primaryTintSolid = Color.alphaBlend(primaryTint, white);

  /// Dark mode, option at rest (unselected chip, empty date): neutral grey box.
  static final Color darkOptionFill = Colors.grey[700]!;
  static final Color darkOptionBorder = Colors.grey[600]!;

  /// Dark mode, active (Active Filters chip, picked date): deep Mobo box
  /// (≈ #4F242E) with Mobo text lightened to stay readable on it (≈ #D66681).
  static final Color darkActiveFill = Color.alphaBlend(
    primaryColor.withValues(alpha: 0.3),
    darkSurface, // #1E1E1E
  );
  static final Color darkActiveBorder = primaryColor.withValues(alpha: 0.6);
  static final Color darkActiveText = HSLColor.fromColor(
    primaryColor,
  ).withLightness(0.62).toColor();

  // --- Buttons (§6.2) ------------------------------------------------------

  /// Inactive submit button fill (light mode). Dark mode keeps grey[700].
  static const Color disabledButtonFill = Color(0xFFBDBDBD);

  /// Label + icon on an inactive submit button, both themes.
  static const Color disabledButtonText = Color(0xFFFFFFFF);

  // --- Checkbox (§6.6) -----------------------------------------------------

  /// Mobo outline; Mobo fill + white tick when ticked. Both themes.
  static final CheckboxThemeData checkboxTheme = CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? primaryColor
          : Colors.transparent,
    ),
    checkColor: WidgetStateProperty.all(white),
    side: WidgetStateBorderSide.resolveWith(
      (states) => const BorderSide(color: primaryColor, width: 2),
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );
}

class AppSpacing {
  const AppSpacing._();

  /// Bottom padding of a list with a floating button over it:
  /// 56px button + 16px margin + 16px gap.
  static const double fabClearance = 88;
}
```

- Set `checkboxTheme: checkboxTheme` in **both** the light and the dark `ThemeData`.
- In the dark `ThemeData`, set `bottomNavigationBarTheme.selectedItemColor: primaryColor` (§2.1).
- Change `StatusColors.buildStatusBadge` as described in §2.2.
- Gotcha: any screen that writes `const EdgeInsets.fromLTRB(16, 4, 16, AppSpacing.fabClearance)`
  must `import '../../theme/app_theme.dart'`. A missing import shows up as the misleading error
  "Not a constant expression".

### 1.2 Additions to `lib/theme/form_styles.dart` (`AppFormTheme`)

```dart
/// Outline of a field at rest. Light mode needs none — the grey fill stands
/// out on the white card — but the dark fill is the dark card's own colour,
/// so there a field would vanish without one.
static Color restingBorderColor(bool isDark) =>
    isDark ? Colors.grey[700]! : Colors.transparent;

static BorderSide restingBorderSide(bool isDark) =>
    isDark ? BorderSide(color: restingBorderColor(isDark)) : BorderSide.none;
```

Used by `inputDecoration`'s `border`, `enabledBorder` and a new `disabledBorder`, and by every
container-built field (§2.3).

### 1.3 Where these updates override `CLAUDE.md`

| `CLAUDE.md` says | mobo_billing now does | Why |
|---|---|---|
| §5 disabled button: fill `grey[300]`, text `grey[500]` (light) | fill `#BDBDBD`, **white** text (`disabledButtonFill` / `disabledButtonText`); dark keeps `grey[700]` fill | requested |
| §5 button radius 12 | company-selection sheet buttons use radius 8 | copies the CRM sheet |
| §6 quantity field: "not a +/− stepper" | the invoice form's quantity has **−/+ buttons inside the field** (`LineQuantityInput(showStepper: true)`); the credit-note form is still plain | requested |
| §6 text field: transparent border | dark mode: 1px `grey[700]` outline at rest; light unchanged | dark fields were invisible on dark cards |
| §10 status badge, dark: white text on white @ 15% | the **status colour in both themes** (text in the colour, 12% tint behind) | a state should read the same in both themes |
| §13 bottom nav selected icon/label: `isDark ? white : primary` | **primary in both themes** | dark mode should match light |
| any `isDark ? Colors.white : primary` in a recipe | primary in both themes (§2.1) | same |

`CLAUDE.md` doesn't cover these, and they are now billing's convention:

- themed checkbox (§1.1)
- filter chip and date-field tints, light and dark (§2.4)
- pinned save bar (§6.1)
- 238×144 Business Overview card (§9.3)
- 88px FAB clearance
- Mobo-shade pie chart (§10)

`CLAUDE.md` itself was **not** edited, because it is copied into every Mobo project. To make
these the default everywhere, update §5, §6, §10 and §13 there deliberately.

### 1.4 Existing tokens these changes rely on

- `StatusColors`, with `forState` and `buildStatusBadge`
- `AppShadows.card` / `cardShadow` / `panelShadow`
- `AppRadius.badge` (18) / `AppRadius.segment` (10)
- `AppFormTheme` in `form_styles.dart`

Per `CLAUDE.md` §0/§1/§3/§4/§10 these already exist in a standard Mobo app.

---

## 2. Dark mode — same colours as light mode

**Rule:** dark mode changes only the surfaces and the neutral text. Anything Mobo-coloured
(`#C03355`) in light mode stays Mobo in dark mode, and status colours stay status colours. Many
widgets used to switch Mobo to white in dark mode. That is gone.

### 2.1 Mobo stays Mobo

What changed in billing:

| Where | Dark mode now |
|---|---|
| Add FABs on every list (invoices, credit notes, payments, customers, products) | Mobo fill, **white** icon |
| Dashboard SpeedDial (`main_app_screen.dart`) and its 4 child buttons | Mobo fill, white icon/foreground |
| Bottom nav (selected icon, `activeIcon`, selected label) | Mobo (was white) |
| List-screen header text that is Mobo in light mode (e.g. invoice list) | Mobo |
| Invoice list card title (invoice number) | `AppTheme.primaryColor` in both themes. It was a hard-coded crimson `#B91C5C` in light mode and white in dark mode |
| Dashboard Recent Activity titles, Continue Working On names | Mobo |
| Company selector: Confirm button | Mobo fill, white text and spinner (was white with black text) |
| Company selector: selected row | Mobo @ 10% tint (was white @ 10%) |
| `MoboCheckbox` | Mobo outline/fill + white tick (was white fill + black tick); its `isDark` parameter is gone |
| Create-invoice totals box tint | Mobo tint |
| Reports: Overview amounts, Top Customers amounts | Mobo |
| Everything else the sweep below caught: side rail, quick actions, metric cards, data-loss dialog, full-image screen, location map, select-location, profile, list tiles, detail screens | Mobo |

**How to do it in another app:**

1. Search the whole `lib/` for a dark-white / light-Mobo ternary and replace the whole ternary with
   its primary half (billing: 49 replacements in 29 files):
   ```
   \b(isDark|isDarkMode)\s*\?\s*Colors\.white\s*:\s*(AppTheme\.primaryColor|primaryColor|theme\.primaryColor|Theme\.of\(context\)\.primaryColor|theme\.colorScheme\.primary|Theme\.of\(context\)\.colorScheme\.primary|colorScheme\.primary|primary)\b(?!\.with)
   ```
2. Do the same for tints: `isDark ? Colors.white.withValues(alpha: a) : primary.withValues(alpha: b)`
   → keep the primary half (selected rows, totals box).
3. Look for hard-coded Mobo look-alikes with a dark branch (`Color(0xFFB91C5C)`,
   `Color(0xFFC03355)`), and for nested ternaries the regex misses (billing's
   `profile_details_screen.dart` was fixed by hand).
4. **Then fix what sits on top of a Mobo fill.** After the swap, an icon or label that was
   `isDark ? Colors.black : Colors.white` is now black on Mobo. Search
   `isDark ? Colors.black… : Colors.white` and make each one on a Mobo fill plain white. In billing
   these were the FAB icons, the SpeedDial, the Confirm button's text and spinner, and the
   checkbox tick.
5. Delete the `isDark` locals and parameters left unused; the IDE flags them.

**Kept neutral on purpose:** body text, values, neutral icons, legend labels, the Top Customers
rank and name (white in dark mode, `#101010` in light mode).

### 2.2 Status badges

- `StatusColors.buildStatusBadge` no longer has a dark variant. It always renders `color @ 12%`
  behind 11px w600 text in `color`, radius 18, no border. The `isDark` parameter is kept, and
  ignored, so callers don't change.
- The hand-built badges on payment detail and payment records follow the same rule: status colour
  in both themes.
- Result: Draft orange, Posted/Paid green, In Payment blue, Cancelled red, in either theme.

### 2.3 Form field outline

- **Problem:** in dark mode the field fill (`grey[850]`) equals the form card's fill, and the border
  was transparent, so fields disappeared.
- **Fix:** a 1px `grey[700]` outline at rest in dark mode (`AppFormTheme.restingBorderSide`, §1.2).
  The focus ring stays Mobo 2px and errors stay red. Light mode is unchanged.

| Widget | Change |
|---|---|
| `AppFormTheme.inputDecoration` | `border`, `enabledBorder`, new `disabledBorder` → `restingBorderSide` |
| `MoboDateField` | `Border.all(restingBorderColor)`; padding 14 → **13** vertical, gutter → **gutter − 1** horizontal (§12.6) |
| `CurrencySelectField` | rest: 1px resting border, padding 13 / gutter + 1; open: 2px Mobo, padding 12 / gutter, so the box never changes size |
| `MoboSearchField` | field: 1px resting, 2px Mobo when focused, on a `DecoratedBox`, so it doesn't shift; filter button: `Material(shape: RoundedRectangleBorder(side: restingBorderSide))` |
| `CustomTextField` (simple) | `border` / `enabledBorder` use `restingBorderSide` when `showBorder` is false |
| `LineQuantityInput` / `LinePriceInput` | the shared `_lineNumberDecoration` uses `restingBorderSide` |

This covers the customer, product, invoice, payment and credit-note forms and the payment-records
search.

### 2.4 Filter sheet controls

| Control | Light | Dark |
|---|---|---|
| Option chip, unselected | `primaryTintSolid` fill, `grey[300]` outline, black87 w400 | `darkOptionFill`, `darkOptionBorder` outline, **white w600** |
| Option chip, selected | Mobo fill and outline, white w600 | same |
| "Active Filters" heading | Mobo | Mobo |
| Active Filters chip | `primaryTintSolid`, Mobo @ 30% outline, Mobo text, black54 × | `darkActiveFill`, `darkActiveBorder`, `darkActiveText` text and × |
| Date field, empty | `primaryTintSolid`, `grey[300]` outline, `grey[600]` icon/text | `darkOptionFill`, `darkOptionBorder`, white70 icon/text |
| Date field, picked | `primaryTintSolid`, Mobo @ 30% outline, Mobo icon/text (w500), grey × | `darkActiveFill`, `darkActiveBorder`, `darkActiveText` icon/text/× |
| Date range reversed | red outline + message under the fields | same |
| Tab switch, Clear All / Apply | Mobo | Mobo |

A picked date looks like an Active Filters chip on purpose: both show that a filter is on.
`darkActiveText` is a lighter Mobo because full-strength `#C03355` is hard to read on the deep
Mobo fill. All fills are opaque (§12.5).

---

## 3. Shared widgets

### 3.1 New files — copy as-is, then adjust the imports

| File | What it is | API |
|---|---|---|
| `widgets/pinned_action_bar.dart` | Fixed footer for a form's Save/Create button | `PinnedActionBar(child:)` as `Scaffold.bottomNavigationBar`. White/dark surface, soft top shadow (`black @ 8%`, blur 8, offset `(0,-2)`), `SafeArea(top:false)`, padding `16,12,16,16` |
| `widgets/pagination_bar.dart` | Record count + prev/next arrows | `PaginationBar(totalCount, rangeText, hasPrevious, hasNext, onPrevious, onNext, showArrows = true, isLoading = false)` |
| `widgets/group_section_card.dart` | One collapsible group in a grouped list (CRM layout) | `GroupSectionCard(title, subtitle, isExpanded, onToggle, body, isLoading)` |
| `widgets/filter_sheet.dart` | Shared "Filter & Group By" sheet frame and parts | `FilterSheetShell`, `FilterTabBody`, `FilterSectionTitle`, `FilterChoiceChip`, `FilterActiveFilters`, `FilterActiveChip`, `FilterGroupByTab` (§5) |
| `widgets/date_range_filter_fields.dart` | From / To date fields for a filter sheet | `DateRangeFilterFields(startDate, endDate, onStartChanged, onEndChanged)` + `DateRangeFilterFields.isValid(start, end)` |
| `widgets/remove_product_dialog.dart` | "Remove Product" confirmation | `await confirmRemoveProduct(context, documentType: 'invoice', productName: name)` → `bool` |
| `widgets/mobo_checkbox.dart` | Rounded-square checkbox **(from CRM)** | `MoboCheckbox(value, onChanged, size = 22, radius = 6)`; a null `onChanged` locks it but it still looks ticked |

`filter_sheet.dart` and `date_range_filter_fields.dart` depend on the §1.1 filter tokens.

Key details worth keeping when you copy:

- **PaginationBar rules:**
  - No count when `totalCount == 0`.
  - No arrows when everything fits on one page, or when the list is grouped (`showArrows: false`).
  - On longer lists, an arrow that can't be used is **hidden but keeps its slot**
    (`Visibility(maintainSize: true, …)`), so a quick second tap never lands on the other arrow.
  - With neither a count nor an arrow, the bar returns `SizedBox.shrink()`.
  - Count pill: 13px w600, radius 20, grey fill and border, right-aligned.
  - Arrows: HugeIcons `strokeRoundedArrowLeft01/Right01`, size 20.
- **GroupSectionCard:**
  - Card: radius 12, margin-bottom 12, shadow `blur 16 / spread 2 / offset (0,6) / black @ 8%`,
    no border.
  - Header: padding 16, title 14 w600, count line 14 grey, up/down chevron.
  - Expanded: a 1px divider, then the rows inside **16px padding on every side**. That inset is
    what makes the nested cards narrower than the group card, as in the CRM.
- **confirmRemoveProduct:**
  - `AlertDialog`, radius 20, title "Remove Product" (w700).
  - Body: `Are you sure you want to remove "<name>" from this <documentType>?`
  - `actionsPadding: fromLTRB(24,0,24,24)`; two `Expanded` 48px buttons with a 12px gap: Cancel
    outlined (Mobo, 1.5px) and Remove filled Mobo.
- **MoboCheckbox:**
  - 2px Mobo outline; ticked = Mobo fill + white `check_rounded` (size × 0.75).
  - **Same in dark mode.**
  - 150ms animation; Mobo @ 10% hover tint on desktop.

### 3.2 Changes to existing shared widgets

| Widget | Change |
|---|---|
| `StatusColors.buildStatusBadge` | Status colour in both themes (§2.2) |
| `AppFormTheme.inputDecoration`, `MoboDateField`, `CurrencySelectField`, `MoboSearchField`, `CustomTextField` | Dark resting outline (§2.3) |
| `LineQuantityInput` | New `bool showStepper = false`: −/+ buttons inside the field (§6.4) |
| `MoboFormCard` | New optional `double? dividerHeight`. Null keeps the theme's 16px divider; pass `1` for the tight hairline the CRM forms use. Only the Edit/Register Payment form passes it |
| `MoboInlineDropdown` | New optional `ValueChanged<bool>? onOpenChanged`: `true` when the result panel opens, `false` when it closes. It also fires `false` (post-frame) if the field is disposed while open, so a parent mirroring the state is never left stuck on "open" |
| `MoboSubmitButton` | Inactive fill `AppTheme.disabledButtonFill` (light) / `grey[700]` (dark); inactive foreground `AppTheme.disabledButtonText` (white). Filled state unchanged (Mobo + white) |
| `CustomTextField` (simple) | New optional `String? prefix` (e.g. a currency symbol), rendered as a `prefixIcon` Text (16px, w600, grey) with `prefixIconConstraints` min 0. Unlike `prefixText`, it stays visible while the field is empty and unfocused |
| `EmptyStateWidget` | "Clear All Filters" button → outlined, `AppTheme.primaryColor` for **both** border (1.5px) and text, radius 12, height 48. It was a faded Material pink `#E91E63 @ 30%` |
| `DashboardMetricCard` | Optional `EdgeInsetsGeometry? margin`; new non-compact layout (§9.3). The compact layout (Reports) is separate |
| `confetti_dialog.dart` | Success dialog (§8.1) |

### 3.3 Unit tests to copy

- `test/unit_test/line_item_inputs_test.dart`: `pumpQuantity` takes `showStepper`, and a "with the
  stepper" group (5 tests) covers −/+ stepping, − disabled at 1, the floor at 1, and typing.
- `test/unit_test/date_range_filter_fields_test.dart`: "a picked date reads like an active filter
  chip" checks the Mobo text, the Mobo @ 30% outline, that an empty field differs, and that both use
  `primaryTintSolid`. It runs in light mode.

---

## 4. List screens (invoices, credit notes, payments, customers, products)

Apply to **every** paged list screen in the app.

1. **Pagination:** replace each screen's hand-built bar with `PaginationBar` (§3.1). Feed it the
   provider's `totalCount`, the formatted range (`startRecord-endRecord/totalCount`),
   `hasPreviousPage`, `hasNextPage`, and `showArrows: !isGrouped`.
2. **Space under the floating button:** the last card, including its amount, must be able to
   scroll clear of the FAB. Both the normal and the grouped list get
   `padding: EdgeInsets.fromLTRB(16, …, 16, AppSpacing.fabClearance)` (88px). Empty and loading
   states don't need it.
3. **Grouped lists:** build each group with `GroupSectionCard` (§3.1), with 12px between group
   cards.
4. **No results (filter or group-by active):**
   - Show the same ghost `EmptyStateWidget` as an empty plain list, with "No results found / Try
     adjusting your filters or group by" and the **Clear All Filters** button.
   - The button clears filters, date range **and** group-by together, plus the search box on
     invoices.
   - Before, payments and credit notes showed a folder icon with "No groups found" and no button,
     and invoices showed a blank list.
5. **FAB:** Mobo fill and white icon in both themes (§2.1).
6. **Card title:** Mobo in both themes; not a hard-coded crimson.
7. **Status badges:** one style everywhere (§4.1).

### 4.1 Status badges and colours (from CRM)

- **Badge:** `StatusColors.buildStatusBadge(label, color, isDark:)`. A pill: radius 18, padding
  10×4, 11px w600 text in the status colour on a **12% tint** of it, in both themes (§2.2), no
  border.
- **Colour:** from `StatusColors.forState(state)`:

  | State | Colour |
  |---|---|
  | posted / paid | green `#00A63E` |
  | draft / partial | orange `#F97316` |
  | sent / in-payment | blue `#3B82F6` |
  | cancelled | red `#EF4444` |
  | unknown | grey `#6B7280` |

- **Replace every hand-built badge:**
  - invoice list tile (Cancelled was grey, now red)
  - credit-note list (had its own badge; "Posted" showed orange, now green)
  - the top-right state badge on the invoice and credit-note detail screens (was a 15% tint, 13px
    text, different shape)
- **Payment corner ribbon** (PAID / PARTIAL / IN PAYMENT) on invoice and credit-note detail: keep
  the solid corner-flag shape, but take the colours from `StatusColors` instead of raw Material
  colours. Credit notes used purple for partial, which isn't in the Mobo set. A "reversed" payment
  state falls back to grey.

---

## 5. Filter & Group By sheet

Billing has **one** sheet frame, `FilterSheetShell`. The Invoice / Credit Note / Payment sheet
(`invoice_filter_bottomsheet.dart`) and the Customers and Products sheets all use it. The design is
the CRM's `filter_design_bottomsheet.dart` **(from CRM)**.

### 5.1 Frame

- 80% of screen height; background `grey.shade50` (dark `#1E1E1E`); top corners 16; drag handle
  at the top.
- Header "Filter & Group By" (18, w600) with a close icon, then a 2-tab switch (Filter / Group By).
  The selected tab is a flat Mobo pill, with no glow shadow and no ripple.
- Footer: a top divider, then **Clear All** (outlined) and **Apply** (filled). Equal widths, 48px,
  radius 12, Mobo in light **and** dark mode.
- **One 16px side inset** (`FilterSheetShell.inset`) is shared by the title, chips, date fields,
  section headings, Active Filters chips, Group By rows and footer. Everything starts and ends on
  the same line as the tab switch. An earlier version stacked two paddings (20 outside + 16
  inside), which pushed content about 36px in. Don't add inner padding back.

### 5.2 Parts

| Part | Spec |
|---|---|
| `FilterSectionTitle` | "Status", "Date Range" headings: 14px w600, `grey[600]` (dark `grey[400]`), 24 above / 12 below |
| `FilterChoiceChip` | Radius **8** (rounded square, not a pill), Manrope 13, no checkmark. Selected: solid Mobo with white w600 text. Unselected: see §2.4 |
| `FilterActiveFilters` | "Active Filters" heading (14 w600, Mobo in both themes), then a `Wrap(spacing: 8, runSpacing: 8)` of chips. Renders nothing when empty |
| `FilterActiveChip` | Radius 16, padding 12×6, 12px w500 label, 14px close icon. Colours in §2.4 |
| `FilterGroupByTab` | "None" row first, a divider, then one radio row per option with a description line (e.g. "Group by salesperson"). `loadingWhenEmpty: true` shows "Loading options…" until the options load (Customers/Products) |
| `DateRangeFilterFields` | A **fixed 44px** field, radius 8, a `Material` with an outline. Empty, it looks like an unselected option chip; picked, like an Active Filters chip (§2.4). Calendar icon 16, text 14 (w500 when picked), one line with ellipsis. The clear × is a compact 32px `InkResponse`. A start date after the end date turns both outlines red and shows "Start date cannot be after end date" |

Why the date field is fixed at 44px: a standard `IconButton` has a 48px minimum tap area, so the
field grew from about 46px to 72px once a date was picked.

### 5.3 Behaviour to keep

- Invoice / credit-note / payment sheets: **Clear All resets, applies and closes immediately.**
- Customers / Products sheets: Clear All only resets the choices; the user then taps Apply.
- Apply validates the range with `DateRangeFilterFields.isValid`. A reversed range shows a
  `CustomSnackbar` error instead of being applied.
- The invoice sheet's constructor didn't change, so the screens that open it needed no edits.
- Customers/Products build `FilterSheetShell(filterTab: …, groupByTab: FilterGroupByTab(…),
  onClear: …, onApply: …)` inside a `StatefulBuilder`.
- The old pill-chip widget (`filter_chip_button.dart`) is unused in billing now. Delete it in the
  other app if nothing else references it.

---

## 6. Form screens (create / edit)

### 6.1 Pinned Save/Create button

- Every form puts its button in `bottomNavigationBar: PinnedActionBar(child: _buildSaveButton(...))`:
  invoice, credit note, payment (Register/Edit), "Record Payment" from an invoice, customer and
  product.
- Forms that can show a loading or error screen instead of the form (credit note, invoice,
  payment) hide the bar while that screen is showing.
- Customer form:
  - Its "Scan Card" floating button sits just above the pinned bar.
  - The spacer at the end of the form is `SizedBox(height: isEditing ? 8 : AppSpacing.fabClearance)`.
- `payment_records_screen.dart` is only a list; it has no save button.

### 6.2 Inactive button

- Light: fill `AppTheme.disabledButtonFill` (`#BDBDBD`), with the label **and icon** in white
  (`AppTheme.disabledButtonText`). Dark: fill `grey[700]`, white label.
- Forms with their own button (product form, "Record Payment" in `payment_screen.dart`) set
  `backgroundColor`/`disabledBackgroundColor` and `disabledForegroundColor` to the same two
  tokens.
- Edit forms are already inactive until something changes, so this grey shows exactly there.
- White on `#BDBDBD` is low contrast, by request. If it's hard to read, darken the fill, not the
  text.

### 6.3 When the button becomes active

- **Register Payment** (`create_payment_screen.dart`):
  - Inactive until customer, amount > 0, journal and payment method are all set; when editing, it
    also needs a real change.
  - Before, typing a memo was enough to activate it.
- **Record Payment** (`payment_screen.dart`, from an invoice):
  - Inactive until journal, payment method and amount > 0 are set.
  - Choosing "Partial Amount" clears the amount, so the button stays inactive until one is typed.
  - "Amount greater than due" is still checked on tap.
- **Currency symbol:** amount fields show it via `CustomTextField(prefix: …)`, using the invoice's
  currency and falling back to the company's. The required star is red.

### 6.4 Product lines (invoice and credit note)

- **Card width:** the app theme gives every `Card` an 8px side margin, so the line cards were
  narrower than the search field and totals box. Set `margin: EdgeInsets.zero` on the line `Card`
  so all three line up. The gap between line cards is 12 (was about 20). Applies to invoice and
  credit note.
- **Quantity** (`LineQuantityInput`, shared by both forms):
  - A numeric box: height 44, centred text, radius 10 (`AppRadius.segment`), filled, Mobo cursor
    and focus ring, same look as the unit-price field.
  - Tapping selects the whole number; `onTapOutside` unfocuses.
  - If the field loses focus empty or at 0, it resets to `1`.
  - Whole numbers show without a decimal (`2`, not `2.0`).
- **Quantity stepper** (invoice form only: `showStepper: true`):
  - A − button at the left end and a + button at the right end, inside the field: `IconButton`s
    with `Icons.remove` / `Icons.add`, size 18, Mobo; disabled `grey[400]` (dark `grey[600]`).
  - Tap targets are 36×40. Content padding drops to 4 horizontal, because the buttons already pad
    the number off the edges.
  - Each tap steps by 1. − is disabled at 1 and never goes below 1 (− on 1.5 → 1). + on 2.5 →
    3.5.
  - Typing still works, and `onChanged` fires on each step.
  - The credit-note form leaves the default (no stepper). Pass `showStepper: true` there to match.
- **Remove product:**
  - On **both** forms, the trash icon opens `confirmRemoveProduct(...)`
    (`documentType: 'invoice'` / `'credit note'`).
  - The line is removed only on confirm. The old "… removed" warning toast is gone.
- **Customer picker (invoice):** the selected-customer card under the field hides while the picker
  is open and comes back when it closes, via `MoboInlineDropdown.onOpenChanged`.
- **Customer clear ×:**
  - Invoice: only the × on the selected-customer card, which also resets the delivery-address
    choice. There is no × on the field itself; it would duplicate the card's.
  - Credit note: an inline × next to the dropdown arrow once a customer is chosen. It clears the
    customer and the loaded shipping-address options; saving then shows "Please select a
    customer".
  - Payment: no ×. To change the customer, open the field and pick another.
  - The × on other fields (e.g. Payment Terms) is unchanged.
- **Spinner after create:**
  - The form's `isLoading` used to stay true until the success dialog was dismissed, so the Create
    button kept spinning behind the dialog.
  - Set `isLoading = false` **before** opening the dialog.
  - Done on the invoice form. The payment and credit-note forms have the same pattern and were
    *not* changed (§13).

### 6.5 Payment forms (Edit / Register Payment, `create_payment_screen.dart`)

Sizes are copied from the CRM lead form **(from CRM)**:

- "Edit Payment" title weight → `w600` (was bold).
- Send / Receive radio labels 15/w600 → **14/w500**.
- Gaps between fields 16 → **10**. The divider under "Payment Details" becomes a 1px hairline via
  `MoboFormCard(dividerHeight: 1)`.
- Radio: ring and dot are Mobo when selected and grey when not (copied from the CRM radio).
- The save button is pinned (§6.1).
- The invoice and credit-note forms still use the bold app-bar title and the 16px divider. Aligning
  them was offered but not done.

### 6.6 Customer / product forms

- **Checkboxes** ("Is Company"; product "Active", "Can be Sold", "Can be Purchased"):
  - Remove the per-checkbox colour overrides and rely on the theme checkbox (§1.1).
  - Unticked = Mobo outline; ticked = Mobo fill + white tick, in both themes.
- **Photo placeholder** (customer form):
  - The big circle is **light grey with a grey image icon** (was a pink tint with a red icon).
  - The small add-photo badge is **solid Mobo with a white icon** in both themes (was plain grey
    in dark mode).
- **After saving an edit:** return to the details page and show a success toast (see the trap in
  §12.1):
  ```dart
  final navigator = Navigator.of(context);
  navigator.pop(true);
  CustomSnackbar.showSuccess(navigator.context, 'Customer updated successfully');
  ```
  - Customer create keeps its confetti dialog, then `Navigator.pop(context, true)`.
  - Product edit does the same pop-then-toast. Product create is unchanged.
- **Product details stays open after an edit** (`product_details_screen.dart`):
  - It used to `pop('updated')`, which dropped the user back on the list.
  - Now it sets `_wasEdited = true` and calls `await _loadProductDetails()` in place.
  - On leaving, by the app-bar back **or** the system back (`PopScope(canPop: !_wasEdited,
    onPopInvokedWithResult: …)`), it returns `'refresh'` if it was edited.
  - The list reloads on any non-null result and toasts only for `true` (archived) or `'updated'`.
    So `'refresh'` reloads silently, with no duplicate toast.

---

## 7. Detail screens

### 7.1 Edit button (invoice, credit note, payment, customer, product)

The same on all five: HugeIcons `strokeRoundedPencilEdit02` (pencil in a square), full size, in the
app bar next to the three-dot menu. Colour: grey 600 (light) / grey 400 (dark).

- Invoice, credit note and payment show it **only for drafts** (Odoo only edits drafts).
- Payment had no app-bar button before. The "Edit" entry was removed from its three-dot menu so it
  matches the others.
- The three-dot icon colour differs between screens (black vs grey) and was left alone.

### 7.2 Payment detail text sizes (from CRM `new_quotation_form.dart` header card)

| Element | Before | Now |
|---|---|---|
| Customer name | 18 | 15 |
| Amount value | 20 | 17 |
| Date value | 16 | 15 |
| "Amount" / "Date" labels | 14 | 13 |
| "Payment Information" heading | 16 | 15 |

- The payment number (20), status badge (13) and detail rows already matched.
- The **Payment Receipt** menu icon is now `HugeIcons.strokeRoundedPrinter`, replacing the solid
  `Icons.print`.

### 7.3 Confirm Invoice dialog alignment (`invoice_detail_screen.dart`)

- Before: the title and message sat 24px in from the dialog edge, but the Cancel/Confirm row was
  16px in, so it stuck out 8px on each side, with about 36px above it and 12px below.
- Now: the button row uses the same **24px side inset**, with **24px above and below**.
- The Cancel, Delete, Duplicate and Reset-to-Draft dialogs in that file still have the old padding
  (§13).

---

## 8. Dialogs and sheets

### 8.1 Success dialog (`confetti_dialog.dart`, shared)

- One change covers Invoice Created, Credit Note Created, Payment Registered, Customer Created and
  Invoice Sent.
- The document name is **plain green text** (`StatusColors.green`). The tinted, bordered box around
  it is gone.
- The "Perfect!" button and its `buttonText` parameter are gone.
- A **close X at the top right** (`Positioned`) closes the dialog and stops the confetti. The flow
  then continues as before (e.g. to the detail screen).
- Tapping outside still doesn't dismiss it.
- Padding `(28, 44, 28, 32)` leaves room under the X; min height 240.

### 8.2 Company selection bottom sheet (`company_selector_widget.dart`) **(from CRM)**

- `MoboCheckbox` replaces the stock checkbox. The active company stays ticked and locked.
- Rows: 6px vertical padding outside + 10px inside, 13px text. The selected row is tinted
  **Mobo @ 10%** in both themes.
- Max sheet height 480 (was 350).
- Buttons are 48px tall, radius 8:
  - Reset: 1.2px outline, 16px text.
  - Confirm: 13px text, **Mobo fill with white text and spinner in both themes**.
- Billing-specific behaviour kept: Reset only resets the selection and doesn't close the sheet;
  switching company still uses the allowed-companies logic and data refresh.

---

## 9. Dashboard

### 9.1 Layout and spacing

- **Bottom spacer:** 100 → **64**. The nav bar is outside the scroll area, so 64 plus the 16px
  screen padding just clears the floating quick-actions button.
- **Business Overview left alignment:**
  - The heading had 4px of extra padding that no other heading has; removed.
  - Each card had an 8px margin on every side, which pushed the first card in. The row now passes
    `margin: EdgeInsets.only(top: 8, bottom: 8, right: 16)`, so the first card is flush with the
    greeting card and Quick Navigation.
  - The scrolling row starts exactly at the edge, so the first card's left shadow may be slightly
    trimmed.
- **Bottom nav and SpeedDial:** the selected tab and the SpeedDial are Mobo in both themes (§2.1).

### 9.2 Recent Activity

- **Tab switch animation** (Recent Payments / Recent Invoices):
  - `AnimatedSwitcher`, 300ms, `easeOutCubic` in / `easeInCubic` out.
  - `FadeTransition` + `SlideTransition` of **0.08 × width**: the incoming list enters from the
    side of the tapped tab, and the outgoing one leaves the other way. Track `_tabDirection` (±1)
    from the tapped tab.
  - Wrap each list in `KeyedSubtree(key: ValueKey(_activeTab))`.
  - Use a `layoutBuilder` that returns a top-aligned `Stack` with `clipBehavior: Clip.none`, so
    lists of different heights don't jump and shadows aren't clipped.
- **Titles:** payment and invoice names in Recent Activity, and item names in Continue Working On,
  are Mobo `#C03355`, size 15, **in both themes**.
- **Shading:**
  - All three card types (payment, invoice, Continue Working On) use the same card shadow as the
    Quick Navigation cards.
  - Invoice cards match payment cards: same padding, radius 12, 12px separator.
  - The lists use `clipBehavior: Clip.none` so shadows aren't cut off at the edges.

### 9.3 Business Overview card (`DashboardMetricCard`, non-compact)

| Property | Value |
|---|---|
| Size | width **238** (fixed `minWidth = maxWidth`), about 144 tall inside a row of `SizedBox(height: 160)` |
| Shape | radius **18**, padding **20**, white / `grey[850]` fill, soft shadow (blur 4, spread 2, offset (0,2), black @ 5%) |
| Title | 13px, w500, `grey[600]` (dark `grey[300]`); an optional 12px arrow when tappable |
| Amount | 24px, **w500**, letterSpacing −0.5, `grey[900]` / white, inside `FittedBox(scaleDown, centerLeft)` so long amounts shrink instead of being cut off |
| "≈" prefix | 18px, w400, grey |
| Caption | 11px, w400, `grey[500]` / `[400]`, one line, ellipsis |
| Accent bar | 3 × 40, radius 2, bottom-left (only when `accentColor != null`) |
| Spacing | title at the top, amount + caption grouped in the middle, bar at the bottom (`spaceBetween`) |

The next card peeks in at the right edge. The compact layout (Reports) is unchanged. Don't go
narrower: at 144 wide the cards looked cramped.

---

## 10. Reports tab

- **Date capsules** ("Last 7 / 30 / 90 Days / This Year") are **pinned** in a fixed bar at the top,
  and the report scrolls beneath them. Pull-to-refresh, the loading state and the offline banner
  are inside the scrolling area, so the offline banner now sits under the capsules.
- **Overview amounts** (Total Invoiced, Total Paid, Due Amount, Invoices): Mobo in both themes. This
  applies to the compact cards only; the dashboard's Business Overview cards use the larger layout.
- **Top Customers:**
  - Rank ("1.", "2.") and name: 14 w500, `AppTheme.textPrimary` (`#101010`), white in dark mode.
  - Amount: 14 w600, **Mobo in both themes**.
- **Invoice Status pie:** only shades of Mobo, no other colours. Each status is Mobo at a set
  strength, blended into white so it is opaque and the light shades stay light on the dark card:

  | Status | Strength | Colour |
  |---|---|---|
  | Paid | 100% | `#C03355` |
  | In Payment | 70% | `#D37088` |
  | Partial | 50% | `#E099AA` |
  | Unpaid | 30% | `#ECC2CC` |
  | anything else | 15% | `#F6E0E6` |

  ```dart
  static const Map<String, double> _statusShades = {
    'Paid': 1.0, 'In Payment': 0.7, 'Partial': 0.5, 'Unpaid': 0.3,
  };
  double _statusShade(String status) => _statusShades[status] ?? 0.15;
  Color _getStatusColor(String status) => Color.alphaBlend(
    AppTheme.primaryColor.withValues(alpha: _statusShade(status)), Colors.white);
  ```
  - The percentage label on a slice is white when the shade is above 0.6 (Paid, In Payment) and
    `AppTheme.textPrimary` on the paler ones.
  - The legend dots use the same colours.
  - This applies to the chart only. List badges keep their `StatusColors`.
- **Loading bar:** the thin linear progress bar under the capsules is gone. First-load placeholders
  and the pull-to-refresh spinner stay. Changing the range while a report is showing gives no
  loading cue; add a subtler indicator if that feels too quiet.

---

## 11. Profile / Configuration, Switch Account, Settings

The reference is the CRM's **`configuration_screen.dart`**, not `profile_screen.dart`, which is the
CRM's profile editor **(from CRM)**.

**Profile / Configuration screen (`profile_screen.dart`)**
- Settings gear → HugeIcons `strokeRoundedSettings01`; Logout → `strokeRoundedLogout01`. Thin
  strokes replace the bold Material icons.
- The menu card uses the CRM colours, a hairline border and the card shadow; subtitles are 13px.
- Mobo accents stay Mobo in dark mode (§2.1).

**Switch Account (`switch_account_widget.dart`)**
- Row: the leading icon and subtitle are in the CRM grey, the title is regular black/white, and a
  standard chevron rotates and turns Mobo while open.
- Account tiles:
  - CRM colours and a 2px avatar ring.
  - A three-dot menu with a plain "Remove" (no red text, no bin icon).
  - Each tile still shows "login @ database" and the "Needs re-authentication" warning
    (billing-specific, kept).
- Empty state: a Mobo-tinted circle with an add-user icon and "No Other Accounts".
- Add Account button: 48px tall, bold 16px label.

**Settings (`settings_screen.dart`)**
- The About tiles had an extra 16px of side padding on top of each tile's own 16px. Their icons sat
  32px from the card edge, against 16px for Appearance and Language & Region.
- That extra padding is removed. The "Follow Us" divider, social icons and copyright line keep their
  own indent.

---

## 12. Behaviour traps found during the UI work

### 12.1 `CustomSnackbar` + `Navigator.pop`

`CustomSnackbar` is a `showDialog` route that dismisses itself after about 3s. Showing it and then
calling `Navigator.pop(context)` closes **the toast**, not the screen. The form stays open and the
toast vanishes instantly. Use this pattern wherever a screen closes and the previous screen should
show a toast:

```dart
final navigator = Navigator.of(context);
navigator.pop(result);
CustomSnackbar.showSuccess(navigator.context, 'Saved successfully');
```

`Navigator.of(context)` special-cases a `NavigatorState` context, so `navigator.context` stays
valid after the pop. Search the other app for `showSuccess(` followed by `Navigator.pop(`.

### 12.2 Loading flag stuck behind a dialog

Awaiting a success dialog before clearing `isLoading` leaves the Create button spinning behind it.
Clear the flag first.

### 12.3 `Card` side margins

The app-wide `CardTheme` gives every `Card` an 8px side margin. Anything that must line up with the
full-width widgets around it needs `margin: EdgeInsets.zero`.

### 12.4 Horizontal list heights

A horizontal `ListView` gives each child a tight height equal to the viewport. A `Container` with
`constraints` applies them **inside** its `margin`, so the card height is the row height minus the
vertical margin (row 160 − 16 = 144).

### 12.5 Translucent fills on chips look light in dark mode

The dark theme is built as `lightTheme.copyWith(...)` and doesn't override `canvasColor`. A Material
3 `ChoiceChip` paints its `backgroundColor` over that light canvas, so a translucent fill (e.g. 8%
Mobo) comes out as a light, glowing box on a dark sheet.

Use **opaque** fills, pre-blended with `Color.alphaBlend(tint, base)`. That is why
`primaryTintSolid`, `darkActiveFill` and the pie shades are blended rather than given
`withValues(alpha:)`. The same applies to any surface with a light canvas under it.

### 12.6 A `Container` border changes the size

Giving a `Container` a border pads its child by the border width, even when the border is
transparent.

- **Container-built fields:** when you add the 1px dark outline, take 1px off the padding on each
  side, or the field grows by 2px and no longer lines up with the `InputDecoration` fields beside
  it (`MoboDateField`, `CurrencySelectField`).
- **A border that changes width:** if the border goes 1 → 2px (rest → focus), change the padding
  with it.
- **No layout effect needed:** draw the border on a `DecoratedBox` (`MoboSearchField`); it doesn't
  affect layout.

### 12.7 Black-on-Mobo after the dark-mode swap

Switching a dark-mode fill from white to Mobo (§2.1) leaves the icon or label on it black, because
it was written as `isDark ? black : white` to contrast with the white fill. Check every swapped fill
for what is drawn on top of it.

### 12.8 Bottom sheets with no background are see-through

The theme's `bottomSheetTheme.backgroundColor` is `Colors.transparent` (`CLAUDE.md` §19 expects
each sheet to supply its own surface). A `showModalBottomSheet` that sets neither `backgroundColor`
nor an inner coloured `Container` shows its options floating over the screen behind it. Billing's
customer-form **Scan Card** sheet had this bug. It now passes
`backgroundColor: isDark ? AppTheme.darkSurface : Colors.grey[50]`.

Its labels also need an explicit colour (`isDark ? Colors.white : Colors.black87`). The dark theme
inherits the light `textTheme` (`#101010`), so unstyled text is invisible on a dark sheet.

Search the other app for `showModalBottomSheet(` calls that have no `backgroundColor`.

Related: run follow-up work (permission prompts, dialogs) on the **screen's** context, not the
sheet builder's. The sheet is popped first, so prompts shown on its context never appear.

---

## 13. Left alone / still to do

**Bugs**
- The success-dialog spinner bug on the **payment** and **credit-note** forms (same pattern as
  §12.2).
- Product create still has its own delayed toast in the form. If two toasts ever appear after
  creating a product, remove that one; the list already shows "Product created successfully".

**Inconsistent styling**
- Duplicate (`Icons.copy`) and Reset-to-Draft (`Icons.settings_backup_restore`) on payment detail
  are still solid Material icons.
- The Cancel / Delete / Duplicate / Reset-to-Draft dialogs on invoice detail still have the old
  button padding (§7.3).
- The invoice and credit-note forms still use the bold app-bar title and the 16px divider (§6.5).
- The three-dot icon colour is inconsistent across detail screens.
- The credit-note quantity field has no stepper (§6.4).

**Raw colours and hand-built badges**
- `customer_list_tile.dart` Company/Customer badge:
  - It uses raw `Colors.blue` / `Colors.green`.
  - It still goes white in dark mode.
  - It should move to `StatusColors` + `buildStatusBadge`.
- The payment detail and payment records badges are hand-built. Their colours are right in both
  themes, but they don't use `buildStatusBadge`.

**Dead code and shared-widget scope**
- `_buildActiveFiltersChips` in `invoice_list_screen_new.dart` is never referenced.
- `filter_chip_button.dart` is unused in billing.
- The success-dialog X applies to **all** success dialogs, because the widget is shared. If only one
  should change, the widget needs a flag.

**Style guide**
- `CLAUDE.md` §5, §6, §10 and §13 still describe the old behaviour (§1.3).

---

## 14. Porting checklist

**Tokens and shared code**
- [ ] `primaryTint`, `primaryTintSolid`, `darkOption*`, `darkActive*`, `disabledButtonFill`,
  `disabledButtonText`, `checkboxTheme` (both themes), `AppSpacing.fabClearance` added
- [ ] Dark theme: bottom-nav `selectedItemColor: primaryColor`
- [ ] `AppFormTheme.restingBorderColor` / `restingBorderSide` added and used in `inputDecoration`
  (incl. `disabledBorder`)
- [ ] `buildStatusBadge` uses the status colour in both themes
- [ ] `pinned_action_bar`, `pagination_bar`, `group_section_card`, `filter_sheet`,
  `date_range_filter_fields`, `remove_product_dialog`, `mobo_checkbox` copied and imports fixed
- [ ] `MoboFormCard.dividerHeight`, `MoboInlineDropdown.onOpenChanged`, `MoboSubmitButton` colours,
  `CustomTextField.prefix`, `LineQuantityInput.showStepper`, `EmptyStateWidget` button,
  `DashboardMetricCard.margin` applied
- [ ] Unit tests from §3.3 copied

**Dark mode**
- [ ] `isDark ? Colors.white : primary` sweep done (plus tint variants and hard-coded Mobo hexes)
- [ ] Everything drawn on a Mobo fill is white (FAB icons, SpeedDial, buttons, checkbox tick)
- [ ] Fields visible in dark mode: text, dropdown, date, currency, search, quantity/price
- [ ] Filter chips, Active Filters chips and date fields match §2.4

**Lists**
- [ ] Every paged list uses `PaginationBar` (no count when empty, no arrows on one page, hidden
  arrows keep their slot)
- [ ] Every list has 88px of bottom clearance under its FAB (normal + grouped)
- [ ] Grouped lists use `GroupSectionCard`; filtered-empty / grouped-empty show the ghost screen
  with a Mobo-outlined Clear All Filters button
- [ ] Status badges use `StatusColors.buildStatusBadge` + `forState` in lists, details and ribbons
- [ ] Card titles are Mobo in both themes (no hard-coded crimson)

**Filter sheets**
- [ ] One shared frame, 16px inset, radius-8 chips, 44px date fields, Clear All / Apply both Mobo
- [ ] A picked date looks like an Active Filters chip (light and dark)

**Forms**
- [ ] Pinned save bar on every form; inactive = `#BDBDBD` fill + white text; gated on mandatory
  fields
- [ ] Currency symbol on amount fields
- [ ] Product line card `margin: zero`; numeric quantity (stepper on the invoice form);
  remove-product dialog on both forms
- [ ] Customer ×: card-only on invoice, inline on credit note, none on payment
- [ ] Checkboxes follow the theme (no per-widget overrides); photo placeholder grey with a Mobo badge
- [ ] Edit save: pop first, then toast on `navigator.context`; product details refreshes in place
  and returns `'refresh'`
- [ ] `isLoading` cleared before the success dialog opens

**Detail screens and dialogs**
- [ ] Edit pencil (`strokeRoundedPencilEdit02`, grey) on all five detail screens, draft-only where
  Odoo requires it
- [ ] Payment detail text sizes; printer stroke icon
- [ ] Confirm dialog buttons on the 24px inset
- [ ] Success dialog: green name text, X to close, no button
- [ ] Company selector sheet matches the CRM; Confirm is Mobo in dark mode

**Dashboard, Reports, Settings**
- [ ] Dashboard spacer 64; Recent Activity slide animation, Mobo titles (both themes) and card
  shadows; Business Overview flush left; 238×144 card
- [ ] Reports capsules pinned; Mobo amounts; Top Customers rank/name dark, amount Mobo; pie in Mobo
  shades; no linear loader
- [ ] Configuration icons and card, Switch Account row, Settings About alignment

**Verification**
- [ ] Hot restart succeeds ("Not a constant expression" means a missing `app_theme.dart` import)
- [ ] Unit tests pass
- [ ] Light **and** dark mode checked on every changed screen
- [ ] Filter sheet checked with a picked date in both themes (the field height must not change)
- [ ] Form fields visible in dark mode and the same height as before
- [ ] Edit customer/product: lands on the details page with the toast showing
- [ ] A one-page list shows no arrows; an empty list shows no count

---

## 15. Prompt to give Claude in the other app

> Read `UI_UPDATES_PORTING_GUIDE.md` from mobo_billing. Port these UI updates to this app: first
> the §1 tokens and §3 shared widgets, then the §2 dark-mode pass, then the screens in §4–§11 that
> exist here. Find equivalents by function, skip anything marked "(from CRM)" that this app already
> has, follow `CLAUDE.md` except where §1.3 of the guide overrides it, and check the traps in §12.
> Report which items you skipped and why.
