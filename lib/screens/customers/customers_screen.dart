import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/customer_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/group_section_card.dart';
import '../../widgets/mobo_search_field.dart';
import '../../widgets/customer_list_tile.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/offline_data_banner.dart';
import '../../widgets/empty_state_widget.dart';
import 'customer_details_screen.dart';
import 'customer_form_screen.dart';
import '../../models/customer.dart';
import '../../widgets/custom_snackbar.dart';
import 'package:intl/intl.dart';
import '../../widgets/date_range_filter_fields.dart';
import '../../widgets/pagination_bar.dart';

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
        forceMaterialTransparency: true,
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
        backgroundColor: Theme.of(context).primaryColor,
        tooltip: 'Create Customer',
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: Colors.white,
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
                          // Credit Breaches isn't wired up to any query
                          // filtering yet (see CustomerProvider._buildDomain),
                          // so it's deliberately left out of this count —
                          // toggling it has no effect on the results shown.
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
                    // Offline with records in hand: keep them on screen under
                    // a banner instead of blanking the list.
                    if (!connectivityService.isConnected) {
                      if (provider.customers.isNotEmpty) {
                        return _buildCachedContent(provider);
                      }

                      return ConnectionStatusWidget(
                        onRetry: _loadData,
                        customMessage:
                            'No internet connection. Please check your connection and try again.',
                      );
                    }

                    if (!sessionService.hasValidSession) {
                      return const ConnectionStatusWidget();
                    }

                    // A failed refresh keeps the last good page on screen.
                    if (provider.error != null &&
                        provider.customers.isNotEmpty) {
                      return _buildCachedContent(
                        provider,
                        message: "Couldn't refresh customers",
                      );
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
    final provider = Provider.of<CustomerProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: MoboSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Search customers...',
        hasActiveFilters: _hasActiveFilters(provider),
        onFilterTap: _showFilterBottomSheet,
        onChanged: _onSearchChanged,
        onClear: () {
          _searchDebounce?.cancel();
          Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
        },
      ),
    );
  }

  Widget _buildTopPaginationBar(CustomerProvider provider) {
    return PaginationBar(
      totalCount: provider.totalCount,
      rangeText: provider.isGrouped
          ? '${provider.totalCount}/${provider.totalCount}'
          : '${provider.startRecord}-${provider.endRecord}/${provider.totalCount}',
      showArrows: !provider.isGrouped,
      hasPrevious: provider.hasPreviousPage,
      hasNext: provider.hasNextPage,
      isLoading: provider.isLoading,
      onPrevious: provider.goToPreviousPage,
      onNext: provider.goToNextPage,
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

  /// The customer list under an [OfflineDataBanner], used when the records
  /// came from the cache rather than a live fetch.
  Widget _buildCachedContent(CustomerProvider provider, {String? message}) {
    return Column(
      children: [
        OfflineDataBanner(
          lastUpdated: provider.cacheUpdatedAt,
          onRetry: _loadData,
          message: message,
        ),
        Expanded(child: _buildCustomerList(provider.customers, provider)),
      ],
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, AppSpacing.fabClearance),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final groupKey = group.key;
          final count = group.value;
          final isExpanded = _expandedGroups[groupKey] ?? false;
          final loadedCustomers = provider.loadedGroups[groupKey];

          return GroupSectionCard(
            title: groupKey,
            subtitle: '$count customer${count != 1 ? 's' : ''}',
            isExpanded: isExpanded,
            onToggle: () {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded) {
                provider.loadGroupContacts(groupKey);
              }
            },
            isLoading: loadedCustomers == null,
            body: Column(
              children: [
                for (final customer in loadedCustomers ?? const <Customer>[])
                  _buildCustomerCard(customer),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, AppSpacing.fabClearance),
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
                color: primaryColor,
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FilterSheetShell(
          filterTab: _buildCustomerFilterTab(setDialogState, tempState),
          groupByTab: FilterGroupByTab(
            heading: 'Group customers by',
            options: provider.groupByOptions,
            selected: tempState['selectedGroupBy'],
            loadingWhenEmpty: true,
            onChanged: (value) => setDialogState(
              () => tempState['selectedGroupBy'] = value,
            ),
          ),
          onClear: () => _clearAllFilters(setDialogState, tempState, provider),
          onApply: () => _applyFiltersAndGroupBy(tempState, provider),
        ),
      ),
    );
  }

  Widget _buildCustomerFilterTab(
    StateSetter setDialogState,
    Map<String, dynamic> tempState,
  ) {
    final DateTime? start = tempState['startDate'];
    final DateTime? end = tempState['endDate'];

    return FilterTabBody(
      children: [
        FilterActiveFilters(
          chips: [
            // "Active Only" defaults to ON — hiding archived customers is the
            // baseline, not something the user applied — so the deviation worth
            // surfacing (and offering to undo) here is turning it OFF, i.e.
            // choosing to include archived ones too.
            if (tempState['showActiveOnly'] == false)
              FilterActiveChip(
                label: 'Including Archived',
                onRemove: () =>
                    setDialogState(() => tempState['showActiveOnly'] = true),
              ),
            if (tempState['showCompaniesOnly'] == true)
              FilterActiveChip(
                label: 'Companies',
                onRemove: () => setDialogState(
                  () => tempState['showCompaniesOnly'] = false,
                ),
              ),
            if (tempState['showIndividualsOnly'] == true)
              FilterActiveChip(
                label: 'Individuals',
                onRemove: () => setDialogState(
                  () => tempState['showIndividualsOnly'] = false,
                ),
              ),
            if (tempState['showCreditBreachesOnly'] == true)
              FilterActiveChip(
                label: 'Credit Breaches',
                onRemove: () => setDialogState(
                  () => tempState['showCreditBreachesOnly'] = false,
                ),
              ),
            if (start != null || end != null)
              FilterActiveChip(
                label:
                    'Date: ${start != null ? DateFormat('MMM dd').format(start) : '...'} - ${end != null ? DateFormat('MMM dd, yyyy').format(end) : '...'}',
                onRemove: () => setDialogState(() {
                  tempState['startDate'] = null;
                  tempState['endDate'] = null;
                }),
              ),
          ],
        ),
        const FilterSectionTitle('Status'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChoiceChip(
              label: 'Active Only',
              selected: tempState['showActiveOnly'] == true,
              onTap: () => setDialogState(
                () => tempState['showActiveOnly'] =
                    tempState['showActiveOnly'] != true,
              ),
            ),
            FilterChoiceChip(
              label: 'Credit Breaches',
              selected: tempState['showCreditBreachesOnly'] == true,
              onTap: () => setDialogState(
                () => tempState['showCreditBreachesOnly'] =
                    tempState['showCreditBreachesOnly'] != true,
              ),
            ),
          ],
        ),
        const FilterSectionTitle('Type'),
        // Companies and Individuals exclude each other.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChoiceChip(
              label: 'Companies',
              selected: tempState['showCompaniesOnly'] == true,
              onTap: () => setDialogState(() {
                final val = tempState['showCompaniesOnly'] != true;
                tempState['showCompaniesOnly'] = val;
                if (val) tempState['showIndividualsOnly'] = false;
              }),
            ),
            FilterChoiceChip(
              label: 'Individuals',
              selected: tempState['showIndividualsOnly'] == true,
              onTap: () => setDialogState(() {
                final val = tempState['showIndividualsOnly'] != true;
                tempState['showIndividualsOnly'] = val;
                if (val) tempState['showCompaniesOnly'] = false;
              }),
            ),
          ],
        ),
        const FilterSectionTitle('Date Range'),
        DateRangeFilterFields(
          startDate: start,
          endDate: end,
          onStartChanged: (date) =>
              setDialogState(() => tempState['startDate'] = date),
          onEndChanged: (date) =>
              setDialogState(() => tempState['endDate'] = date),
        ),
      ],
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
    if (!DateRangeFilterFields.isValid(
      tempState['startDate'],
      tempState['endDate'],
    )) {
      CustomSnackbar.showError(context, DateRangeFilterFields.rangeError);
      return;
    }

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
    // Credit Breaches is excluded here too — it's not wired up to any query
    // filtering yet, so it shouldn't count as a result-affecting filter.
    return !provider.showActiveOnly ||
        provider.showCompaniesOnly ||
        provider.showIndividualsOnly ||
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
