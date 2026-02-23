import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobo_billing/screens/payment/create_payment_screen.dart';
import 'package:provider/provider.dart';
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
import '../widgets/lazy_load_indexed_stack.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({Key? key}) : super(key: key);

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.refreshUserName();
      Provider.of<CompanyProvider>(context, listen: false).initialize();
    });
  }

  void _onTabTapped(BuildContext context, int index) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
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

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != 0) {
          nav.setIndex(0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Text(
            _getAppBarTitle(currentIndex),
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
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
                animatedIconTheme: IconThemeData(
                  size: 22,
                  color: isDark ? Colors.black : Colors.white,
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
                backgroundColor: isDark ? Colors.white : AppTheme.primaryColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
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
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : AppTheme.primaryColor,
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
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : AppTheme.primaryColor,
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
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : AppTheme.primaryColor,
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
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : AppTheme.primaryColor,
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
        bottomNavigationBar: Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return SnakeNavigationBar.color(
              behaviour: SnakeBarBehaviour.pinned,
              snakeShape: SnakeShape.indicator,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              selectedItemColor: isDark ? Colors.white : AppTheme.primaryColor,
              unselectedItemColor: isDark ? Colors.grey[300] : Colors.black,
              showUnselectedLabels: true,
              showSelectedLabels: true,
              currentIndex: currentIndex,
              onTap: (i) => _onTabTapped(context, i),
              snakeViewColor: AppTheme.primaryColor,
              elevation: 8,
              height: 70,
              items: [
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedDashboardSquare02,
                    ),
                  ),
                  label: 'Dashboard',
                  activeIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedDashboardSquare02,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedInvoice),
                  ),
                  label: 'Invoices',
                  activeIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedInvoice,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedInvoice01),
                  ),
                  label: 'Credit Notes',
                  activeIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedInvoice01,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedWallet03),
                  ),
                  label: 'Payments',
                  activeIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedWallet03,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
                BottomNavigationBarItem(
                  icon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(icon: HugeIcons.strokeRoundedAnalytics01),
                  ),
                  label: 'Reports',
                  activeIcon: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAnalytics01,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
              selectedLabelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.primaryColor,
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
      ),
    );
  }
}
