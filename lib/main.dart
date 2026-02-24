import 'package:flutter/material.dart';
import 'package:mobo_billing/providers/auth_provider.dart';
import 'package:mobo_billing/providers/credit_note_provider.dart';
import 'package:mobo_billing/providers/invoice_provider.dart';
import 'package:mobo_billing/providers/last_opened_provider.dart';
import 'package:mobo_billing/providers/payment_provider.dart';
import 'package:mobo_billing/providers/settings_provider.dart';
import 'package:mobo_billing/providers/theme_provider.dart';
import 'package:mobo_billing/providers/profile_provider.dart';
import 'package:mobo_billing/providers/odoo_settings_provider.dart';
import 'package:mobo_billing/providers/invoice_export_provider.dart';
import 'package:mobo_billing/providers/currency_provider.dart';
import 'package:mobo_billing/services/connectivity_service.dart';
import 'package:mobo_billing/services/session_service.dart';
import 'package:mobo_billing/providers/customer_provider.dart';
import 'package:mobo_billing/providers/product_provider.dart';
import 'package:provider/provider.dart';
import 'package:mobo_billing/providers/navigation_provider.dart';
import 'package:mobo_billing/providers/customer_form_provider.dart';
import 'package:mobo_billing/providers/company_provider.dart';
import 'package:mobo_billing/screens/login/server_setup_screen.dart';
import 'package:mobo_billing/screens/main_app_screen.dart';
import 'package:mobo_billing/theme/app_theme.dart';
import 'package:mobo_billing/services/biometric_service.dart';
import 'package:mobo_billing/screens/auth/app_lock_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobo_billing/screens/others/get_started_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BiometricService.initialize();

  runApp(const BillingApp());
}

class BillingApp extends StatelessWidget {
  const BillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => SessionService()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LastOpenedProvider()),
        ChangeNotifierProvider(create: (_) => CreditNoteProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => OdooSettingsProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceExportProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => CustomerFormProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          if (!themeProvider.isInitialized) {
            return const SizedBox.shrink();
          }
          return MaterialApp(
            title: 'Odoo Billing App',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (context) => const ServerSetupScreen(),
              '/get-started': (context) => const GetStartedScreen(),
              '/app': (context) => const MainAppScreen(),
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static bool _hasPlayedOnce = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();

    if (_hasPlayedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _proceedNext();
      });
      return;
    }
    _hasPlayedOnce = true;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      const assetPath = 'assets/splash/billing.mp4';
      _videoController = VideoPlayerController.asset(assetPath);
      await _videoController!.initialize();

      if (!mounted) return;

      setState(() {
        _isVideoInitialized = true;
      });

      await _videoController!.play();

      bool hasNavigated = false;

      final minimumDuration = Future.delayed(const Duration(seconds: 2));

      _videoController!.addListener(() {
        if (!hasNavigated &&
            _videoController!.value.position >=
                _videoController!.value.duration) {
          hasNavigated = true;
          if (mounted) {
            minimumDuration.then((_) {
              if (mounted) _proceedNext();
            });
          }
        }
      });

      minimumDuration.then((_) {
        if (!hasNavigated && mounted) {
          hasNavigated = true;
          _proceedNext();
        }
      });
    } catch (e) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _proceedNext();
    }
  }

  Future<void> _proceedNext() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    final results = await Future.wait([
      authProvider.autoLogin(),
      settingsProvider.loadLocalSettings(),
    ]);

    final isLoggedIn = results[0] as bool;

    if (!mounted) return;

    if (isLoggedIn) {
      final shouldPromptBiometric =
          await BiometricService.shouldPromptBiometric();

      if (shouldPromptBiometric && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => AppLockScreen(
              onAuthenticationSuccess: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const MainAppScreen(),
                  ),
                );
              },
            ),
          ),
        );
      } else if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainAppScreen()),
        );
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

      if (!mounted) return;

      if (!hasSeenGetStarted) {
        Navigator.of(context).pushReplacementNamed('/get-started');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: AppTheme.primaryColor)),
          if (_isVideoInitialized && _videoController != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
