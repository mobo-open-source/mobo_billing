import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/custom_snackbar.dart';
import '../theme/app_theme.dart';

/// Service for requesting and managing device runtime permissions.
class RuntimePermissionService {
  static final RuntimePermissionService _instance = RuntimePermissionService._internal();
  factory RuntimePermissionService() => _instance;
  RuntimePermissionService._internal();

  static RuntimePermissionService get instance => _instance;

  Future<bool> requestStoragePermissionInstance(BuildContext context) => 
      requestStoragePermission(context);
  
  Future<bool> requestCameraPermissionInstance(BuildContext context) => 
      requestCameraPermission(context);

  Future<bool> requestPhonePermissionInstance(BuildContext context) => 
      requestPhonePermission(context);

  /// Requests microphone permission with an optional rationale dialog.
  static Future<bool> requestMicrophonePermission(BuildContext context, {bool showRationale = true}) async {
    try {
      var status = await Permission.microphone.status;

      if (status.isGranted) return true;

      
      if (showRationale && await Permission.microphone.shouldShowRequestRationale) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Microphone Access',
          'This app needs microphone access to enable voice search functionality. You can search for products, customers, and invoices using your voice.',
          Icons.mic,
        );

        if (!shouldRequest) return false;
      }

      status = await Permission.microphone.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog(
          context,
          'Microphone Permission',
          'Microphone permission is permanently denied. Please enable it in app settings to use voice search.',
        );
        return false;
      }

      if (!status.isGranted) {
        if (context.mounted) {
          CustomSnackbar.showError(context, 'Microphone permission denied. Voice search will not work.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Failed to request microphone permission');
      }
      return false;
    }
  }

  /// Requests camera permission with an optional rationale dialog.
  static Future<bool> requestCameraPermission(BuildContext context, {bool showRationale = true}) async {
    try {
      var status = await Permission.camera.status;

      if (status.isGranted) return true;

      
      if (showRationale && await Permission.camera.shouldShowRequestRationale) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Camera Access',
          'This app needs camera access to scan barcodes and QR codes for quick product lookup and invoice processing.',
          Icons.camera_alt,
        );

        if (!shouldRequest) return false;
      }

      status = await Permission.camera.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog(
          context,
          'Camera Permission',
          'Camera permission is permanently denied. Please enable it in app settings to use scanning features.',
        );
        return false;
      }

      if (!status.isGranted) {
        if (context.mounted) {
          CustomSnackbar.showError(context, 'Camera permission denied. Scanning will not work.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Failed to request camera permission');
      }
      return false;
    }
  }

  /// Requests location permission with an optional rationale dialog.
  static Future<bool> requestLocationPermission(BuildContext context, {bool showRationale = true}) async {
    try {
      var status = await Permission.location.status;

      if (status.isGranted) return true;

      
      if (showRationale && await Permission.location.shouldShowRequestRationale) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Location Access',
          'This app needs location access to show customer locations on maps, find nearby customers, and provide location-based services.',
          Icons.location_on,
        );

        if (!shouldRequest) return false;
      }

      status = await Permission.location.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog(
          context,
          'Location Permission',
          'Location permission is permanently denied. Please enable it in app settings to use location features.',
        );
        return false;
      }

      if (!status.isGranted) {
        if (context.mounted) {
          CustomSnackbar.showError(context, 'Location permission denied. Location features will not work.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Failed to request location permission');
      }
      return false;
    }
  }

  /// Requests phone/call permission with an optional rationale dialog.
  static Future<bool> requestPhonePermission(BuildContext context, {bool showRationale = true}) async {
    try {
      var status = await Permission.phone.status;

      if (status.isGranted) return true;

      
      if (showRationale && await Permission.phone.shouldShowRequestRationale) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Phone Access',
          'This app needs phone access to make direct calls to customers from their contact information.',
          Icons.phone,
        );

        if (!shouldRequest) return false;
      }

      status = await Permission.phone.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog(
          context,
          'Phone Permission',
          'Phone permission is permanently denied. Please enable it in app settings to make calls.',
        );
        return false;
      }

      if (!status.isGranted) {
        if (context.mounted) {
          CustomSnackbar.showError(context, 'Phone permission denied. Calling will not work.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Failed to request phone permission');
      }
      return false;
    }
  }

  /// Requests external storage or photo library permission with an optional rationale dialog.
  static Future<bool> requestStoragePermission(BuildContext context, {bool showRationale = true}) async {
    try {
      Permission permission;
      
      
      if (Platform.isAndroid) {
        permission = Permission.photos;
        var status = await permission.status;
        
        
        if (status == PermissionStatus.denied) {
          permission = Permission.storage;
          status = await permission.status;
        }
        
        if (status.isGranted) return true;
      } else {
        permission = Permission.photos;
        var status = await permission.status;
        if (status.isGranted) return true;
      }

      
      if (showRationale && await permission.shouldShowRequestRationale) {
        final shouldRequest = await _showPermissionRationale(
          context,
          'Storage Access',
          'This app needs storage access to save and share documents, invoices, and other files.',
          Icons.folder,
        );

        if (!shouldRequest) return false;
      }

      final status = await permission.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentlyDeniedDialog(
          context,
          'Storage Permission',
          'Storage permission is permanently denied. Please enable it in app settings to save and share files.',
        );
        return false;
      }

      if (!status.isGranted) {
        if (context.mounted) {
          CustomSnackbar.showError(context, 'Storage permission denied. File operations may not work.');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        CustomSnackbar.showError(context, 'Failed to request storage permission');
      }
      return false;
    }
  }

  static Future<bool> _showPermissionRationale(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Not Now', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: isDark ? 0 : 3,
                    ),
                    child: const Text('Grant Permission', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ) ?? false;
  }

  static Future<void> _showPermanentlyDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      elevation: isDark ? 0 : 3,
                    ),
                    child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Checks if a specific permission has already been granted.
  static Future<bool> isPermissionGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// Checks the status of multiple permissions simultaneously.
  static Future<Map<Permission, bool>> checkMultiplePermissions(List<Permission> permissions) async {
    final Map<Permission, bool> results = {};
    
    for (final permission in permissions) {
      results[permission] = await isPermissionGranted(permission);
    }
    
    return results;
  }
}
