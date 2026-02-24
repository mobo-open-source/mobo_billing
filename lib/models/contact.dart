class Contact {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? mobile;
  final String? street;
  final String? street2;
  final String? city;
  final String? state;
  final String? zip;
  final String? country;
  final String? companyName;
  final String? vat;
  final String? imageUrl;
  final int? paymentTermId;
  final bool isCompany;

  Contact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.mobile,
    this.street,
    this.street2,
    this.city,
    this.state,
    this.zip,
    this.country,
    this.companyName,
    this.vat,
    this.imageUrl,
    this.paymentTermId,
    this.isCompany = false,
  });

  /// Creates a Contact instance from an Odoo JSON map.
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      mobile: json['mobile']?.toString(),
      street: json['street']?.toString(),
      street2: json['street2']?.toString(),
      city: json['city']?.toString(),
      state: json['state_id'] is List && (json['state_id'] as List).length > 1
          ? json['state_id'][1]?.toString()
          : null,
      zip: json['zip']?.toString(),
      country: json['country_id'] is List && (json['country_id'] as List).length > 1
          ? json['country_id'][1]?.toString()
          : null,
      companyName: json['company_name']?.toString(),
      vat: json['vat']?.toString(),
      imageUrl: json['image_1920']?.toString(),
      paymentTermId: json['property_payment_term_id'] is List &&
              (json['property_payment_term_id'] as List).isNotEmpty
          ? json['property_payment_term_id'][0] as int?
          : null,
      isCompany: json['is_company'] == true,
    );
  }

  /// Converts the contact instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'mobile': mobile,
      'street': street,
      'street2': street2,
      'city': city,
      'state': state,
      'zip': zip,
      'country': country,
      'company_name': companyName,
      'vat': vat,
      'image_1920': imageUrl,
      'property_payment_term_id': paymentTermId,
      'is_company': isCompany,
    };
  }

  @override
  String toString() {
    return 'Contact(id: $id, name: $name, email: $email)';
  }
}
