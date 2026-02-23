import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobo_billing/providers/invoice_provider.dart';
import 'package:mobo_billing/models/invoice.dart';
import 'package:mobo_billing/models/customer.dart';
import 'package:mobo_billing/models/payment.dart';
import 'package:mobo_billing/models/product.dart';
import 'package:mobo_billing/widgets/custom_snackbar.dart';
import 'package:mobo_billing/widgets/dashboard_charts.dart';
import 'package:mobo_billing/widgets/dashboard_metric_card.dart';
import 'package:mobo_billing/widgets/dashboard_quick_actions.dart';
import 'package:mobo_billing/widgets/dashboard_empty_state.dart';
import 'package:mobo_billing/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';
import 'package:mobo_billing/widgets/profile_avatar_widget.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import 'package:mobo_billing/providers/profile_provider.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'package:mobo_billing/screens/Invoice/invoice_detail_screen.dart';
import 'package:mobo_billing/screens/Invoice/invoice_list_screen_new.dart';
import 'package:mobo_billing/screens/customers/customers_screen.dart';
import 'package:mobo_billing/screens/customers/customer_details_screen.dart';
import 'package:mobo_billing/screens/CreditNotes/credit_note_detail_screen.dart';
import 'package:mobo_billing/screens/product/product_details_screen.dart';
import 'package:mobo_billing/screens/product/products_screen.dart';
import 'package:mobo_billing/screens/payment/payment_records_screen.dart';
import 'package:mobo_billing/services/connectivity_service.dart';
import 'package:mobo_billing/services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/shimmer_loading.dart';
import '../../providers/currency_provider.dart';
import '../CreditNotes/credit_notes_screen.dart';
import 'package:mobo_billing/screens/payment/payment_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {});
  }

  Future<void> _loadData() async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final profileProvider = context.read<ProfileProvider>();

    try {
      await Future.wait([
        invoiceProvider.loadDashboardData(),
        if (profileProvider.profile == null) profileProvider.loadProfile(),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException(
            'Dashboard loading timed out after 30 seconds',
          );
        },
      );
    } on TimeoutException catch (e) {
    } catch (e) {
      if (mounted && invoiceProvider.dashboardLoaded) {
        CustomSnackbar.showError(
          context,
          e.toString().contains('502')
              ? 'Server is temporarily unavailable (502). Showing cached data.'
              : 'Failed to refresh data: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<InvoiceProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final lastOpenedProvider = context.watch<LastOpenedProvider>();

    final isDataLoading =
        provider.isLoading ||
        profileProvider.isLoading ||
        lastOpenedProvider.isLoading;

    final isDataNotLoaded =
        (!provider.dashboardLoaded && provider.error == null) ||
        (profileProvider.profile == null && !profileProvider.hasError) ||
        !lastOpenedProvider.hasLoaded;

    return Consumer2<ConnectivityService, SessionService>(
      builder: (context, connectivityService, sessionService, child) {
        if (!connectivityService.isConnected) {
          return ConnectionStatusWidget(
            onRetry: _loadData,
            customMessage:
                'No internet connection. Please check your connection and try again.',
          );
        }

        if (!sessionService.hasValidSession) {
          return const ConnectionStatusWidget();
        }

        if (sessionService.isRefreshing) {
          return _buildLoadingState(isDark);
        }

        if (!provider.dashboardLoaded &&
            (sessionService.isServerUnreachable ||
                provider.isServerUnreachable)) {
          return ConnectionStatusWidget(
            serverUnreachable: true,
            serverErrorMessage:
                provider.error ??
                'Server is unreachable. Please check your connection and try again.',
            onRetry: _loadData,
          );
        }

        if ((provider.error != null && !provider.dashboardLoaded) ||
            (profileProvider.error != null &&
                profileProvider.profile == null)) {
          return _buildErrorState(
            provider.error ?? profileProvider.error ?? 'Unknown error',
          );
        }

        if (isDataNotLoaded) {
          return _buildLoadingState(isDark);
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: ResponsiveLayout.getScreenPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, profileProvider, isDark),
                      const SizedBox(height: 32),
                      _buildMetricsGrid(provider, isDark),
                      const SizedBox(height: 16),
                      _buildQuickNavigation(isDark),
                      const SizedBox(height: 16),
                      _buildQuickActions(provider, isDark),

                      _buildChartsSection(provider, isDark),
                      const SizedBox(height: 16),
                      _buildRecentActivity(provider, isDark),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              if (isDataLoading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProfileProvider profileProvider,
    bool isDark,
  ) {
    final profile = profileProvider.profile;
    final userName = profile?['name'] as String? ?? 'User';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(userName),
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your billing operations efficiently',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildUserAvatar(profile),
        ],
      ),
    );
  }

  String _getGreeting(String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    final firstName = userName.split(' ')[0];
    return '$greeting, $firstName!';
  }

  Widget _buildUserAvatar(Map<String, dynamic>? profile) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const ProfileAvatarWidget(radius: 28, iconSize: 24),
    );
  }

  Widget _buildMetricsGrid(InvoiceProvider provider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'Business Overview',
            style: TextStyle(
              fontSize: 18,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              DashboardMetricCard(
                title: 'Today\'s Sales',
                value: context.read<CurrencyProvider>().formatAmount(
                  provider.todaysSales,
                ),
                subtitle: 'Sales made today',
                accentColor: Colors.blue,
                isCompact: false,
              ),
              DashboardMetricCard(
                title: 'Total Revenue',
                value: context.read<CurrencyProvider>().formatAmount(
                  provider.totalRevenue,
                ),
                subtitle: 'All time revenue',
                accentColor: Colors.green,
                isCompact: false,
              ),
              DashboardMetricCard(
                title: 'Pending',
                value: context.read<CurrencyProvider>().formatAmount(
                  provider.pendingRevenue,
                ),
                subtitle: '${provider.pendingPaymentInvoices} invoices pending',
                accentColor: Colors.orange,
                isCompact: false,
              ),
              DashboardMetricCard(
                title: 'Overdue',
                value: context.read<CurrencyProvider>().formatAmount(
                  provider.overdueAmount,
                ),
                subtitle: '${provider.overdueInvoices} invoices overdue',
                accentColor: Colors.red,
                isCompact: false,
              ),
              DashboardMetricCard(
                title: 'Customers',
                value: '${provider.totalCustomers}',
                subtitle: 'Active customers',
                accentColor: Colors.blue,
                isCompact: false,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection(InvoiceProvider provider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue Overview',
          style: TextStyle(
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ResponsiveRow(
          forceColumn: true,
          children: [
            RevenueLineChart(
              revenueData: provider.dailyRevenueData,
              isDark: isDark,
              primaryColor: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity(InvoiceProvider provider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,

              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: EdgeInsets.zero,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: 0),
            labelColor: isDark ? Colors.black : Colors.white,
            unselectedLabelColor: isDark ? Colors.grey[300] : Colors.black54,
            labelStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            splashFactory: NoSplash.splashFactory,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Recent Payments'),
              Tab(text: 'Recent Invoices'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _tabController.index == 0
              ? KeyedSubtree(
                  key: const ValueKey('payments'),
                  child: _buildRecentPaymentsList(
                    provider.recentPayments,
                    isDark,
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('invoices'),
                  child: _buildRecentInvoicesList(
                    provider.recentInvoices,
                    isDark,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRecentPaymentsList(
    List<Map<String, dynamic>> payments,
    bool isDark,
  ) {
    if (payments.isEmpty) {
      return DashboardEmptyStateWidget(
        title: 'No recent payments',
        icon: HugeIcons.strokeRoundedMoneyBag02,
        isDark: isDark,
        height: 200,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: payments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final payment = payments[index];
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0.0;
        final rawPaymentDate = payment['payment_date'] ?? payment['date'];
        final date = rawPaymentDate is String ? rawPaymentDate : '';
        final partnerName =
            (payment['partner_id'] is List &&
                (payment['partner_id'] as List).length > 1)
            ? (payment['partner_id'] as List)[1] as String
            : 'Unknown Customer';

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PaymentDetailScreen(payment: Payment.fromJson(payment)),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),

              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black26
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getValidTitle(payment['name']?.toString()),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_getValidTitle(partnerName)} • $date',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  context.read<CurrencyProvider>().formatAmount(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentInvoicesList(List<Invoice> invoices, bool isDark) {
    if (invoices.isEmpty) {
      return DashboardEmptyStateWidget(
        title: 'No recent invoices',
        icon: HugeIcons.strokeRoundedInvoice01,
        isDark: isDark,
        height: 200,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invoices.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final amount = invoice.amountTotal;
        final date = invoice.invoiceDate != null
            ? invoice.invoiceDate!.toIso8601String().split('T')[0]
            : '';

        final partnerName = invoice.customerName;
        final state = invoice.state;

        Color stateColor = Colors.grey;
        if (state == 'posted') stateColor = Colors.green;
        if (state == 'cancel') stateColor = Colors.red;

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(
                  invoiceId: invoice.id,
                  invoice: invoice,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getValidTitle(invoice.name),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$partnerName • $date',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Consumer<CurrencyProvider>(
                  builder: (context, currencyProvider, _) {
                    final currencyCode = invoice.currencySymbol.isNotEmpty
                        ? invoice.currencySymbol
                        : null;

                    return Text(
                      currencyProvider.formatAmount(
                        amount,
                        currency: currencyCode,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickNavigation(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Navigation',
          style: TextStyle(
            fontSize: 18,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildNavigationTile(
          isDark: isDark,
          color: Colors.blue,
          icon: HugeIcons.strokeRoundedUserGroup,
          label: 'Customers',
          subtitle: 'Manage your contacts',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CustomersScreen()));
          },
        ),
        _buildNavigationTile(
          isDark: isDark,
          color: Colors.orange,
          icon: HugeIcons.strokeRoundedPackage,
          label: 'Products',
          subtitle: 'Manage products & services',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions(InvoiceProvider provider, bool isDark) {
    return Consumer<LastOpenedProvider>(
      builder: (context, lastOpenedProvider, child) {
        return ResponsiveRow(
          forceColumn: true,
          children: [
            RecentItemsWidget(
              recentItems: lastOpenedProvider.items
                  .map(
                    (item) => {
                      'type': item.type,
                      'name': _getValidTitle(item.title),
                      'subtitle': _getValidSubtitle(item.subtitle),
                      'lastModified': lastOpenedProvider.getTimeAgo(
                        item.lastAccessed,
                      ),
                      'icon': item.iconKey,
                      'onTap': () => _navigateToLastOpenedItem(item),
                    },
                  )
                  .toList(),
              isLoading: lastOpenedProvider.isLoading,
              isDark: isDark,
              onViewAll: () {},
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationTile({
    required bool isDark,
    required Color color,
    required List<List<dynamic>> icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? color.withOpacity(0.7)
                    : color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: HugeIcon(
                icon: icon,
                color: isDark ? Colors.white : color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLastOpenedItem(LastOpenedItem item) {
    try {
      switch (item.type) {
        case 'invoice':
          final data = item.data ?? {};
          final id =
              data['id'] ??
              (item.id.startsWith('invoice_')
                  ? int.tryParse(item.id.replaceFirst('invoice_', ''))
                  : null);
          if (id is int) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(
                  invoiceId: id,
                  invoice: data.isNotEmpty
                      ? Invoice.fromJson(data)
                      : Invoice.fromJson({'id': id, 'name': item.title}),
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InvoiceListScreenNew()),
            );
          }
          break;

        case 'customer':
          final data = item.data ?? {};
          final id =
              data['id'] ??
              (item.id.startsWith('customer_')
                  ? int.tryParse(item.id.replaceFirst('customer_', ''))
                  : null);
          if (data.isNotEmpty && id is int) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomerDetailsScreen(
                  customer: Customer.fromJson(Map<String, dynamic>.from(data)),
                ),
              ),
            );
          }
          break;

        case 'product':
          final data = item.data ?? {};
          if (data.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProductDetailsScreen(product: Product.fromJson(data)),
              ),
            );
          }
          break;

        case 'credit_note':
        case 'creditnote':
          final data = item.data ?? {};
          if (data.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    CreditNoteDetailScreen(creditNote: Invoice.fromJson(data)),
              ),
            );
          }
          break;

        case 'payment':
          final data = item.data ?? {};
          if (data.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PaymentDetailScreen(payment: Payment.fromJson(data)),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaymentRecordsScreen()),
            );
          }
          break;

        case 'page':
          if (item.route == '/payment_record' &&
              item.data != null &&
              item.data!.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PaymentDetailScreen(payment: Payment.fromJson(item.data!)),
              ),
            );
          } else if (item.route == '/credit_note' &&
              item.data != null &&
              item.data!.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CreditNoteDetailScreen(
                  creditNote: Invoice.fromJson(item.data!),
                ),
              ),
            );
          } else {
            _navigateToPage(item.route);
          }
          break;

        default:
      }
    } catch (e) {}
  }

  void _navigateToPage(String route) {
    switch (route) {
      case '/payment_record':
      case '/payments':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PaymentRecordsScreen()));
        break;
      case '/invoices':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const InvoiceListScreenNew()));
        break;
      case '/customers':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CustomersScreen()));
        break;
      case '/products':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
        break;
      case '/credit_note':
      case '/credit_notes':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreditNotesScreen()));
        break;
      default:
    }
  }

  String _getValidSubtitle(String? subtitle) {
    if (subtitle == null || subtitle.isEmpty) return '';
    if (subtitle.toLowerCase() == 'false') return '';
    return subtitle;
  }

  String _getValidTitle(String? title) {
    if (title == null || title.isEmpty) return 'Untitled';
    if (title.toLowerCase() == 'false') return 'Untitled';
    return title;
  }

  Widget _buildLoadingState(bool isDark) {
    return const DashboardShimmerLoading();
  }

  Widget _buildErrorState(String error) {
    return ConnectionStatusWidget(
      serverUnreachable: true,
      serverErrorMessage: error,
      onRetry: _loadData,
    );
  }
}
