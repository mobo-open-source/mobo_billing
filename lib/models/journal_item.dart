/// Represents an Odoo journal item (account.move.line) in the general ledger.
class JournalItem {
  final int? id;
  final String? name;
  final int? accountId;
  final String? accountName;
  final int? partnerId;
  final String? partnerName;
  final double? debit;
  final double? credit;
  final double? balance;
  final double? amountCurrency;
  final int? currencyId;
  final String? currencyName;

  JournalItem({
    this.id,
    this.name,
    this.accountId,
    this.accountName,
    this.partnerId,
    this.partnerName,
    this.debit,
    this.credit,
    this.balance,
    this.amountCurrency,
    this.currencyId,
    this.currencyName,
  });

  /// Creates a JournalItem from an Odoo RPC JSON map.
  factory JournalItem.fromJson(Map<String, dynamic> json) {
    int? getInt(dynamic value) {
      if (value is int) return value;
      if (value is List && value.isNotEmpty && value[0] is int) return value[0];
      return null;
    }

    String? getString(dynamic value) {
      if (value == null || value == false || value.toString().toLowerCase() == 'false') return null;
      if (value is List && value.length > 1) return value[1].toString();
      return value.toString();
    }

    double? getDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return null;
    }


    int? accountId;
    String? accountName;
    if (json['account_id'] is List && (json['account_id'] as List).isNotEmpty) {
      accountId = json['account_id'][0] as int?;
      accountName = json['account_id'].length > 1 ? json['account_id'][1]?.toString() : null;
    } else if (json['account_id'] is int) {
      accountId = json['account_id'] as int;
    }


    int? partnerId;
    String? partnerName;
    if (json['partner_id'] is List && (json['partner_id'] as List).isNotEmpty) {
      partnerId = json['partner_id'][0] as int?;
      partnerName = json['partner_id'].length > 1 ? json['partner_id'][1]?.toString() : null;
    } else if (json['partner_id'] is int) {
      partnerId = json['partner_id'] as int;
    }


    int? currencyId;
    String? currencyName;
    if (json['currency_id'] is List && (json['currency_id'] as List).isNotEmpty) {
      currencyId = json['currency_id'][0] as int?;
      currencyName = json['currency_id'].length > 1 ? json['currency_id'][1]?.toString() : null;
    } else if (json['currency_id'] is int) {
      currencyId = json['currency_id'] as int;
    }

    return JournalItem(
      id: getInt(json['id']),
      name: getString(json['name']),
      accountId: accountId,
      accountName: accountName,
      partnerId: partnerId,
      partnerName: partnerName,
      debit: getDouble(json['debit']),
      credit: getDouble(json['credit']),
      balance: getDouble(json['balance']),
      amountCurrency: getDouble(json['amount_currency']),
      currencyId: currencyId,
      currencyName: currencyName,
    );
  }

  /// Converts the journal item to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'account_id': accountId != null ? [accountId, accountName] : null,
      'partner_id': partnerId != null ? [partnerId, partnerName] : null,
      'debit': debit,
      'credit': credit,
      'balance': balance,
      'amount_currency': amountCurrency,
      'currency_id': currencyId != null ? [currencyId, currencyName] : null,
    };
  }
}
