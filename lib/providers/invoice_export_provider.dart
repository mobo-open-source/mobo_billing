import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import '../services/odoo_api_service.dart';
import '../models/invoice.dart';
import '../services/runtime_permission_service.dart';

/// Provider for exporting invoice data to localized files (Excel/CSV).
class InvoiceExportProvider extends ChangeNotifier {
  final OdooApiService _apiService;
  final RuntimePermissionService _permissionService;

  InvoiceExportProvider({
    OdooApiService? apiService,
    RuntimePermissionService? permissionService,
  }) : _apiService = apiService ?? OdooApiService(),
       _permissionService = permissionService ?? RuntimePermissionService();

  bool _isExporting = false;
  String _errorMessage = '';
  String? _savedFilePath;
  String? _savedFileName;

  bool get isExporting => _isExporting;

  String get errorMessage => _errorMessage;

  String? get savedFilePath => _savedFilePath;

  String? get savedFileName => _savedFileName;

  /// Exports invoices within a date range to Excel or CSV format.
  Future<void> exportInvoices(
    BuildContext context, {
    required DateTime fromDate,
    required DateTime toDate,
    required String format,
    required String status,
  }) async {
    final hasPermission = await _permissionService.requestStoragePermissionInstance(context);
    if (!hasPermission) return;

    _setExporting(true);
    _errorMessage = '';

    try {
      final invoices = await _fetchInvoicesForPeriod(
        fromDate: fromDate,
        toDate: toDate,
        status: status,
      );

      if (invoices.isEmpty) {
        throw Exception('No invoices found for the selected period and status');
      }

      if (format == 'Excel') {
        await _exportToExcel(invoices, fromDate, toDate);
      } else {
        await _exportToCSV(invoices, fromDate, toDate);
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        _errorMessage = 'Export timed out. Please try a smaller date range.';
      } else {
        _errorMessage = 'Export failed: ${e.toString()}';
      }
    } finally {
      _setExporting(false);
    }
  }

  Future<List<Invoice>> _fetchInvoicesForPeriod({
    required DateTime fromDate,
    required DateTime toDate,
    required String status,
  }) async {
    List<dynamic> domain = [
      ['invoice_date', '>=', fromDate.toIso8601String().split('T')[0]],
      ['invoice_date', '<=', toDate.toIso8601String().split('T')[0]],
    ];

    switch (status) {
      case 'draft':
        domain.add(['state', '=', 'draft']);
        break;
      case 'posted':
        domain.add(['state', '=', 'posted']);
        break;
      case 'paid':
        domain.addAll([
          ['state', '=', 'posted'],
          ['payment_state', '=', 'paid'],
        ]);
        break;
      case 'unpaid':
        domain.addAll([
          ['state', '=', 'posted'],
          [
            'payment_state',
            'in',
            ['not_paid', 'partial'],
          ],
        ]);
        break;
    }

    final invoiceData = await _apiService.searchRead('account.move', domain, [
      'name',
      'invoice_date',
      'invoice_date_due',
      'partner_id',
      'state',
      'payment_state',
      'amount_untaxed',
      'amount_tax',
      'amount_total',
      'currency_id',
      'ref',
      'invoice_origin',
      'payment_reference',
      'invoice_line_ids',
    ]);

    return invoiceData.map((data) => Invoice.fromJson(data)).toList();
  }

  Future<void> _exportToExcel(
    List<Invoice> invoices,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Invoice Report'];

    final headers = [
      'Invoice Number',
      'Date',
      'Due Date',
      'Customer',
      'Status',
      'Payment Status',
      'Subtotal',
      'Tax',
      'Total',
      'Currency',
      'Reference',
      'Origin',
      'Payment Reference',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.black,
      );
    }

    for (int i = 0; i < invoices.length; i++) {
      final invoice = invoices[i];
      final rowIndex = i + 1;

      final rowData = [
        invoice.name,
        invoice.invoiceDate?.toIso8601String().split('T')[0] ?? '',
        invoice.invoiceDateDue?.toIso8601String().split('T')[0] ?? '',
        invoice.customerName,
        _getStatusDisplayName(invoice.state),
        _getPaymentStatusDisplayName(invoice.paymentState),
        invoice.amountUntaxed.toStringAsFixed(2),
        invoice.amountTax.toStringAsFixed(2),
        invoice.amountTotal.toStringAsFixed(2),
        invoice.currencySymbol,
        invoice.ref ?? '',
        invoice.invoiceOrigin ?? '',
        invoice.paymentReference ?? '',
      ];

      for (int j = 0; j < rowData.length; j++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: j, rowIndex: rowIndex),
        );
        cell.value = TextCellValue(rowData[j]);
      }
    }

    final summaryRowIndex = invoices.length + 2;
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      'TOTAL',
    );

    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountTotal,
    );
    final totalTax = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountTax,
    );
    final totalUntaxed = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountUntaxed,
    );

    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      totalUntaxed.toStringAsFixed(2),
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      totalTax.toStringAsFixed(2),
    );
    sheet
        .cell(
          CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: summaryRowIndex),
        )
        .value = TextCellValue(
      totalAmount.toStringAsFixed(2),
    );

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: summaryRowIndex),
      );
      cell.cellStyle = CellStyle(bold: true);
    }

    await _saveAndOpenFile(
      excel.encode()!,
      'invoice_report_${fromDate.toIso8601String().split('T')[0]}_to_${toDate.toIso8601String().split('T')[0]}.xlsx',
    );
  }

  Future<void> _exportToCSV(
    List<Invoice> invoices,
    DateTime fromDate,
    DateTime toDate,
  ) async {
    final csvData = StringBuffer();

    csvData.writeln(
      [
        'Invoice Number',
        'Date',
        'Due Date',
        'Customer',
        'Status',
        'Payment Status',
        'Subtotal',
        'Tax',
        'Total',
        'Currency',
        'Reference',
        'Origin',
        'Payment Reference',
      ].map((field) => '"$field"').join(','),
    );

    for (final invoice in invoices) {
      csvData.writeln(
        [
              invoice.name,
              invoice.invoiceDate?.toIso8601String().split('T')[0] ?? '',
              invoice.invoiceDateDue?.toIso8601String().split('T')[0] ?? '',
              invoice.customerName,
              _getStatusDisplayName(invoice.state),
              _getPaymentStatusDisplayName(invoice.paymentState),
              invoice.amountUntaxed.toStringAsFixed(2),
              invoice.amountTax.toStringAsFixed(2),
              invoice.amountTotal.toStringAsFixed(2),
              invoice.currencySymbol,
              invoice.ref ?? '',
              invoice.invoiceOrigin ?? '',
              invoice.paymentReference ?? '',
            ]
            .map((field) => '"${field.toString().replaceAll('"', '""')}"')
            .join(','),
      );
    }

    final totalAmount = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountTotal,
    );
    final totalTax = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountTax,
    );
    final totalUntaxed = invoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.amountUntaxed,
    );

    csvData.writeln();
    csvData.writeln(
      [
        'TOTAL',
        '',
        '',
        '',
        '',
        '',
        totalUntaxed.toStringAsFixed(2),
        totalTax.toStringAsFixed(2),
        totalAmount.toStringAsFixed(2),
        '',
        '',
        '',
        '',
      ].map((field) => '"$field"').join(','),
    );

    await _saveAndOpenFile(
      utf8.encode(csvData.toString()),
      'invoice_report_${fromDate.toIso8601String().split('T')[0]}_to_${toDate.toIso8601String().split('T')[0]}.csv',
    );
  }

  Future<void> _saveAndOpenFile(List<int> bytes, String filename) async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          directory = Directory('${directory.path}/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        }
      }

      directory ??= await getApplicationDocumentsDirectory();

      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(bytes);

      _savedFilePath = file.path;
      _savedFileName = filename;

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to save file: ${e.toString()}');
    }
  }

  /// Opens the directory/folder where the exported file was saved.
  Future<void> openSavedFile() async {
    if (_savedFilePath == null) return;

    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'action_view',
          data:
              'content://com.android.externalstorage.documents/tree/primary%3ADownload',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      } else {
        final uri = Uri.file(_savedFilePath!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Cannot open file');
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to open file location: ${e.toString()}';

      notifyListeners();
    }
  }

  /// Triggers a system share dialog for the exported file.
  Future<void> shareSavedFile() async {
    if (_savedFilePath == null) return;

    try {
      await Share.shareXFiles([
        XFile(_savedFilePath!),
      ], text: 'Invoice Export Report');
    } catch (e) {
      _errorMessage = 'Failed to share file: $e';
      notifyListeners();
    }
  }

  /// Clears the record of the last saved file.
  void clearSavedFile() {
    _savedFilePath = null;
    _savedFileName = null;
    notifyListeners();
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'posted':
        return 'Posted';
      case 'cancel':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  String _getPaymentStatusDisplayName(String? paymentState) {
    switch (paymentState) {
      case 'not_paid':
        return 'Not Paid';
      case 'in_payment':
        return 'In Payment';
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partially Paid';
      case 'reversed':
        return 'Reversed';
      case 'invoicing_legacy':
        return 'Invoicing App Legacy';
      default:
        return paymentState ?? 'Unknown';
    }
  }

  void _setExporting(bool exporting) {
    _isExporting = exporting;
    notifyListeners();
  }
}
