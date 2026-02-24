/// Filter criteria for querying customers from Odoo.
class CustomerFilter {
  final String? name;
  final String? email;
  final String? phone;
  final String? city;
  final String? country;
  final bool? isCompany;
  final bool? hasEmail;
  final bool? hasPhone;
  final String? category;
  final DateTime? createdAfter;
  final DateTime? createdBefore;

  const CustomerFilter({
    this.name,
    this.email,
    this.phone,
    this.city,
    this.country,
    this.isCompany,
    this.hasEmail,
    this.hasPhone,
    this.category,
    this.createdAfter,
    this.createdBefore,
  });


  /// Generates an Odoo RPC domain list from the filter criteria.
  List<dynamic> toDomain() {
    List<dynamic> domain = [['active', '=', true]];

    if (name != null && name!.isNotEmpty) {
      domain.add(['name', 'ilike', name]);
    }

    if (email != null && email!.isNotEmpty) {
      domain.add(['email', 'ilike', email]);
    }

    if (phone != null && phone!.isNotEmpty) {
      domain.add('|');
      domain.add(['phone', 'ilike', phone]);
      domain.add(['mobile', 'ilike', phone]);
    }

    if (city != null && city!.isNotEmpty) {
      domain.add(['city', 'ilike', city]);
    }

    if (country != null && country!.isNotEmpty) {
      domain.add(['country_id.name', 'ilike', country]);
    }

    if (isCompany != null) {
      domain.add(['is_company', '=', isCompany]);
    }

    if (hasEmail == true) {
      domain.add(['email', '!=', false]);
    } else if (hasEmail == false) {
      domain.add('|');
      domain.add(['email', '=', false]);
      domain.add(['email', '=', '']);
    }

    if (hasPhone == true) {
      domain.add('|');
      domain.add(['phone', '!=', false]);
      domain.add(['mobile', '!=', false]);
    } else if (hasPhone == false) {
      domain.add(['phone', '=', false]);
      domain.add(['mobile', '=', false]);
    }

    if (createdAfter != null) {
      domain.add(['create_date', '>=', createdAfter!.toIso8601String()]);
    }

    if (createdBefore != null) {
      domain.add(['create_date', '<=', createdBefore!.toIso8601String()]);
    }

    return domain;
  }


  bool get hasActiveFilters {
    return name != null && name!.isNotEmpty ||
        email != null && email!.isNotEmpty ||
        phone != null && phone!.isNotEmpty ||
        city != null && city!.isNotEmpty ||
        country != null && country!.isNotEmpty ||
        isCompany != null ||
        hasEmail != null ||
        hasPhone != null ||
        createdAfter != null ||
        createdBefore != null;
  }


  int get activeFilterCount {
    int count = 0;
    if (name != null && name!.isNotEmpty) count++;
    if (email != null && email!.isNotEmpty) count++;
    if (phone != null && phone!.isNotEmpty) count++;
    if (city != null && city!.isNotEmpty) count++;
    if (country != null && country!.isNotEmpty) count++;
    if (isCompany != null) count++;
    if (hasEmail != null) count++;
    if (hasPhone != null) count++;
    if (createdAfter != null) count++;
    if (createdBefore != null) count++;
    return count;
  }


  /// Returns a copy of the filter with updated values.
  CustomerFilter copyWith({
    String? name,
    String? email,
    String? phone,
    String? city,
    String? country,
    bool? isCompany,
    bool? hasEmail,
    bool? hasPhone,
    String? category,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool clearName = false,
    bool clearEmail = false,
    bool clearPhone = false,
    bool clearCity = false,
    bool clearCountry = false,
    bool clearIsCompany = false,
    bool clearHasEmail = false,
    bool clearHasPhone = false,
    bool clearCreatedAfter = false,
    bool clearCreatedBefore = false,
  }) {
    return CustomerFilter(
      name: clearName ? null : (name ?? this.name),
      email: clearEmail ? null : (email ?? this.email),
      phone: clearPhone ? null : (phone ?? this.phone),
      city: clearCity ? null : (city ?? this.city),
      country: clearCountry ? null : (country ?? this.country),
      isCompany: clearIsCompany ? null : (isCompany ?? this.isCompany),
      hasEmail: clearHasEmail ? null : (hasEmail ?? this.hasEmail),
      hasPhone: clearHasPhone ? null : (hasPhone ?? this.hasPhone),
      category: category ?? this.category,
      createdAfter: clearCreatedAfter ? null : (createdAfter ?? this.createdAfter),
      createdBefore: clearCreatedBefore ? null : (createdBefore ?? this.createdBefore),
    );
  }


  CustomerFilter clear() {
    return const CustomerFilter();
  }

  @override
  String toString() {
    return 'CustomerFilter(name: $name, email: $email, phone: $phone, city: $city, country: $country, isCompany: $isCompany, hasEmail: $hasEmail, hasPhone: $hasPhone, createdAfter: $createdAfter, createdBefore: $createdBefore)';
  }
}
