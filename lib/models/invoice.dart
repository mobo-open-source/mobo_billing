import 'invoice_line.dart';
import 'journal_item.dart';

/// Represents an Odoo account.move (Invoice) with its lines and associated metadata.
class Invoice {
  final int id;
  final String name;
  final DateTime? invoiceDate;
  final DateTime? invoiceDateDue;
  final String customerName;
  final int? customerId;
  final String state;
  final String? paymentState;
  final double amountUntaxed;
  final double amountTax;
  final double amountTotal;
  final double amountResidual;
  final String currencySymbol;
  final String? ref;
  final String? invoiceOrigin;
  final String? paymentReference;
  final List<int> invoiceLineIds;
  final String moveType;
  final int? companyId;
  final dynamic currencyId;
  final List<InvoiceLine> invoiceLines;
  

  String get partnerName => customerName;
  int? get partnerId => customerId;


  final String? salespersonName;
  final String? salesTeamName;
  final String? partnerBankName;
  final DateTime? deliveryDate;
  final String? incotermName;
  final String? incotermLocation;
  final String? fiscalPositionName;
  final bool secured;
  final String? paymentMethodName;
  final bool autoPost;
  final bool toCheck;
  final String? campaignName;
  final String? mediumName;
  final String? sourceName;
  final String? paymentTermName;
  final String? journalName;
  final List<JournalItem> journalItems;

  Invoice({
    required this.id,
    required this.name,
    this.invoiceDate,
    this.invoiceDateDue,
    required this.customerName,
    this.customerId,
    required this.state,
    this.paymentState,
    required this.amountUntaxed,
    required this.amountTax,
    required this.amountTotal,
    required this.amountResidual,
    required this.currencySymbol,
    this.ref,
    this.invoiceOrigin,
    this.paymentReference,
    required this.invoiceLineIds,
    required this.moveType,
    this.companyId,
    this.currencyId,
    this.invoiceLines = const [],
    this.salespersonName,
    this.salesTeamName,
    this.partnerBankName,
    this.deliveryDate,
    this.incotermName,
    this.incotermLocation,
    this.fiscalPositionName,
    this.secured = false,
    this.paymentMethodName,
    this.autoPost = false,
    this.toCheck = false,
    this.campaignName,
    this.mediumName,
    this.sourceName,
    this.paymentTermName,
    this.journalName,
    this.journalItems = const [],
  });

  /// Creates an Invoice instance from an Odoo RPC JSON map.
  factory Invoice.fromJson(Map<String, dynamic> json) {
    String? getString(dynamic value) {
      if (value == null || value == false || value.toString().toLowerCase() == 'false' || value.toString().isEmpty) return null;
      if (value is List && value.isNotEmpty) {
        return value.length > 1 ? value[1]?.toString() : value[0]?.toString();
      }
      return value.toString();
    }

    int? getInt(dynamic value) {
      if (value is int) return value;
      if (value is List && value.isNotEmpty && value[0] is int) return value[0];
      return null;
    }


    String customerName = '';
    int? customerId;
    if (json['partner_id'] is List && (json['partner_id'] as List).isNotEmpty) {
      final partnerData = json['partner_id'] as List;
      customerId = partnerData[0] as int?;
      customerName = partnerData.length > 1 ? partnerData[1]?.toString() ?? '' : '';
    } else if (json['partner_id'] is int) {
      customerId = json['partner_id'] as int;
    }


    String currencySymbol = '';
    if (json['currency_id'] is List && (json['currency_id'] as List).isNotEmpty) {
      final currencyData = json['currency_id'] as List;
      currencySymbol = currencyData.length > 1 ? currencyData[1]?.toString() ?? '' : '';
    }

    return Invoice(
      id: json['id'] ?? 0,
      name: getString(json['name']) ?? '',
      invoiceDate: json['invoice_date'] != null 
          ? DateTime.tryParse(json['invoice_date'].toString())
          : null,
      invoiceDateDue: json['invoice_date_due'] != null 
          ? DateTime.tryParse(json['invoice_date_due'].toString())
          : null,
      customerName: customerName,
      customerId: customerId,
      state: json['state']?.toString() ?? 'draft',
      paymentState: json['payment_state']?.toString(),
      amountUntaxed: (json['amount_untaxed'] ?? 0.0).toDouble(),
      amountTax: (json['amount_tax'] ?? 0.0).toDouble(),
      amountTotal: (json['amount_total'] ?? 0.0).toDouble(),
      amountResidual: (json['amount_residual'] ?? 0.0).toDouble(),
      currencySymbol: currencySymbol,
      ref: json['ref']?.toString(),
      invoiceOrigin: json['invoice_origin']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      invoiceLineIds: json['invoice_line_ids'] != null 
          ? List<int>.from(json['invoice_line_ids'])
          : [],
      moveType: json['move_type']?.toString() ?? 'out_invoice',
      companyId: getInt(json['company_id']),
      currencyId: json['currency_id'],
      invoiceLines: json['invoice_lines'] != null 
          ? (json['invoice_lines'] as List).map((l) => InvoiceLine.fromJson(l)).toList()
          : [],
      salespersonName: getString(json['invoice_user_id']),
      salesTeamName: getString(json['team_id']),
      partnerBankName: getString(json['partner_bank_id']),
      deliveryDate: json['delivery_date'] != null 
          ? DateTime.tryParse(json['delivery_date'].toString())
          : null,
      incotermName: getString(json['invoice_incoterm_id']),
      incotermLocation: getString(json['incoterm_location']),
      fiscalPositionName: getString(json['fiscal_position_id']),
      secured: json['secured'] == true,
      paymentMethodName: getString(json['preferred_payment_method_line_id']),
      autoPost: json['auto_post'] == true,
      toCheck: json['to_check'] == true || json['checked'] == true,
      campaignName: getString(json['campaign_id']),
      mediumName: getString(json['medium_id']),
      sourceName: getString(json['source_id']),
      paymentTermName: getString(json['invoice_payment_term_id']),
      journalName: getString(json['journal_id']),
      journalItems: json['journal_items'] != null
          ? (json['journal_items'] as List).map((j) => JournalItem.fromJson(j)).toList()
          : [],
    );
  }

  /// Converts the invoice instance to a JSON map compatible with Odoo or local storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invoice_date': invoiceDate?.toIso8601String().split('T')[0],
      'invoice_date_due': invoiceDateDue?.toIso8601String().split('T')[0],
      'partner_id': customerId != null ? [customerId, customerName] : null,
      'state': state,
      'payment_state': paymentState,
      'amount_untaxed': amountUntaxed,
      'amount_tax': amountTax,
      'amount_total': amountTotal,
      'amount_residual': amountResidual,
      'currency_id': currencyId ?? (currencySymbol.isNotEmpty ? [0, currencySymbol] : null),
      'ref': ref,
      'invoice_origin': invoiceOrigin,
      'payment_reference': paymentReference,
      'invoice_line_ids': invoiceLineIds,
      'move_type': moveType,
      'company_id': companyId,
      'invoice_lines': invoiceLines.map((l) => l.toJson()).toList(),
      'invoice_user_id': salespersonName,
      'team_id': salesTeamName,
      'partner_bank_id': partnerBankName,
      'delivery_date': deliveryDate?.toIso8601String().split('T')[0],
      'invoice_incoterm_id': incotermName,
      'incoterm_location': incotermLocation,
      'fiscal_position_id': fiscalPositionName,
      'secured': secured,
      'preferred_payment_method_line_id': paymentMethodName,
      'auto_post': autoPost,
      'to_check': toCheck,
      'campaign_id': campaignName,
      'medium_id': mediumName,
      'source_id': sourceName,
      'invoice_payment_term_id': paymentTermName,
      'journal_id': journalName,
      'journal_items': journalItems.map((j) => j.toJson()).toList(),
    };
  }
}
