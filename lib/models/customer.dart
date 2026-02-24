/// Represents an Odoo res.partner (Customer/Contact) with profile and accounting data.
class Customer {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? vat;
  final String? street;
  final String? street2;
  final String? city;
  final String? zip;
  final String? website;
  final String? comment;
  final bool isCompany;
  final int customerRank;
  final int supplierRank;
  final String? image128;
  final String? companyType;
  final String? title;
  final String? function;
  final String? lang;
  final String? category;
  final int? countryId;
  final String? countryName;
  final int? stateId;
  final String? stateName;
  final String? ref;
  final bool active;
  final String? industry;
  final String? creditLimit;
  final String? companyName;
  final DateTime? createDate;
  final DateTime? writeDate;
  final String? tz;
  final int? userId;
  final int? propertyPaymentTermId;
  final double? totalInvoiced;
  final double? credit;
  final double? debit;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final dynamic currencyId;

  Customer({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.mobile,
    this.vat,
    this.street,
    this.street2,
    this.city,
    this.zip,
    this.website,
    this.comment,
    this.isCompany = false,
    this.customerRank = 1,
    this.supplierRank = 0,
    this.image128,
    this.companyType,
    this.title,
    this.function,
    this.lang,
    this.category,
    this.countryId,
    this.countryName,
    this.stateId,
    this.stateName,
    this.ref,
    this.active = true,
    this.industry,
    this.creditLimit,
    this.companyName,
    this.createDate,
    this.writeDate,
    this.tz,
    this.userId,
    this.propertyPaymentTermId,
    this.totalInvoiced,
    this.credit,
    this.debit,
    this.partnerLatitude,
    this.partnerLongitude,
    this.currencyId,
  });

  /// Creates a Customer instance from an Odoo RPC JSON map.
  factory Customer.fromJson(Map<String, dynamic> json) {
    String? getString(dynamic value) {
      if (value == null || value == false || value.toString().toLowerCase() == 'false' || value.toString().isEmpty) return null;
      return value.toString();
    }

    int? getInt(dynamic value) {
      if (value is int) return value;
      if (value is List && value.isNotEmpty && value[0] is int) return value[0];
      return null;
    }

    double? getDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return null;
    }

    return Customer(
      id: getInt(json['id']),
      name: getString(json['name']) ?? '',
      email: getString(json['email']),
      phone: getString(json['phone']),
      mobile: getString(json['mobile']),
      vat: getString(json['vat']),
      street: getString(json['street']),
      street2: getString(json['street2']),
      city: getString(json['city']),
      zip: getString(json['zip']),
      website: getString(json['website']),
      comment: getString(json['comment']),
      isCompany: json['is_company'] == true,
      customerRank: json['customer_rank'] is int ? json['customer_rank'] : 0,
      supplierRank: json['supplier_rank'] is int ? json['supplier_rank'] : 0,
      image128: getString(json['image_128']),
      companyType: getString(json['company_type']),
      title: json['title'] is List && (json['title'] as List).length > 1 
          ? json['title'][1].toString() 
          : getString(json['title']),
      function: getString(json['function']),
      lang: getString(json['lang']),
      category: json['category_id'] is List && (json['category_id'] as List).length > 1 
          ? json['category_id'][1].toString() 
          : getString(json['category_id']),
      countryId: getInt(json['country_id']),
      countryName: json['country_id'] is List && (json['country_id'] as List).length > 1 
          ? json['country_id'][1].toString() 
          : null,
      stateId: getInt(json['state_id']),
      stateName: json['state_id'] is List && (json['state_id'] as List).length > 1 
          ? json['state_id'][1].toString() 
          : null,
      ref: getString(json['ref']),
      active: json['active'] ?? true,
      industry: json['industry_id'] is List && (json['industry_id'] as List).length > 1 
          ? json['industry_id'][1].toString() 
          : getString(json['industry_id']),
      creditLimit: getString(json['credit_limit']),
      companyName: getString(json['company_name']),
      createDate: json['create_date'] != null 
          ? DateTime.tryParse(json['create_date'].toString()) 
          : null,
      writeDate: json['write_date'] != null 
          ? DateTime.tryParse(json['write_date'].toString()) 
          : null,
      tz: getString(json['tz']),
      userId: getInt(json['user_id']),
      propertyPaymentTermId: getInt(json['property_payment_term_id']),
      totalInvoiced: getDouble(json['total_invoiced']),
      credit: getDouble(json['credit']),
      debit: getDouble(json['debit']),
      partnerLatitude: getDouble(json['partner_latitude']),
      partnerLongitude: getDouble(json['partner_longitude']),
      currencyId: json['currency_id'],
    );
  }

  /// Converts the Customer instance to a JSON map for persistence or server updates.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'name': name,
      'is_company': isCompany,
      'customer_rank': customerRank,
      'supplier_rank': supplierRank,
      'active': active,
    };


    if (email != null && email!.isNotEmpty) data['email'] = email;
    if (phone != null && phone!.isNotEmpty) data['phone'] = phone;
    if (mobile != null && mobile!.isNotEmpty) data['mobile'] = mobile;
    if (vat != null && vat!.isNotEmpty) data['vat'] = vat;
    if (street != null && street!.isNotEmpty) data['street'] = street;
    if (street2 != null && street2!.isNotEmpty) data['street2'] = street2;
    if (city != null && city!.isNotEmpty) data['city'] = city;
    if (zip != null && zip!.isNotEmpty) data['zip'] = zip;
    if (website != null && website!.isNotEmpty) data['website'] = website;
    if (comment != null && comment!.isNotEmpty) data['comment'] = comment;
    if (image128 != null && image128!.isNotEmpty) data['image_128'] = image128;
    if (companyType != null) data['company_type'] = companyType;
    if (title != null && title!.isNotEmpty) data['title'] = title;
    if (function != null && function!.isNotEmpty) data['function'] = function;
    if (lang != null && lang!.isNotEmpty) data['lang'] = lang;
    if (countryId != null) data['country_id'] = countryId;
    if (stateId != null) data['state_id'] = stateId;
    if (ref != null && ref!.isNotEmpty) data['ref'] = ref;
    if (industry != null && industry!.isNotEmpty) data['industry_id'] = industry;
    if (creditLimit != null && creditLimit!.isNotEmpty) data['credit_limit'] = creditLimit;
    if (companyName != null && companyName!.isNotEmpty) data['company_name'] = companyName;
    if (createDate != null) data['create_date'] = createDate!.toIso8601String();
    if (writeDate != null) data['write_date'] = writeDate!.toIso8601String();
    if (tz != null) data['tz'] = tz;
    if (userId != null) data['user_id'] = userId;
    if (propertyPaymentTermId != null) data['property_payment_term_id'] = propertyPaymentTermId;
    if (totalInvoiced != null) data['total_invoiced'] = totalInvoiced;
    if (credit != null) data['credit'] = credit;
    if (debit != null) data['debit'] = debit;
    if (partnerLatitude != null) data['partner_latitude'] = partnerLatitude;
    if (partnerLongitude != null) data['partner_longitude'] = partnerLongitude;
    if (currencyId != null) data['currency_id'] = currencyId;

    return data;
  }

  Customer copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? mobile,
    String? vat,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? website,
    String? comment,
    bool? isCompany,
    int? customerRank,
    int? supplierRank,
    String? image128,
    String? companyType,
    String? title,
    String? function,
    String? lang,
    String? category,
    int? countryId,
    String? countryName,
    int? stateId,
    String? stateName,
    String? ref,
    bool? active,
    String? industry,
    String? creditLimit,
    String? companyName,
    DateTime? createDate,
    DateTime? writeDate,
    String? tz,
    int? userId,
    int? propertyPaymentTermId,
    double? totalInvoiced,
    double? credit,
    double? debit,
    double? partnerLatitude,
    double? partnerLongitude,
    dynamic currencyId,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mobile: mobile ?? this.mobile,
      vat: vat ?? this.vat,
      street: street ?? this.street,
      street2: street2 ?? this.street2,
      city: city ?? this.city,
      zip: zip ?? this.zip,
      website: website ?? this.website,
      comment: comment ?? this.comment,
      isCompany: isCompany ?? this.isCompany,
      customerRank: customerRank ?? this.customerRank,
      supplierRank: supplierRank ?? this.supplierRank,
      image128: image128 ?? this.image128,
      companyType: companyType ?? this.companyType,
      title: title ?? this.title,
      function: function ?? this.function,
      lang: lang ?? this.lang,
      category: category ?? this.category,
      countryId: countryId ?? this.countryId,
      countryName: countryName ?? this.countryName,
      stateId: stateId ?? this.stateId,
      stateName: stateName ?? this.stateName,
      ref: ref ?? this.ref,
      active: active ?? this.active,
      industry: industry ?? this.industry,
      creditLimit: creditLimit ?? this.creditLimit,
      companyName: companyName ?? this.companyName,
      createDate: createDate ?? this.createDate,
      writeDate: writeDate ?? this.writeDate,
      tz: tz ?? this.tz,
      userId: userId ?? this.userId,
      propertyPaymentTermId: propertyPaymentTermId ?? this.propertyPaymentTermId,
      totalInvoiced: totalInvoiced ?? this.totalInvoiced,
      credit: credit ?? this.credit,
      debit: debit ?? this.debit,
      partnerLatitude: partnerLatitude ?? this.partnerLatitude,
      partnerLongitude: partnerLongitude ?? this.partnerLongitude,
      currencyId: currencyId ?? this.currencyId,
    );
  }

  @override
  String toString() {
    return 'Customer{id: $id, name: $name, isCompany: $isCompany, email: $email}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
