import 'package:flutter/material.dart';
import 'odoo_api_service.dart';
import '../widgets/confetti_dialog.dart';

/// Service for handling high-level invoice actions like sending invoices to customers.
class InvoiceService {
  /// Sends an invoice to the customer using Odoo's 'action_invoice_sent' flow.
  static Future<void> sendInvoice(
    BuildContext context,
    int moveId, {
    required VoidCallback closeLoadingDialog,
  }) async {
    try {
      final apiService = OdooApiService();

      if (apiService.uid == null) {
        throw Exception('No active Odoo session');
      }

      final invoiceCheck = await apiService.searchRead(
        'account.move',
        [
          ['id', '=', moveId],
        ],
        ['id', 'name', 'state', 'move_type', 'partner_id', 'is_move_sent'],
      );

      if (invoiceCheck.isEmpty) {
        throw Exception(
          'Invoice with ID $moveId not found or has been deleted',
        );
      }

      final invoice = invoiceCheck.first;
      final invoiceState = invoice['state'];
      final invoiceName = invoice['name'];
      final moveType = invoice['move_type'];
      final isMoveSent = invoice['is_move_sent'] ?? false;

      if (invoiceState != 'posted') {
        throw Exception(
          'Invoice $invoiceName must be validated/posted before it can be sent. Current state: $invoiceState',
        );
      }

      if (moveType != 'out_invoice' && moveType != 'out_refund') {
        throw Exception(
          'This document type ($moveType) cannot be sent as an invoice',
        );
      }

      final wizardAction = await apiService.call(
        'account.move',
        'action_invoice_sent',
        [moveId],
      );

      if (wizardAction is Map && wizardAction.containsKey('res_model')) {
        final wizardModel = wizardAction['res_model'];
        final wizardContext = wizardAction['context'] ?? {};

        if (wizardModel == 'base.document.layout') {
          if (wizardContext is Map &&
              wizardContext.containsKey('report_action')) {
            final reportAction = wizardContext['report_action'];
            if (reportAction is Map &&
                reportAction['res_model'] == 'account.move.send.wizard') {
              final nestedContext = reportAction['context'] ?? wizardContext;

              final wizardCreateResult = await apiService.call(
                'account.move.send.wizard',
                'create',
                [
                  {'move_id': moveId},
                ],
                {'context': nestedContext},
              );

              if (wizardCreateResult is int) {
                final sendResult = await apiService.call(
                  'account.move.send.wizard',
                  'action_send_and_print',
                  [wizardCreateResult],
                  {'context': nestedContext},
                );

                await _verifyAndShowSuccess(
                  context,
                  moveId,
                  invoiceName,
                  closeLoadingDialog,
                );
              } else {
                throw Exception('Failed to create send wizard');
              }
            } else {
              throw Exception(
                'No valid send wizard found in document layout action',
              );
            }
          } else {
            throw Exception(
              'Document layout wizard missing report_action context',
            );
          }
        } else if (wizardModel == 'account.move.send.wizard') {
          final wizardCreateResult = await apiService.call(
            'account.move.send.wizard',
            'create',
            [
              {'move_id': moveId},
            ],
            {'context': wizardContext},
          );

          if (wizardCreateResult is int) {
            final sendResult = await apiService.call(
              'account.move.send.wizard',
              'action_send_and_print',
              [wizardCreateResult],
              {'context': wizardContext},
            );

            await _verifyAndShowSuccess(
              context,
              moveId,
              invoiceName,
              closeLoadingDialog,
            );
          } else {
            throw Exception('Failed to create send wizard');
          }
        } else {
          throw Exception('Unexpected wizard model: $wizardModel');
        }
      } else {
        final directResult = await apiService.call(
          'account.move',
          'action_send_and_print',
          [moveId],
        );

        if (context.mounted) {
          closeLoadingDialog();
          final documentType = moveType == 'out_refund'
              ? 'Credit Note'
              : 'Invoice';
          showInvoiceSentConfettiDialog(
            context,
            invoiceName,
            documentType: documentType,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        closeLoadingDialog();
      }
      rethrow;
    }
  }

  /// Verifies if the invoice was successfully sent and shows a confetti dialog.
  static Future<void> _verifyAndShowSuccess(
    BuildContext context,
    int moveId,
    String invoiceName,
    VoidCallback closeLoadingDialog,
  ) async {
    final apiService = OdooApiService();

    await Future.delayed(const Duration(milliseconds: 500));

    final verifyResult = await apiService.read(
      'account.move',
      [moveId],
      ['is_move_sent', 'move_type'],
    );

    final isSent = verifyResult.isNotEmpty
        ? verifyResult.first['is_move_sent'] ?? false
        : false;
    final moveType = verifyResult.isNotEmpty
        ? verifyResult.first['move_type']
        : 'out_invoice';
    final documentType = moveType == 'out_refund' ? 'Credit Note' : 'Invoice';

    if (context.mounted) {
      if (isSent) {
        closeLoadingDialog();

        showInvoiceSentConfettiDialog(
          context,
          invoiceName,
          documentType: documentType,
        );
      } else {
        closeLoadingDialog();
      }
    }
  }
}
