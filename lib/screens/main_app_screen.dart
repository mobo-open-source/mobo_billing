import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_billing/screens/payment/create_payment_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobo_billing/providers/profile_provider.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import 'package:mobo_billing/screens/dashboard/dashboard_screen.dart';
import 'package:mobo_billing/screens/Invoice/invoice_list_screen_new.dart';
import 'package:mobo_billing/providers/auth_provider.dart';
import 'package:mobo_billing/widgets/profile_avatar_widget.dart';
import 'package:mobo_billing/screens/CreditNotes/credit_notes_screen.dart';
import 'package:mobo_billing/screens/Invoice/create_invoice_screen.dart';
import 'package:mobo_billing/screens/payment/payment_records_screen.dart';
import 'package:mobo_billing/screens/reports/reports_dashboard_screen.dart';
import 'package:mobo_billing/providers/navigation_provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter/services.dart';
import 'CreditNotes/create_credit_note_screen.dart';
import 'customers/customer_form_screen.dart';
import '../widgets/company_selector_widget.dart';
import '../providers/company_provider.dart';
import '../services/review_service.dart';
import '../widgets/lazy_load_indexed_stack.dart';
import '../widgets/app_side_rail.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  /// The tabs, in [LazyLoadIndexedStack] order — shared by the bottom bar
  /// (portrait) and the side rail (landscape).
  static const List<AppNavTab> _tabs = [
    (icon: HugeIcons.strokeRoundedDashboardSquare02, label: 'Dashboard'),
    (icon: HugeIcons.strokeRoundedInvoice, label: 'Invoices'),
    (icon: HugeIcons.strokeRoundedInvoice01, label: 'Credit Notes'),
    (icon: HugeIcons.strokeRoundedWallet03, label: 'Payments'),
    (icon: HugeIcons.strokeRoundedAnalytics01, label: 'Reports'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Always open on the default Dashboard tab for a fresh login.
      Provider.of<NavigationProvider>(context, listen: false).reset();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshUserName();
      Provider.of<ProfileProvider>(context, listen: false).loadProfile();
      Provider.of<CompanyProvider>(context, listen: false).initialize();

      // Check for rating prompt after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          ReviewService().trackAppOpen();
          ReviewService().checkAndShowRating(context);
        }
      });
    });
  }

  void _onTabTapped(BuildContext context, int index) {
    Provider.of<NavigationProvider>(context, listen: false).selectTab(index);
  }

  String _getAppBarTitle(int currentIndex) {
    switch (currentIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Invoices';
      case 2:
        return 'Credit Notes';
      case 3:
        return 'Payment Records';
      case 4:
        return 'Reports & Analytics';
      default:
        return 'Dashboard';
    }
  }

  List<Widget> _getAppBarActions(bool isDark, int currentIndex) {
    switch (currentIndex) {
      case 0:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
      case 1:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
      case 2:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
      case 3:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
      case 4:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
      default:
        return [
          const CompanySelectorWidget(),
          const ProfileAvatarWidget(),
          const SizedBox(width: 6),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nav = Provider.of<NavigationProvider>(context);
    final currentIndex = nav.currentIndex;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != NavigationProvider.dashboardTab) {
          nav.selectTab(NavigationProvider.dashboardTab);
        }
      },
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          children: [
            if (isLandscape) ...[
              AppSideRail(
                tabs: _tabs,
                selectedIndex: currentIndex,
                onSelected: (i) => _onTabTapped(context, i),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : AppTheme.divider,
              ),
            ],
            // Keyed, and wrapped the same way in both orientations, so
            // rotating the device keeps the open tabs (their data and scroll
            // position) instead of rebuilding them as the rail comes and goes.
            Expanded(
              key: const ValueKey('main-content'),
              child: MediaQuery.removePadding(
                context: context,
                // The rail already keeps clear of a left-hand notch.
                removeLeft: isLandscape,
                child: _buildScaffold(
                  context,
                  isDark,
                  currentIndex,
                  isLandscape,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    bool isDark,
    int currentIndex,
    bool isLandscape,
  ) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text(
          _getAppBarTitle(currentIndex),
          style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        actions: _getAppBarActions(isDark, currentIndex),
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: LazyLoadIndexedStack(
        index: currentIndex,
        children: const [
          DashboardScreen(),
          InvoiceListScreenNew(),
          CreditNotesScreen(),
          PaymentRecordsScreen(),
          ReportsDashboardScreen(),
        ],
      ),
      floatingActionButton: currentIndex == 0
          ? SpeedDial(
              animatedIcon: AnimatedIcons.menu_close,
              animatedIconTheme: const IconThemeData(
                size: 22,
                color: Colors.white,
              ),
              spacing: 8,
              spaceBetweenChildren: 8,
              closeManually: false,
              useRotationAnimation: true,
              animationCurve: Curves.easeOutCubic,
              animationDuration: const Duration(milliseconds: 160),
              direction: SpeedDialDirection.up,
              onOpen: () => HapticFeedback.lightImpact(),
              onClose: () => HapticFeedback.selectionClick(),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              overlayColor: Colors.black,
              overlayOpacity: isDark ? 0.30 : 0.20,
              elevation: 0,
              tooltip: 'Quick Actions',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              childPadding: const EdgeInsets.all(6),
              childMargin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              heroTag: 'speed-dial-hero-tag',
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.payment, color: Colors.white),
                  backgroundColor: AppTheme.primaryColor,
                  label: 'Create Payment',
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  labelBackgroundColor: isDark
                      ? Colors.grey[850]
                      : Colors.white,
                  elevation: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreatePaymentScreen(),
                      ),
                    );
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.note_add, color: Colors.white),
                  backgroundColor: AppTheme.primaryColor,
                  label: 'Create Credit Note',
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  labelBackgroundColor: isDark
                      ? Colors.grey[850]
                      : Colors.white,
                  elevation: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateCreditNoteScreen(),
                      ),
                    );
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.person_add, color: Colors.white),
                  backgroundColor: AppTheme.primaryColor,
                  label: 'Create Customer',
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  labelBackgroundColor: isDark
                      ? Colors.grey[850]
                      : Colors.white,
                  elevation: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CustomerFormScreen(),
                      ),
                    );
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.receipt_long, color: Colors.white),
                  backgroundColor: AppTheme.primaryColor,
                  label: 'Create Invoice',
                  labelStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  labelBackgroundColor: isDark
                      ? Colors.grey[850]
                      : Colors.white,
                  elevation: 0,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateInvoiceScreen(),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      bottomNavigationBar: isLandscape
          ? null
          : Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return SnakeNavigationBar.color(
                  behaviour: SnakeBarBehaviour.pinned,
                  snakeShape: SnakeShape.indicator,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 0,
                  ),
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  selectedItemColor: AppTheme.primaryColor,
                  unselectedItemColor: isDark ? Colors.grey[300] : Colors.black,
                  showUnselectedLabels: true,
                  showSelectedLabels: true,
                  currentIndex: currentIndex,
                  onTap: (i) => _onTabTapped(context, i),
                  snakeViewColor: AppTheme.primaryColor,
                  elevation: 8,
                  height: 70,
                  items: [
                    for (final tab in _tabs)
                      BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: HugeIcon(icon: tab.icon),
                        ),
                        label: tab.label,
                        activeIcon: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: HugeIcon(
                            icon: tab.icon,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                  ],
                  selectedLabelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                    overflow: TextOverflow.ellipsis,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    overflow: TextOverflow.ellipsis,
                  ),
                  shadowColor: isDark ? Colors.black26 : Colors.grey[200]!,
                );
              },
            ),
    );
  }
}
