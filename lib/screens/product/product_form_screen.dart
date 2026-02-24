import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/odoo_api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_text_field_simple.dart' as simple;
import '../../models/product.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../services/runtime_permission_service.dart';
import '../../services/odoo_error_handler.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final bool isEditing;

  const ProductFormScreen({Key? key, this.product, this.isEditing = false})
    : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  final OdooApiService _apiService = OdooApiService();

  late TextEditingController _nameController;
  late TextEditingController _defaultCodeController;
  late TextEditingController _barcodeController;
  late TextEditingController _listPriceController;
  late TextEditingController _standardPriceController;
  late TextEditingController _weightController;
  late TextEditingController _volumeController;
  late TextEditingController _descriptionController;

  List<Map<String, dynamic>> _categoryOptions = [];
  List<Map<String, dynamic>> _taxOptions = [];
  List<Map<String, dynamic>> _uomOptions = [];
  List<Map<String, dynamic>> _currencyOptions = [];
  bool _dropdownsLoading = true;

  int? _selectedCategory;
  int? _selectedTax;
  int? _selectedUOM;
  int? _selectedCurrency;
  bool _isActive = true;
  bool _canBeSold = true;
  bool _canBePurchased = true;

  bool _isLoading = false;
  bool _isEditMode = false;
  String? _imageBase64;
  File? _pickedImageFile;
  String? _pickedImageBase64;
  final ImagePicker _picker = ImagePicker();

  bool get _isNameFilled => _nameController.text.trim().isNotEmpty;

  @override
  bool get hasUnsavedData {
    if (_isEditMode || _isLoading) return false;
    return _nameController.text.isNotEmpty ||
        _defaultCodeController.text.isNotEmpty ||
        _barcodeController.text.isNotEmpty ||
        _listPriceController.text.isNotEmpty ||
        _standardPriceController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _pickedImageFile != null;
  }

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.product != null;
    final p = widget.product;
    String clean(String? v) => (v == null || v == 'false') ? '' : v;

    _nameController = TextEditingController(text: p?.name ?? '');
    _defaultCodeController = TextEditingController(text: p?.defaultCode ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _descriptionController = TextEditingController(
      text: p?.descriptionSale ?? '',
    );
    _listPriceController = TextEditingController(
      text: p?.listPrice.toString() ?? '',
    );
    _standardPriceController = TextEditingController(
      text: p?.standardPrice.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: p?.weight?.toString() ?? '',
    );
    _volumeController = TextEditingController(
      text: p?.volume?.toString() ?? '',
    );

    _isActive = p?.active ?? true;
    _canBeSold = p?.saleOk ?? true;
    _canBePurchased = p?.purchaseOk ?? true;

    if (widget.product != null) {
      _imageBase64 = p?.image128;
    }

    _fetchDropdowns();
    _nameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _defaultCodeController.dispose();
    _barcodeController.dispose();
    _listPriceController.dispose();
    _standardPriceController.dispose();
    _weightController.dispose();
    _volumeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdowns() async {
    setState(() {
      _dropdownsLoading = true;
    });

    try {
      final categories = await _apiService.searchRead('product.category', [], [
        'name',
      ]);
      _categoryOptions = categories
          .map((c) => {'id': c['id'] as int, 'name': c['name'].toString()})
          .toList();

      final taxes = await _apiService.searchRead('account.tax', [], ['name']);
      _taxOptions = taxes
          .map((t) => {'id': t['id'] as int, 'name': t['name'].toString()})
          .toList();

      final uoms = await _apiService.searchRead('uom.uom', [], ['name']);
      _uomOptions = uoms
          .map((u) => {'id': u['id'] as int, 'name': u['name'].toString()})
          .toList();

      final currencies = await _apiService.searchRead('res.currency', [], [
        'name',
        'symbol',
      ]);
      _currencyOptions = currencies
          .map(
            (c) => {
              'id': c['id'] as int,
              'name': c['name'].toString(),
              'symbol': c['symbol']?.toString() ?? '',
            },
          )
          .toList();

      final p = widget.product;
      if (p != null) {
        _selectedCategory = p.categoryId;
        _selectedTax = (p.taxesId?.isNotEmpty ?? false) ? p.taxesId![0] : null;
        _selectedUOM = p.uomId;
        _selectedCurrency = p.currencyId is List
            ? p.currencyId[0]
            : p.currencyId;
      }

      setState(() {
        _dropdownsLoading = false;
      });
    } catch (e) {
      setState(() {
        _dropdownsLoading = false;
      });
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to load options: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasPermission = await RuntimePermissionService.requestCameraPermission(context);
      if (!hasPermission) return;
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 600,
    );
    if (picked != null) {
      setState(() {
        _pickedImageFile = File(picked.path);
      });
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImageBase64 = base64Encode(bytes);
      });
    }
  }

  void _showImageSourceActionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Photo Options',
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
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.camera);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera02,
                        size: 20,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Take Photo',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromSource(ImageSource.gallery);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedImageCrop,
                        size: 20,
                        color: isDark ? Colors.white : primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;

    if (_dropdownsLoading) {
      return PopScope(
        canPop: !hasUnsavedData,
        onPopInvoked: (didPop) async {
          if (didPop) return;
          final shouldPop = await handleWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _isEditMode ? 'Edit Product' : 'Create Product',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            foregroundColor: isDark ? Colors.white : primaryColor,
            elevation: 0,
            leading: IconButton(
              onPressed: () => handleNavigation(() => Navigator.pop(context)),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          body: _buildShimmerLoading(isDark),
        ),
      );
    }

    Widget photoWidget;
    if (_pickedImageFile != null) {
      photoWidget = CircleAvatar(
        radius: 48,
        backgroundColor: isDark
            ? Colors.grey.shade200
            : primaryColor.withOpacity(.1),
        backgroundImage: FileImage(_pickedImageFile!),
      );
    } else if (_imageBase64 != null && _imageBase64!.isNotEmpty) {
      try {
        final base64String = _imageBase64!.contains(',')
            ? _imageBase64!.split(',').last
            : _imageBase64!;
        final bytes = base64Decode(base64String);
        photoWidget = CircleAvatar(
          radius: 48,
          backgroundColor: isDark
              ? Colors.grey.shade200
              : primaryColor.withOpacity(.1),
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        photoWidget = CircleAvatar(
          radius: 48,
          backgroundColor: isDark
              ? Colors.grey.shade200
              : primaryColor.withOpacity(.1),
          child: Icon(
            Icons.image,
            size: 48,
            color: isDark ? Colors.grey.shade800 : primaryColor,
          ),
        );
      }
    } else {
      photoWidget = CircleAvatar(
        radius: 48,
        backgroundColor: isDark
            ? Colors.grey.shade200
            : primaryColor.withOpacity(.1),
        child: Icon(
          Icons.image,
          size: 48,
          color: isDark ? Colors.grey.shade800 : primaryColor,
        ),
      );
    }

    return PopScope(
      canPop: !hasUnsavedData,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await handleWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'Edit Product' : 'Create Product',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          foregroundColor: isDark ? Colors.white : primaryColor,
          elevation: 0,
          leading: IconButton(
            onPressed: () => handleNavigation(() => Navigator.pop(context)),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    photoWidget,
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isLoading ? null : _showImageSourceActionSheet,
                        borderRadius: BorderRadius.circular(24),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: isDark ? Colors.grey : primaryColor,
                          child: Icon(
                            Icons.add_a_photo,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              simple.CustomTextField(
                controller: _nameController,
                labelText: 'Product Name *',
                hintText: 'Enter product name',
                isDark: isDark,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Product name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _defaultCodeController,
                labelText: 'SKU/Default Code',
                hintText: 'Enter SKU',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _barcodeController,
                labelText: 'Barcode',
                hintText: 'Enter barcode',
                isDark: isDark,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final hasPermission = await RuntimePermissionService.requestCameraPermission(context);
                    if (hasPermission && mounted) {
                      CustomSnackbar.showInfo(context, 'Barcode scanner integration coming soon!');
                    }
                  },
                  tooltip: 'Scan Barcode',
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return PopupMenuButton<int>(
                        initialValue: _selectedCategory,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          maxHeight: 400,
                        ),
                        offset: const Offset(0, 56),
                        color: isDark ? Colors.grey[850] : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        onSelected: (val) {
                          setState(() => _selectedCategory = val);
                        },
                        itemBuilder: (context) => _categoryOptions.isEmpty
                            ? [
                                PopupMenuItem<int>(
                                  enabled: false,
                                  child: Text(
                                    'No records found',
                                    style: GoogleFonts.manrope(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ]
                            : _categoryOptions
                                  .map(
                                    (cat) => PopupMenuItem<int>(
                                      value: cat['id'] as int,
                                      child: Text(
                                        cat['name'] as String,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xffF8FAFB),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _categoryOptions.isEmpty
                                      ? 'No records found'
                                      : (_selectedCategory != null
                                            ? (_categoryOptions.firstWhere(
                                                    (cat) =>
                                                        cat['id'] ==
                                                        _selectedCategory,
                                                    orElse: () => {
                                                      'name':
                                                          'Select a product category',
                                                    },
                                                  )['name']
                                                  as String)
                                            : 'Select a product category'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _categoryOptions.isEmpty
                                        ? Colors.grey
                                        : (_selectedCategory != null
                                              ? (isDark
                                                    ? Colors.white70
                                                    : const Color(0xff000000))
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600])),
                                    fontStyle:
                                        (_selectedCategory == null ||
                                            _categoryOptions.isEmpty)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _listPriceController,
                labelText: 'List Price',
                hintText: 'Enter selling price',
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _standardPriceController,
                labelText: 'Cost Price',
                hintText: 'Enter cost price',
                isDark: isDark,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.trim().isNotEmpty) {
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tax',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return PopupMenuButton<int>(
                        initialValue: _selectedTax,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          maxHeight: 400,
                        ),
                        offset: const Offset(0, 56),
                        color: isDark ? Colors.grey[850] : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        onSelected: (val) {
                          setState(() => _selectedTax = val);
                        },
                        itemBuilder: (context) => _taxOptions.isEmpty
                            ? [
                                PopupMenuItem<int>(
                                  enabled: false,
                                  child: Text(
                                    'No records found',
                                    style: GoogleFonts.manrope(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ]
                            : _taxOptions
                                  .map(
                                    (tax) => PopupMenuItem<int>(
                                      value: tax['id'] as int,
                                      child: Text(
                                        tax['name'] as String,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xffF8FAFB),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _taxOptions.isEmpty
                                      ? 'No records found'
                                      : (_selectedTax != null
                                            ? (_taxOptions.firstWhere(
                                                    (tax) =>
                                                        tax['id'] ==
                                                        _selectedTax,
                                                    orElse: () => {
                                                      'name':
                                                          'Select applicable tax',
                                                    },
                                                  )['name']
                                                  as String)
                                            : 'Select applicable tax'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _taxOptions.isEmpty
                                        ? Colors.grey
                                        : (_selectedTax != null
                                              ? (isDark
                                                    ? Colors.white70
                                                    : const Color(0xff000000))
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600])),
                                    fontStyle:
                                        (_selectedTax == null ||
                                            _taxOptions.isEmpty)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unit of Measure',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return PopupMenuButton<int>(
                        initialValue: _selectedUOM,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          maxHeight: 400,
                        ),
                        offset: const Offset(0, 56),
                        color: isDark ? Colors.grey[850] : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        onSelected: (val) {
                          setState(() => _selectedUOM = val);
                        },
                        itemBuilder: (context) => _uomOptions.isEmpty
                            ? [
                                PopupMenuItem<int>(
                                  enabled: false,
                                  child: Text(
                                    'No records found',
                                    style: GoogleFonts.manrope(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ]
                            : _uomOptions
                                  .map(
                                    (uom) => PopupMenuItem<int>(
                                      value: uom['id'] as int,
                                      child: Text(
                                        uom['name'] as String,
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xffF8FAFB),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _uomOptions.isEmpty
                                      ? 'No records found'
                                      : (_selectedUOM != null
                                            ? (_uomOptions.firstWhere(
                                                    (uom) =>
                                                        uom['id'] ==
                                                        _selectedUOM,
                                                    orElse: () => {
                                                      'name': 'Select unit',
                                                    },
                                                  )['name']
                                                  as String)
                                            : 'Select unit'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _uomOptions.isEmpty
                                        ? Colors.grey
                                        : (_selectedUOM != null
                                              ? (isDark
                                                    ? Colors.white70
                                                    : const Color(0xff000000))
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600])),
                                    fontStyle:
                                        (_selectedUOM == null ||
                                            _uomOptions.isEmpty)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Currency',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return PopupMenuButton<int>(
                        initialValue: _selectedCurrency,
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                          maxWidth: constraints.maxWidth,
                          maxHeight: 400,
                        ),
                        offset: const Offset(0, 56),
                        color: isDark ? Colors.grey[850] : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        onSelected: (val) {
                          setState(() => _selectedCurrency = val);
                        },
                        itemBuilder: (context) => _currencyOptions.isEmpty
                            ? [
                                PopupMenuItem<int>(
                                  enabled: false,
                                  child: Text(
                                    'No records found',
                                    style: GoogleFonts.manrope(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ]
                            : _currencyOptions
                                  .map(
                                    (curr) => PopupMenuItem<int>(
                                      value: curr['id'] as int,
                                      child: Text(
                                        '${curr['name']} (${curr['symbol']})',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? const Color(0xFF2A2A2A)
                                : const Color(0xffF8FAFB),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _currencyOptions.isEmpty
                                      ? 'No records found'
                                      : (_selectedCurrency != null
                                            ? (() {
                                                final curr = _currencyOptions
                                                    .firstWhere(
                                                      (c) =>
                                                          c['id'] ==
                                                          _selectedCurrency,
                                                      orElse: () => {
                                                        'name':
                                                            'Select currency',
                                                        'symbol': '',
                                                      },
                                                    );
                                                return '${curr['name']} (${curr['symbol']})';
                                              })()
                                            : 'Select currency'),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _currencyOptions.isEmpty
                                        ? Colors.grey
                                        : (_selectedCurrency != null
                                              ? (isDark
                                                    ? Colors.white70
                                                    : const Color(0xff000000))
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600])),
                                    fontStyle:
                                        (_selectedCurrency == null ||
                                            _currencyOptions.isEmpty)
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _weightController,
                labelText: 'Weight',
                hintText: 'Enter weight in kg',
                isDark: isDark,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _volumeController,
                labelText: 'Volume',
                hintText: 'Enter volume in cubic meters',
                isDark: isDark,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              simple.CustomTextField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Enter a product description',
                isDark: isDark,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    checkColor: Colors.white,
                    activeColor: isDark ? Colors.grey : primaryColor,
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v ?? true),
                  ),
                  const Text('Active'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    checkColor: Colors.white,
                    activeColor: isDark ? Colors.grey : primaryColor,
                    value: _canBeSold,
                    onChanged: (v) => setState(() => _canBeSold = v ?? true),
                  ),
                  const Text('Can be Sold'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    checkColor: Colors.white,
                    activeColor: isDark ? Colors.grey : primaryColor,
                    value: _canBePurchased,
                    onChanged: (v) =>
                        setState(() => _canBePurchased = v ?? true),
                  ),
                  const Text('Can be Purchased'),
                ],
              ),
              const SizedBox(height: 24),
              SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isNameFilled)
                        ? null
                        : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: isDark
                          ? Colors.grey[700]!
                          : Colors.grey[400]!,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isEditMode ? 'Save Changes' : 'Create Product',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: List.generate(
          10,
          (index) => Container(
            height: 44,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final productData = {
        'name': _nameController.text,
        'default_code': _defaultCodeController.text.isEmpty
            ? false
            : _defaultCodeController.text,
        'barcode': _barcodeController.text.isEmpty
            ? false
            : _barcodeController.text,
        'list_price': double.tryParse(_listPriceController.text) ?? 0.0,
        'standard_price': double.tryParse(_standardPriceController.text) ?? 0.0,
        'weight': double.tryParse(_weightController.text) ?? 0.0,
        'volume': double.tryParse(_volumeController.text) ?? 0.0,
        'description_sale': _descriptionController.text.isEmpty
            ? false
            : _descriptionController.text,
        'active': _isActive,
        'sale_ok': _canBeSold,
        'purchase_ok': _canBePurchased,
        'image_1920': _pickedImageBase64 ?? _imageBase64 ?? false,
      };

      if (_selectedCategory != null) {
        productData['categ_id'] = _selectedCategory!;
      }
      if (_selectedTax != null) {
        productData['taxes_id'] = [
          [
            6,
            0,
            [_selectedTax!],
          ],
        ];
      }
      if (_selectedUOM != null) {
        productData['uom_id'] = _selectedUOM!;
      }
      if (_selectedCurrency != null) {
        productData['currency_id'] = _selectedCurrency!;
      }

      if (widget.product != null) {
        final result = await _apiService.write('product.product', [
          widget.product!.id,
        ], productData);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.pop(context, true);

          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              CustomSnackbar.showSuccess(
                context,
                'Product updated successfully',
              );
            }
          });
        }
      } else {
        final newId = await _apiService.create('product.product', productData);

        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          Navigator.pop(context, true);

          Future.delayed(const Duration(milliseconds: 100), () {
            if (context.mounted) {
              CustomSnackbar.showSuccess(
                context,
                'Product created successfully',
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        final userMessage = OdooErrorHandler.toUserMessage(e);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Failed to Save Product',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: Text(userMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
