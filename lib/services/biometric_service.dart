import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing biometric authentication (Face ID, Fingerprint).
class BiometricService {
  static LocalAuthentication? _localAuth;
  static bool _isInitialized = false;

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _localAuth = LocalAuthentication();
      _isInitialized = true;
    }
  }

  /// Checks if the device supports biometric authentication.
  static Future<bool> isBiometricAvailable() async {
    try {
      await _ensureInitialized();

      if (_localAuth == null) {
        return false;
      }

      final bool isDeviceSupported = await _localAuth!.isDeviceSupported();

      if (!isDeviceSupported) {
        return false;
      }

      final bool canCheckBiometrics = await _localAuth!.canCheckBiometrics;

      return canCheckBiometrics;
    } on PlatformException catch (e) {
      return false;
    } catch (e) {
      return false;
    }
  }


  /// Checks if the user has enabled biometric authentication in the app settings.
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Persists the user's biometric authentication preference.
  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  /// Prompts the user for biometric authentication.
  static Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to access the app',
  }) async {
    try {
      await _ensureInitialized();
      if (_localAuth == null) {
        return false;
      }

      final bool isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }

      final bool didAuthenticate = await _localAuth!.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
          break;
        case 'NotEnrolled':
          break;
        case 'LockedOut':
          break;
        case 'PermanentlyLockedOut':
          break;
        default:
      }
      return false;
    } catch (e) {
      return false;
    }
  }


  /// Determines if the app should prompt for biometric authentication based on settings and availability.
  static Future<bool> shouldPromptBiometric() async {
    try {
      final isEnabled = await isBiometricEnabled();
      if (!isEnabled) {
        return false;
      }

      final isAvailable = await isBiometricAvailable();

      return isAvailable;
    } catch (e) {
      return false;
    }
  }

  static Future<void> initialize() async {
    try {
      await _ensureInitialized();
      await _localAuth?.isDeviceSupported();
    } catch (e) {}
  }
}
