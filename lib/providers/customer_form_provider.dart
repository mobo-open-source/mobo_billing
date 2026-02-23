import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../services/runtime_permission_service.dart';
import '../services/odoo_api_service.dart';
import '../models/customer.dart';

/// Provider for managing customer creation/edit form state and image/OCR operations.
class CustomerFormProvider extends ChangeNotifier {
  final OdooApiService _apiService;
  final ImagePicker _picker;

  CustomerFormProvider({OdooApiService? apiService, ImagePicker? picker})
    : _apiService = apiService ?? OdooApiService(),
      _picker = picker ?? ImagePicker();

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool _isDropdownLoading = false;

  bool get isDropdownLoading => _isDropdownLoading;

  bool _isOcrLoading = false;

  bool get isOcrLoading => _isOcrLoading;

  String? _error;

  String? get error => _error;

  List<Map<String, dynamic>> _countryOptions = [];

  List<Map<String, dynamic>> get countryOptions => _countryOptions;

  List<Map<String, dynamic>> _stateOptions = [];

  List<Map<String, dynamic>> get stateOptions => _stateOptions;

  List<Map<String, String>> _titleOptions = [];

  List<Map<String, String>> get titleOptions => _titleOptions;

  List<Map<String, String>> _currencyOptions = [];

  List<Map<String, String>> get currencyOptions => _currencyOptions;

  List<Map<String, String>> _languageOptions = [];

  List<Map<String, String>> get languageOptions => _languageOptions;

  File? _pickedImage;

  File? get pickedImage => _pickedImage;

  void setPickedImage(File? file) {
    _pickedImage = file;
    notifyListeners();
  }

  /// Loads countries, titles, currencies, and languages for form dropdowns.
  Future<void> loadDropdownData() async {
    _isDropdownLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _fetchCountries(),
        _fetchTitles(),
        _fetchCurrencies(),
        _fetchLanguages(),
      ]);
    } catch (e) {
      _error = "Failed to load some options: $e";
    } finally {
      _isDropdownLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCountries() async {
    final result = await _apiService.searchRead(
      'res.country',
      [],
      ['id', 'name', 'code'],
      0,
      300,
      'name ASC',
    );
    _countryOptions = List<Map<String, dynamic>>.from(result);
  }

  /// Fetches the list of states for a specific country.
  Future<void> fetchStates(int countryId) async {
    _stateOptions = [];
    notifyListeners();
    final result = await _apiService.searchRead(
      'res.country.state',
      [
        ['country_id', '=', countryId],
      ],
      ['id', 'name', 'code'],
      0,
      300,
      'name ASC',
    );
    _stateOptions = List<Map<String, dynamic>>.from(result);
    notifyListeners();
  }

  Future<void> _fetchTitles() async {
    try {
      final result = await _apiService.searchRead('res.partner.title', [], [
        'id',
        'name',
      ]);
      _titleOptions = result
          .map(
            (e) => {'value': e['id'].toString(), 'label': e['name'].toString()},
          )
          .toList();
    } catch (e) {
      _titleOptions = [];
    }
  }

  Future<void> _fetchCurrencies() async {
    final result = await _apiService.searchRead(
      'res.currency',
      [
        ['active', '=', true],
      ],
      ['id', 'name'],
    );
    _currencyOptions = result
        .map(
          (e) => {'value': e['id'].toString(), 'label': e['name'].toString()},
        )
        .toList();
  }

  Future<void> _fetchLanguages() async {
    final result = await _apiService.searchRead(
      'res.lang',
      [
        ['active', '=', true],
      ],
      ['code', 'name'],
    );
    _languageOptions = result
        .map(
          (e) => {'value': e['code'].toString(), 'label': e['name'].toString()},
        )
        .toList();
  }

  /// Picks an image from the camera or gallery, requesting camera permissions if needed.
  Future<File?> pickImage(BuildContext context, ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final hasPermission = await RuntimePermissionService.requestCameraPermission(context);
        if (!hasPermission) return null;
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (pickedFile != null) {
        _pickedImage = File(pickedFile.path);
        notifyListeners();
        return _pickedImage;
      }
    } catch (e) {}
    return null;
  }

  /// Scans a business card using ML Kit OCR to extract text (Placeholder implementation).
  Future<Map<String, dynamic>?> scanBusinessCard(BuildContext context, ImageSource source) async {
    _isOcrLoading = true;
    notifyListeners();

    try {
      if (source == ImageSource.camera) {
        final hasPermission = await RuntimePermissionService.requestCameraPermission(context);
        if (!hasPermission) {
          _isOcrLoading = false;
          notifyListeners();
          return null;
        }
      }

      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );

      if (pickedFile == null) {
        _isOcrLoading = false;
        notifyListeners();
        return null;
      }

      final imageFile = File(pickedFile.path);
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      final recognizedText = await textRecognizer.processImage(inputImage);
      final fullText = recognizedText.text.trim();
      await textRecognizer.close();

      if (fullText.isEmpty) {
        _isOcrLoading = false;
        notifyListeners();
        return null;
      }

      _isOcrLoading = false;
      notifyListeners();
    } catch (e) {
      _isOcrLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Clears the current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Resets the form state and cleared picked images.
  void reset() {
    _pickedImage = null;
    _error = null;
    _stateOptions = [];
    notifyListeners();
  }

  /// Pre-populates form state from an existing customer model.
  void populateFromCustomer(Customer customer) {
    _pickedImage = null;
    if (customer.countryId != null) {
      fetchStates(customer.countryId!);
    }
    notifyListeners();
  }
}
