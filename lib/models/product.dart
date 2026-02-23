/// Represents an Odoo product.template with pricing, stock, and metadata.
class Product {
  final int id;
  final String name;
  final String? description;
  final String? descriptionSale;
  final double? cost;
  final double? listPrice;
  final String? imageUrl;
  final String? image128;
  final String? barcode;
  final String? defaultCode;
  final int? uomId;
  final String? uomName;
  final double? qtyAvailable;
  final int? categoryId;
  final String? categoryName;
  final dynamic currencyId;
  final List<dynamic>? taxesId;
  final dynamic productTmplId;
  final int? productVariantCount;
  final List<dynamic>? productVariantIds;
  final double? weight;
  final double? volume;
  final bool active;
  final bool saleOk;
  final bool purchaseOk;
  final String? createDate;
  final String? costMethod;
  final dynamic propertyStockInventory;
  final dynamic propertyStockProduction;

  double get standardPrice => cost ?? 0.0;

  Product({
    required this.id,
    required this.name,
    this.description,
    this.descriptionSale,
    this.cost,
    this.listPrice,
    this.imageUrl,
    this.image128,
    this.barcode,
    this.defaultCode,
    this.uomId,
    this.uomName,
    this.qtyAvailable,
    this.categoryId,
    this.categoryName,
    this.currencyId,
    this.taxesId,
    this.productTmplId,
    this.productVariantCount,
    this.productVariantIds,
    this.weight,
    this.volume,
    this.active = true,
    this.saleOk = true,
    this.purchaseOk = true,
    this.createDate,
    this.costMethod,
    this.propertyStockInventory,
    this.propertyStockProduction,
  });

  static String? _parseString(dynamic value) {
    if (value == null || value == false || value.toString() == 'false' || value.toString().isEmpty) {
      return null;
    }
    return value.toString();
  }

  /// Creates a Product instance from an Odoo RPC JSON map.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: _parseString(json['name']) ?? 'Unknown Product',
      description: _parseString(json['description']),
      descriptionSale: _parseString(json['description_sale']),
      cost: (json['standard_price'] as num?)?.toDouble(),
      listPrice: (json['list_price'] as num?)?.toDouble(),
      imageUrl: _parseString(json['image_1920']),
      image128: _parseString(json['image_128']),
      barcode: _parseString(json['barcode']),
      defaultCode: _parseString(json['default_code']),
      uomId: json['uom_id'] is List && (json['uom_id'] as List).isNotEmpty
          ? json['uom_id'][0] as int?
          : null,
      uomName: json['uom_id'] is List && (json['uom_id'] as List).length > 1
          ? _parseString(json['uom_id'][1])
          : null,
      qtyAvailable: (json['qty_available'] as num?)?.toDouble(),
      categoryId: json['categ_id'] is List && (json['categ_id'] as List).isNotEmpty
          ? json['categ_id'][0] as int?
          : null,
      categoryName: json['categ_id'] is List && (json['categ_id'] as List).length > 1
          ? _parseString(json['categ_id'][1])
          : null,
      currencyId: json['currency_id'],
      taxesId: json['taxes_id'] is List ? json['taxes_id'] : null,
      productTmplId: json['product_tmpl_id'],
      productVariantCount: json['product_variant_count'] as int?,
      productVariantIds: json['product_variant_ids'] is List ? json['product_variant_ids'] : null,
      weight: (json['weight'] as num?)?.toDouble(),
      volume: (json['volume'] as num?)?.toDouble(),
      active: json['active'] as bool? ?? true,
      saleOk: json['sale_ok'] as bool? ?? true,
      purchaseOk: json['purchase_ok'] as bool? ?? true,
      createDate: _parseString(json['create_date']),
      costMethod: _parseString(json['cost_method']),
      propertyStockInventory: json['property_stock_inventory'],
      propertyStockProduction: json['property_stock_production'],
    );
  }

  /// Converts the Product instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'description_sale': descriptionSale,
      'standard_price': cost,
      'list_price': listPrice,
      'image_1920': imageUrl,
      'image_128': image128,
      'barcode': barcode,
      'default_code': defaultCode,
      'uom_id': uomId != null && uomName != null ? [uomId, uomName] : null,
      'qty_available': qtyAvailable,
      'categ_id': categoryId != null && categoryName != null ? [categoryId, categoryName] : null,
      'currency_id': currencyId,
      'taxes_id': taxesId,
      'product_tmpl_id': productTmplId,
      'product_variant_count': productVariantCount,
      'product_variant_ids': productVariantIds,
      'weight': weight,
      'volume': volume,
      'active': active,
      'sale_ok': saleOk,
      'purchase_ok': purchaseOk,
      'create_date': createDate,
      'cost_method': costMethod,
      'property_stock_inventory': propertyStockInventory,
      'property_stock_production': propertyStockProduction,
    };
  }

  String? get currencyCode {
    if (currencyId is List && (currencyId as List).length > 1) {
      return currencyId[1].toString();
    }
    return null;
  }

  Product copyWith({
    int? id,
    String? name,
    String? description,
    String? descriptionSale,
    double? cost,
    double? listPrice,
    String? imageUrl,
    String? image128,
    String? barcode,
    String? defaultCode,
    int? uomId,
    String? uomName,
    double? qtyAvailable,
    int? categoryId,
    String? categoryName,
    dynamic currencyId,
    List<dynamic>? taxesId,
    dynamic productTmplId,
    int? productVariantCount,
    List<dynamic>? productVariantIds,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      descriptionSale: descriptionSale ?? this.descriptionSale,
      cost: cost ?? this.cost,
      listPrice: listPrice ?? this.listPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      image128: image128 ?? this.image128,
      barcode: barcode ?? this.barcode,
      defaultCode: defaultCode ?? this.defaultCode,
      uomId: uomId ?? this.uomId,
      uomName: uomName ?? this.uomName,
      qtyAvailable: qtyAvailable ?? this.qtyAvailable,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      currencyId: currencyId ?? this.currencyId,
      taxesId: taxesId ?? this.taxesId,
      productTmplId: productTmplId ?? this.productTmplId,
      productVariantCount: productVariantCount ?? this.productVariantCount,
      productVariantIds: productVariantIds ?? this.productVariantIds,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: $listPrice)';
  }
}
