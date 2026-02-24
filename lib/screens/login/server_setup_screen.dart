import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/odoo_api_service.dart';
import 'login_layout.dart';
import 'login_screen.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen();

  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<String> suggestions;
  final Function(String) onSuggestionSelected;
  final Widget child;

  const _CustomAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.child,
  });

  @override
  State<_CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<_CustomAutocompleteField> {
  bool _showSuggestions = false;
  List<String> _filteredSuggestions = [];
  late FocusNode _focusNode;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
      if (_filteredSuggestions.isNotEmpty) {
        _showSuggestionsOverlay();
      }
    } else {
      _hideSuggestions();
    }
  }

  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      _updateSuggestions();
      if (_overlayEntry != null) {
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) {
          _overlayEntry!.markNeedsBuild();
        } else {
          _removeOverlay();
        }
      }
    }
  }

  String _extractDomainFromUrl(String url) {
    if (url.startsWith('https://')) return url.substring(8);
    if (url.startsWith('http://')) return url.substring(7);
    return url;
  }

  void _updateSuggestions() {
    final text = widget.controller.text.toLowerCase().trim();
    if (text.isEmpty) {
      _filteredSuggestions = List.from(widget.suggestions);
    } else {
      _filteredSuggestions = widget.suggestions.where((s) {
        final suggestionLower = s.toLowerCase();
        if (text == 'h') {
          return suggestionLower.startsWith('https://');
        } else if (text == 'ht' || text == 'htt' || text == 'http') {
          return suggestionLower.startsWith('http://') ||
              suggestionLower.startsWith('https://');
        } else if (text == 'https') {
          return suggestionLower.startsWith('https://');
        } else if (text.startsWith('http://') || text.startsWith('https://')) {
          return suggestionLower.startsWith(text);
        }
        final textDomain = _extractDomainFromUrl(text);
        final suggestionDomain = _extractDomainFromUrl(suggestionLower);
        return suggestionDomain.startsWith(textDomain);
      }).toList();
    }
    setState(() {
      _showSuggestions = _filteredSuggestions.isNotEmpty;
    });
    if (_overlayEntry != null) {
      if (_filteredSuggestions.isEmpty) {
        _removeOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    } else if (_filteredSuggestions.isNotEmpty) {
      _showSuggestionsOverlay();
    }
  }

  void _showSuggestionsOverlay() {
    if (_filteredSuggestions.isEmpty || _overlayEntry != null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final fieldWidth =
        renderBox?.size.width ?? (MediaQuery.of(context).size.width - 48);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hoverColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.05);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        width: fieldWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60),
          child: Material(
            elevation: 12.0,
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black.withOpacity(0.2),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: _filteredSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _filteredSuggestions[index];
                    return InkWell(
                      onTap: () {
                        widget.onSuggestionSelected(suggestion);
                        _hideSuggestions();
                        _focusNode.unfocus();
                      },
                      hoverColor: hoverColor,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                suggestion,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestions() {
    _removeOverlay();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Focus(focusNode: _focusNode, child: widget.child),
    );
  }
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  final _urlController = TextEditingController();

  String _selectedProtocol = 'https://';
  String? _selectedDatabase;
  List<String> _databases = [];
  List<String> _urlHistory = [];
  bool _isLoading = false;
  bool _shouldValidate = false;
  bool _urlHasError = false;
  bool _dbHasError = false;
  bool _manualDbEntryRequired = false;
  String? _errorMessage;
  String? _dbInfoMessage;
  final _dbController = TextEditingController();
  Timer? _debounceTimer;

  String _extractProtocol(String fullUrl) {
    if (fullUrl.startsWith('https://')) return 'https://';
    if (fullUrl.startsWith('http://')) return 'http://';
    return _selectedProtocol;
  }

  String _extractDomain(String fullUrl) {
    if (fullUrl.startsWith('https://')) return fullUrl.substring(8);
    if (fullUrl.startsWith('http://')) return fullUrl.substring(7);
    return fullUrl;
  }

  void _setUrlFromFullUrl(String fullUrl) {
    final protocol = _extractProtocol(fullUrl);
    final domain = _extractDomain(fullUrl);
    setState(() {
      _selectedProtocol = protocol;
      _urlController.text = domain;
      _urlHasError = domain.trim().isEmpty;
      _dbHasError = false;
      _errorMessage = null;
      _shouldValidate = false;
    });
    _debounceTimer?.cancel();
    if (domain.trim().isNotEmpty && _isValidUrl(domain.trim())) {
      _validateUrlAndFetchDatabases();
    }
  }

  bool get _isNextButtonEnabled {
    final hasUrl = _urlController.text.trim().isNotEmpty;
    final hasDb = _selectedDatabase != null && _selectedDatabase!.isNotEmpty;

    final urlChecked =
        (_databases.isNotEmpty || _manualDbEntryRequired) &&
        _errorMessage == null;
    return hasUrl && urlChecked && hasDb && !_isLoading;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _dbController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('lastUrl');
    final savedDatabase = prefs.getString('lastDatabase');

    final urlHistoryList = prefs.getStringList('previous_server_urls') ?? [];
    setState(() {
      _urlHistory = urlHistoryList;
    });

    if (savedUrl != null && savedUrl.isNotEmpty) {
      String cleanUrl = savedUrl;
      if (savedUrl.startsWith('https://')) {
        _selectedProtocol = 'https://';
        cleanUrl = savedUrl.substring(8);
      } else if (savedUrl.startsWith('http://')) {
        _selectedProtocol = 'http://';
        cleanUrl = savedUrl.substring(7);
      }

      setState(() {
        _urlController.text = cleanUrl;
      });

      _validateUrlAndFetchDatabases();
    }

    if (savedDatabase != null && savedDatabase.isNotEmpty) {
      setState(() {
        _selectedDatabase = savedDatabase;
      });
    }
  }

  void _setProtocol(String protocol) {
    setState(() {
      _selectedProtocol = protocol;
    });
    final trimmed = _urlController.text.trim();
    if (trimmed.isNotEmpty && _isValidUrl(trimmed)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _validateUrlAndFetchDatabases();
        }
      });
    }
  }

  String _getFullUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return '';

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    return '$_selectedProtocol$url';
  }

  bool _isValidUrl(String url) {
    try {
      String urlToValidate = url.trim();
      if (urlToValidate.isEmpty) return false;

      if (!urlToValidate.startsWith('http://') &&
          !urlToValidate.startsWith('https://')) {
        urlToValidate = '$_selectedProtocol$urlToValidate';
      }

      final uri = Uri.parse(urlToValidate);
      if (!uri.hasScheme || uri.host.isEmpty) {
        return false;
      }

      final host = uri.host.toLowerCase();
      if (host.contains(' ') || host.startsWith('.') || host.endsWith('.')) {
        return false;
      }

      final validHostPattern = RegExp(r'^[a-zA-Z0-9.-]+$');
      if (!validHostPattern.hasMatch(host)) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  String? _getUrlValidationError(String url) {
    if (url.trim().isEmpty) {
      return null;
    }

    if (!_isValidUrl(url)) {
      return 'Please enter a valid server URL';
    }

    return null;
  }

  String _normalizeUrl(String url) {
    String normalizedUrl = url.trim();

    if (!normalizedUrl.startsWith('http://') &&
        !normalizedUrl.startsWith('https://')) {
      normalizedUrl = '$_selectedProtocol$normalizedUrl';
    }

    try {
      final uri = Uri.parse(normalizedUrl);
      final origin = Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : 0,
      );
      final originStr = origin.hasPort && origin.port != 0
          ? '${origin.scheme}://${origin.host}:${origin.port}'
          : '${origin.scheme}://${origin.host}';
      return originStr;
    } catch (_) {
      if (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      return normalizedUrl;
    }
  }

  Future<void> _validateUrlAndFetchDatabases() async {
    final trimmedUrl = _urlController.text.trim();

    if (trimmedUrl.isEmpty) {
      setState(() {
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    if (!_isValidUrl(trimmedUrl)) {
      setState(() {
        _databases.clear();
        _selectedDatabase = null;
        _errorMessage = 'Please enter a valid server URL';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _databases.clear();
      _selectedDatabase = null;
      _manualDbEntryRequired = false;
      _dbController.clear();
    });

    try {
      final baseUrl = _normalizeUrl(trimmedUrl);

      final databases = await OdooApiService()
          .listDatabasesForUrl(baseUrl)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Please check your internet connection.',
              );
            },
          );

      if (!mounted) return;

      final previousSelected = _selectedDatabase;
      setState(() {
        _databases = databases;
        _isLoading = false;
        _shouldValidate = false;
        _urlHasError = false;
        if (_databases.isEmpty) {
          _selectedDatabase = null;
          _dbHasError = false;
          _errorMessage = null;
          _dbInfoMessage = null;
        } else {
          if (previousSelected != null &&
              _databases.contains(previousSelected)) {
            _selectedDatabase = previousSelected;
          } else {
            _selectedDatabase = _databases.first;
          }
          _dbHasError = false;
          _errorMessage = null;
          _dbInfoMessage = null;
        }
      });

      if (mounted && _databases.isEmpty) {
        final defaultDb = await OdooApiService.getDefaultDatabase(baseUrl);
        if (!mounted) return;
        setState(() {
          if (defaultDb != null && defaultDb.isNotEmpty) {
            _databases = [defaultDb];
            _selectedDatabase = defaultDb;
            _errorMessage = null;
            _dbInfoMessage = 'Detected default database: $defaultDb';
          } else {
            _selectedDatabase = null;
            _errorMessage =
                'This server does not expose the database list and no default database could be detected.';
            _dbInfoMessage = null;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage =
          'Could not connect to server. Please check the URL and try again.';

      if (e.toString().contains('timeout') ||
          e.toString().contains('Connection timeout')) {
        errorMessage =
            'Connection timeout. Please check your internet connection and try again.';
      } else if (e.toString().contains('404') ||
          e.toString().contains('not found')) {
        errorMessage = 'Server not found. Please verify the URL is correct.';
      } else if (e.toString().contains('connection') ||
          e.toString().contains('SocketException')) {
        errorMessage =
            'Unable to connect to server. Check URL and network connection.';
      } else if (e.toString().contains('FormatException') ||
          e.toString().contains('Invalid')) {
        errorMessage = 'Invalid server URL format. Please check and try again.';
      }

      if (e.toString().contains('ACCESS_DENIED_DB_LIST')) {
        final baseUrl = _normalizeUrl(trimmedUrl);
        final defaultDb = await OdooApiService.getDefaultDatabase(baseUrl);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _databases.clear();
          if (defaultDb != null && defaultDb.isNotEmpty) {
            _databases = [defaultDb];
            _selectedDatabase = defaultDb;
            _errorMessage = null;
            _dbInfoMessage = 'Detected default database: $defaultDb';
          } else {
            _selectedDatabase = null;
            _manualDbEntryRequired = true;
            _errorMessage = null;
            _dbInfoMessage =
                'Could not discover default database. Please enter it manually.';
          }
        });
      } else {
        final baseUrl = _normalizeUrl(trimmedUrl);

        final defaultDb = await OdooApiService.getDefaultDatabase(baseUrl);
        if (!mounted) return;
        if (defaultDb != null && defaultDb.isNotEmpty) {
          setState(() {
            _isLoading = false;
            _databases = [defaultDb];
            _selectedDatabase = defaultDb;
            _errorMessage = null;
            _dbInfoMessage = 'Detected default database: $defaultDb';
          });
        } else {
          setState(() {
            _isLoading = false;
            _databases.clear();
            _selectedDatabase = null;
            _errorMessage = errorMessage;
            _dbInfoMessage = null;
          });
        }
      }
    }
  }

  void _proceedToLogin() async {
    if (_selectedDatabase == null || _selectedDatabase!.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a database';
      });
      return;
    }

    String url = _getFullUrl();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastUrl', url);
      await prefs.setString('lastDatabase', _selectedDatabase!);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                LoginScreen(serverUrl: url, database: _selectedDatabase!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to proceed to login. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: LoginLayout(
        title: 'Sign In',
        subtitle: 'Configure your server connection',
        child: _buildServerSetupForm(),
      ),
    );
  }

  Widget _buildServerSetupForm() {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CustomAutocompleteField(
            controller: _urlController,
            suggestions: _urlHistory,
            onSuggestionSelected: (selection) {
              _setUrlFromFullUrl(selection);
            },
            child: LoginUrlTextField(
              controller: _urlController,
              hint: 'Enter Server Address',
              prefixIcon: HugeIcons.strokeRoundedServerStack01,
              enabled: true,
              hasError: _urlHasError,
              selectedProtocol: _selectedProtocol,
              urlHistory: _urlHistory,
              isLoading: _isLoading,
              autovalidateMode: _shouldValidate
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              validator: (value) {
                if (_isLoading || !_shouldValidate) {
                  return null;
                }
                if (value == null || value.isEmpty) {
                  return 'Server URL is required';
                }
                return null;
              },
              onProtocolChanged: _setProtocol,
              onChanged: (value) {
                _debounceTimer?.cancel();

                setState(() {
                  _shouldValidate = false;
                  _urlHasError = false;
                });

                final trimmed = value.trim();
                final validationError = _getUrlValidationError(trimmed);

                if (validationError != null) {
                  setState(() {
                    _errorMessage = validationError;
                    _databases.clear();
                    _selectedDatabase = null;
                    _isLoading = false;
                  });
                  return;
                }

                if (_errorMessage != null &&
                    trimmed.isNotEmpty &&
                    _isValidUrl(trimmed)) {
                  setState(() {
                    _errorMessage = null;
                  });
                }

                _debounceTimer = Timer(const Duration(milliseconds: 700), () {
                  if (!mounted) return;
                  _validateUrlAndFetchDatabases();
                });
              },
            ),
          ),

          if (_databases.isNotEmpty || _manualDbEntryRequired) ...[
            const SizedBox(height: 16),
            if (_manualDbEntryRequired)
              LoginTextField(
                controller: _dbController,
                hint: 'Database Name',
                prefixIcon: HugeIcons.strokeRoundedDatabase,
                enabled: !_isLoading,
                hasError: _dbHasError,
                onChanged: (value) {
                  setState(() {
                    _selectedDatabase = value.trim();
                    _dbHasError = value.trim().isEmpty;
                    _errorMessage = null;
                  });
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Database name is required';
                  }
                  return null;
                },
                autovalidateMode: _shouldValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
              )
            else
              LoginDropdownField(
                hint: _isLoading ? 'Loading...' : 'Database',
                value: _selectedDatabase,
                items: _databases,
                onChanged: _isLoading
                    ? null
                    : (String? newValue) {
                        setState(() {
                          _selectedDatabase = newValue;
                          _dbHasError = (newValue == null || newValue.isEmpty);
                          _errorMessage = null;
                        });
                      },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Database is required';
                  }
                  return null;
                },
                hasError: _dbHasError,
                autovalidateMode: _shouldValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
              ),
            const SizedBox(height: 16),
            if (_dbInfoMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  _dbInfoMessage!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 16),

          LoginErrorDisplay(error: _errorMessage),

          LoginButton(
            text: 'Next',
            isLoading: _isLoading,
            isEnabled: _isNextButtonEnabled,
            onPressed: _isNextButtonEnabled ? _proceedToLogin : null,
          ),
        ],
      ),
    );
  }
}
