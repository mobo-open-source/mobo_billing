import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/confetti_dialog.dart';
import 'dart:math' as math;
import '../../widgets/custom_snackbar.dart';
import '../../widgets/location_map_widget.dart';
import 'select_location_screen.dart';
import '../../providers/customer_provider.dart';
import 'package:latlong2/latlong.dart';
import 'customer_form_screen.dart';
import '../../models/customer.dart';
import '../../widgets/full_image_screen.dart';
import '../../providers/last_opened_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/runtime_permission_service.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer? customer;
  final bool isEditing;

  const CustomerDetailsScreen({Key? key, this.customer, this.isEditing = false})
    : super(key: key);

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController = TextEditingController();
  late TextEditingController _emailController = TextEditingController();
  late TextEditingController _phoneController = TextEditingController();
  late TextEditingController _mobileController = TextEditingController();
  late TextEditingController _vatController = TextEditingController();
  late TextEditingController _websiteController = TextEditingController();
  late TextEditingController _streetController = TextEditingController();
  late TextEditingController _street2Controller = TextEditingController();
  late TextEditingController _cityController = TextEditingController();
  late TextEditingController _zipController = TextEditingController();
  late TextEditingController _commentController = TextEditingController();
  late TextEditingController _jobPositionController = TextEditingController();
  late TextEditingController _creditLimitController = TextEditingController();
  late TextEditingController _industryController = TextEditingController();
  late TextEditingController _companyNameController = TextEditingController();
  late TextEditingController _languageController = TextEditingController();
  late TextEditingController _timezoneController = TextEditingController();
  late TextEditingController _salespersonController = TextEditingController();
  late TextEditingController _paymentTermsController = TextEditingController();
  late TextEditingController _countryController = TextEditingController();
  late TextEditingController _stateController = TextEditingController();

  bool isReal(String? v) =>
      v != null && v.trim().isNotEmpty && v.trim().toLowerCase() != 'false';

  bool _isCompany = false;
  bool _isSupplier = false;
  bool _isCustomer = true;
  bool _isLoading = false;
  bool _isLoadingData = false;
  bool _isEditMode = false;
  bool _hasUnsavedChanges = false;
  String _error = '';
  String? _selectedImageBase64;
  final ImagePicker _imagePicker = ImagePicker();

  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  List<dynamic> _titles = [];
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _languages = [];

  int? _selectedCountryId;
  int? _selectedStateId;
  String? _selectedTitle;
  int? _selectedCurrencyId;
  int? _selectedLanguageId;

  bool _isLoadingDropdowns = true;
  bool _isLoadingStates = false;

  Customer? _currentCustomer;
  Map<String, dynamic>? _customerStats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _currentCustomer = widget.customer;
    _isEditMode = widget.customer == null;
    _populateForm();
    _loadAllData();
    _setupChangeListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentCustomer != null) {
        try {
          Provider.of<LastOpenedProvider>(
            context,
            listen: false,
          ).trackCustomerAccess(customer: _currentCustomer!);
        } catch (_) {}
      }
    });
  }

  Future<void> _loadAllData() async {
    if (widget.customer == null) {
      await _loadDropdowns();
      return;
    }

    setState(() {
      _isLoadingData = true;
    });

    try {
      await Future.wait([
        _loadDropdowns(),
        _loadCustomerStats(),
        _refreshCustomerData(),
      ]);
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _refreshCustomerData() async {
    if (_currentCustomer == null || _currentCustomer!.id == null) return;

    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final updatedCustomer = await provider.getCustomerDetails(
        _currentCustomer!.id!,
      );

      if (updatedCustomer != null && mounted) {
        setState(() {
          _currentCustomer = updatedCustomer;
          _populateForm();
        });
      }
    } catch (e) {}
  }

  Future<void> _refreshData() async {
    await _loadAllData();
  }

  void _setupChangeListeners() {
    _nameController.addListener(() => _hasUnsavedChanges = true);
    _emailController.addListener(() => _hasUnsavedChanges = true);
    _phoneController.addListener(() => _hasUnsavedChanges = true);
  }

  Future<void> _loadDropdowns() async {
    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final results = await provider.fetchDropdownOptions();

      if (mounted) {
        setState(() {
          _countries = results['countries'] as List<Map<String, dynamic>>;
          _titles = results['titles'] as List<dynamic>;
          _currencies = results['currencies'] as List<Map<String, dynamic>>;
          _languages = results['languages'] as List<Map<String, dynamic>>;

          if (_currentCustomer != null && _currentCustomer!.lang != null) {
            final langCode = _currentCustomer!.lang!.toString();
            try {
              final langRecord = _languages.firstWhere(
                (l) => l['code'] == langCode,
                orElse: () => <String, dynamic>{},
              );
              if (langRecord.isNotEmpty) {
                _selectedLanguageId = langRecord['id'] as int?;
              }
            } catch (e) {}
          }

          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDropdowns = false;
          _error = 'Failed to load dropdown options: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadStates(int countryId) async {
    setState(() {
      _isLoadingStates = true;
      _selectedStateId = null;
      _states = [];
    });

    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final states = await provider.fetchStates(countryId);
      if (mounted) {
        setState(() {
          _states = states;
          _isLoadingStates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStates = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(CustomerDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customer != null && widget.customer != oldWidget.customer) {
      _populateForm();
    }
  }

  Future<void> _loadCustomerStats() async {
    if (_currentCustomer == null || _currentCustomer!.id == null) return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final stats = await provider.getCustomerStats(_currentCustomer!.id!);
      if (mounted) {
        setState(() {
          _customerStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  void _populateForm() {
    if (_currentCustomer == null) return;

    final customer = _currentCustomer!;
    _nameController.text = customer.name;
    _emailController.text = customer.email ?? '';
    _phoneController.text = customer.phone ?? '';
    _mobileController.text = customer.mobile ?? '';
    _vatController.text = customer.vat ?? '';
    _streetController.text = customer.street ?? '';
    _street2Controller.text = customer.street2 ?? '';
    _cityController.text = customer.city ?? '';
    _zipController.text = customer.zip ?? '';
    _websiteController.text = customer.website ?? '';
    _commentController.text = customer.comment ?? '';
    _jobPositionController.text = customer.function ?? '';
    _creditLimitController.text = customer.creditLimit ?? '';
    _industryController.text = customer.industry ?? '';
    _companyNameController.text = customer.companyName ?? '';
    _languageController.text = customer.lang ?? '';
    _timezoneController.text = customer.tz ?? '';
    _salespersonController.text = customer.userId?.toString() ?? '';
    _paymentTermsController.text =
        customer.propertyPaymentTermId?.toString() ?? '';
    _countryController.text = customer.countryName ?? '';
    _stateController.text = customer.stateName ?? '';
    _selectedImageBase64 = customer.image128;

    _selectedCountryId = customer.countryId;
    if (_selectedCountryId != null) {
      _loadStates(_selectedCountryId!);
    }
    _selectedStateId = customer.stateId;
    _selectedTitle = customer.title;
    _selectedCurrencyId = customer.currencyId is List
        ? customer.currencyId[0]
        : customer.currencyId;

    _selectedLanguageId =
        int.tryParse(customer.lang ?? '') ??
        (customer.lang is int ? customer.lang as int : null);

    _isCompany = customer.isCompany;
    _isSupplier = customer.supplierRank > 0;
    _isCustomer = customer.customerRank > 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _vatController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _websiteController.dispose();
    _commentController.dispose();
    _jobPositionController.dispose();
    _creditLimitController.dispose();
    _industryController.dispose();
    _companyNameController.dispose();
    _languageController.dispose();
    _timezoneController.dispose();
    _salespersonController.dispose();
    _paymentTermsController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _viewFullImage() {
    if (_selectedImageBase64 != null &&
        _selectedImageBase64!.isNotEmpty &&
        _selectedImageBase64 != 'false') {
      try {
        final base64Str = _selectedImageBase64!.contains(',')
            ? _selectedImageBase64!.split(',').last
            : _selectedImageBase64!;
        final bytes = base64Decode(base64Str);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FullImageScreen(imageBytes: bytes, title: _getName()),
          ),
        );
      } catch (e) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_hasUnsavedChanges || !_isEditMode,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_hasUnsavedChanges && _isEditMode) {
          final shouldPop = await _showDiscardDialog(context);
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[900]
            : const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: theme.brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.customer == null
                ? 'New Customer'
                : (_isEditMode ? 'Edit Customer' : 'Customer Details'),
          ),
          actions: [
            if (widget.customer != null && !_isEditMode)
              IconButton(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedPencilEdit02,
                  color:
                      (_isLoading || _isLoadingData || _currentCustomer == null)
                      ? (theme.brightness == Brightness.dark
                            ? Colors.grey[700]
                            : Colors.grey[400])
                      : (theme.brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600]),
                ),
                onPressed:
                    (_isLoading || _isLoadingData || _currentCustomer == null)
                    ? null
                    : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerFormScreen(
                              customer: _currentCustomer,
                              isEditing: true,
                            ),
                          ),
                        );
                        if (result == true) {
                          _refreshData();
                        }
                      },
              ),
            if (widget.customer != null && !_isEditMode)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: theme.brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Colors.white,
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareContact();
                      break;
                    case 'copy':
                      _copyContactInfo();
                      break;
                    case 'location':
                      _handleLocationPress();
                      break;
                    case 'archive':
                      _archiveCustomer();
                      break;
                    case 'delete':
                      _showDeleteDialog();
                      break;
                  }
                },
                itemBuilder: (context) {
                  final isDark = theme.brightness == Brightness.dark;
                  return [
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedShare01,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Share Contact',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedCopy02,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Copy Info',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'location',
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCoordinate01,
                                color: isDark
                                    ? Colors.grey[300]!
                                    : Colors.grey[800]!,
                                size: 20,
                              ),
                              if (widget.customer == null ||
                                  _currentCustomer!.partnerLatitude == null ||
                                  _currentCustomer!.partnerLatitude == 0.0 ||
                                  _currentCustomer!.partnerLongitude == null ||
                                  _currentCustomer!.partnerLongitude == 0.0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF1A1C1E)
                                            : Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            widget.customer != null &&
                                    _currentCustomer!.partnerLatitude != null &&
                                    _currentCustomer!.partnerLatitude != 0.0 &&
                                    _currentCustomer!.partnerLongitude !=
                                        null &&
                                    _currentCustomer!.partnerLongitude != 0.0
                                ? 'Change Customer Location'
                                : 'Set Customer Location',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArchive03,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Archive Customer',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedDelete02,
                            color: Colors.red[400]!,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete Customer',
                            style: TextStyle(
                              color: Colors.red[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
        body: _isLoading
            ? const CustomerDetailShimmer()
            : _isLoadingData
            ? const CustomerDetailShimmer()
            : RefreshIndicator(
                onRefresh: _refreshData,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_error.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade600,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        _buildCustomerHeader(),

                        const SizedBox(height: 24),

                        if (!_isEditMode) ...[_buildAllInfoExpansionTiles()],

                        if (_isEditMode) ...[
                          _buildSectionHeader(
                            'Main Information',
                            Icons.person_outline,
                          ),

                          _buildFormField(
                            label: 'Name *',
                            value: _nameController.text,
                            controller: _nameController,
                            isRequired: true,
                            icon: Icons.person,
                          ),

                          _buildFormField(
                            label: 'Job Position',
                            value: _jobPositionController.text,
                            controller: _jobPositionController,
                            icon: Icons.work_outline,
                          ),

                          const SizedBox(height: 16),

                          _buildSectionHeader(
                            'Contact Information',
                            Icons.contact_phone_outlined,
                          ),

                          _buildFormField(
                            label: 'Email',
                            value: _emailController.text,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            icon: Icons.email_outlined,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: 'Phone',
                                  value: _phoneController.text,
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildFormField(
                                  label: 'Mobile',
                                  value: _mobileController.text,
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  icon: Icons.smartphone_outlined,
                                ),
                              ),
                            ],
                          ),

                          _buildFormField(
                            label: 'Website',
                            value: _websiteController.text,
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                            icon: Icons.language_outlined,
                          ),

                          const SizedBox(height: 16),

                          _buildSectionHeader(
                            'Address Information',
                            Icons.location_on_outlined,
                          ),

                          _buildFormField(
                            label: 'Street Address',
                            value: _streetController.text,
                            controller: _streetController,
                            icon: Icons.home_outlined,
                          ),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildFormField(
                                  label: 'City',
                                  value: _cityController.text,
                                  controller: _cityController,
                                  icon: Icons.location_city_outlined,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  label: 'ZIP Code',
                                  value: _zipController.text,
                                  controller: _zipController,
                                  icon: Icons.markunread_mailbox_outlined,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          _buildSectionHeader(
                            'Business Information',
                            Icons.business_outlined,
                          ),

                          _buildFormField(
                            label: 'Tax ID',
                            value: _vatController.text,
                            controller: _vatController,
                            icon: Icons.receipt_long_outlined,
                          ),

                          _buildFormField(
                            label: 'Industry',
                            value: _industryController.text,
                            controller: _industryController,
                            icon: Icons.factory_outlined,
                          ),

                          _buildFormField(
                            label: 'Credit Limit',
                            value: _creditLimitController.text,
                            controller: _creditLimitController,
                            keyboardType: TextInputType.number,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!_isEditMode) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _error = '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.grey.shade50,
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveCustomer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    shadowColor: Colors.transparent,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.customer == null
                                  ? Icons.add_rounded
                                  : Icons.check_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.customer == null
                                  ? 'Create Customer'
                                  : 'Save Changes',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final customerData = {
        'name': _nameController.text,
        'email': _emailController.text.isEmpty ? false : _emailController.text,
        'phone': _phoneController.text.isEmpty ? false : _phoneController.text,
        'mobile': _mobileController.text.isEmpty
            ? false
            : _mobileController.text,
        'vat': _vatController.text.isEmpty ? false : _vatController.text,
        'street': _streetController.text.isEmpty
            ? false
            : _streetController.text,
        'street2': _street2Controller.text.isEmpty
            ? false
            : _street2Controller.text,
        'city': _cityController.text.isEmpty ? false : _cityController.text,
        'zip': _zipController.text.trim(),
        'website': _websiteController.text.trim(),
        'comment': _commentController.text.trim(),
        'function': _jobPositionController.text.trim(),
        'is_company': _isCompany,
        'customer_rank': _isCustomer ? 1 : 0,
        'supplier_rank': _isSupplier ? 1 : 0,
      };

      if (_creditLimitController.text.isNotEmpty) {
        customerData['credit_limit'] =
            double.tryParse(_creditLimitController.text) ?? 0.0;
      }
      if (_industryController.text.isNotEmpty) {
        customerData['industry_id'] = _industryController.text;
      }
      if (_selectedCountryId != null) {
        customerData['country_id'] = _selectedCountryId!;
      }
      if (_selectedStateId != null) {
        customerData['state_id'] = _selectedStateId!;
      }
      if (_selectedTitle != null) {
        customerData['title'] = int.tryParse(_selectedTitle!) ?? false;
      }
      if (_selectedCurrencyId != null) {
        customerData['currency_id'] = _selectedCurrencyId!;
      }
      if (_selectedLanguageId != null) {
        final langRecord = _languages.firstWhere(
          (l) => l['id'] == _selectedLanguageId,
          orElse: () => <String, dynamic>{},
        );
        if (langRecord.isNotEmpty) {
          customerData['lang'] = langRecord['code'];
        }
      }

      if (_selectedImageBase64 != null && _selectedImageBase64!.isNotEmpty) {
        customerData['image_128'] = _selectedImageBase64!;
      }

      final provider = Provider.of<CustomerProvider>(context, listen: false);

      if (widget.customer != null) {
        await provider.updateCustomer(_currentCustomer!.id!, customerData);
        if (mounted) {
          setState(() {
            _isEditMode = false;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          CustomSnackbar.showSuccess(context, 'Customer updated successfully');
        }
      } else {
        await provider.createCustomer(customerData);
        if (mounted) {
          _hasUnsavedChanges = false;
          showCustomerCreatedConfettiDialog(context, _nameController.text);
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to save customer: ${e.toString()}',
        );
      }
      setState(() {
        _error = 'Failed to save customer: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete Customer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this customer? This action cannot be undone.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
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
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
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
                    Navigator.pop(context);
                    _deleteCustomer();
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
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: const Text(
                    'Delete',
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

  Future<void> _archiveCustomer() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Archive Customer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Are you sure you want to archive this customer?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
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
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
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
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
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

    if (confirm != true) return;

    _showLoadingDialog(
      context,
      'Archiving Customer',
      'Please wait while we archive this customer...',
    );

    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      await provider.archiveCustomer(_currentCustomer!.id!);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        CustomSnackbar.showSuccess(context, 'Customer archived successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        CustomSnackbar.showError(
          context,
          'Failed to archive customer: ${e.toString()}',
        );
        setState(() {
          _error = 'Failed to archive customer: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _deleteCustomer() async {
    _showLoadingDialog(
      context,
      'Deleting Customer',
      'Please wait while we delete this customer...',
    );

    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      await provider.deleteCustomer(_currentCustomer!.id!);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        CustomSnackbar.showSuccess(context, 'Customer deleted successfully');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        CustomSnackbar.showError(
          context,
          'Failed to delete customer: ${e.toString()}',
        );
        setState(() {
          _error = 'Failed to delete customer: ${e.toString()}';
        });
      }
    }
  }

  void _showLoadingDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
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

  Future<void> _handleLocationPress() async {
    if (_hasValidCoordinates()) {
      final latVal = _currentCustomer!.partnerLatitude;
      final lngVal = _currentCustomer!.partnerLongitude;

      if (latVal != null && lngVal != null) {
        try {
          final url =
              'https://www.google.com/maps/search/?api=1&query=$latVal,$lngVal';
          if (await canLaunchUrlString(url)) {
            await launchUrlString(url);
          } else {
            if (mounted) {
              CustomSnackbar.showWarning(
                context,
                'Could not open maps application.',
              );
            }
          }
        } catch (e) {
          if (mounted) {
            CustomSnackbar.showError(
              context,
              'Failed to open maps: ${e.toString()}',
            );
          }
        }
        return;
      }
    }

    _showLocationOptions();
  }

  String _getName() {
    return _nameController.text.isNotEmpty
        ? _nameController.text
        : 'New Customer';
  }

  Widget _buildCustomerHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    InkWell(
                      onTap: _isEditMode ? _pickImage : _viewFullImage,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: _getName().length > 20
                              ? 28
                              : (_getName().length > 15 ? 30 : 32),
                          backgroundColor: const Color(0xFFF5F5F5),
                          backgroundImage:
                              _selectedImageBase64 != null &&
                                  _selectedImageBase64!.isNotEmpty &&
                                  _selectedImageBase64 != 'false'
                              ? MemoryImage(base64Decode(_selectedImageBase64!))
                              : null,
                          child:
                              (_selectedImageBase64 == null ||
                                  _selectedImageBase64!.isEmpty ||
                                  _selectedImageBase64 == 'false')
                              ? Text(
                                  _getName().isNotEmpty
                                      ? _getName()[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: _getName().length > 20
                                        ? 20
                                        : (_getName().length > 15 ? 22 : 24),
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.black54
                                        : Colors.grey[800],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_currentCustomer != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Tooltip(
                          message: _currentCustomer!.active
                              ? 'Active Customer'
                              : 'Inactive Customer',
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _currentCustomer!.active
                                  ? Colors.green
                                  : Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF23272E)
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _currentCustomer!.active
                                  ? Icons.check
                                  : Icons.close,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getName(),
                        style: TextStyle(
                          fontSize: _getName().length > 20
                              ? 20
                              : (_getName().length > 15 ? 22 : 24),
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 0),
                      Text(
                        _isCompany ? 'Company' : 'Customer',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white60 : theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
              thickness: 1,
              height: 1,
            ),
            _buildQuickActionButtons(isDark),
          ],
        ),
      ),
    );
  }

  bool _hasValidCoordinates() {
    if (widget.customer == null) return false;

    final lat = _currentCustomer!.partnerLatitude;
    final lng = _currentCustomer!.partnerLongitude;

    bool isValid(dynamic value) {
      if (value == null) return false;
      if (value is bool && value == false) return false;
      if (value is int && value == 0) return false;
      if (value is double && value.abs() < 0.000001) return false;
      if (value is String) {
        if (value.isEmpty) return false;
        if (value.toLowerCase() == 'false') return false;
        final parsed = double.tryParse(value);
        if (parsed == null || parsed.abs() < 0.000001) return false;
      }
      return true;
    }

    return isValid(lat) && isValid(lng);
  }

  Widget _buildQuickActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActionButton(
              icon: HugeIcons.strokeRoundedCalling02,
              label: 'Call',
              color: const Color(0xFF059669),
              onTap: () => _makePhoneCall(),
              isDark: isDark,
              isEnabled:
                  isReal(_phoneController.text) ||
                  isReal(_mobileController.text),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActionButton(
              icon: HugeIcons.strokeRoundedMessage01,
              label: 'Message',
              color: const Color(0xFF2563EB),
              onTap: () => _showMessageOptions(),
              isDark: isDark,
              isEnabled:
                  isReal(_phoneController.text) ||
                  isReal(_mobileController.text),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildActionButton(
              icon: HugeIcons.strokeRoundedMailOpen,
              label: 'Email',
              color: const Color(0xFFD97706),
              onTap: () => _sendEmail(),
              isDark: isDark,
              isEnabled: isReal(_emailController.text),
            ),
          ),
        ),
        Expanded(
          child: _buildActionButton(
            icon: HugeIcons.strokeRoundedLocation05,
            label: 'Location',
            color: const Color(0xFFDC2626),
            onTap: () => _handleLocationPress(),
            isDark: isDark,
            isEnabled: true,
            showWarning: !_hasValidCoordinates(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required dynamic icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isEnabled = true,
    bool showWarning = false,
  }) {
    final effectiveColor = isEnabled
        ? (isDark ? Colors.white : color)
        : (isDark ? Colors.grey[600]! : Colors.grey[400]!);
    final containerColor = isEnabled
        ? (isDark ? color.withOpacity(0.15) : Colors.white)
        : (isDark ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[100]!);
    final labelColor = isEnabled
        ? (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280))
        : (isDark ? Colors.grey[600]! : Colors.grey[500]!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: containerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: icon,
                        size: 22,
                        color: effectiveColor,
                      ),
                    ),
                  ),
                  if (showWarning)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : Colors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                  fontSize: 12,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181A20) : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
            dropdownColor: isDark ? const Color(0xFF23272E) : Colors.white,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _makePhoneCall() async {
    String phoneNumber = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : _mobileController.text;

    if (phoneNumber.isNotEmpty) {
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      try {
        final hasPermission = await RuntimePermissionService.requestPhonePermission(context);
        if (!hasPermission) return;

        if (Platform.isAndroid) {
          final AndroidIntent intent = AndroidIntent(
            action: 'android.intent.action.DIAL',
            data: 'tel:$phoneNumber',
          );
          await intent.launch();
        } else {
          final url = Uri.parse('tel:$phoneNumber');
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            if (mounted) {
              CustomSnackbar.showWarning(
                context,
                'Could not launch phone app.',
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showInfo(context, 'Please call $phoneNumber manually');
        }
      }
    }
  }

  void _showMessageOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phoneNumber = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : _mobileController.text;

    if (phoneNumber.isEmpty) {
      CustomSnackbar.showWarning(context, 'No phone number available');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Send Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedMessage01,
                  color: Color(0xFF2563EB),
                ),
              ),
              title: Text(
                'System Messenger',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Send SMS to $phoneNumber',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendSMS();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedWhatsapp,
                  color: Color(0xFF25D366),
                ),
              ),
              title: Text(
                'WhatsApp',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Send WhatsApp message to $phoneNumber',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _sendWhatsAppMessage();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppMessage() async {
    String phoneNumber = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : _mobileController.text;

    if (phoneNumber.isEmpty) {
      if (mounted) {
        CustomSnackbar.showWarning(context, 'No phone number available');
      }
      return;
    }

    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '').trim();

    try {
      final whatsappUrl = 'https://wa.me/$phoneNumber';
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          CustomSnackbar.showWarning(
            context,
            'WhatsApp application not found.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to open WhatsApp: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _sendSMS() async {
    String phoneNumber = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : _mobileController.text;

    if (phoneNumber.isEmpty) return;

    phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    try {
      if (Platform.isAndroid) {
        final AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.SENDTO',
          data: 'smsto:$phoneNumber',
        );
        await intent.launch();
      } else {
        final smsUri = Uri.parse('sms:$phoneNumber');
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        } else {
          if (mounted) {
            CustomSnackbar.showWarning(context, 'Could not launch SMS app.');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showInfo(
          context,
          'Failed to open SMS app: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_emailController.text.isNotEmpty) {
      try {
        if (Platform.isAndroid) {
          final AndroidIntent intent = AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: 'mailto:${_emailController.text}',
            arguments: <String, dynamic>{
              'android.intent.extra.SUBJECT': 'Hello ${_nameController.text}',
            },
          );
          await intent.launch();
        } else {
          final String emailUrl =
              'mailto:${_emailController.text}?subject=Hello ${Uri.encodeComponent(_nameController.text)}';
          final uri = Uri.parse(emailUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            if (mounted) {
              CustomSnackbar.showWarning(
                context,
                'Could not launch email app.',
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showInfo(
            context,
            'Please email ${_emailController.text} manually',
          );
        }
      }
    }
  }

  Future<void> _openLocation({double? lat, double? lng}) async {
    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
      final webUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );

      try {
        if (await canLaunchUrl(geoUri)) {
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {}

      try {
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (e) {}
    }

    String address = '';
    if (_streetController.text.isNotEmpty) {
      address += _streetController.text;
    }
    if (_cityController.text.isNotEmpty) {
      if (address.isNotEmpty) address += ', ';
      address += _cityController.text;
    }
    if (_zipController.text.isNotEmpty) {
      if (address.isNotEmpty) address += ' ';
      address += _zipController.text;
    }

    if (address.isNotEmpty) {
      final Uri mapsUri = Uri(
        scheme: 'https',
        host: 'maps.google.com',
        path: '/search/',
        queryParameters: {'api': '1', 'query': address},
      );
      try {
        if (await canLaunchUrl(mapsUri)) {
          await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            CustomSnackbar.showWarning(context, 'Could not launch maps app.');
          }
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.showError(
            context,
            'Could not open maps: ${e.toString()}',
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImageFromSource(ImageSource.camera);
                },
              ),
              if (_selectedImageBase64 != null &&
                  _selectedImageBase64!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _selectedImageBase64 = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);
        final List<int> imageBytes = await imageFile.readAsBytes();
        final String base64Image = base64Encode(imageBytes);

        setState(() {
          _selectedImageBase64 = base64Image;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to pick image: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: theme.primaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.grey.shade800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyToggle(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.business_center_outlined,
            color: theme.primaryColor.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact Type',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCompany ? 'Company' : 'Individual',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (_isEditMode)
            Switch.adaptive(
              value: _isCompany,
              onChanged: (value) {
                setState(() {
                  _isCompany = value;
                });
              },
              activeColor: theme.primaryColor,
            ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String value,
    required TextEditingController controller,
    bool isRequired = false,
    TextInputType? keyboardType,
    dynamic icon,
    int maxLines = 1,
  }) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isEditMode)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  floatingLabelStyle: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  prefixIcon: icon != null
                      ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: HugeIcon(
                            icon: icon,
                            color: isDark
                                ? Colors.grey[400]
                                : Colors.grey.shade500,
                            size: 20,
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1F2937)
                      : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  hintText: label.contains('*')
                      ? 'Enter ${label.replaceAll(' *', '')}'
                      : 'Enter ${label.toLowerCase()}',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ),
                validator: isRequired
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        return null;
                      }
                    : null,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F2937) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (icon != null) ...[
                        HugeIcon(
                          icon: icon,
                          color: theme.primaryColor.withOpacity(0.7),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label.replaceAll(' *', ''),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey[400]
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value.isEmpty ? 'Not specified' : value,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown() {
    if (!_isEditMode) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _selectedCountryId,
        decoration: InputDecoration(
          labelText: 'Country',
          prefixIcon: const Icon(Icons.public),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('Select Country'),
          ),
          ..._countries.map(
            (c) => DropdownMenuItem<int>(
              value: c['id'] as int,
              child: Text(c['name']?.toString() ?? ''),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedCountryId = v;
            _hasUnsavedChanges = true;
          });
          if (v != null) _loadStates(v);
        },
      ),
    );
  }

  Widget _buildStateDropdown() {
    if (!_isEditMode) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _selectedStateId,
        decoration: InputDecoration(
          labelText: 'State/Province',
          prefixIcon: const Icon(Icons.location_city),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('Select State')),
          ..._states.map(
            (s) => DropdownMenuItem<int>(
              value: s['id'] as int,
              child: Text(s['name']?.toString() ?? ''),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedStateId = v;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildTitleDropdown() {
    if (!_isEditMode) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedTitle,
        decoration: InputDecoration(
          labelText: 'Title',
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Select Title'),
          ),
          ..._titles.map(
            (t) => DropdownMenuItem<String>(
              value: t['id']?.toString(),
              child: Text(t['name']?.toString() ?? ''),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedTitle = v;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    if (!_isEditMode) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _selectedCurrencyId,
        decoration: InputDecoration(
          labelText: 'Currency',
          prefixIcon: const Icon(Icons.attach_money),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('Select Currency'),
          ),
          ..._currencies.map(
            (c) => DropdownMenuItem<int>(
              value: c['id'] as int,
              child: Text(c['name']?.toString() ?? ''),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedCurrencyId = v;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    if (!_isEditMode) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        value: _selectedLanguageId,
        decoration: InputDecoration(
          labelText: 'Language',
          prefixIcon: const Icon(Icons.language),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        ),
        items: [
          const DropdownMenuItem<int>(
            value: null,
            child: Text('Select Language'),
          ),
          ..._languages.map(
            (l) => DropdownMenuItem<int>(
              value: l['id'] as int,
              child: Text(l['name']?.toString() ?? ''),
            ),
          ),
        ],
        onChanged: (v) {
          setState(() {
            _selectedLanguageId = v;
            _hasUnsavedChanges = true;
          });
        },
      ),
    );
  }

  Future<bool?> _showDiscardDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Discard Changes?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'You have unsaved changes. Are you sure you want to discard them?',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
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
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
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
                  onPressed: () => Navigator.pop(ctx, true),
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
                    'Discard',
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

  Future<void> _shareContact() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    BuildContext? dialogContext;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: primaryColor,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Creating contact card...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please wait while we prepare the contact for sharing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final imageBytes = await _generateContactImage();

      final docDir = await getApplicationDocumentsDirectory();
      final file = File(
        '${docDir.path}/contact_${_nameController.text.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);

      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Contact: ${_nameController.text}',
        text: _nameController.text,
      );
    } catch (e) {
      if (dialogContext != null && Navigator.of(dialogContext!).canPop()) {
        Navigator.of(dialogContext!).pop();
      }
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to share contact: ${e.toString()}',
        );
      }
    }
  }

  Future<Uint8List> _generateContactImage() async {
    const double scaleFactor = 12.0;
    const double cardWidth = 720;
    const double cardHeight = 540;
    final double canvasWidth = cardWidth * scaleFactor;
    final double canvasHeight = cardHeight * scaleFactor;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
    );

    const primaryColor = Color(0xFFBB2649);
    const accentColor = Color(0xFF0F172A);
    const brandColor = Color(0xFF3B82F6);
    const backgroundColor = Color(0xFFFFFFFF);
    const headerColor = Color(0xFFF8FAFC);
    const textColor = Color(0xFF0F172A);
    const lightTextColor = Color(0xFF64748B);
    const dividerColor = Color(0xFFCBD5E1);

    final cardRect = Rect.fromLTWH(0, 0, canvasWidth, canvasHeight);
    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRect(cardRect, backgroundPaint);

    final headerPaint = Paint()..color = headerColor;
    final headerRect = Rect.fromLTWH(0, 0, canvasWidth, 140 * scaleFactor);
    canvas.drawRect(headerRect, headerPaint);

    final double avatarRadius = 48 * scaleFactor;
    final double avatarCenterX = canvasWidth / 2;
    final double avatarCenterY = 70 * scaleFactor;

    final avatarBgPaint = Paint()..color = brandColor.withOpacity(0.1);
    canvas.drawCircle(
      Offset(avatarCenterX, avatarCenterY),
      avatarRadius,
      avatarBgPaint,
    );

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.person.codePoint),
        style: TextStyle(
          fontFamily: Icons.person.fontFamily,
          fontSize: 48 * scaleFactor,
          color: brandColor,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        avatarCenterX - iconPainter.width / 2,
        avatarCenterY - iconPainter.height / 2,
      ),
    );

    double currentY = 160 * scaleFactor;

    if (_nameController.text.isNotEmpty) {
      final nameStyle = ui.TextStyle(
        color: textColor,
        fontSize: 24 * scaleFactor,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5 * scaleFactor,
      );
      final nameParagraph =
          ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
            ..pushStyle(nameStyle)
            ..addText(_nameController.text)
            ..pop();
      final nameLayout = nameParagraph.build()
        ..layout(
          ui.ParagraphConstraints(width: canvasWidth - 80 * scaleFactor),
        );
      canvas.drawParagraph(nameLayout, Offset(40 * scaleFactor, currentY));
      currentY += 35 * scaleFactor;
    }

    final dividerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 2 * scaleFactor;
    canvas.drawLine(
      Offset(80 * scaleFactor, currentY),
      Offset(canvasWidth - 80 * scaleFactor, currentY),
      dividerPaint,
    );
    currentY += 24 * scaleFactor;

    void drawField(String label, String? value, IconData icon) {
      if (value == null || value.isEmpty) return;
      if (currentY + 36 * scaleFactor > canvasHeight - 20 * scaleFactor) return;

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            fontSize: 16 * scaleFactor,
            color: brandColor,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      iconPainter.layout();
      iconPainter.paint(
        canvas,
        Offset(60 * scaleFactor, currentY + 6 * scaleFactor),
      );

      final labelStyle = ui.TextStyle(
        color: lightTextColor,
        fontSize: 11 * scaleFactor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5 * scaleFactor,
      );
      final labelParagraph = ui.ParagraphBuilder(ui.ParagraphStyle())
        ..pushStyle(labelStyle)
        ..addText(label.toUpperCase())
        ..pop();
      final labelLayout = labelParagraph.build()
        ..layout(
          ui.ParagraphConstraints(width: canvasWidth - 120 * scaleFactor),
        );
      canvas.drawParagraph(labelLayout, Offset(85 * scaleFactor, currentY));

      final valueStyle = ui.TextStyle(
        color: textColor,
        fontSize: 14 * scaleFactor,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1 * scaleFactor,
      );
      final valueParagraph = ui.ParagraphBuilder(ui.ParagraphStyle())
        ..pushStyle(valueStyle)
        ..addText(value)
        ..pop();
      final valueLayout = valueParagraph.build()
        ..layout(
          ui.ParagraphConstraints(width: canvasWidth - 120 * scaleFactor),
        );
      canvas.drawParagraph(
        valueLayout,
        Offset(85 * scaleFactor, currentY + 16 * scaleFactor),
      );

      currentY += math.max(
        36 * scaleFactor,
        valueLayout.height + 20 * scaleFactor,
      );
    }

    drawField('Email', _emailController.text, Icons.email_outlined);
    currentY += 8 * scaleFactor;
    drawField('Phone', _phoneController.text, Icons.phone_outlined);
    currentY += 8 * scaleFactor;
    drawField('Mobile', _mobileController.text, Icons.phone_android_outlined);
    currentY += 8 * scaleFactor;
    drawField('Website', _websiteController.text, Icons.language_outlined);
    currentY += 8 * scaleFactor;

    final addressParts = [
      _streetController.text,
      _cityController.text,
      _zipController.text,
    ].where((part) => part.isNotEmpty).toList();
    if (addressParts.isNotEmpty) {
      drawField('Address', addressParts.join(', '), Icons.location_on_outlined);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final finalBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (finalBytes == null) throw Exception('Failed to encode image');
    return finalBytes.buffer.asUint8List();
  }

  Future<void> _copyContactInfo() async {
    try {
      final List<String> infoLines = [];

      if (_nameController.text.isNotEmpty) {
        infoLines.add('Name: ${_nameController.text}');
      }
      if (_jobPositionController.text.isNotEmpty) {
        infoLines.add('Position: ${_jobPositionController.text}');
      }
      if (_emailController.text.isNotEmpty) {
        infoLines.add('Email: ${_emailController.text}');
      }
      if (_phoneController.text.isNotEmpty) {
        infoLines.add('Phone: ${_phoneController.text}');
      }
      if (_mobileController.text.isNotEmpty) {
        infoLines.add('Mobile: ${_mobileController.text}');
      }
      if (_websiteController.text.isNotEmpty) {
        infoLines.add('Website: ${_websiteController.text}');
      }

      final addressParts = [
        _streetController.text,
        _cityController.text,
        _zipController.text,
      ].where((part) => part.isNotEmpty).toList();
      if (addressParts.isNotEmpty) {
        infoLines.add('Address: ${addressParts.join(', ')}');
      }

      final contactInfo = infoLines.join('\n');

      if (contactInfo.isEmpty) {
        if (mounted) {
          CustomSnackbar.showInfo(
            context,
            'No contact information available to copy',
          );
        }
        return;
      }

      await Clipboard.setData(ClipboardData(text: contactInfo));

      if (mounted) {
        CustomSnackbar.showSuccess(
          context,
          'Contact information copied to clipboard',
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to copy contact info: ${e.toString()}',
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String? value, dynamic icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = isReal(value) ? value! : 'N/A';
    if (displayValue == 'N/A') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'false') return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildCustomerStatisticsSection() {
    if (_customerStats == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    final totalOrders = _customerStats!['total_orders'] ?? 0;
    final confirmedOrders = _customerStats!['confirmed_orders'] ?? 0;
    final draftOrders = _customerStats!['draft_orders'] ?? 0;
    final totalAmount = _customerStats!['total_amount'] ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedActivity01,
                  color: primaryColor,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildStatListItem(
              'Total Orders',
              totalOrders.toString(),
              HugeIcons.strokeRoundedShoppingBag02,
              primaryColor,
            ),
            const SizedBox(height: 12),
            _buildStatListItem(
              'Confirmed Orders',
              confirmedOrders.toString(),
              HugeIcons.strokeRoundedTickDouble03,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatListItem(
              'Draft Orders',
              draftOrders.toString(),
              HugeIcons.strokeRoundedDocumentValidation,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildStatListItem(
              'Total Amount',
              totalAmount.toStringAsFixed(2),
              HugeIcons.strokeRoundedMoneyBag02,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatListItem(
    String label,
    String value,
    dynamic icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A20) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllInfoExpansionTiles() {
    return Column(
      children: [
        _buildCustomerStatisticsSection(),
        const SizedBox(height: 24),
        _buildContactInfoExpansionTile(),
        const SizedBox(height: 24),
        _buildCompanyInfoExpansionTile(),
        _buildBusinessInfoExpansionTile(),
        const SizedBox(height: 24),
        _buildAdditionalInfoExpansionTile(),
      ],
    );
  }

  Widget _buildCompanyInfoExpansionTile() {
    if (!_isCompany && !isReal(_companyNameController.text)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ExpansionTile(
              initiallyExpanded: false,
              backgroundColor: isDark ? Colors.grey[850] : Colors.white,
              collapsedBackgroundColor: isDark
                  ? Colors.grey[850]
                  : Colors.white,
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: 20,
              ),
              title: Text(
                'Company Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              trailing: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowDown01,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 20,
              ),

              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Company Name',
                      _companyNameController.text,
                      HugeIcons.strokeRoundedBuilding05,
                    ),
                    _buildInfoRow(
                      'VAT Number',
                      _vatController.text,
                      HugeIcons.strokeRoundedAccountSetting03,
                    ),
                    _buildInfoRow(
                      'Company Type',
                      _currentCustomer?.companyType?.toString(),
                      HugeIcons.strokeRoundedCatalogue,
                    ),
                    _buildInfoRow(
                      'Industry',
                      _industryController.text,
                      HugeIcons.strokeRoundedWorkHistory,
                    ),
                    _buildInfoRow(
                      'Website',
                      _websiteController.text,
                      HugeIcons.strokeRoundedWebDesign02,
                    ),
                    _buildInfoRow(
                      'Email',
                      _emailController.text,
                      HugeIcons.strokeRoundedMail01,
                    ),
                    _buildInfoRow(
                      'Phone',
                      _phoneController.text,
                      HugeIcons.strokeRoundedCall02,
                    ),
                    _buildInfoRow(
                      'Address',
                      [
                        _streetController.text,
                        _street2Controller.text,
                        _cityController.text,
                        _stateController.text,
                        _zipController.text,
                        _countryController.text,
                      ].where((s) => isReal(s)).join(', '),
                      HugeIcons.strokeRoundedLocation05,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBusinessInfoExpansionTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          collapsedBackgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          title: Text(
            'Business Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          trailing: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Salesperson',
                  _salespersonController.text,
                  HugeIcons.strokeRoundedUser,
                ),
                _buildInfoRow(
                  'Industry',
                  _industryController.text,
                  HugeIcons.strokeRoundedWorkHistory,
                ),
                _buildInfoRow(
                  'Customer Rank',
                  _currentCustomer?.customerRank?.toString(),
                  HugeIcons.strokeRoundedRanking,
                ),
                _buildInfoRow(
                  'Payment Terms',
                  _paymentTermsController.text,
                  HugeIcons.strokeRoundedInvoice01,
                ),
                _buildInfoRow(
                  'Credit Limit',
                  _creditLimitController.text,
                  HugeIcons.strokeRoundedPayment02,
                ),
                _buildInfoRow(
                  'Currency',
                  _currentCustomer?.currencyId is List
                      ? _currentCustomer!.currencyId[1]?.toString()
                      : _currentCustomer?.currencyId?.toString(),
                  HugeIcons.strokeRoundedMoneyExchange03,
                ),
                _buildInfoRow(
                  'Customer Type',
                  _isCompany ? 'Company' : 'Individual',
                  HugeIcons.strokeRoundedUser02,
                ),
                _buildInfoRow(
                  'Status',
                  (_currentCustomer?.active == true) ? 'Active' : 'Inactive',
                  (_currentCustomer?.active == true)
                      ? HugeIcons.strokeRoundedTickDouble03
                      : Icons.cancel_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalInfoExpansionTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          collapsedBackgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          title: Text(
            'Additional Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          trailing: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Title',
                  _selectedTitle,
                  HugeIcons.strokeRoundedUser,
                ),
                _buildInfoRow(
                  'Language',
                  _languageController.text,
                  HugeIcons.strokeRoundedLanguageSquare,
                ),
                _buildInfoRow(
                  'Timezone',
                  _timezoneController.text,
                  HugeIcons.strokeRoundedTime04,
                ),
                if (_currentCustomer != null) ...[
                  _buildInfoRow(
                    'Created',
                    _formatDate(
                      _currentCustomer!.createDate?.toIso8601String(),
                    ),
                    HugeIcons.strokeRoundedCalendar03,
                  ),
                  _buildInfoRow(
                    'Last Updated',
                    _formatDate(_currentCustomer!.writeDate?.toIso8601String()),
                    HugeIcons.strokeRoundedCalendar03,
                  ),
                ],
                _buildInfoRow(
                  'Notes',
                  _commentController.text,
                  HugeIcons.strokeRoundedNote02,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoExpansionTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          initiallyExpanded: false,
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          collapsedBackgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          title: Text(
            'Contact Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          trailing: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Phone',
                  _phoneController.text,
                  HugeIcons.strokeRoundedCall02,
                ),
                _buildInfoRow(
                  'Mobile',
                  _mobileController.text,
                  HugeIcons.strokeRoundedSmartPhone01,
                ),
                _buildInfoRow(
                  'Email',
                  _emailController.text,
                  HugeIcons.strokeRoundedMail01,
                ),
                _buildInfoRow(
                  'Website',
                  _websiteController.text,
                  HugeIcons.strokeRoundedWebDesign02,
                ),
                _buildInfoRow(
                  'Street',
                  _streetController.text,
                  HugeIcons.strokeRoundedLocation05,
                ),
                _buildInfoRow(
                  'Street 2',
                  _street2Controller.text,
                  HugeIcons.strokeRoundedLocation04,
                ),
                _buildInfoRow(
                  'City',
                  _cityController.text,
                  HugeIcons.strokeRoundedCity03,
                ),
                _buildInfoRow(
                  'State',
                  _stateController.text,
                  HugeIcons.strokeRoundedLocation01,
                ),
                _buildInfoRow(
                  'ZIP Code',
                  _zipController.text,
                  HugeIcons.strokeRoundedPinCode,
                ),
                _buildInfoRow(
                  'Country',
                  _countryController.text,
                  HugeIcons.strokeRoundedGlobal,
                ),
                if (widget.customer != null &&
                    _currentCustomer!.partnerLatitude != null &&
                    _currentCustomer!.partnerLongitude != null &&
                    _currentCustomer!.partnerLatitude != 0.0 &&
                    _currentCustomer!.partnerLongitude != 0.0) ...[
                  const SizedBox(height: 16),
                  LocationMapWidget(
                    latitude: (_currentCustomer!.partnerLatitude ?? 0.0)
                        .toDouble(),
                    longitude: (_currentCustomer!.partnerLongitude ?? 0.0)
                        .toDouble(),
                    customer: _currentCustomer!,
                    onOpenMap: () => _openLocation(
                      lat: (_currentCustomer!.partnerLatitude ?? 0.0)
                          .toDouble(),
                      lng: (_currentCustomer!.partnerLongitude ?? 0.0)
                          .toDouble(),
                    ),
                    onCoordinatesRemoved: () {
                      setState(() {
                        _currentCustomer = _currentCustomer!.copyWith(
                          partnerLatitude: 0.0,
                          partnerLongitude: 0.0,
                        );
                      });
                    },
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange[900]!.withOpacity(0.2)
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.orange[700]!.withOpacity(0.3)
                            : Colors.orange[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLocationOffline01,
                          color: isDark
                              ? Colors.orange[300]
                              : Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No valid location coordinates found for this customer. Please geolocate or select the coordinates from map to display the mapview snippet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.orange[200]
                                  : Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Location Options',
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
                icon: HugeIcons.strokeRoundedCoordinate01,
                color: isDark ? Colors.white : primaryColor,
              ),
              title: Text(
                'Geolocalize with Odoo',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Use Odoo\'s geolocation service',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _handleLocationAction();
              },
            ),
            ListTile(
              leading: HugeIcon(
                icon: HugeIcons.strokeRoundedMaping,
                color: isDark ? Colors.white : primaryColor,
              ),
              title: Text(
                'Select location on map',
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              subtitle: Text(
                'Manually choose a location on the map',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _showSelectLocationScreen();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLocationAction() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    bool hasAddress =
        _streetController.text.isNotEmpty ||
        _cityController.text.isNotEmpty ||
        _zipController.text.isNotEmpty;

    if (!hasAddress) {
      CustomSnackbar.showWarning(
        context,
        'Cannot geolocalize: No address available for this customer.',
      );
      return;
    }

    final shouldGeo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isDark ? 0 : 8,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Geolocalize Customer',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No location coordinates available. Would you like to geolocalize this customer using their address?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange[900]?.withOpacity(0.2)
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.orange[700]! : Colors.orange[200]!,
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: isDark ? Colors.orange[300] : Colors.orange[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: Geolocation must be enabled in Odoo settings. It is OFF by default.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.orange[300] : Colors.orange[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.grey[400]
                        : Colors.grey[700],
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
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
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
                    'Geolocalize',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldGeo == true) {
      _showLoadingDialog(
        context,
        'Geolocalizing Customer',
        'Please wait while we fetch the location...',
      );
      await _geoLocalizeCustomer();
    }
  }

  Future<void> _geoLocalizeCustomer() async {
    try {
      final provider = Provider.of<CustomerProvider>(context, listen: false);
      final result = await provider.geoLocalizeCustomer(_currentCustomer!.id!);

      if (result == true) {
        await _refreshCustomerData();

        if (mounted) {
          final lat = _currentCustomer!.partnerLatitude;
          final lng = _currentCustomer!.partnerLongitude;
          final hasCoords =
              lat != null && lng != null && lat != 0.0 && lng != 0.0;

          Navigator.of(context, rootNavigator: true).pop();

          if (hasCoords) {
            CustomSnackbar.showSuccess(
              context,
              'Location updated successfully!',
            );
          } else {
            CustomSnackbar.showWarning(
              context,
              'Geolocalization finished but no coordinates were found. Please check the address or Odoo settings.',
            );
          }
          setState(() {});
        }
      } else {
        throw Exception('Geolocation failed or returned false');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        String errorMessage = 'Failed to geolocalize customer';
        if (e.toString().contains('Access Denied')) {
          errorMessage = 'Access denied. Please check your permissions.';
        } else if (e.toString().contains('Network Error')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('Missing Google Maps Key')) {
          errorMessage =
              'Server configuration error: Missing Google Maps API Key.';
        }

        CustomSnackbar.showError(context, errorMessage);
      }
    }
  }

  Future<void> _showSelectLocationScreen() async {
    final LatLng? initialLocation =
        (widget.customer != null &&
            _currentCustomer!.partnerLatitude != null &&
            _currentCustomer!.partnerLongitude != null &&
            _currentCustomer!.partnerLatitude != 0.0)
        ? LatLng(
            (_currentCustomer!.partnerLatitude ?? 0.0).toDouble(),
            (_currentCustomer!.partnerLongitude ?? 0.0).toDouble(),
          )
        : null;

    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationScreen(
          initialLocation: initialLocation,
          onSaveLocation: (location) async {
            try {
              final provider = Provider.of<CustomerProvider>(
                context,
                listen: false,
              );
              final success = await provider
                  .updateCustomer(_currentCustomer!.id!, {
                    'partner_latitude': location.latitude,
                    'partner_longitude': location.longitude,
                  });
              return success;
            } catch (e) {
              return false;
            }
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentCustomer = _currentCustomer!.copyWith(
          partnerLatitude: result.latitude,
          partnerLongitude: result.longitude,
        );
      });
    }
  }
}
