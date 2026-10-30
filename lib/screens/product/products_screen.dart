import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/group_section_card.dart';
import '../../widgets/mobo_search_field.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/product_list_tile.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/pagination_bar.dart';

class ProductsScreen extends StatefulWidget {
  final bool autoFocusSearch;

  const ProductsScreen({super.key, this.autoFocusSearch = false});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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
      if (widget.autoFocusSearch) {
        _searchFocusNode.requestFocus();
      }
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

  /// Loads (or, after a create/edit/archive, reloads) the list for whatever
  /// is in the search box — reloading unfiltered would leave the box showing
  /// a query the list no longer matches.
  Future<void> _loadData() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    await _runSearch(_searchController.text);
    await provider.fetchGroupByOptions();
    if (mounted) setState(() => _isFirstLoad = false);
  }

  Future<void> _runSearch(String query) {
    _searchDebounce?.cancel();
    final provider = Provider.of<ProductProvider>(context, listen: false);
    // Groups are re-read for the new query; open tiles would otherwise spin
    // on data that was just cleared.
    if (provider.isGrouped && _expandedGroups.isNotEmpty) {
      setState(() => _expandedGroups.clear());
    }
    return provider.searchProducts(query);
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _runSearch(query);
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
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: appBarFg,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Products'),
        actions: const [],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_create_product',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductFormScreen()),
          );
          if (result == true) {
            _loadData();
            if (mounted) {
              CustomSnackbar.showSuccess(
                context,
                'Product created successfully',
              );
            }
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        tooltip: 'Create Product',
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPackageAdd,
          color: Colors.white,
        ),
      ),
      body: Consumer<ProductProvider>(
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
                          (provider.showServicesOnly ? 1 : 0) +
                          (provider.showConsumablesOnly ? 1 : 0) +
                          (provider.showStorableOnly ? 1 : 0) +
                          (provider.showAvailableOnly ? 1 : 0),
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

                    if (provider.error != null && provider.products.isEmpty) {
                      return ConnectionStatusWidget(
                        serverUnreachable: true,
                        serverErrorMessage: provider.error,
                        onRetry: () {
                          _loadData();
                        },
                      );
                    }

                    final content = (_isFirstLoad || provider.isLoading)
                        ? const CommonListShimmer()
                        : provider.products.isEmpty && !provider.isGrouped
                        ? _buildEmptyState(provider)
                        : _buildProductList(provider.products, provider);

                    final bool isScrollable =
                        provider.isLoading || provider.products.isNotEmpty;

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
    final provider = Provider.of<ProductProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      child: MoboSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Search products...',
        hasActiveFilters: _hasActiveFilters(provider),
        onFilterTap: _showFilterBottomSheet,
        onChanged: _onSearchChanged,
        // Lets the keyboard's search key re-run the same text (onChanged
        // only fires when the text changes).
        onSubmitted: _runSearch,
        onClear: () => _runSearch(''),
      ),
    );
  }

  Widget _buildTopPaginationBar(ProductProvider provider) {
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

  Widget _buildEmptyState(ProductProvider provider) {
    final hasFilters = _hasActiveFilters(provider);
    return EmptyStateWidget(
      title: hasFilters ? 'No results found' : 'No products found',
      subtitle: hasFilters
          ? 'Try adjusting your filters'
          : 'There are no product records to display',
      showClearButton: hasFilters,
      onClearFilters: () {
        provider.clearFilters();
        provider.setGroupBy(null);
      },
    );
  }

  Widget _buildProductList(List<Product> products, ProductProvider provider) {
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
          final groupProducts = provider.loadedGroups[groupKey];

          return GroupSectionCard(
            title: groupKey,
            subtitle: '$count product${count != 1 ? 's' : ''}',
            isExpanded: isExpanded,
            onToggle: () {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded) {
                provider.loadGroupProducts({'key': groupKey});
              }
            },
            isLoading: groupProducts == null,
            body: Column(
              children: [
                for (final product in groupProducts ?? const <Product>[])
                  _buildProductCard(product),
              ],
            ),
          );
        },
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, AppSpacing.fabClearance),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ProductListTile(
      id: product.id.toString(),
      name: product.name,
      defaultCode: product.defaultCode,
      price: product.listPrice ?? 0.0,
      currencyId: product.currencyId is List ? product.currencyId : null,
      category: product.categoryName,
      stockQuantity: (product.qtyAvailable ?? 0.0).toInt(),
      imageBase64: product.image128,
      variantCount: product.productVariantCount,
      isDark: isDark,
      onTap: () async {
        final templateId = product.id;
        final variantCount = product.productVariantCount ?? 1;

        if (variantCount > 1) {
          _showVariantsDialog(product, templateId);
        } else {
          if (product.productVariantIds != null &&
              product.productVariantIds!.isNotEmpty) {
            final variantId = product.productVariantIds![0] as int;
            final variantProduct = product.copyWith(id: variantId);
            _navigateToDetails(variantProduct);
          } else {
            _navigateToDetails(product);
          }
        }
      },
    );
  }

  void _navigateToDetails(Product product) async {
    try {
      final id = product.id.toString();
      final name = product.name;
      final category = product.categoryName;
      if (id.isNotEmpty) {
        await Provider.of<LastOpenedProvider>(
          context,
          listen: false,
        ).trackProductAccess(product: product);
      }
    } catch (_) {}

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(product: product),
      ),
    );
    if (result != null) {
      _loadData();
      if (mounted) {
        if (result == true) {
          CustomSnackbar.showSuccess(context, 'Product archived successfully');
        } else if (result == 'updated') {
          CustomSnackbar.showSuccess(context, 'Product updated successfully');
        }
      }
    }
  }

  Future<void> _showVariantsDialog(Product product, int templateId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ProductProvider>(context, listen: false);

    Future<List<Product>>? variantsFuture = provider.getProductVariants(
      templateId,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Variant',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return FutureBuilder<List<Product>>(
                        future: variantsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          if (snapshot.hasError) {
                            final errorMessage = snapshot.error.toString();
                            final isTimeout =
                                errorMessage.contains('timeout') ||
                                errorMessage.contains('Timeout');

                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isTimeout
                                        ? Icons.timer_off_outlined
                                        : Icons.error_outline,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    isTimeout
                                        ? 'Request timed out. Please check your connection and try again.'
                                        : 'Failed to load variants',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setDialogState(() {
                                        variantsFuture = provider
                                            .getProductVariants(templateId);
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'No variants found',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            );
                          }

                          final variants = snapshot.data!;

                          return Scrollbar(
                            thumbVisibility: true,
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: variants.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final variant = variants[index];
                                return _buildVariantTile(variant);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantTile(Product variant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ProductListTile(
      id: variant.id.toString(),
      name: variant.name,
      defaultCode: variant.defaultCode,
      price: variant.listPrice ?? 0.0,
      currencyId: variant.currencyId is List ? variant.currencyId : null,
      category: variant.categoryName,
      stockQuantity: (variant.qtyAvailable ?? 0.0).toInt(),
      imageBase64: variant.image128,
      variantCount: 1,
      isDark: isDark,
      onTap: () {
        Navigator.pop(context);
        _navigateToDetails(variant);
      },
    );
  }

  void _showFilterBottomSheet() {
    final provider = Provider.of<ProductProvider>(context, listen: false);

    final Map<String, dynamic> tempState = {
      'showServicesOnly': provider.showServicesOnly,
      'showConsumablesOnly': provider.showConsumablesOnly,
      'showStorableOnly': provider.showStorableOnly,
      'showAvailableOnly': provider.showAvailableOnly,
      'selectedGroupBy': provider.selectedGroupBy,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => FilterSheetShell(
          filterTab: _buildProductFilterTab(setDialogState, tempState),
          groupByTab: FilterGroupByTab(
            heading: 'Group products by',
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

  Widget _buildProductFilterTab(
    StateSetter setDialogState,
    Map<String, dynamic> tempState,
  ) {
    return FilterTabBody(
      children: [
        FilterActiveFilters(
          chips: [
            if (tempState['showServicesOnly'] == true)
              FilterActiveChip(
                label: 'Services',
                onRemove: () =>
                    setDialogState(() => tempState['showServicesOnly'] = false),
              ),
            if (tempState['showConsumablesOnly'] == true)
              FilterActiveChip(
                label: 'Consumables',
                onRemove: () => setDialogState(
                  () => tempState['showConsumablesOnly'] = false,
                ),
              ),
            if (tempState['showStorableOnly'] == true)
              FilterActiveChip(
                label: 'Storable',
                onRemove: () => setDialogState(
                  () => tempState['showStorableOnly'] = false,
                ),
              ),
            if (tempState['showAvailableOnly'] == true)
              FilterActiveChip(
                label: 'Available Only',
                onRemove: () => setDialogState(
                  () => tempState['showAvailableOnly'] = false,
                ),
              ),
          ],
        ),
        const FilterSectionTitle('Product Type'),
        // One product type at a time.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, label) in const [
              ('showServicesOnly', 'Services'),
              ('showConsumablesOnly', 'Consumables'),
              ('showStorableOnly', 'Storable'),
            ])
              FilterChoiceChip(
                label: label,
                selected: tempState[key] == true,
                onTap: () => setDialogState(() {
                  final val = tempState[key] != true;
                  tempState['showServicesOnly'] = false;
                  tempState['showConsumablesOnly'] = false;
                  tempState['showStorableOnly'] = false;
                  tempState[key] = val;
                }),
              ),
          ],
        ),
        const FilterSectionTitle('Availability'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChoiceChip(
              label: 'Available Only',
              selected: tempState['showAvailableOnly'] == true,
              onTap: () => setDialogState(
                () => tempState['showAvailableOnly'] =
                    tempState['showAvailableOnly'] != true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _clearAllFilters(
    StateSetter setDialogState,
    Map<String, dynamic> tempState,
    ProductProvider provider,
  ) {
    setDialogState(() {
      tempState['showServicesOnly'] = false;
      tempState['showConsumablesOnly'] = false;
      tempState['showStorableOnly'] = false;
      tempState['showAvailableOnly'] = false;
      tempState['selectedGroupBy'] = null;
    });
  }

  void _applyFiltersAndGroupBy(
    Map<String, dynamic> tempState,
    ProductProvider provider,
  ) {
    provider.setFilterState(
      showServicesOnly: tempState['showServicesOnly'],
      showConsumablesOnly: tempState['showConsumablesOnly'],
      showStorableOnly: tempState['showStorableOnly'],
      showAvailableOnly: tempState['showAvailableOnly'],
    );
    provider.setGroupBy(tempState['selectedGroupBy']);
    Navigator.of(context).pop();
  }

  bool _hasActiveFilters(ProductProvider provider) {
    return provider.showServicesOnly ||
        provider.showConsumablesOnly ||
        provider.showStorableOnly ||
        provider.showAvailableOnly ||
        provider.selectedGroupBy != null;
  }

  Widget _buildFilterIndicator(ProductProvider provider) {
    if (!_hasActiveFilters(provider)) {
      return const SizedBox.shrink();
    }

    int filterCount = 0;
    if (provider.showServicesOnly) filterCount++;
    if (provider.showConsumablesOnly) filterCount++;
    if (provider.showStorableOnly) filterCount++;
    if (provider.showAvailableOnly) filterCount++;
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

  Widget _buildActiveFiltersChips(ProductProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (!provider.showServicesOnly &&
        !provider.showConsumablesOnly &&
        !provider.showStorableOnly &&
        !provider.showAvailableOnly &&
        !provider.isGrouped) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (provider.showServicesOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Services', style: TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    provider.setFilterState(showServicesOnly: false),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ),
          if (provider.showConsumablesOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text(
                  'Consumables',
                  style: TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    provider.setFilterState(showConsumablesOnly: false),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ),
          if (provider.showStorableOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Storable', style: TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    provider.setFilterState(showStorableOnly: false),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ),
          if (provider.showAvailableOnly)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text(
                  'Available Only',
                  style: TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () =>
                    provider.setFilterState(showAvailableOnly: false),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ),
          if (provider.isGrouped)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  'Group: ${provider.groupByOptions[provider.selectedGroupBy] ?? provider.selectedGroupBy}',
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => provider.setGroupBy(null),
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                side: BorderSide.none,
              ),
            ),
          TextButton(
            onPressed: () => provider.clearFilters(),
            child: const Text('Clear All', style: TextStyle(fontSize: 12)),
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
