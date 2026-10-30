import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks whether to drop a product line from the [documentType] being built
/// ("invoice", "credit note"), since the quantity and price already entered go
/// with it. Resolves to true only when the user confirms.
Future<bool> confirmRemoveProduct(
  BuildContext context, {
  required String documentType,
  String? productName,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final label = productName == null || productName.isEmpty
      ? 'this product'
      : '"$productName"';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      title: Text(
        'Remove Product',
        style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      content: Text(
        'Are you sure you want to remove $label from this $documentType?',
        style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
      // Same 24px side inset as the text, so the buttons line up with it.
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return confirmed == true;
}
