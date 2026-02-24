/// Configuration settings for Odoo invoices, including company info, taxes, and journals.
class OdooInvoiceSettings {
  final int companyId;
  final String companyName;
  final String companyCurrency;
  final String currencySymbol;
  final String currencyPosition;
  final int decimalPlaces;
  final List<OdooTax> availableTaxes;
  final List<int> defaultTaxIds;
  final List<OdooPaymentTerm> paymentTerms;
  final int defaultPaymentTermId;
  final String invoiceSequence;
  final List<OdooJournal> journals;
  final int defaultJournalId;
  final String companyAddress;
  final String companyPhone;
  final String companyEmail;
  final String companyWebsite;
  final String companyVat;
  final bool autoPostInvoices;
  final String defaultInvoicePolicy;

  OdooInvoiceSettings({
    required this.companyId,
    required this.companyName,
    required this.companyCurrency,
    required this.currencySymbol,
    required this.currencyPosition,
    required this.decimalPlaces,
    required this.availableTaxes,
    required this.defaultTaxIds,
    required this.paymentTerms,
    required this.defaultPaymentTermId,
    required this.invoiceSequence,
    required this.journals,
    required this.defaultJournalId,
    required this.companyAddress,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyWebsite,
    required this.companyVat,
    required this.autoPostInvoices,
    required this.defaultInvoicePolicy,
  });

  factory OdooInvoiceSettings.fromJson(Map<String, dynamic> json) {
    return OdooInvoiceSettings(
      companyId: json['company_id'] ?? 0,
      companyName: json['company_name'] ?? '',
      companyCurrency: json['company_currency'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '',
      currencyPosition: json['currency_position'] ?? 'before',
      decimalPlaces: json['decimal_places'] ?? 2,
      availableTaxes: (json['available_taxes'] as List<dynamic>?)
          ?.map((tax) => OdooTax.fromJson(tax))
          .toList() ?? [],
      defaultTaxIds: List<int>.from(json['default_tax_ids'] ?? []),
      paymentTerms: (json['payment_terms'] as List<dynamic>?)
          ?.map((term) => OdooPaymentTerm.fromJson(term))
          .toList() ?? [],
      defaultPaymentTermId: json['default_payment_term_id'] ?? 0,
      invoiceSequence: json['invoice_sequence'] ?? 'INV',
      journals: (json['journals'] as List<dynamic>?)
          ?.map((journal) => OdooJournal.fromJson(journal))
          .toList() ?? [],
      defaultJournalId: json['default_journal_id'] ?? 0,
      companyAddress: json['company_address'] ?? '',
      companyPhone: json['company_phone'] ?? '',
      companyEmail: json['company_email'] ?? '',
      companyWebsite: json['company_website'] ?? '',
      companyVat: json['company_vat'] ?? '',
      autoPostInvoices: json['auto_post_invoices'] ?? false,
      defaultInvoicePolicy: json['default_invoice_policy'] ?? 'order',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'company_currency': companyCurrency,
      'currency_symbol': currencySymbol,
      'currency_position': currencyPosition,
      'decimal_places': decimalPlaces,
      'available_taxes': availableTaxes.map((tax) => tax.toJson()).toList(),
      'default_tax_ids': defaultTaxIds,
      'payment_terms': paymentTerms.map((term) => term.toJson()).toList(),
      'default_payment_term_id': defaultPaymentTermId,
      'invoice_sequence': invoiceSequence,
      'journals': journals.map((journal) => journal.toJson()).toList(),
      'default_journal_id': defaultJournalId,
      'company_address': companyAddress,
      'company_phone': companyPhone,
      'company_email': companyEmail,
      'company_website': companyWebsite,
      'company_vat': companyVat,
      'auto_post_invoices': autoPostInvoices,
      'default_invoice_policy': defaultInvoicePolicy,
    };
  }
}

/// Represents an Odoo tax configuration (account.tax).
class OdooTax {
  final int id;
  final String name;
  final double amount;
  final String amountType;
  final String typeCode;
  final bool active;
  final String description;

  OdooTax({
    required this.id,
    required this.name,
    required this.amount,
    required this.amountType,
    required this.typeCode,
    required this.active,
    required this.description,
  });

  factory OdooTax.fromJson(Map<String, dynamic> json) {
    return OdooTax(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      amountType: json['amount_type']?.toString() ?? 'percent',
      typeCode: json['type_tax_use']?.toString() ?? 'sale',
      active: json['active'] ?? true,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'amount_type': amountType,
      'type_tax_use': typeCode,
      'active': active,
      'description': description,
    };
  }
}

/// Represents an Odoo payment term (account.payment.term).
class OdooPaymentTerm {
  final int id;
  final String name;
  final String note;
  final bool active;

  OdooPaymentTerm({
    required this.id,
    required this.name,
    required this.note,
    required this.active,
  });

  factory OdooPaymentTerm.fromJson(Map<String, dynamic> json) {
    return OdooPaymentTerm(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'note': note,
      'active': active,
    };
  }
}

/// Represents an Odoo accounting journal (account.journal).
class OdooJournal {
  final int id;
  final String name;
  final String code;
  final String type;
  final bool active;

  OdooJournal({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.active,
  });

  factory OdooJournal.fromJson(Map<String, dynamic> json) {
    return OdooJournal(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'sale',
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'active': active,
    };
  }
}
