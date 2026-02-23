class Payment {
  final int id;
  final String name;
  final double amount;
  final DateTime? date;
  final String state;
  final String paymentType;
  final int? partnerId;
  final String partnerName;
  final int? journalId;
  final String journalName;
  final int? currencyId;
  final String currencyName;
  final String? paymentReference;
  final String? memo;
  final String? paymentMethodName;
  final String? partnerBankName;

  Payment({
    required this.id,
    required this.name,
    required this.amount,
    this.date,
    required this.state,
    required this.paymentType,
    this.partnerId,
    this.partnerName = '',
    this.journalId,
    this.journalName = '',
    this.currencyId,
    this.currencyName = '',
    this.paymentReference,
    this.memo,
    this.paymentMethodName,
    this.partnerBankName,
  });

  /// Creates a Payment instance from an Odoo RPC JSON map.
  factory Payment.fromJson(Map<String, dynamic> json) {
    String? getString(dynamic value) {
      if (value == null || value == false || value.toString().toLowerCase() == 'false') return null;
      return value.toString();
    }

    int? getInt(dynamic value) {
      if (value is int) return value;
      if (value is List && value.isNotEmpty && value[0] is int) return value[0];
      return null;
    }

    double? getDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return 0.0;
    }

    DateTime? getDateTime(dynamic value) {
      if (value == null || value == false) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }


    int? partnerId;
    String partnerName = '';
    if (json['partner_id'] is List && (json['partner_id'] as List).isNotEmpty) {
      partnerId = json['partner_id'][0] as int?;
      partnerName = json['partner_id'].length > 1 ? json['partner_id'][1]?.toString() ?? '' : '';
    } else if (json['partner_id'] is int) {
      partnerId = json['partner_id'] as int;
    }


    int? journalId;
    String journalName = '';
    if (json['journal_id'] is List && (json['journal_id'] as List).isNotEmpty) {
      journalId = json['journal_id'][0] as int?;
      journalName = json['journal_id'].length > 1 ? json['journal_id'][1]?.toString() ?? '' : '';
    } else if (json['journal_id'] is int) {
      journalId = json['journal_id'] as int;
    }


    int? currencyId;
    String currencyName = '';
    if (json['currency_id'] is List && (json['currency_id'] as List).isNotEmpty) {
      currencyId = json['currency_id'][0] as int?;
      currencyName = json['currency_id'].length > 1 ? json['currency_id'][1]?.toString() ?? '' : '';
    } else if (json['currency_id'] is int) {
      currencyId = json['currency_id'] as int;
    }

    return Payment(
      id: getInt(json['id']) ?? 0,
      name: getString(json['name']) ?? '',
      amount: getDouble(json['amount']) ?? 0.0,
      date: getDateTime(json['date']),
      state: getString(json['state']) ?? 'draft',
      paymentType: getString(json['payment_type']) ?? 'inbound',
      partnerId: partnerId,
      partnerName: partnerName,
      journalId: journalId,
      journalName: journalName,
      currencyId: currencyId,
      currencyName: currencyName,
      paymentReference: getString(json['payment_reference']),
      memo: getString(json['memo']) ?? getString(json['ref']),
      paymentMethodName: json['payment_method_line_id'] is List && (json['payment_method_line_id'] as List).length > 1
          ? json['payment_method_line_id'][1].toString()
          : getString(json['payment_method_name']),
      partnerBankName: json['partner_bank_id'] is List && (json['partner_bank_id'] as List).length > 1
          ? json['partner_bank_id'][1].toString()
          : getString(json['partner_bank_name']),
    );
  }

  /// Converts the Payment instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'date': date?.toIso8601String(),
      'state': state,
      'payment_type': paymentType,
      'partner_id': partnerId != null ? [partnerId, partnerName] : null,
      'journal_id': journalId != null ? [journalId, journalName] : null,
      'currency_id': currencyId != null ? [currencyId, currencyName] : null,
      'payment_reference': paymentReference,
      'ref': memo,
      'memo': memo,
      'payment_method_name': paymentMethodName,
      'partner_bank_name': partnerBankName,
    };
  }
}
