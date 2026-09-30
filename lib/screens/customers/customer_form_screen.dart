import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../providers/customer_form_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/session_service.dart';
import '../../widgets/connection_status_widget.dart';
import '../../widgets/mobo_form_fields.dart';
import '../../theme/form_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_snackbar.dart';
import '../../widgets/confetti_dialog.dart';
import '../../utils/data_loss_warning_mixin.dart';
import '../../services/odoo_error_handler.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;
  final bool isEditing;

  const CustomerFormScreen({super.key, this.customer, this.isEditing = false});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen>
    with DataLossWarningMixin {
  final _formKey = GlobalKey<FormState>();
  bool _hasBeenSaved = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _mobileController;
  late TextEditingController _websiteController;
  late TextEditingController _functionController;
  late TextEditingController _streetController;
  late TextEditingController _street2Controller;
  late TextEditingController _cityController;
  late TextEditingController _zipController;
  late TextEditingController _companyNameController;
  late TextEditingController _vatController;
  late TextEditingController _industryController;
  late TextEditingController _creditLimitController;
  late TextEditingController _commentController;

  bool _isCompany = false;
  int? _selectedCountryId;
  int? _selectedStateId;
  String? _selectedTitle;
  String? _selectedCurrency;
  String? _selectedLanguage;

  @override
  bool get hasUnsavedData {
    if (_hasBeenSaved) return false;
    final c = widget.customer;
    String clean(String? v) => (v == null || v == 'false') ? '' : v;

    return _nameController.text.trim() != clean(c?.name) ||
        _emailController.text.trim() != clean(c?.email) ||
        _phoneController.text.trim() != clean(c?.phone) ||
        _mobileController.text.trim() != clean(c?.mobile) ||
        _websiteController.text.trim() != clean(c?.website) ||
        _functionController.text.trim() != clean(c?.function) ||
        _streetController.text.trim() != clean(c?.street) ||
        _street2Controller.text.trim() != clean(c?.street2) ||
        _cityController.text.trim() != clean(c?.city) ||
        _zipController.text.trim() != clean(c?.zip) ||
        _vatController.text.trim() != clean(c?.vat) ||
        _commentController.text.trim() != clean(c?.comment) ||
        _isCompany != (c?.isCompany ?? false) ||
        _selectedCountryId != c?.countryId ||
        _selectedStateId != c?.stateId ||
        _selectedTitle != c?.title ||
        _selectedLanguage != c?.lang ||
        _companyNameController.text.trim() != clean(c?.companyName) ||
        _industryController.text.trim() != clean(c?.industry) ||
        _creditLimitController.text.trim() != clean(c?.creditLimit);
  }

  @override
  void onConfirmLeave() {}

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    String clean(String? v) => (v == null || v == 'false') ? '' : v;

    _nameController = TextEditingController(text: clean(c?.name));
    _emailController = TextEditingController(text: clean(c?.email));
    _phoneController = TextEditingController(text: clean(c?.phone));
    _mobileController = TextEditingController(text: clean(c?.mobile));
    _websiteController = TextEditingController(text: clean(c?.website));
    _functionController = TextEditingController(text: clean(c?.function));
    _streetController = TextEditingController(text: clean(c?.street));
    _street2Controller = TextEditingController(text: clean(c?.street2));
    _cityController = TextEditingController(text: clean(c?.city));
    _zipController = TextEditingController(text: clean(c?.zip));
    _companyNameController = TextEditingController(text: clean(c?.companyName));
    _vatController = TextEditingController(text: clean(c?.vat));
    _industryController = TextEditingController(text: clean(c?.industry));
    _creditLimitController = TextEditingController(text: clean(c?.creditLimit));
    _commentController = TextEditingController(text: clean(c?.comment));

    _isCompany = c?.isCompany ?? false;
    _selectedCountryId = c?.countryId;
    _selectedStateId = c?.stateId;
    _selectedTitle = c?.title;
    _selectedLanguage = c?.lang;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formProvider = Provider.of<CustomerFormProvider>(
        context,
        listen: false,
      );
      formProvider.reset();
      formProvider.loadDropdownData();
      if (_selectedCountryId != null) {
        formProvider.fetchStates(_selectedCountryId!);
      }
    });

    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileController.dispose();
    _websiteController.dispose();
    _functionController.dispose();
    _streetController.dispose();
    _street2Controller.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _companyNameController.dispose();
    _vatController.dispose();
    _industryController.dispose();
    _creditLimitController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!ConnectivityService.instance.isConnected) {
      CustomSnackbar.showError(
        context,
        "You're offline. Reconnect to save this customer.",
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final customerProvider = Provider.of<CustomerProvider>(
      context,
      listen: false,
    );
    final formProvider = Provider.of<CustomerFormProvider>(
      context,
      listen: false,
    );

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'is_company': _isCompany,
      'type': 'contact',
    };

    data['customer_rank'] = 1;

    void addField(String key, String value) {
      if (value.trim().isNotEmpty && value.trim().toLowerCase() != 'false') {
        data[key] = value.trim();
      }
    }

    addField('email', _emailController.text);
    addField('phone', _phoneController.text);
    addField('mobile', _mobileController.text);
    addField('website', _websiteController.text);
    addField('function', _functionController.text);
    addField('street', _streetController.text);
    addField('street2', _street2Controller.text);
    addField('city', _cityController.text);
    addField('zip', _zipController.text);
    addField('vat', _vatController.text);
    addField('comment', _commentController.text);

    if (_selectedCountryId != null) data['country_id'] = _selectedCountryId;
    if (_selectedStateId != null) data['state_id'] = _selectedStateId;
    if (_selectedTitle != null) data['title'] = int.tryParse(_selectedTitle!);
    if (_selectedLanguage != null) data['lang'] = _selectedLanguage;
    if (_companyNameController.text.isNotEmpty)
      data['company_name'] = _companyNameController.text.trim();

    if (_industryController.text.isNotEmpty) {
      final industryId = int.tryParse(_industryController.text.trim());
      if (industryId != null) {
        data['industry_id'] = industryId;
      }
    }

    if (_creditLimitController.text.isNotEmpty) {
      data['credit_limit'] =
          double.tryParse(_creditLimitController.text.trim()) ?? 0.0;
    }

    if (formProvider.pickedImage != null) {
      final bytes = await formProvider.pickedImage!.readAsBytes();
      data['image_1920'] = base64Encode(bytes);
    }

    bool success = false;
    bool retry = true;
    int retryCount = 0;
    const int maxRetries = 5;

    while (retry && retryCount < maxRetries) {
      retry = false;
      try {
        if (widget.isEditing) {
          success = await customerProvider.updateCustomer(
            widget.customer!.id!,
            data,
          );
        } else {
          final newId = await customerProvider.createCustomer(data);
          success = newId > 0;
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('keyerror') ||
            errorStr.contains('invalid field')) {
          final regExp = RegExp(
            r"['"
            "]([^'"
            "]+)['"
            "]",
          );
          final match = regExp.firstMatch(errorStr);
          if (match != null) {
            final fieldName = match.group(1);
            if (fieldName != null && data.containsKey(fieldName)) {
              data.remove(fieldName);
              retry = true;
              retryCount++;
              continue;
            }
          }
        }

        if (mounted) {
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
                'Failed to Save Customer',
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
        return;
      }
    }

    if (success && mounted) {
      setState(() {
        _hasBeenSaved = true;
      });
      if (!widget.isEditing) {
        await showCustomerCreatedConfettiDialog(
          context,
          _nameController.text.trim(),
        );
      } else {
        CustomSnackbar.showSuccess(context, 'Customer updated successfully');
      }
      if (mounted) Navigator.pop(context, true);
    } else if (mounted && !success) {
      final errorMsg = customerProvider.error ?? 'Failed to save customer';
      final userMessage = OdooErrorHandler.toUserMessage(errorMsg);
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
            'Failed to Save Customer',
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
                  Provider.of<CustomerFormProvider>(
                    context,
                    listen: false,
                  ).pickImage(context, ImageSource.camera);
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
                  Provider.of<CustomerFormProvider>(
                    context,
                    listen: false,
                  ).pickImage(context, ImageSource.gallery);
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

  void _showBusinessCardScanner() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  final data = await Provider.of<CustomerFormProvider>(
                    context,
                    listen: false,
                  ).scanBusinessCard(context, ImageSource.camera);
                  if (data != null) _applyOcrData(data);
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Scan with Camera',
                        style: TextStyle(fontSize: 16),
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
                onTap: () async {
                  Navigator.pop(context);
                  final data = await Provider.of<CustomerFormProvider>(
                    context,
                    listen: false,
                  ).scanBusinessCard(context, ImageSource.gallery);
                  if (data != null) _applyOcrData(data);
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
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Scan from Gallery',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _applyOcrData(Map<String, dynamic> data) {
    if (data['name'] != null) _nameController.text = data['name'];
    if (data['email'] != null) _emailController.text = data['email'];
    if (data['phone'] != null) _phoneController.text = data['phone'];
    if (data['company'] != null) _companyNameController.text = data['company'];
    if (data['position'] != null) _functionController.text = data['position'];
    if (data['website'] != null) _websiteController.text = data['website'];
    CustomSnackbar.showSuccess(context, 'Business card data extracted');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Consumer2<ConnectivityService, SessionService>(
      builder: (context, connectivityService, sessionService, child) {
        // Offline: only block when there is no cached dropdown data to fill the
        // form with. Otherwise it opens read-only-ish, with saving refused in
        // _save and a banner explaining why.
        final formProviderForGate = context.read<CustomerFormProvider>();
        if (!connectivityService.isConnected &&
            formProviderForGate.countryOptions.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.isEditing ? 'Edit Customer' : 'Create Customer',
              ),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : primaryColor,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            body: ConnectionStatusWidget(
              onRetry: () async {
                final ok = await connectivityService.checkConnectivityOnce();
                if (ok && mounted) setState(() {});
              },
              customMessage:
                  'No internet connection. Please check your connection and try again.',
            ),
          );
        }

        if (!sessionService.hasValidSession) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                widget.isEditing ? 'Edit Customer' : 'Create Customer',
              ),
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              foregroundColor: isDark ? Colors.white : primaryColor,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            body: const ConnectionStatusWidget(),
          );
        }

        return Consumer<CustomerFormProvider>(
          builder: (context, formProvider, child) {
            if (formProvider.error != null) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    widget.isEditing ? 'Edit Customer' : 'Create Customer',
                  ),
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  foregroundColor: isDark ? Colors.white : primaryColor,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                body: ConnectionStatusWidget(
                  serverUnreachable: true,
                  serverErrorMessage: formProvider.error,
                  onRetry: () => formProvider.loadDropdownData(),
                ),
              );
            }

            if (formProvider.isDropdownLoading) {
              return _buildShimmerLoading(isDark, primaryColor);
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
                    widget.isEditing ? 'Edit Customer' : 'Create Customer',
                  ),
                  backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                  foregroundColor: isDark ? Colors.white : primaryColor,
                  elevation: 0,
                  leading: IconButton(
                    onPressed: () =>
                        handleNavigation(() => Navigator.pop(context)),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                body: RefreshIndicator(
                  onRefresh: () => formProvider.loadDropdownData(),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 16),
                        _buildPhotoPicker(formProvider, isDark, primaryColor),
                        const SizedBox(height: 16),

                        MoboFormCard(
                          title: 'Basic Information',
                          children: [
                            MoboTextField(
                              controller: _nameController,
                              label: 'Name',
                              hintText: 'Enter full name',
                              isRequired: true,
                              leadingIcon: HugeIcons.strokeRoundedUser,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _emailController,
                              label: 'Email',
                              hintText: 'Enter email address',
                              leadingIcon: HugeIcons.strokeRoundedMail01,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                                  );
                                  if (!emailRegex.hasMatch(v.trim())) {
                                    return 'Enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _phoneController,
                              label: 'Phone',
                              hintText: 'Enter phone number',
                              leadingIcon: HugeIcons.strokeRoundedCall,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _mobileController,
                              label: 'Mobile',
                              hintText: 'Enter mobile number',
                              leadingIcon: HugeIcons.strokeRoundedSmartPhone01,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _websiteController,
                              label: 'Website',
                              hintText: 'Enter website URL',
                              leadingIcon: HugeIcons.strokeRoundedGlobe,
                              keyboardType: TextInputType.url,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _functionController,
                              label: 'Job Position',
                              hintText: 'Enter job position',
                              leadingIcon: HugeIcons.strokeRoundedBriefcase01,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Checkbox(
                                  value: _isCompany,
                                  activeColor: AppTheme.primaryColor,
                                  onChanged: (v) =>
                                      setState(() => _isCompany = v ?? false),
                                ),
                                Text(
                                  'Is Company',
                                  style: AppFormTheme.fieldValueStyle(isDark),
                                ),
                              ],
                            ),
                          ],
                        ),

                        MoboFormCard(
                          title: 'Company Details',
                          children: [
                            MoboTextField(
                              controller: _companyNameController,
                              label: 'Company Name',
                              hintText: 'Enter company name',
                              leadingIcon: HugeIcons.strokeRoundedBuilding03,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _vatController,
                              label: 'VAT Number',
                              hintText: 'Enter VAT number',
                              leadingIcon: HugeIcons.strokeRoundedInvoice01,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _industryController,
                              label: 'Industry',
                              hintText: 'Enter industry',
                              leadingIcon: HugeIcons.strokeRoundedFactory01,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _creditLimitController,
                              label: 'Credit Limit',
                              hintText: 'Enter credit limit',
                              leadingIcon: HugeIcons.strokeRoundedDollarCircle,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),

                        MoboFormCard(
                          title: 'Address',
                          children: [
                            MoboTextField(
                              controller: _streetController,
                              label: 'Street',
                              hintText: 'Enter street address',
                              leadingIcon: HugeIcons.strokeRoundedLocation01,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _street2Controller,
                              label: 'Street 2',
                              hintText: 'Enter additional address',
                              leadingIcon: HugeIcons.strokeRoundedLocation01,
                            ),
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _cityController,
                              label: 'City',
                              hintText: 'Enter city name',
                              leadingIcon: HugeIcons.strokeRoundedCity01,
                            ),
                            const SizedBox(height: 16),
                            MoboInlineDropdown<Map<String, dynamic>>(
                              label: 'Country',
                              hintText: 'Select country',
                              leadingIcon: HugeIcons.strokeRoundedGlobe,
                              selectedLabel: _optionLabel(
                                formProvider.countryOptions,
                                (c) => c['id'] == _selectedCountryId,
                                'name',
                              ),
                              items: formProvider.countryOptions,
                              titleBuilder: (c) =>
                                  c['name']?.toString() ?? 'Unknown',
                              isItemSelected: (c) =>
                                  c['id'] == _selectedCountryId,
                              emptyText: 'No countries found',
                              onItemTap: (country) {
                                final id = country['id'] as int?;
                                setState(() {
                                  _selectedCountryId = id;
                                  _selectedStateId = null;
                                });
                                if (id != null) formProvider.fetchStates(id);
                              },
                            ),
                            if (formProvider.stateOptions.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              MoboInlineDropdown<Map<String, dynamic>>(
                                label: 'State',
                                hintText: 'Select state',
                                leadingIcon:
                                    HugeIcons.strokeRoundedMapsLocation01,
                                selectedLabel: _optionLabel(
                                  formProvider.stateOptions,
                                  (st) => st['id'] == _selectedStateId,
                                  'name',
                                ),
                                items: formProvider.stateOptions,
                                titleBuilder: (st) =>
                                    st['name']?.toString() ?? 'Unknown',
                                isItemSelected: (st) =>
                                    st['id'] == _selectedStateId,
                                emptyText: 'No states found',
                                onItemTap: (st) => setState(
                                  () => _selectedStateId = st['id'] as int?,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            MoboTextField(
                              controller: _zipController,
                              label: 'ZIP Code',
                              hintText: 'Enter ZIP code',
                              leadingIcon: HugeIcons.strokeRoundedLocation01,
                            ),
                          ],
                        ),

                        MoboFormCard(
                          title: 'Additional Information',
                          children: [
                            if (formProvider.titleOptions.isNotEmpty) ...[
                              MoboInlineDropdown<Map<String, String>>(
                                label: 'Title',
                                hintText: 'Select title',
                                leadingIcon: HugeIcons.strokeRoundedUserAccount,
                                selectedLabel: _optionLabel(
                                  formProvider.titleOptions,
                                  (t) => t['value'] == _selectedTitle,
                                  'label',
                                ),
                                items: formProvider.titleOptions,
                                titleBuilder: (t) => t['label'] ?? '',
                                isItemSelected: (t) =>
                                    t['value'] == _selectedTitle,
                                emptyText: 'No titles found',
                                onItemTap: (t) =>
                                    setState(() => _selectedTitle = t['value']),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (formProvider.languageOptions.isNotEmpty) ...[
                              MoboInlineDropdown<Map<String, String>>(
                                label: 'Language',
                                hintText: 'Select language',
                                leadingIcon: HugeIcons.strokeRoundedTranslate,
                                selectedLabel: _optionLabel(
                                  formProvider.languageOptions,
                                  (l) => l['value'] == _selectedLanguage,
                                  'label',
                                ),
                                items: formProvider.languageOptions,
                                titleBuilder: (l) => l['label'] ?? '',
                                isItemSelected: (l) =>
                                    l['value'] == _selectedLanguage,
                                emptyText: 'No languages found',
                                onItemTap: (l) => setState(
                                  () => _selectedLanguage = l['value'],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            MoboTextField(
                              controller: _commentController,
                              label: 'Internal Notes',
                              hintText: 'Enter any additional information',
                              leadingIcon: HugeIcons.strokeRoundedNote01,
                              maxLines: 3,
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        SafeArea(
                          child: Consumer<CustomerProvider>(
                            builder: (context, customerProvider, child) {
                              final isBusy =
                                  customerProvider.isLoading ||
                                  formProvider.isOcrLoading;
                              return MoboSubmitButton(
                                label: widget.isEditing
                                    ? 'Save Changes'
                                    : 'Create Customer',
                                loadingLabel: widget.isEditing
                                    ? 'Saving Changes'
                                    : 'Creating Customer',
                                isLoading: isBusy,
                                isReady: _nameController.text.trim().isNotEmpty,
                                onPressed: _save,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                floatingActionButton: widget.isEditing
                    ? null
                    : FloatingActionButton.extended(
                        onPressed: _showBusinessCardScanner,
                        backgroundColor: primaryColor,
                        label: const Text('Scan Card'),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAiScan,
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  /// Label of the first option in [options] matching [test].
  String? _optionLabel<T extends Map>(
    List<T> options,
    bool Function(T) test,
    String field,
  ) {
    final match = options.where(test).toList();
    return match.isEmpty ? null : match.first[field]?.toString();
  }

  Widget _buildPhotoPicker(
    CustomerFormProvider formProvider,
    bool isDark,
    Color primaryColor,
  ) {
    Widget photoWidget;
    if (formProvider.pickedImage != null) {
      photoWidget = CircleAvatar(
        radius: 48,
        backgroundImage: FileImage(formProvider.pickedImage!),
      );
    } else if (widget.customer?.image128 != null) {
      photoWidget = CircleAvatar(
        radius: 48,
        backgroundImage: MemoryImage(base64Decode(widget.customer!.image128!)),
      );
    } else {
      photoWidget = CircleAvatar(
        radius: 48,
        backgroundColor: isDark
            ? Colors.grey.shade200
            : primaryColor.withOpacity(.1),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage03,
          size: 48,
          color: isDark ? Colors.grey.shade800 : primaryColor,
        ),
      );
    }

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          photoWidget,
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _showImageSourceActionSheet,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.grey : primaryColor,
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedImageAdd01,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, Color primaryColor) {
    final shimmerBase = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final shimmerHighlight = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Customer' : 'Create Customer',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        foregroundColor: isDark ? Colors.white : primaryColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01),
        ),
      ),
      body: Container(
        color: isDark ? Colors.grey[900] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Shimmer.fromColors(
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    15,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
