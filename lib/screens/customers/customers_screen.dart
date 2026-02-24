import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/customer_list_tile.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';
import 'customer_details_screen.dart';
import 'customer_form_screen.dart';
import '../../models/customer.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';
import '../../utils/date_picker_utils.dart';

class CustomersScreen extends StatefulWidget {
  final bool autoFocusSearch;

  const CustomersScreen({super.key, this.autoFocusSearch = false});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, bool> _expandedGroups = {};
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CustomerProvider>(context, listen: false);
    await provider.loadCustomers();
    await provider.fetchGroupByOptions();
    if (mounted) setState(() => _isFirstLoad = false);
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      if (query.isEmpty) {
        provider.loadCustomers();
      } else {
        provider.searchCustomers(query);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarFg =
        Theme.of(context).appBarTheme.foregroundColor ??
        (isDark ? Colors.white : Colors.black);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: appBarFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Customers'),
        actions: const [],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_customer',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
          );
          if (result == true) {
            _loadData();
          }
        },
        backgroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        tooltip: 'Create Customer',
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: isDark ? Colors.black : Colors.white,
        ),
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildSearchField(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    ActiveFiltersBadge(
                      count:
                          (provider.showActiveOnly ? 0 : 1) +
                          (provider.showCompaniesOnly ? 1 : 0) +
                          (provider.showIndividualsOnly ? 1 : 0) +
                          (provider.showCreditBreachesOnly ? 1 : 0) +
                          (provider.startDate != null ||
                                  provider.endDate != null
                              ? 1
                              : 0),
                      hasGroupBy: provider.selectedGroupBy != null,
                    ),
                    if (provider.selectedGroupBy != null) ...[
                      const SizedBox(width: 8),
                      GroupByPill(
                        label:
                            provider.groupByOptions[provider.selectedGroupBy] ??
                            provider.selectedGroupBy!,
                      ),
                    ],

                    const Spacer(),

                    _buildTopPaginationBar(provider),
                  ],
                ),
              ),
              Expanded(
                child: Consumer2<ConnectivityService, SessionService>(
                  builder: (context, connectivityService, sessionService, child) {
                    if (!connectivityService.isConnected) {
                      return ConnectionStatusWidget(
                        onRetry: () {
                          if (connectivityService.isConnected &&
                              sessionService.hasValidSession) {
                            _loadData();
                          }
                        },
                        customMessage:
                            'No internet connection. Please check your connection and try again.',
                      );
                    }

                    if (!sessionService.hasValidSession) {
                      return const ConnectionStatusWidget();
                    }

                    if (provider.error != null && provider.customers.isEmpty) {
                      return ConnectionStatusWidget(
                        serverUnreachable: true,
                        serverErrorMessage: provider.error,
                        onRetry: () {
                          _loadData();
                        },
                      );
                    }

                    final content = (_isFirstLoad || provider.isLoading)
                        ? const CommonListShimmer(hasAvatar: true)
                        : provider.customers.isEmpty && !provider.isGrouped
                        ? _buildEmptyState(provider)
                        : _buildCustomerList(provider.customers, provider);

                    final bool isScrollable =
                        provider.isLoading ||
                        !(provider.error != null ||
                            (provider.customers.isEmpty &&
                                !provider.isGrouped));

                    return RefreshIndicator(
                      onRefresh: () async {
                        try {
                          _loadData();
                        } catch (e) {
                          if (mounted) _showErrorSnackBar(e.toString());
                        }
                      },
                      child: isScrollable
                          ? content
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: constraints.maxHeight,
                                    ),
                                    child: Center(child: content),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: _onSearchChanged,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xff1E1E1E),
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.normal,
            fontSize: 15,
            height: 1.0,
            letterSpacing: 0.0,
          ),
          decoration: InputDecoration(
            hintText: 'Search customers...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white : const Color(0xff1E1E1E),
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.normal,
              fontSize: 15,
              height: 1.0,
              letterSpacing: 0.0,
            ),
            prefixIcon: IconButton(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedFilterHorizontal,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              onPressed: _showFilterBottomSheet,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.grey[400] : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchDebounce?.cancel();
                      Provider.of<CustomerProvider>(
                        context,
                        listen: false,
                      ).loadCustomers();
                      setState(() {});
                    },
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[850]! : Colors.white,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[850]! : Colors.white,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            isDense: true,
            alignLabelWithHint: true,
          ),
        ),
      ),
    );
  }

  Widget _buildTopPaginationBar(CustomerProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paginationText = provider.isGrouped
        ? '${provider.totalCount}/${provider.totalCount}'
        : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}';

    return Container(
      padding: const EdgeInsets.only(right: 0, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paginationText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          if (!provider.isGrouped) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasPreviousPage && !provider.isLoading)
                      ? provider.goToPreviousPage
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      size: 20,
                      color: (provider.hasPreviousPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (provider.hasNextPage && !provider.isLoading)
                      ? provider.goToNextPage
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 4,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 20,
                      color: (provider.hasNextPage && !provider.isLoading)
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(CustomerProvider provider) {
    final hasFilters = _hasActiveFilters(provider);
    return EmptyStateWidget(
      title: hasFilters ? 'No results found' : 'No customers found',
      subtitle: hasFilters
          ? 'Try adjusting your filters'
          : 'There are no customer records to display',
      showClearButton: hasFilters,
      onClearFilters: () {
        provider.clearFilters();
        provider.setGroupBy(null);
      },
    );
  }

  Widget _buildCustomerList(
    List<Customer> customers,
    CustomerProvider provider,
  ) {
    if (provider.isGrouped) {
      final groups = provider.groupSummary.entries.toList();

      if (groups.isEmpty) {
        return _buildEmptyState(provider);
      }

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final groupKey = group.key;
          final count = group.value;
          final isExpanded = _expandedGroups[groupKey] ?? false;

          Widget? expandedContent;
          if (isExpanded) {
            if (provider.loadedGroups.containsKey(groupKey)) {
              expandedContent = Column(
                children: provider.loadedGroups[groupKey]!
                    .map(
                      (customer) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: _buildCustomerCard(customer),
                      ),
                    )
                    .toList(),
              );
            } else {
              expandedContent = const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
          }

          return _buildOdooStyleGroupTile(
            context,
            groupKey,
            count,
            isExpanded,
            () {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded) {
                provider.loadGroupContacts(groupKey);
              }
            },
            expandedContent: expandedContent,
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      itemBuilder: (context, index) {
        final customer = customers[index];
        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomerListTile(
      customer: customer,
      isDark: isDark,
      imageCache: _imageCache,
      onTap: () async {
        try {
          final id = customer.id?.toString() ?? '';
          final name = customer.name;
          if (id.isNotEmpty) {
            final type = customer.companyType;
            await Provider.of<LastOpenedProvider>(
              context,
              listen: false,
            ).trackCustomerAccess(customer: customer);
          }
        } catch (_) {}

        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CustomerDetailsScreen(customer: customer),
          ),
        );
        if (result == true) {
          _loadData();
        }
      },
      onCall: () => _makePhoneCall(customer.phone),
      onMessage: () => _showChatOptionsBottomSheet(context, customer),
      onEmail: () => _sendEmail(customer.email),
      onLocation: () => _viewLocation(customer),
    );
  }

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty || phoneNumber == 'false') {
      CustomSnackbar.showInfo(context, 'No phone number available');
      return;
    }

    try {
      final phoneUrl = 'tel:$phoneNumber';
      if (await canLaunchUrl(Uri.parse(phoneUrl))) {
        await launchUrl(Uri.parse(phoneUrl));
      } else {
        CustomSnackbar.showError(context, 'Could not launch phone app');
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to make call: ${e.toString()}');
    }
  }

  bool _hasValidPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null ||
        phoneNumber.trim().isEmpty ||
        phoneNumber == 'false') {
      return false;
    }

    String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleanedNumber.isEmpty) {
      cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    }

    return cleanedNumber.isNotEmpty && cleanedNumber.length >= 7;
  }

  void _showNoPhoneNumberMessage() {
    CustomSnackbar.showError(
      context,
      'No phone number available for this contact',
    );
  }

  Future<void> _sendSMS(String? phoneNumber) async {
    if (!_hasValidPhoneNumber(phoneNumber)) {
      _showNoPhoneNumberMessage();
      return;
    }

    String cleanedNumber = phoneNumber!
        .replaceAll(RegExp(r'[^\d+]'), '')
        .trim();

    if (cleanedNumber.isEmpty) {
      cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    }

    if (cleanedNumber.isEmpty) {
      CustomSnackbar.showError(
        context,
        'Phone number contains no valid digits',
      );
      return;
    }

    final isInternational = cleanedNumber.startsWith('+');
    final minLength = isInternational ? 8 : 7;

    if (cleanedNumber.length < minLength) {
      CustomSnackbar.showError(
        context,
        'Phone number is too short (minimum $minLength digits)',
      );
      return;
    }

    if (cleanedNumber.length > 20) {
      CustomSnackbar.showError(
        context,
        'Phone number is too long. Please check the format.',
      );
      return;
    }

    try {
      final smsUri = Uri(scheme: 'sms', path: cleanedNumber);

      try {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return;
      } catch (e) {}

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        CustomSnackbar.showError(context, 'No SMS app found to send message');
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to send SMS: ${e.toString()}');
    }
  }

  Future<void> _openWhatsApp(BuildContext context, Customer customer) async {
    final phoneNumber = customer.phone ?? customer.mobile;

    if (!_hasValidPhoneNumber(phoneNumber)) {
      _showNoPhoneNumberMessage();
      return;
    }

    try {
      final cleanedNumber = phoneNumber!
          .replaceAll(RegExp(r'[^\d+]'), '')
          .trim();

      if (cleanedNumber.isEmpty) {
        throw Exception('Invalid phone number format');
      }

      String whatsappNumber = cleanedNumber;

      if (whatsappNumber.startsWith('+')) {
        whatsappNumber = whatsappNumber.substring(1);
      }

      if (whatsappNumber.length == 10) {
        if (whatsappNumber.startsWith('9') ||
            whatsappNumber.startsWith('8') ||
            whatsappNumber.startsWith('7') ||
            whatsappNumber.startsWith('6')) {
          whatsappNumber = '91$whatsappNumber';
        } else if (whatsappNumber.startsWith('2') ||
            whatsappNumber.startsWith('3') ||
            whatsappNumber.startsWith('4') ||
            whatsappNumber.startsWith('5')) {
          whatsappNumber = '1$whatsappNumber';
        }
      }

      if (whatsappNumber.length < 7) {
        throw Exception('Phone number too short for WhatsApp');
      }

      if (whatsappNumber.length > 15) {
        throw Exception('Phone number too long for WhatsApp');
      }

      final whatsappUrl = Uri.encodeFull('https://wa.me/$whatsappNumber');

      try {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      } catch (e) {}

      if (await canLaunchUrl(Uri.parse(whatsappUrl))) {
        await launchUrl(
          Uri.parse(whatsappUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        CustomSnackbar.showError(
          context,
          'WhatsApp is not available on this device',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'Failed to open WhatsApp: ${e.toString()}',
      );
    }
  }

  void _showChatOptionsBottomSheet(BuildContext context, Customer customer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Send Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white24 : Colors.grey[300],
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedMessage01,
                color: isDark ? Colors.white : primaryColor,
              ),
              title: Text(
                'System Messenger',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Send SMS using default messaging app',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                final phoneNumber = customer.phone ?? customer.mobile;
                _sendSMS(phoneNumber);
              },
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedWhatsapp,
                color: Colors.green,
              ),
              title: Text(
                'WhatsApp',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Send message via WhatsApp',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _openWhatsApp(context, customer);
              },
            ),
            Builder(
              builder: (context) =>
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendEmail(String? email) async {
    if (email == null || email.isEmpty || email == 'false') {
      CustomSnackbar.showInfo(context, 'No email address available');
      return;
    }

    try {
      final emailUrl = 'mailto:$email';
      if (await canLaunchUrl(Uri.parse(emailUrl))) {
        await launchUrl(Uri.parse(emailUrl));
      } else {
        CustomSnackbar.showError(context, 'Could not launch email app');
      }
    } catch (e) {
      CustomSnackbar.showError(
        context,
        'Failed to open email app: ${e.toString()}',
      );
    }
  }

  void _viewLocation(Customer customer) {
    final lat = customer.partnerLatitude;
    final lng = customer.partnerLongitude;

    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      _openInMaps(lat, lng);
    } else {
      CustomSnackbar.showInfo(
        context,
        'No location data available for this customer',
      );
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    try {
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        CustomSnackbar.showError(context, 'Could not launch maps app');
      }
    } catch (e) {
      CustomSnackbar.showError(context, 'Failed to open maps: ${e.toString()}');
    }
  }

  void _showFilterBottomSheet() {
    final provider = Provider.of<CustomerProvider>(context, listen: false);

    final Map<String, dynamic> tempState = {
      'showActiveOnly': provider.showActiveOnly,
      'showCompaniesOnly': provider.showCompaniesOnly,
      'showIndividualsOnly': provider.showIndividualsOnly,
      'showCreditBreachesOnly': provider.showCreditBreachesOnly,
      'startDate': provider.startDate,
      'endDate': provider.endDate,
      'selectedGroupBy': provider.selectedGroupBy,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232323) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Filter & Group By',
                              style: theme.textTheme.titleMedium?.copyWith(
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
                              color: isDark ? Colors.white : Colors.black54,
                            ),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        indicator: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        indicatorPadding: const EdgeInsets.all(4),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        tabs: const [
                          Tab(height: 48, text: 'Filter'),
                          Tab(height: 48, text: 'Group By'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildCustomerFilterTab(
                            context,
                            setDialogState,
                            isDark,
                            theme,
                            provider,
                            tempState,
                          ),
                          _buildCustomerGroupByTab(
                            context,
                            setDialogState,
                            isDark,
                            theme,
                            provider,
                            tempState,
                          ),
                        ],
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[50],
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _clearAllFilters(
                                setDialogState,
                                tempState,
                                provider,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Clear All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _applyFiltersAndGroupBy(tempState, provider),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                              ),
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCustomerFilterTab(
    BuildContext context,
    StateSetter setDialogState,
    bool isDark,
    ThemeData theme,
    CustomerProvider provider,
    Map<String, dynamic> tempState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tempState['showActiveOnly'] == true ||
              tempState['showCompaniesOnly'] == true ||
              tempState['showIndividualsOnly'] == true ||
              tempState['showCreditBreachesOnly'] == true ||
              tempState['startDate'] != null ||
              tempState['endDate'] != null) ...[
            Text(
              'Active Filters',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isDark ? Colors.white : theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (tempState['showActiveOnly'] == true)
                  Chip(
                    label: const Text(
                      'Active Only',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showActiveOnly'] = false,
                    ),
                  ),
                if (tempState['showCompaniesOnly'] == true)
                  Chip(
                    label: const Text(
                      'Companies',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showCompaniesOnly'] = false,
                    ),
                  ),
                if (tempState['showIndividualsOnly'] == true)
                  Chip(
                    label: const Text(
                      'Individuals',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showIndividualsOnly'] = false,
                    ),
                  ),
                if (tempState['showCreditBreachesOnly'] == true)
                  Chip(
                    label: const Text(
                      'Credit Breaches',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showCreditBreachesOnly'] = false,
                    ),
                  ),
                if (tempState['startDate'] != null ||
                    tempState['endDate'] != null)
                  Chip(
                    label: Text(
                      'Date: ${tempState['startDate'] != null ? DateFormat('MMM dd').format(tempState['startDate']) : '...'} - ${tempState['endDate'] != null ? DateFormat('MMM dd, yyyy').format(tempState['endDate']) : '...'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(() {
                      tempState['startDate'] = null;
                      tempState['endDate'] = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Status',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: Text(
                  'Active Only',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showActiveOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showActiveOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showActiveOnly'] == true,
                selectedColor: theme.primaryColor,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(.08)
                    : theme.primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                onSelected: (val) =>
                    setDialogState(() => tempState['showActiveOnly'] = val),
              ),
              ChoiceChip(
                label: Text(
                  'Credit Breaches',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showCreditBreachesOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showCreditBreachesOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showCreditBreachesOnly'] == true,
                selectedColor: theme.primaryColor,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(.08)
                    : theme.primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                onSelected: (val) => setDialogState(
                  () => tempState['showCreditBreachesOnly'] = val,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Type',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: Text(
                  'Companies',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showCompaniesOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showCompaniesOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showCompaniesOnly'] == true,
                selectedColor: theme.primaryColor,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(.08)
                    : theme.primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                onSelected: (val) {
                  setDialogState(() {
                    tempState['showCompaniesOnly'] = val;
                    if (val) tempState['showIndividualsOnly'] = false;
                  });
                },
              ),
              ChoiceChip(
                label: Text(
                  'Individuals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showIndividualsOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showIndividualsOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showIndividualsOnly'] == true,
                selectedColor: theme.primaryColor,
                backgroundColor: isDark
                    ? Colors.white.withOpacity(.08)
                    : theme.primaryColor.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  ),
                ),
                onSelected: (val) {
                  setDialogState(() {
                    tempState['showIndividualsOnly'] = val;
                    if (val) tempState['showCompaniesOnly'] = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Date Range',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () async {
              final date = await DatePickerUtils.showStandardDatePicker(
                context: context,
                initialDate: tempState['startDate'] ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setDialogState(() => tempState['startDate'] = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tempState['startDate'] != null
                          ? 'From: ${DateFormat('MMM dd, yyyy').format(tempState['startDate'])}'
                          : 'Select start date',
                      style: TextStyle(
                        color: tempState['startDate'] != null
                            ? (isDark ? Colors.white : Colors.grey[800])
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ),
                  if (tempState['startDate'] != null)
                    IconButton(
                      onPressed: () =>
                          setDialogState(() => tempState['startDate'] = null),
                      icon: Icon(
                        Icons.clear,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: () async {
              final date = await DatePickerUtils.showStandardDatePicker(
                context: context,
                initialDate: tempState['endDate'] ?? DateTime.now(),
                firstDate: tempState['startDate'] ?? DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setDialogState(() => tempState['endDate'] = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tempState['endDate'] != null
                          ? 'To: ${DateFormat('MMM dd, yyyy').format(tempState['endDate'])}'
                          : 'Select end date',
                      style: TextStyle(
                        color: tempState['endDate'] != null
                            ? (isDark ? Colors.white : Colors.grey[800])
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ),
                  if (tempState['endDate'] != null)
                    IconButton(
                      onPressed: () =>
                          setDialogState(() => tempState['endDate'] = null),
                      icon: Icon(
                        Icons.clear,
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCustomerGroupByTab(
    BuildContext context,
    StateSetter setDialogState,
    bool isDark,
    ThemeData theme,
    CustomerProvider provider,
    Map<String, dynamic> tempState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Group customers by',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String?>(
            title: Text(
              'None',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Display as a simple list',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
            value: null,
            groupValue: tempState['selectedGroupBy'],
            onChanged: (value) {
              setDialogState(() {
                tempState['selectedGroupBy'] = value;
              });
            },
            activeColor: theme.primaryColor,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          if (provider.groupByOptions.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text("Loading options...")),
            ),
          ] else ...[
            ...provider.groupByOptions.entries.map((entry) {
              String description = '';
              switch (entry.key) {
                case 'user_id':
                  description = 'Group by assigned salesperson';
                  break;
                case 'country_id':
                  description = 'Group by country';
                  break;
                case 'state_id':
                  description = 'Group by state';
                  break;
                case 'company_id':
                  description = 'Group by company';
                  break;
                default:
                  description = 'Group by ${entry.value.toLowerCase()}';
              }
              return RadioListTile<String>(
                title: Text(
                  entry.value,
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
                value: entry.key,
                groupValue: tempState['selectedGroupBy'],
                onChanged: (value) {
                  setDialogState(() {
                    tempState['selectedGroupBy'] = value;
                  });
                },
                activeColor: theme.primaryColor,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _clearAllFilters(
    StateSetter setDialogState,
    Map<String, dynamic> tempState,
    CustomerProvider provider,
  ) {
    setDialogState(() {
      tempState['showActiveOnly'] = true;
      tempState['showCompaniesOnly'] = false;
      tempState['showIndividualsOnly'] = false;
      tempState['showCreditBreachesOnly'] = false;
      tempState['startDate'] = null;
      tempState['endDate'] = null;
      tempState['selectedGroupBy'] = null;
    });
  }

  void _applyFiltersAndGroupBy(
    Map<String, dynamic> tempState,
    CustomerProvider provider,
  ) {
    provider.setFilterState(
      showActiveOnly: tempState['showActiveOnly'],
      showCompaniesOnly: tempState['showCompaniesOnly'],
      showIndividualsOnly: tempState['showIndividualsOnly'],
      showCreditBreachesOnly: tempState['showCreditBreachesOnly'],
      startDate: tempState['startDate'],
      endDate: tempState['endDate'],
    );

    provider.setGroupBy(tempState['selectedGroupBy']);

    if (tempState['selectedGroupBy'] == null) {
      provider.loadCustomers(search: _searchController.text);
    }

    Navigator.of(context).pop();
  }

  bool _hasActiveFilters(CustomerProvider provider) {
    return !provider.showActiveOnly ||
        provider.showCompaniesOnly ||
        provider.showIndividualsOnly ||
        provider.showCreditBreachesOnly ||
        provider.startDate != null ||
        provider.endDate != null ||
        provider.selectedGroupBy != null;
  }

  Widget _buildFilterIndicator(CustomerProvider provider) {
    if (!_hasActiveFilters(provider)) {
      return const SizedBox.shrink();
    }

    int filterCount = 0;
    if (!provider.showActiveOnly) filterCount++;
    if (provider.showCompaniesOnly) filterCount++;
    if (provider.showIndividualsOnly) filterCount++;
    if (provider.showCreditBreachesOnly) filterCount++;
    if (provider.startDate != null || provider.endDate != null) filterCount++;
    if (provider.selectedGroupBy != null) filterCount++;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            filterCount == 1 ? '1 filter' : '$filterCount filters',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              provider.clearFilters();
              provider.setGroupBy(null);
            },
            child: Icon(
              Icons.close,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOdooStyleGroupTile(
    BuildContext context,
    String groupTitle,
    int count,
    bool isExpanded,
    VoidCallback onTap, {
    Widget? expandedContent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.08),
            ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count customer${count != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded && expandedContent != null) expandedContent,
        ],
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    if (!mounted) return;
    CustomSnackbar.showError(
      context,
      error.contains('502')
          ? 'Server is temporarily unavailable (502). Showing cached data.'
          : 'Failed to refresh: $error',
    );
  }
}
