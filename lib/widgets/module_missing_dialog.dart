import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';

void showModuleMissingDialog(BuildContext context) {
  _showBlockingLoginDialog(
    context,
    icon: HugeIcons.strokeRoundedAlertCircle,
    iconColor: AppTheme.primaryColor,
    title: 'Module Missing',
    message:
        'The required "Invoicing" module is not installed. Please contact your administrator to enable it.',
  );
}

/// Shown when the credentials are valid but the user isn't granted billing
/// access (e.g. missing the Billing/Invoicing user group in Odoo).
void showAccessDeniedDialog(BuildContext context) {
  _showBlockingLoginDialog(
    context,
    icon: HugeIcons.strokeRoundedShield01,
    iconColor: StatusColors.red,
    title: 'Access Denied',
    message:
        'Your account does not have permission to access Billing. Please contact your administrator to request access.',
  );
}

void _showBlockingLoginDialog(
  BuildContext context, {
  required List<List<dynamic>> icon,
  required Color iconColor,
  required String title,
  required String message,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      title: Row(
        children: [
          HugeIcon(icon: icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: GoogleFonts.manrope(
          fontSize: 15,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[300]!
              : Colors.black87,
          height: 1.5,
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: Theme.of(context).brightness == Brightness.dark
                  ? 0
                  : 3,
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'Back to Login',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
