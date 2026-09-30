import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/auth_provider.dart';
import '../main_app_screen.dart';
import 'login_layout.dart';
import 'forgot_password_screen.dart';
import '../../widgets/module_missing_dialog.dart';
import 'totp_page.dart';
import '../../services/odoo_api_service.dart';

class LoginScreen extends StatefulWidget {
  final String? serverUrl;
  final String? database;

  const LoginScreen({Key? key, this.serverUrl, this.database})
    : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _shouldValidate = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;
  String? _errorMessage;
  bool _isPasswordVisible = false;
  String _protocol = 'https://';

  late String serverUrl;
  late String database;

  @override
  void initState() {
    super.initState();

    serverUrl = widget.serverUrl ?? '';
    database = widget.database ?? '';

    if (serverUrl.startsWith('http://')) {
      _protocol = 'http://';
    } else if (serverUrl.startsWith('https://')) {
      _protocol = 'https://';
    }

    if (serverUrl.isEmpty || database.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (serverUrl.isNotEmpty && database.isEmpty) {
          final detected = await OdooApiService.getDefaultDatabase(serverUrl);
          if (!mounted) return;
          if (detected != null && detected.isNotEmpty) {
            setState(() {
              database = detected;
              _errorMessage = null;
            });
          } else {
            setState(() {
              _errorMessage =
                  'Server URL and database are required. Please go back and configure.';
            });
          }
        } else {
          setState(() {
            _errorMessage =
                'Server URL and database are required. Please go back and configure.';
          });
        }
      });
    }

    _usernameController.clear();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginLayout(
      title: 'Sign In',
      subtitle: 'Enter your credentials to continue',
      backButton: Positioned(
        top: 24,
        left: 0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 64,
              width: 64,
              alignment: Alignment.center,
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
      child: Form(key: _loginFormKey, child: _buildLoginForm()),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AutofillGroup(
          child: Column(
            children: [
              LoginTextField(
                controller: _usernameController,
                hint: 'Email',
                prefixIcon: HugeIcons.strokeRoundedMail01,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                hasError: _emailHasError,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.username,
                ],
                autovalidateMode: _shouldValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (value) {
                  if (!_shouldValidate) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {
                    _emailHasError = value.trim().isEmpty;
                    if (_errorMessage != null) _errorMessage = null;
                  });
                },
              ),

              const SizedBox(height: 16),

              LoginTextField(
                controller: _passwordController,
                hint: 'Password',
                prefixIcon: HugeIcons.strokeRoundedLockPassword,
                obscureText: !_isPasswordVisible,
                enabled: !_isLoading,
                hasError: _passwordHasError,
                autofillHints: const [AutofillHints.password],
                autovalidateMode: _shouldValidate
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (value) {
                  if (!_shouldValidate) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Transform.scale(
                    scale: 20 / 24.0,
                    child: HugeIcon(
                      icon: _isPasswordVisible
                          ? HugeIcons.strokeRoundedView
                          : HugeIcons.strokeRoundedViewOff,
                      color: Colors.black54,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                onChanged: (value) {
                  setState(() {
                    _passwordHasError = value.isEmpty;
                    if (_errorMessage != null) _errorMessage = null;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ForgotPasswordScreen(url: serverUrl, db: database),
                      ),
                    );
                  },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _isLoading ? Colors.white54 : Colors.white70,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        LoginErrorDisplay(error: _errorMessage),

        LoginButton(
          text: 'Sign In',
          isLoading: _isLoading,
          onPressed: _performLogin,
          loadingWidget: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Signing In',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _performLogin() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _shouldValidate = true;
      _errorMessage = null;
    });

    final formValid = _loginFormKey.currentState?.validate() ?? false;

    setState(() {
      _emailHasError = _usernameController.text.trim().isEmpty;
      _passwordHasError = _passwordController.text.isEmpty;
    });

    if (!formValid) {
      await HapticFeedback.lightImpact();
      return;
    }

    if (serverUrl.isEmpty || database.isEmpty) {
      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Server configuration missing. Please go back and setup server.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final success = await authProvider.login(
        serverUrl,
        database,
        username,
        password,
      );

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastUrl', serverUrl);
        await prefs.setString('lastUsername', username);
        await prefs.setString('lastDatabase', database);
        await prefs.setBool('isLoggedIn', true);

        try {
          List<String> urls = prefs.getStringList('previous_server_urls') ?? [];
          urls.removeWhere((u) => u == serverUrl);
          urls.insert(0, serverUrl);
          if (urls.length > 10) {
            urls = urls.take(10).toList();
          }
          await prefs.setStringList('previous_server_urls', urls);
        } catch (_) {}

        if (mounted) {
          final accessResult = await authProvider.checkAppAccess();

          if (accessResult != AppAccessResult.ok) {
            await authProvider.logout();
            if (mounted) {
              if (accessResult == AppAccessResult.accessDenied) {
                showAccessDeniedDialog(context);
              } else {
                showModuleMissingDialog(context);
              }
              setState(() {
                _isLoading = false;
              });
            }
            return;
          }

          TextInput.finishAutofillContext();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainAppScreen()),
            (route) => false,
          );
        }
      } else {
        await HapticFeedback.heavyImpact();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'Invalid credentials. Please check your email and password.';
          _isLoading = false;
        });
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('null') ||
          errorStr.contains('two factor') ||
          errorStr.contains('2fa')) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TotpPage(
                serverUrl: serverUrl,
                database: database,
                username: _usernameController.text.trim(),
                password: _passwordController.text.trim(),
                protocol: _protocol,
              ),
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      await HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _errorMessage = _parseLoginError(e.toString());
        _isLoading = false;
      });
    }
  }

  String _parseLoginError(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('access denied') ||
        errorLower.contains('invalid login') ||
        errorLower.contains('authentication failed') ||
        errorLower.contains('wrong login/password') ||
        errorLower.contains('invalid username or password') ||
        errorLower.contains('login failed')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    }

    if (errorLower.contains('database') && errorLower.contains('not found')) {
      return 'Database not found. Please check your server configuration.';
    }

    if (errorLower.contains('connection') ||
        errorLower.contains('network') ||
        errorLower.contains('timeout') ||
        errorLower.contains('unreachable')) {
      return 'Unable to connect to server. Please check your internet connection and server URL.';
    }

    if (errorLower.contains('500') ||
        errorLower.contains('internal server error')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    }

    if (errorLower.contains('permission') || errorLower.contains('access')) {
      return 'Access denied. Please check your user permissions.';
    }

    return 'Login failed. Please check your credentials and try again.';
  }
}
