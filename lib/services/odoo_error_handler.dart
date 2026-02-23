/// Utility for parsing and transforming Odoo server errors into user-friendly messages.
class OdooErrorHandler {
  /// Checks if an error is related to access rights or permissions.
  static bool isAccessError(dynamic e) {
    final s = e.toString().toLowerCase();
    return s.contains('accesserror') ||
        s.contains('access rights') ||
        s.contains('access denied') ||
        s.contains('not allowed to') ||
        s.contains('permission');
  }

  /// Converts various Odoo and network errors into human-readable messages.
  static String toUserMessage(dynamic e, {String? defaultMessage}) {
    final errorString = e.toString();
    final s = errorString.toLowerCase();

    if (s.contains('no journal could be found') ||
        s.contains('no journal of type')) {
      String companyName = 'your company';
      String journalType = 'the required type';

      final companyMatch =
          RegExp(r'company\s+(.*?)\s+for\s+any').firstMatch(errorString) ??
          RegExp(r'company\s+(.*?)\s+[\(\)]').firstMatch(errorString);
      if (companyMatch != null && companyMatch.groupCount >= 1) {
        companyName = companyMatch.group(1)!.trim();
      }

      final typeMatch = RegExp(r'types?:\s*(\w+)').firstMatch(errorString);
      if (typeMatch != null && typeMatch.groupCount >= 1) {
        journalType = typeMatch.group(1)!.trim();
      }

      return '''⚙️ Configuration Required

The system cannot create an invoice because a ${journalType.toUpperCase()} journal is not configured for $companyName.

📋 To fix this issue:

1. Log into Odoo web interface
2. Go to Accounting → Configuration → Journals
3. Create a new journal with:
   • Type: ${journalType.toUpperCase()}
   • Name: Customer Invoices (or similar)
   • Short Code: INV (or your preference)
   • Company: $companyName

If this is a new database, you may need to install the Chart of Accounts first from Accounting → Configuration → Settings.

Please contact your system administrator if you need assistance.''';
    }

    if (s.contains('missing required account on accountable line')) {
      return '''⚙️ Accounting Configuration Required

The system cannot create an invoice because an income account is missing for one of the products.

📋 To fix this issue:

1. Log into Odoo web interface
2. Check the Product configuration:
   • Go to Inventory → Products
   • Open the product(s) in your invoice
   • Go to the 'Accounting' tab
   • Ensure 'Income Account' is set
3. OR check the Product Category:
   • Go to Inventory → Configuration → Product Categories
   • Ensure 'Income Account' is set for the category

If you have just installed Odoo, ensure you have a Chart of Accounts installed.

Please contact your system administrator for assistance.''';
    }

    if (s.contains('chart of accounts') ||
        s.contains('no account configured') ||
        s.contains('account.account')) {
      return '''⚙️ Accounting Setup Required

The accounting module is not fully configured for this company.

📋 To fix this issue:

1. Log into Odoo web interface
2. Go to Accounting → Configuration → Settings
3. Install the Chart of Accounts for your country
4. Complete the accounting setup wizard

This will automatically create all necessary journals and accounts.

Please contact your system administrator for assistance.''';
    }

    if (s.contains('fiscal position') && s.contains('not found')) {
      return '''⚙️ Fiscal Position Error

The fiscal position configured for this customer or company is invalid or missing.

📋 To fix this issue:

1. Check the customer's fiscal position settings
2. Verify fiscal positions in Accounting → Configuration → Fiscal Positions
3. Update or remove the invalid fiscal position

Please contact your system administrator for assistance.''';
    }

    if (s.contains('you are not allowed to create') ||
        s.contains('you are not allowed to modify') ||
        s.contains('you do not have permission')) {
      if (errorString.contains('message: ')) {
        final parts = errorString.split('message: ');
        if (parts.length > 1) {
          String permissionMsg = parts[1];
          if (permissionMsg.contains(', arguments:')) {
            permissionMsg = permissionMsg.split(', arguments:')[0];
          }
          if (permissionMsg.contains(', context:')) {
            permissionMsg = permissionMsg.split(', context:')[0];
          }
          return '🔒 Permission Denied\n\n$permissionMsg\n\nPlease contact your administrator to request the necessary permissions.';
        }
      }
    }

    if (isAccessError(e)) {
      return '🔒 Access Denied\n\nYou do not have sufficient permissions to perform this action.\n\nPlease contact your administrator to request the necessary permissions.';
    }

    if (s.contains('socketexception') ||
        s.contains('connection refused') ||
        s.contains('connection timeout') ||
        s.contains('host unreachable') ||
        s.contains('no route to host') ||
        s.contains('network is unreachable') ||
        s.contains('failed to connect') ||
        s.contains('connection failed') ||
        s.contains('server returned html instead of json')) {
      return '🌐 Connection Error\n\nThe server could not be reached. Please check:\n\n• Your internet connection\n• Server URL in settings\n• Server availability\n\nThen try again.';
    }

    if (s.contains('timeout')) {
      return '⏱️ Request Timeout\n\nThe request took too long to complete.\n\nThis might be due to:\n• Slow internet connection\n• Server overload\n• Large data processing\n\nPlease try again.';
    }

    if (s.contains('product') &&
        (s.contains('not found') || s.contains('does not exist'))) {
      return '📦 Product Error\n\nThe selected product is invalid or has been deleted.\n\nPlease select a different product and try again.';
    }

    if (s.contains('partner') &&
        (s.contains('not found') || s.contains('does not exist'))) {
      return '👤 Customer Error\n\nThe selected customer is invalid or has been deleted.\n\nPlease select a different customer and try again.';
    }

    if (s.contains('company inconsistencies') ||
        s.contains('company crossover')) {
      if (errorString.contains('message:')) {
        try {
          final messageStart = errorString.indexOf('message:');
          final messageContent = errorString.substring(
            messageStart + 'message:'.length,
          );

          var messageEnd = messageContent.indexOf(', arguments:');
          if (messageEnd == -1)
            messageEnd = messageContent.indexOf(', context:');
          if (messageEnd == -1) messageEnd = messageContent.indexOf(', debug:');

          if (messageEnd > 0) {
            String cleanMessage = messageContent
                .substring(0, messageEnd)
                .trim();
            cleanMessage = cleanMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
            return '⚠️ Company Mismatch\n\n$cleanMessage';
          }
        } catch (parseError) {}
      }
      return '⚠️ Company Mismatch\n\nThe product and taxes belong to different companies. Please ensure all items in the invoice belong to the same company.\n\nContact your administrator if you need assistance.';
    }

    if (s.contains('invalid field')) {
      return '🛠️ Compatibility Issue\n\nThe app encountered a field that is not supported by your Odoo version.\n\n$errorString\n\nPlease contact support with this error message.';
    }

    if (s.contains('no outstanding account') ||
        s.contains('outstanding account could be found')) {
      return '⚠️ Payment Configuration Error\n\nNo outstanding account could be found to make the payment.\n\nPlease check your payment method configuration or contact your accountant.';
    }

    String cleanMessage = errorString.replaceAll(RegExp(r'^Exception:\s*'), '');
    if (cleanMessage.trim().isEmpty) cleanMessage = 'Unknown Error';

    final lowerClean = cleanMessage.toLowerCase();
    final isGeneric =
        lowerClean == 'odoo server error' ||
        lowerClean == 'rpc error' ||
        lowerClean == 'xml-rpc error';

    if (!isGeneric && defaultMessage == null) {
      return '❌ Operation Failed\n\n$cleanMessage';
    }

    return defaultMessage ??
        '❌ Operation Failed\n\nAn unexpected error occurred. Please try again or contact support if the problem persists.';
  }
}
