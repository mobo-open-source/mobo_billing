import 'package:flutter/material.dart';
import 'odoo_api_service.dart';
import 'invoice_service.dart';
import '../widgets/confetti_dialog.dart';

/// Service for handling low-level payment RPC actions like sending receipts.
class PaymentRpcService {
  /// Sends a payment receipt to the customer via email.
  static Future<void> sendPaymentReceipt(
    BuildContext context,
    int paymentId, {
    required VoidCallback closeLoadingDialog,
  }) async {
    try {
      await Future(() async {
        final apiService = OdooApiService();

        if (apiService.uid == null) {
          throw Exception('No active Odoo session');
        }

        final paymentCheck = await apiService.searchRead(
          'account.payment',
          [
            ['id', '=', paymentId],
          ],
          ['id', 'name', 'state', 'is_sent', 'reconciled_invoice_ids'],
        );

        if (paymentCheck.isEmpty) {
          throw Exception(
            'Payment with ID $paymentId not found or has been deleted',
          );
        }

        final payment = paymentCheck.first;
        final paymentState = payment['state']?.toString() ?? 'draft';
        final paymentName =
            (payment['name'] is String &&
                (payment['name'] as String).isNotEmpty)
            ? payment['name'] as String
            : 'Draft Payment';

        bool success = false;

        try {
          final wizardId = await apiService.call(
            'account.payment.send',
            'create',
            [
              {
                'payment_ids': [paymentId],
              },
            ],
          );

          if (wizardId is int) {
            await apiService.call('account.payment.send', 'action_send_mail', [
              [wizardId],
            ]);
            success = true;
          }
        } catch (e) {}

        if (!success) {
          try {
            final wizardAction = await apiService.call(
              'account.payment',
              'action_send_receipt',
              [paymentId],
            );

            if (wizardAction is Map && wizardAction.containsKey('res_model')) {
              final wizardModel = wizardAction['res_model'];
              final wizardContext = wizardAction['context'] ?? {};

              if (wizardModel == 'mail.compose.message') {
                int? wizardId;
                try {
                  final odoo18Context = Map<String, dynamic>.from(
                    wizardContext,
                  );
                  odoo18Context.remove('default_res_id');
                  odoo18Context['default_res_ids'] = [paymentId];
                  wizardId = await apiService.call(
                    'mail.compose.message',
                    'create',
                    [{}],
                    {'context': odoo18Context},
                  );
                } catch (e) {
                  wizardId = await apiService.call(
                    'mail.compose.message',
                    'create',
                    [{}],
                    {'context': wizardContext},
                  );
                }

                if (wizardId is int) {
                  await apiService.call(
                    'mail.compose.message',
                    'action_send_mail',
                    [wizardId],
                    {'context': wizardContext},
                  );
                  success = true;
                }
              }
            }
          } catch (e) {}
        }

        if (!success) {
          final reconciledInvoiceIds = payment['reconciled_invoice_ids'];
          if (reconciledInvoiceIds is List && reconciledInvoiceIds.isNotEmpty) {
            final invoiceId = reconciledInvoiceIds.first;

            await InvoiceService.sendInvoice(
              context,
              invoiceId,
              closeLoadingDialog: closeLoadingDialog,
            );
            return;
          }
        }

        if (!success) {
          try {
            final templates = await apiService.searchRead(
              'mail.template',
              [
                '|',
                ['name', 'ilike', 'Payment Receipt'],
                ['model', '=', 'account.payment'],
              ],
              ['id', 'name'],
              0,
              1,
            );
            int? templateId = templates.isNotEmpty
                ? templates.first['id']
                : null;

            final baseContext = {
              'default_model': 'account.payment',
              'default_template_id': templateId,
              'default_composition_mode': 'comment',
              'mark_payment_as_sent': true,
              'active_ids': [paymentId],
              'active_model': 'account.payment',
            };

            int? wizardId;
            try {
              final odoo18Context = {
                ...baseContext,
                'default_res_ids': [paymentId],
              };
              wizardId = await apiService.call(
                'mail.compose.message',
                'create',
                [{}],
                {'context': odoo18Context},
              );
            } catch (e) {
              final legacyContext = {
                ...baseContext,
                'default_res_id': paymentId,
              };
              wizardId = await apiService.call(
                'mail.compose.message',
                'create',
                [{}],
                {'context': legacyContext},
              );
            }

            if (wizardId is int) {
              await apiService.call(
                'mail.compose.message',
                'action_send_mail',
                [wizardId],
                {'context': baseContext},
              );
              success = true;
            }
          } catch (e) {}
        }

        if (success) {
          await _verifyAndShowSuccess(
            context,
            paymentId,
            paymentName.toString(),
            closeLoadingDialog,
          );
        } else {
          throw Exception(
            'Your Odoo version does not support sending standalone payment receipts via email, and this payment is not linked to an invoice.',
          );
        }
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Sending payment receipt timed out after 30 seconds');
        },
      );
    } catch (e) {
      if (context.mounted) {
        closeLoadingDialog();
      }
      rethrow;
    }
  }

  /// Verifies if the receipt was successfully sent and shows a confetti dialog.
  static Future<void> _verifyAndShowSuccess(
    BuildContext context,
    int paymentId,
    String paymentName,
    VoidCallback closeLoadingDialog,
  ) async {
    closeLoadingDialog();

    if (context.mounted) {
      showInvoiceSentConfettiDialog(
        context,
        paymentName,
        documentType: 'Payment Receipt',
      );
    }
  }
}
