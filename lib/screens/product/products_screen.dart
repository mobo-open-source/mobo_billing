import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../providers/product_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/filter_badges.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/product_list_tile.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/empty_state_widget.dart';

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

  Future<void> _loadData() async {
    final provider = Provider.of<ProductProvider>(context, listen: false);
    await provider.loadProducts();
    await provider.fetchGroupByOptions();
    if (mounted) setState(() => _isFirstLoad = false);
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final provider = Provider.of<ProductProvider>(context, listen: false);
      if (query.isEmpty) {
        provider.loadProducts();
      } else {
        provider.searchProducts(query);
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
        backgroundColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        tooltip: 'Create Product',
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPackageAdd,
          color: isDark ? Colors.black : Colors.white,
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
            hintText: 'Search products...',
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
                size: 18,
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
                      Provider.of<ProductProvider>(
                        context,
                        listen: false,
                      ).loadProducts();
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

  Widget _buildTopPaginationBar(ProductProvider provider) {
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
              final groupProducts = provider.loadedGroups[groupKey]!;
              expandedContent = Column(
                children: groupProducts
                    .map(
                      (product) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: _buildProductCard(product),
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
            groupKey,
            count,
            isExpanded,
            provider,
            () {
              setState(() {
                _expandedGroups[groupKey] = !isExpanded;
              });
              if (!isExpanded) {
                provider.loadGroupProducts({'key': groupKey});
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
                          _buildProductFilterTab(
                            context,
                            setDialogState,
                            isDark,
                            theme,
                            provider,
                            tempState,
                          ),
                          _buildProductGroupByTab(
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

  Widget _buildProductFilterTab(
    BuildContext context,
    StateSetter setDialogState,
    bool isDark,
    ThemeData theme,
    ProductProvider provider,
    Map<String, dynamic> tempState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tempState['showServicesOnly'] == true ||
              tempState['showConsumablesOnly'] == true ||
              tempState['showStorableOnly'] == true ||
              tempState['showAvailableOnly'] == true) ...[
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
                if (tempState['showServicesOnly'] == true)
                  Chip(
                    label: const Text(
                      'Services',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showServicesOnly'] = false,
                    ),
                  ),
                if (tempState['showConsumablesOnly'] == true)
                  Chip(
                    label: const Text(
                      'Consumables',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showConsumablesOnly'] = false,
                    ),
                  ),
                if (tempState['showStorableOnly'] == true)
                  Chip(
                    label: const Text(
                      'Storable',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showStorableOnly'] = false,
                    ),
                  ),
                if (tempState['showAvailableOnly'] == true)
                  Chip(
                    label: const Text(
                      'Available Only',
                      style: TextStyle(fontSize: 13),
                    ),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(.08)
                        : theme.primaryColor.withOpacity(0.08),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setDialogState(
                      () => tempState['showAvailableOnly'] = false,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          Text(
            'Product Type',
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
                  'Services',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showServicesOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showServicesOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showServicesOnly'] == true,
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
                    tempState['showServicesOnly'] = val;
                    if (val) {
                      tempState['showConsumablesOnly'] = false;
                      tempState['showStorableOnly'] = false;
                    }
                  });
                },
              ),
              ChoiceChip(
                label: Text(
                  'Consumables',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showConsumablesOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showConsumablesOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showConsumablesOnly'] == true,
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
                    tempState['showConsumablesOnly'] = val;
                    if (val) {
                      tempState['showServicesOnly'] = false;
                      tempState['showStorableOnly'] = false;
                    }
                  });
                },
              ),
              ChoiceChip(
                label: Text(
                  'Storable',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showStorableOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showStorableOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showStorableOnly'] == true,
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
                    tempState['showStorableOnly'] = val;
                    if (val) {
                      tempState['showServicesOnly'] = false;
                      tempState['showConsumablesOnly'] = false;
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Availability',
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
                  'Available Only',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: tempState['showAvailableOnly'] == true
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: tempState['showAvailableOnly'] == true
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                selected: tempState['showAvailableOnly'] == true,
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
                    setDialogState(() => tempState['showAvailableOnly'] = val),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProductGroupByTab(
    BuildContext context,
    StateSetter setDialogState,
    bool isDark,
    ThemeData theme,
    ProductProvider provider,
    Map<String, dynamic> tempState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Group products by',
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
                case 'categ_id':
                  description = 'Group by product category';
                  break;
                case 'type':
                  description = 'Group by product type';
                  break;
                case 'uom_id':
                  description = 'Group by unit of measure';
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

  Widget _buildOdooStyleGroupTile(
    String groupTitle,
    int count,
    bool isExpanded,
    ProductProvider provider,
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
                            '$count product${count != 1 ? 's' : ''}',
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
