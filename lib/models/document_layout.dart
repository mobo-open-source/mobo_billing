class DocumentLayout {
  final int id;
  final String name;
  final String displayName;
  final String? description;
  final bool isDefault;
  final Map<String, dynamic>? layoutConfig;

  DocumentLayout({
    required this.id,
    required this.name,
    required this.displayName,
    this.description,
    this.isDefault = false,
    this.layoutConfig,
  });

  factory DocumentLayout.fromJson(Map<String, dynamic> json) {
    return DocumentLayout(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
      description: json['description'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      layoutConfig: json['layout_config'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'is_default': isDefault,
      'layout_config': layoutConfig,
    };
  }

  @override
  String toString() {
    return 'DocumentLayout(id: $id, name: $name, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentLayout && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CompanySettings {
  final int companyId;
  final String companyName;
  final String? companyInformations;
  final DocumentLayout? externalReportLayout;
  final String? emailPrimaryColor;
  final String? emailSecondaryColor;
  final bool isRootCompany;
  final int activeUserCount;
  final int languageCount;
  final int companyCount;

  CompanySettings({
    required this.companyId,
    required this.companyName,
    this.companyInformations,
    this.externalReportLayout,
    this.emailPrimaryColor,
    this.emailSecondaryColor,
    this.isRootCompany = false,
    this.activeUserCount = 0,
    this.languageCount = 0,
    this.companyCount = 0,
  });

  factory CompanySettings.fromJson(Map<String, dynamic> json) {
    DocumentLayout? layout;
    if (json['external_report_layout_id'] != null) {
      final layoutData = json['external_report_layout_id'];
      if (layoutData is Map<String, dynamic>) {
        layout = DocumentLayout.fromJson(layoutData);
      } else if (layoutData is List && layoutData.length >= 2) {
        layout = DocumentLayout(
          id: layoutData[0] as int,
          displayName: layoutData[1] as String,
          name: layoutData[1] as String,
        );
      }
    }

    return CompanySettings(
      companyId: json['company_id'] is List 
          ? json['company_id'][0] as int 
          : json['company_id'] as int? ?? 1,
      companyName: json['company_name'] as String? ?? 
          (json['company_id'] is List ? json['company_id'][1] as String : 'Company'),
      companyInformations: json['company_informations'] as String?,
      externalReportLayout: layout,
      emailPrimaryColor: json['email_primary_color'] as String?,
      emailSecondaryColor: json['email_secondary_color'] as String?,
      isRootCompany: json['is_root_company'] as bool? ?? false,
      activeUserCount: json['active_user_count'] as int? ?? 0,
      languageCount: json['language_count'] as int? ?? 0,
      companyCount: json['company_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'company_informations': companyInformations,
      'external_report_layout_id': externalReportLayout?.toJson(),
      'email_primary_color': emailPrimaryColor,
      'email_secondary_color': emailSecondaryColor,
      'is_root_company': isRootCompany,
      'active_user_count': activeUserCount,
      'language_count': languageCount,
      'company_count': companyCount,
    };
  }
}
