import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../services/odoo_session_manager.dart';
import 'custom_snackbar.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../services/runtime_permission_service.dart';

class PDFGenerator {
  static const bool _debugMode = false;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _localTimeout = Duration(seconds: 30);
  static const int _maxRetryAttempts = 1;

  /// Hard ceiling for one PDF request, covering *every* report candidate.
  /// Without it the fallback list multiplies the per-request timeout (5 reports
  /// x 30s) and the "Generating PDF" dialog can sit there for minutes.
  static const Duration _overallDeadline = Duration(seconds: 45);

  /// Report candidates for a customer invoice, most likely first.
  static const List<String> invoiceReportNames = [
    'account.report_invoice_with_payments',
    'account.report_invoice',
    'account.account_invoices',
    'account.report_invoice_document',
    'account.account_invoice_report',
  ];

  /// A connectivity failure — retrying the other report names cannot help.
  static bool _isOfflineError(Object error) {
    final message = error.toString();
    return message.contains('Failed host lookup') ||
        message.contains('No address associated with hostname') ||
        message.contains('SocketException') ||
        message.contains('Network is unreachable') ||
        message.contains('Connection refused') ||
        message.contains('Connection failed') ||
        message.contains('Connection closed');
  }

  /// Downloads the rendered invoice PDF, trying each report name in turn.
  ///
  /// Bounded two ways so the caller's loading dialog always ends: the whole
  /// walk shares [_overallDeadline], and an offline error aborts immediately
  /// instead of burning that budget on candidates that cannot succeed.
  static Future<Uint8List> _fetchInvoicePdfBytes({
    required String odooUrl,
    required int invoiceId,
    List<String> reportNames = invoiceReportNames,
  }) async {
    const methodName = '_fetchInvoicePdfBytes';
    final deadline = DateTime.now().add(_overallDeadline);
    final perRequestTimeout = _isLocalEnvironment(odooUrl)
        ? _localTimeout
        : _requestTimeout;

    Object? lastError;

    for (final reportName in reportNames) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _log(
          'Overall deadline reached before trying $reportName',
          method: methodName,
          level: 'WARN',
        );
        break;
      }

      final timeout = remaining < perRequestTimeout
          ? remaining
          : perRequestTimeout;

      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final pdfUrl =
            '$odooUrl/report/pdf/$reportName/$invoiceId?t=$timestamp';

        final response = await OdooSessionManager.makeAuthenticatedRequest(
          pdfUrl,
          body: null,
          timeout: timeout,
          maxRetries: 1,
        ).timeout(timeout);

        if (response.statusCode == 200 && _isPdfContent(response.bodyBytes)) {
          _log('Generated PDF with report $reportName', method: methodName);
          return response.bodyBytes;
        }

        lastError = Exception(
          'Report $reportName returned status ${response.statusCode}',
        );
      } on TimeoutException catch (e) {
        lastError = e;
        _log(
          'Report $reportName timed out after ${timeout.inSeconds}s',
          method: methodName,
          level: 'WARN',
        );
      } catch (e) {
        lastError = e;
        if (_isOfflineError(e)) {
          throw Exception(
            'Could not reach the server. Check your internet connection and try again.',
          );
        }
        _log(
          'Report $reportName failed: $e',
          method: methodName,
          level: 'WARN',
        );
      }
    }

    if (lastError is TimeoutException) {
      throw Exception(
        'The server took too long to generate the PDF. Please try again.',
      );
    }

    throw Exception(
      'Could not generate the invoice PDF. Please try again in a moment.',
    );
  }

  /// Renders the invoice and hands it to the platform print dialog.
  ///
  /// This is what "Print Invoice" uses — `Share.shareXFiles` only offers the
  /// share sheet, which has no print action on most devices.
  static Future<void> printInvoicePdf(
    BuildContext context,
    Invoice invoice, {
    VoidCallback? onPdfGenerated,
  }) async {
    final invoiceName = _safeString(invoice.name);
    final odooSession = await OdooSessionManager.getCurrentSession();
    final odooUrl = odooSession?.serverUrl ?? '';

    if (odooUrl.isEmpty) {
      throw Exception('Unable to generate PDF: no active server session');
    }

    final bytes = await _fetchInvoicePdfBytes(
      odooUrl: odooUrl,
      invoiceId: invoice.id,
    );

    // Close the caller's loading dialog before the system print sheet opens.
    onPdfGenerated?.call();

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Invoice $invoiceName',
    );
  }

  static void _log(String message, {String? method, String level = 'INFO'}) {
    if (_debugMode) {
      final timestamp = DateTime.now().toIso8601String();
    }
  }

  static Future<void> generateInvoicePdf(
    BuildContext context,
    Invoice invoice, {
    VoidCallback? onPdfGenerated,
  }) async {
    const methodName = 'generateInvoicePdf';
    final String invoiceName = _safeString(invoice.name);

    final hasPermission =
        await RuntimePermissionService.requestStoragePermission(context);
    if (!hasPermission) return;

    final odooSession = await OdooSessionManager.getCurrentSession();
    final String odooUrl = odooSession?.serverUrl ?? '';
    final int invoiceId = invoice.id;

    if (odooUrl.isEmpty) {
      _log('Invalid parameters', method: methodName, level: 'ERROR');
      throw ArgumentError(
        'Unable to generate PDF: Missing required information',
      );
    }

    try {
      // Bounded by _overallDeadline, so this can never leave the caller's
      // loading dialog up for minutes.
      final pdfBytes = await _fetchInvoicePdfBytes(
        odooUrl: odooUrl,
        invoiceId: invoiceId,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Invoice_${invoiceName}_${DateTime.now().millisecondsSinceEpoch}.pdf'
              .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final filePath = '${tempDir.path}/$fileName';

      await _cleanUpOldInvoicePdfFiles(tempDir, invoiceName);

      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      if (!await file.exists()) {
        throw Exception(
          'Invoice PDF was generated but failed to save to device',
        );
      }

      _log('Invoice PDF saved successfully: $filePath', method: methodName);

      if (onPdfGenerated != null) {
        onPdfGenerated();
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Invoice $invoiceName',
        subject: 'Invoice $invoiceName',
      );

      if (context.mounted) {
        _showSuccessSnackBar(
          context,
          'Invoice PDF generated and ready to share',
        );
      }
    } on TimeoutException {
      _log(
        'Invoice PDF generation timed out',
        method: methodName,
        level: 'ERROR',
      );
      rethrow;
    } on SocketException catch (e) {
      _log('Network error: $e', method: methodName, level: 'ERROR');
      rethrow;
    } catch (e, stackTrace) {
      _log(
        'Unexpected error: ${e.toString()}',
        method: methodName,
        level: 'ERROR',
      );
      _log('StackTrace: $stackTrace', method: methodName, level: 'ERROR');
      rethrow;
    }
  }

  static Future<void> generatePaymentPdf(
    BuildContext context,
    Payment payment, {
    VoidCallback? onPdfGenerated,
  }) async {
    const methodName = 'generatePaymentPdf';
    final String paymentName = _safeString(payment.name);

    final hasPermission =
        await RuntimePermissionService.requestStoragePermission(context);
    if (!hasPermission) return;

    final odooSession = await OdooSessionManager.getCurrentSession();
    final String odooUrl = odooSession?.serverUrl ?? '';
    final int paymentId = payment.id;

    const reportNames = ['account.report_payment_receipt'];

    if (odooUrl.isEmpty || paymentId == null) {
      _log('Invalid parameters', method: methodName, level: 'ERROR');
      throw ArgumentError(
        'Unable to generate PDF: Missing required information',
      );
    }

    bool isDialogOpen = false;

    try {
      http.Response? successfulResponse;
      Exception? lastError;
      bool isLocalEnvironment = _isLocalEnvironment(odooUrl);
      Duration timeoutDuration = isLocalEnvironment
          ? _localTimeout
          : _requestTimeout;

      for (final reportName in reportNames) {
        for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final pdfUrl =
                '$odooUrl/report/pdf/$reportName/$paymentId?t=$timestamp';
            _log(
              'Attempt $attempt: Trying report $reportName at $pdfUrl',
              method: methodName,
            );

            final response = await _makeRequestWithRetry(
              context,
              () => OdooSessionManager.makeAuthenticatedRequest(
                pdfUrl,
                body: null,
                timeout: timeoutDuration,
                maxRetries: 1,
              ),
              reportName: reportName,
              timeout: timeoutDuration,
            );

            if (response.statusCode == 200 &&
                _isPdfContent(response.bodyBytes)) {
              successfulResponse = response;
              _log(
                'Successfully generated Payment PDF with report $reportName',
                method: methodName,
              );
              break;
            }
          } on TimeoutException catch (e) {
            _log(
              'Request timed out on attempt $attempt for report $reportName after ${timeoutDuration.inSeconds} seconds',
              method: methodName,
              level: 'WARN',
            );
            lastError = TimeoutException(
              'PDF generation is taking longer than expected',
              timeoutDuration,
            );
            if (attempt < _maxRetryAttempts) {
              _log('Waiting before retry...', method: methodName);
              await Future.delayed(Duration(seconds: 3 * attempt));
            }
          } catch (e) {
            _log(
              'Error with report $reportName (attempt $attempt): $e',
              method: methodName,
              level: 'WARN',
            );
            lastError = e is Exception ? e : Exception(e.toString());
            if (attempt < _maxRetryAttempts) {
              await Future.delayed(Duration(seconds: 2 * attempt));
            }
          }
        }
        if (successfulResponse != null) break;
      }

      if (successfulResponse == null) {
        throw lastError ?? Exception('Payment PDF generation failed');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'Payment_${paymentName}_${DateTime.now().millisecondsSinceEpoch}.pdf'
              .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final filePath = '${tempDir.path}/$fileName';

      await _cleanUpOldPaymentPdfFiles(tempDir, paymentName);

      final file = File(filePath);
      await file.writeAsBytes(successfulResponse.bodyBytes);

      if (onPdfGenerated != null) {
        onPdfGenerated();
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Payment Receipt $paymentName',
        subject: 'Payment Receipt $paymentName',
      );

      if (context.mounted) {
        _showSuccessSnackBar(
          context,
          'Payment PDF generated and ready to share',
        );
      }
    } catch (e) {
      _log(
        'Unexpected error: ${e.toString()}',
        method: methodName,
        level: 'ERROR',
      );
      rethrow;
    } finally {
      if (isDialogOpen && context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  static Future<void> sendPaymentViaWhatsApp(
    BuildContext context,
    Map payment, {
    VoidCallback? onPdfGenerated,
  }) async {
    const methodName = 'sendPaymentViaWhatsApp';
    _log('Starting payment sharing via WhatsApp', method: methodName);

    final odooSession = await OdooSessionManager.getCurrentSession();
    final String odooUrl = odooSession?.serverUrl ?? '';
    final int? paymentId = payment['id'] as int?;
    final String paymentName = _safeString(payment['name']);

    const reportNames = ['account.report_payment_receipt'];

    if (odooUrl.isEmpty || paymentId == null) {
      throw ArgumentError(
        'Unable to send payment: Missing required information',
      );
    }

    try {
      final filePath = await _generatePaymentPdf(
        context,
        odooUrl,
        paymentId,
        paymentName,
        reportNames,
      );

      if (filePath == null) {
        throw Exception('Failed to generate PDF');
      }

      if (onPdfGenerated != null) {
        onPdfGenerated();
      }

      final xFile = XFile(filePath);
      final message = 'Here is your payment receipt $paymentName.';

      await _sharePdfWithFallback(context, xFile, message, isInvoice: false);
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> _generatePaymentPdf(
    BuildContext context,
    String odooUrl,
    int paymentId,
    String paymentName,
    List<String> reportNames,
  ) async {
    http.Response? successfulResponse;
    bool isLocalEnvironment = _isLocalEnvironment(odooUrl);
    Duration timeoutDuration = isLocalEnvironment
        ? _localTimeout
        : _requestTimeout;

    for (final reportName in reportNames) {
      for (int attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
        try {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final pdfUrl =
              '$odooUrl/report/pdf/$reportName/$paymentId?t=$timestamp';

          final response = await _makeRequestWithRetry(
            context,
            () => OdooSessionManager.makeAuthenticatedRequest(
              pdfUrl,
              body: null,
              timeout: timeoutDuration,
              maxRetries: 1,
            ),
            reportName: reportName,
            timeout: timeoutDuration,
          );

          if (response.statusCode == 200 && _isPdfContent(response.bodyBytes)) {
            successfulResponse = response;
            break;
          }
        } catch (e) {
          if (attempt == _maxRetryAttempts) continue;
          await Future.delayed(Duration(seconds: 2 * attempt));
        }
      }
      if (successfulResponse != null) break;
    }

    if (successfulResponse == null) return null;

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'Payment_${paymentName}_${DateTime.now().millisecondsSinceEpoch}.pdf'
            .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final filePath = '${tempDir.path}/$fileName';

    await _cleanUpOldPaymentPdfFiles(tempDir, paymentName);

    final file = File(filePath);
    await file.writeAsBytes(successfulResponse.bodyBytes);

    return await file.exists() ? filePath : null;
  }

  static Future<void> _cleanUpOldPaymentPdfFiles(
    Directory tempDir,
    String paymentName,
  ) async {
    try {
      final files = await tempDir.list().toList();
      final pattern = RegExp(
        'Payment_${paymentName}_\\d+\\.pdf'.replaceAll(
          RegExp(r'[^a-zA-Z0-9_.-]'),
          '_',
        ),
      );

      for (final file in files) {
        if (file is File && pattern.hasMatch(file.path)) {
          await file.delete();
        }
      }
    } catch (e) {
      _log('Error cleaning up old Payment PDF files: $e', level: 'WARN');
    }
  }

  static Future<void> sendInvoiceViaWhatsApp(
    BuildContext context,
    Invoice invoice, {
    VoidCallback? onPdfGenerated,
  }) async {
    const methodName = 'sendInvoiceViaWhatsApp';
    _log('Starting invoice sharing via WhatsApp', method: methodName);

    final odooSession = await OdooSessionManager.getCurrentSession();
    final String odooUrl = odooSession?.serverUrl ?? '';
    final int invoiceId = invoice.id;
    final String invoiceName = _safeString(invoice.name);

    const reportNames = [
      'account.report_invoice_with_payments',
      'account.report_invoice',
      'account.account_invoices',
    ];

    if (odooUrl.isEmpty || invoiceId == null) {
      _log(
        'Invalid parameters: missing URL or invoice ID',
        method: methodName,
        level: 'ERROR',
      );
      throw ArgumentError(
        'Unable to send invoice: Missing required information',
      );
    }

    try {
      final filePath = await _generateInvoicePdf(
        context,
        odooUrl,
        invoiceId,
        invoiceName,
        reportNames,
      );

      if (filePath == null) {
        throw Exception('Failed to generate PDF');
      }

      if (onPdfGenerated != null) {
        onPdfGenerated();
      }

      final xFile = XFile(filePath);
      final message =
          'Here is your invoice $invoiceName. Please review and let us know if you have any questions.';

      await _sharePdfWithFallback(context, xFile, message, isInvoice: true);
    } catch (e, stackTrace) {
      _log(
        'Unexpected error: ${e.toString()}',
        method: methodName,
        level: 'ERROR',
      );
      _log('StackTrace: $stackTrace', method: methodName, level: 'ERROR');
      rethrow;
    }
  }

  static Future<void> _sharePdfWithFallback(
    BuildContext context,
    XFile file,
    String message, {
    bool isInvoice = false,
  }) async {
    try {
      await Share.shareXFiles(
        [file],
        text: message,
        subject: isInvoice ? 'Invoice' : 'Quotation',
        sharePositionOrigin: Rect.fromLTWH(
          0,
          0,
          MediaQuery.of(context).size.width,
          MediaQuery.of(context).size.height / 2,
        ),
      );

      if (context.mounted) {
        _showSuccessSnackBar(
          context,
          isInvoice
              ? 'Invoice shared successfully'
              : 'Quotation shared successfully',
        );
      }
    } catch (e) {
      _log('Error sharing with text: $e', level: 'WARN');

      try {
        await Share.shareXFiles(
          [file],
          sharePositionOrigin: Rect.fromLTWH(
            0,
            0,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height / 2,
          ),
        );

        if (context.mounted) {
          _showSuccessSnackBar(
            context,
            isInvoice
                ? 'Invoice PDF shared successfully'
                : 'Quotation PDF shared successfully',
          );
        }
      } catch (e) {
        _log('Error sharing PDF only: $e', level: 'ERROR');
        if (context.mounted) {
          _showErrorSnackBar(
            context,
            isInvoice ? 'Failed to share invoice' : 'Failed to share quotation',
          );
        }
        rethrow;
      }
    }
  }

  static Future<String?> _generateInvoicePdf(
    BuildContext context,
    String odooUrl,
    int invoiceId,
    String invoiceName,
    List<String> reportNames,
  ) async {
    final pdfBytes = await _fetchInvoicePdfBytes(
      odooUrl: odooUrl,
      invoiceId: invoiceId,
      reportNames: reportNames,
    );

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'Invoice_${invoiceName}_${DateTime.now().millisecondsSinceEpoch}.pdf'
            .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final filePath = '${tempDir.path}/$fileName';

    await _cleanUpOldInvoicePdfFiles(tempDir, invoiceName);

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    return await file.exists() ? filePath : null;
  }

  static Future<void> _cleanUpOldInvoicePdfFiles(
    Directory tempDir,
    String invoiceName,
  ) async {
    try {
      final files = await tempDir.list().toList();
      final pattern = RegExp(
        'Invoice_${invoiceName}_\\d+\\.pdf'.replaceAll(
          RegExp(r'[^a-zA-Z0-9_.-]'),
          '_',
        ),
      );

      for (final file in files) {
        if (file is File && pattern.hasMatch(file.path)) {
          await file.delete();
        }
      }
    } catch (e) {
      _log('Error cleaning up old Invoice PDF files: $e', level: 'WARN');
    }
  }

  static bool _isLocalEnvironment(String url) {
    return url.contains('localhost') ||
        url.contains('127.0.0.1') ||
        url.contains('192.168.') ||
        url.contains('10.0.2.2');
  }

  static bool _isPdfContent(List<int> bytes) {
    if (bytes.length < 4) return false;

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  static Future<http.Response> _makeRequestWithRetry(
    BuildContext context,
    Future<http.Response> Function() requestFn, {
    required String reportName,
    required Duration timeout,
  }) async {
    return await requestFn().timeout(timeout);
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    CustomSnackbar.showError(context, message);
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    CustomSnackbar.showSuccess(context, message);
  }

  static String _getUserFriendlyError(Object error) {
    final e = error.toString();
    if (e.contains('SocketException') || e.contains('Connection refused')) {
      return 'Could not connect to server. Please check your internet connection.';
    }
    if (e.contains('TimeoutException')) {
      return 'Request timed out. Server might be busy.';
    }
    if (e.contains('404')) {
      return 'Report not found on server.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  static String _safeString(dynamic value) {
    if (value == null) return 'Draft';
    final str = value.toString();
    if (str == 'false' || str.isEmpty) return 'Draft';
    return str;
  }
}
