import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../providers/last_opened_provider.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shimmer_loading.dart';
import '../../providers/currency_provider.dart';
import '../../services/odoo_api_service.dart';
import '../../widgets/full_image_screen.dart';
import '../../widgets/custom_snackbar.dart';
import 'product_sales_history_screen.dart';
import 'product_form_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({Key? key, required this.product})
    : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Product? _loadedProduct;
  List<String> _taxNames = [];
  double? _totalSold;
  double? _averageOrderValue;
  Map<String, dynamic>? _quotationLines;
  String? _lastSaleDate;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final prod = widget.product;
        if (prod.id != 0) {
          Provider.of<LastOpenedProvider>(
            context,
            listen: false,
          ).trackProductAccess(product: widget.product);
        }
      } catch (_) {}
    });

    _loadProductDetails();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadProductDetails() async {
    setState(() => _isLoading = true);

    try {
      final apiService = OdooApiService();
      final productId = widget.product.id;

      final result = await apiService
          .call(
            'product.product',
            'read',
            [
              [productId],
            ],
            {
              'fields': [
                'id',
                'name',
                'list_price',
                'default_code',
                'barcode',
                'categ_id',
                'image_128',
                'description_sale',
                'create_date',
                'currency_id',
                'standard_price',
                'qty_available',
                'weight',
                'volume',
                'cost_method',
                'property_stock_inventory',
                'property_stock_production',
                'taxes_id',
                'uom_id',
                'active',
              ],
            },
          )
          .timeout(const Duration(seconds: 15));

      if (result is List && result.isNotEmpty && mounted) {
        final productData = result[0] as Map<String, dynamic>;
        setState(() {
          _loadedProduct = Product.fromJson(productData);
        });

        await Future.wait([
          _loadTaxNames(apiService, productData),
          _loadSalesAnalytics(apiService, productId),
        ]);
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTaxNames(
    OdooApiService apiService,
    Map<String, dynamic> productData,
  ) async {
    try {
      if (productData['taxes_id'] is List &&
          (productData['taxes_id'] as List).isNotEmpty) {
        final taxesResult = await apiService
            .call(
              'account.tax',
              'search_read',
              [
                [
                  ['id', 'in', productData['taxes_id']],
                ],
              ],
              {
                'fields': ['name'],
              },
            )
            .timeout(const Duration(seconds: 15));

        if (taxesResult is List && mounted) {
          setState(() {
            _taxNames = taxesResult.map((t) => t['name'].toString()).toList();
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _loadSalesAnalytics(
    OdooApiService apiService,
    dynamic productId,
  ) async {
    try {
      final salesOrderResult = await apiService
          .call(
            'sale.order.line',
            'search_read',
            [
              [
                ['product_id', '=', productId],
                [
                  'state',
                  'in',
                  ['sale', 'done'],
                ],
              ],
            ],
            {
              'fields': [
                'product_uom_qty',
                'price_subtotal',
                'order_id',
                'create_date',
              ],
              'limit': 100,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (salesOrderResult is List && mounted) {
        double totalQuantity = 0;
        double totalValue = 0;
        String? lastDate;
        if (salesOrderResult.isNotEmpty) {
          lastDate = salesOrderResult[0]['create_date'];
        }
        for (var line in salesOrderResult) {
          totalQuantity += (line['product_uom_qty'] ?? 0.0);
          totalValue += (line['price_subtotal'] ?? 0.0);
        }
        setState(() {
          _totalSold = totalQuantity;
          _averageOrderValue = salesOrderResult.isNotEmpty
              ? totalValue / salesOrderResult.length
              : 0;
          _lastSaleDate = lastDate;
        });
      }

      final quotationResult = await apiService
          .call(
            'sale.order.line',
            'search_read',
            [
              [
                ['product_id', '=', productId],
                ['state', '=', 'draft'],
              ],
            ],
            {
              'fields': ['product_uom_qty', 'price_subtotal'],
              'limit': 50,
            },
          )
          .timeout(const Duration(seconds: 15));

      if (quotationResult is List && mounted) {
        double quotationQty = 0;
        for (var line in quotationResult) {
          quotationQty += (line['product_uom_qty'] ?? 0.0);
        }
        setState(() {
          _quotationLines = {
            'total_qty': quotationQty,
            'count': quotationResult.length,
          };
        });
      }
    } catch (e) {}
  }

  Product get _product => _loadedProduct ?? widget.product;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = _product;

    final salePrice = product.listPrice ?? 0.0;
    final available = (product.qtyAvailable ?? 0).toInt();
    final cost = product.standardPrice;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedPencilEdit02,
              color: _isLoading
                  ? (isDark ? Colors.grey[700] : Colors.grey[400])
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            tooltip: 'Edit Product',
            onPressed: _isLoading
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductFormScreen(
                          product: product,
                          isEditing: true,
                        ),
                      ),
                    );
                    if (result == true && context.mounted) {
                      Navigator.pop(context, 'updated');
                    }
                  },
          ),
          PopupMenuButton<String>(
            enabled: !_isLoading,
            icon: Icon(
              Icons.more_vert,
              color: (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 20,
            ),
            color: isDark ? Colors.grey[900] : Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'view_sales_history',
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAnalytics01,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'View Sales History',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'generate_barcode',
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedQrCode,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Generate Barcode',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'archive_product',
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArchive02,
                      color: isDark ? Colors.red[300] : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Archive Product',
                      style: TextStyle(
                        color: isDark ? Colors.red[300] : Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'view_sales_history':
                  _showSalesHistoryScreen(context);
                  break;
                case 'generate_barcode':
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showBarcodeGeneratorDialog(context);
                  });
                  break;
                case 'archive_product':
                  _showArchiveProductDialog(context);
                  break;
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const ProductDetailShimmer()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                color: isDark ? Colors.blue[200] : AppTheme.primaryColor,
                onRefresh: () async {
                  await _loadProductDetails();
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(context),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Pricing Information',
                        children: [
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, child) {
                              return _buildInfoRow(
                                'Sale Price',
                                currencyProvider.formatAmount(salePrice),
                                highlight: true,
                                valueColor: isDark
                                    ? Colors.white70
                                    : AppTheme.primaryColor,
                              );
                            },
                          ),
                          _buildInfoRow(
                            'Currency',
                            Provider.of<CurrencyProvider>(
                              context,
                              listen: false,
                            ).currency,
                          ),
                          if (product.cost != null)
                            Consumer<CurrencyProvider>(
                              builder: (context, currencyProvider, child) {
                                return _buildInfoRow(
                                  'Standard Price',
                                  currencyProvider.formatAmount(cost),
                                );
                              },
                            ),
                          if (product.cost != null)
                            Consumer<CurrencyProvider>(
                              builder: (context, currencyProvider, child) {
                                return _buildInfoRow(
                                  'Cost',
                                  currencyProvider.formatAmount(cost),
                                );
                              },
                            ),
                          _buildInfoRow(
                            'Taxes',
                            _taxNames.isNotEmpty
                                ? _taxNames.join(', ')
                                : 'None',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        title: 'Sales Performance',
                        children: [
                          _buildInfoRow(
                            'Total Sold',
                            '${_totalSold?.toStringAsFixed(1) ?? '0.0'} units',
                            highlight: false,
                            valueColor: isDark ? Colors.white70 : Colors.black,
                          ),
                          Consumer<CurrencyProvider>(
                            builder: (context, currencyProvider, child) {
                              return _buildInfoRow(
                                'Avg Order Value',
                                currencyProvider.formatAmount(
                                  _averageOrderValue ?? 0.0,
                                ),
                                valueColor: isDark
                                    ? Colors.white70
                                    : Colors.black,
                              );
                            },
                          ),
                          _buildInfoRow(
                            'In Quotations',
                            '${_quotationLines?['total_qty']?.toStringAsFixed(1) ?? '0.0'} units (${_quotationLines?['count'] ?? 0} quotes)',
                            valueColor: isDark ? Colors.white70 : Colors.black,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        title: 'Sales Analytics',
                        children: [
                          _buildInfoRow(
                            'Total Sales',
                            '${(_totalSold?.toInt() ?? 0)}',
                          ),
                          _buildInfoRow(
                            'Last Sale Date',
                            _lastSaleDate?.split('.')[0] ?? 'N/A',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        title: 'Inventory Information',
                        children: [
                          _buildInfoRow(
                            'Available Quantity',
                            available.toString(),
                            highlight: true,
                            valueColor: isDark
                                ? Colors.white70
                                : available > 0
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                          _buildInfoRow(
                            'Stock Status',
                            available > 0 ? 'In Stock' : 'Out of Stock',
                          ),
                          if (product.propertyStockInventory != null)
                            _buildInfoRow(
                              'Inventory Location',
                              _extractLocationName(
                                product.propertyStockInventory,
                              ),
                            ),
                          if (product.propertyStockProduction != null)
                            _buildInfoRow(
                              'Production Location',
                              _extractLocationName(
                                product.propertyStockProduction,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (product.weight != null || product.volume != null)
                        _buildSectionCard(
                          title: 'Shipping Information',
                          children: [
                            if (product.weight != null)
                              _buildInfoRow('Weight', '${product.weight} kg'),
                            if (product.volume != null)
                              _buildInfoRow('Volume', '${product.volume} m³'),
                          ],
                        ),
                      const SizedBox(height: 12),
                      if (product.costMethod != null)
                        _buildSectionCard(
                          title: 'Operations',
                          children: [
                            _buildInfoRow(
                              'Cost Method',
                              product.costMethod ?? 'N/A',
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      _buildSectionCard(
                        title: 'System Information',
                        children: [
                          if (product.createDate != null)
                            _buildInfoRow(
                              'Created',
                              product.createDate!.split('.')[0],
                            ),
                          _buildInfoRow('Product ID', product.id.toString()),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = _product;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtle = isDark ? Colors.white60 : Colors.black54;
    final dividerColor = isDark ? Colors.white12 : Colors.black12;

    final salePrice = product.listPrice ?? 0.0;
    final available = (product.qtyAvailable ?? 0).toInt();
    final category = product.categoryName ?? '';
    final defaultCodeVal = product.defaultCode;
    final defaultCode =
        (defaultCodeVal != null &&
            defaultCodeVal != false &&
            defaultCodeVal.toString().trim().isNotEmpty &&
            defaultCodeVal.toString().toLowerCase() != 'false' &&
            defaultCodeVal.toString().toLowerCase() != 'null')
        ? defaultCodeVal.toString()
        : '';
    final barcodeVal = product.barcode;
    final barcode =
        (barcodeVal != null &&
            barcodeVal != false &&
            barcodeVal.toString().trim().isNotEmpty)
        ? barcodeVal.toString()
        : '';

    Widget buildMetric(
      String label,
      String value, {
      Color? valueColor,
      CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
    }) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  final imageBase64 = product.image128 ?? product.imageUrl;

                  if (imageBase64 != null && imageBase64.isNotEmpty) {
                    try {
                      final base64Str = imageBase64.contains(',')
                          ? imageBase64.split(',').last
                          : imageBase64;
                      final bytes = base64Decode(base64Str);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullImageScreen(
                            imageBytes: bytes,
                            title: 'Product Image',
                            productId: product.id,
                          ),
                        ),
                      );
                    } catch (e) {}
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black26
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildProductImageContent(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: product.name.length > 20
                            ? 20
                            : (product.name.length > 15 ? 22 : 24),
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (category.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedFilterMailCircle,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                category,
                                style: TextStyle(color: subtle, fontSize: 12),
                              ),
                            ],
                          ),
                        if (defaultCode.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedQrCode,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                defaultCode,
                                style: TextStyle(color: subtle, fontSize: 12),
                              ),
                            ],
                          ),
                        if (barcode.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedBarCode02,
                                size: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                barcode,
                                style: TextStyle(color: subtle, fontSize: 12),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: buildMetric(
                  'Sale Price',
                  Provider.of<CurrencyProvider>(
                    context,
                    listen: false,
                  ).formatAmount(salePrice),
                  valueColor: isDark ? Colors.white : Colors.black,
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
              Expanded(
                child: buildMetric(
                  'Available',
                  available.toString(),
                  valueColor: isDark ? Colors.white : Colors.black,
                  crossAxisAlignment: CrossAxisAlignment.center,
                ),
              ),
              Expanded(
                child: buildMetric(
                  'Status',
                  available > 0 ? 'In Stock' : 'Out of Stock',
                  valueColor: available > 0
                      ? (isDark ? Colors.green[300] : Colors.green[700])
                      : (isDark ? Colors.red[300] : Colors.red[700]),
                  crossAxisAlignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductImageContent(bool isDark) {
    final product = _product;
    final imageBase64 = product.image128 ?? product.imageUrl;

    return Container(
      color: isDark ? Colors.white10 : Colors.grey[100],
      child: imageBase64 != null && imageBase64.isNotEmpty
          ? Image.memory(
              base64Decode(
                imageBase64.contains(',')
                    ? imageBase64.split(',').last
                    : imageBase64,
              ),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Text(
                  product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black45,
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                product.name.isNotEmpty ? product.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black45,
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[400],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool highlight = false,
    Color? valueColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? (isDark ? Colors.white : Colors.black),
                fontSize: 14,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extractLocationName(dynamic location) {
    if (location == null || location == false) return 'N/A';
    if (location is List && location.length >= 2) {
      return location[1]?.toString() ?? 'N/A';
    }
    return location.toString();
  }

  void _showSalesHistoryScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ProductSalesHistoryScreen(product: _product.toJson()),
      ),
    );
  }

  void _showBarcodeGeneratorDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final product = _product;
    final barcode = product.barcode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Generate Barcode',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (barcode != null &&
                  barcode != 'false' &&
                  barcode.isNotEmpty) ...[
                Text(
                  'Barcode',
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: barcode,
                    width: 200,
                    height: 80,
                    drawText: true,
                  ),
                ),
                const SizedBox(height: 24),
              ] else ...[
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedBarCode02,
                        size: 64,
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "This product doesn't have any barcode provided.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: isDark ? 0 : 3,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showArchiveProductDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Archive Product',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Text(
            'Are you sure you want to archive this product? This action will hide the product from active listings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _archiveProduct();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: isDark ? 0 : 3,
                  ),
                  child: const Text(
                    'Archive',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _archiveProduct() async {
    bool isLoaderShowing = false;

    final navigator = Navigator.of(context);

    try {
      final apiService = OdooApiService();
      final productId = widget.product.id;

      if (mounted) {
        _showLoadingDialog(
          context,
          'Archiving Product',
          'Please wait while we archive this product...',
        );
        isLoaderShowing = true;
      }

      final productResult = await apiService
          .call(
            'product.product',
            'read',
            [
              [productId],
            ],
            {
              'fields': ['product_tmpl_id'],
            },
          )
          .timeout(const Duration(seconds: 20));

      if (productResult is! List || productResult.isEmpty) {
        if (mounted && isLoaderShowing) {
          navigator.pop();
          isLoaderShowing = false;
        }
        throw Exception('Product not found');
      }

      final templateId = (productResult[0]['product_tmpl_id'] as List?)?.first;

      final result1 = await apiService
          .call('product.product', 'write', [
            [productId],
            {'active': false},
          ])
          .timeout(const Duration(seconds: 20));

      var result2 = true;
      if (templateId != null) {
        result2 = await apiService
            .call('product.template', 'write', [
              [templateId],
              {'active': false},
            ])
            .timeout(const Duration(seconds: 20));
      }

      if (mounted && isLoaderShowing) {
        navigator.pop();
        isLoaderShowing = false;
      }

      if (result1 == true && result2 == true) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception(
          'Failed to archive product or template. Odoo returned: product:$result1, template:$result2',
        );
      }
    } catch (e) {
      if (mounted) {
        if (isLoaderShowing) {
          navigator.pop();
          isLoaderShowing = false;
        }
        CustomSnackbar.showError(context, 'Failed to archive product: $e');
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: LoadingAnimationWidget.fourRotatingDots(
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
