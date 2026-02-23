/// Filter criteria for querying products from Odoo.
class ProductFilter {
  final bool? canBeSold;
  final bool? canBePurchased;
  final String? productType;
  final bool? hasBarcode;
  final bool? hasImage;
  final DateTime? createdAfter;
  final DateTime? createdBefore;

  const ProductFilter({
    this.canBeSold,
    this.canBePurchased,
    this.productType,
    this.hasBarcode,
    this.hasImage,
    this.createdAfter,
    this.createdBefore,
  });


  /// Generates an Odoo RPC domain list from the filter criteria.
  List<dynamic> toDomain() {
    List<dynamic> domain = [];

    if (canBeSold != null) {
      domain.add(['sale_ok', '=', canBeSold]);
    }

    if (canBePurchased != null) {
      domain.add(['purchase_ok', '=', canBePurchased]);
    }

    if (productType != null && productType!.isNotEmpty) {
      domain.add(['type', '=', productType]);
    }

    if (hasBarcode != null) {
      if (hasBarcode!) {
        domain.add(['barcode', '!=', false]);
        domain.add(['barcode', '!=', '']);
      } else {
        domain.add('|');
        domain.add(['barcode', '=', false]);
        domain.add(['barcode', '=', '']);
      }
    }

    if (hasImage != null) {
      if (hasImage!) {
        domain.add(['image_128', '!=', false]);
      } else {
        domain.add(['image_128', '=', false]);
      }
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
    return canBeSold != null ||
           canBePurchased != null ||
           (productType != null && productType!.isNotEmpty) ||
           hasBarcode != null ||
           hasImage != null ||
           createdAfter != null ||
           createdBefore != null;
  }


  int get activeFilterCount {
    int count = 0;
    if (canBeSold != null) count++;
    if (canBePurchased != null) count++;
    if (productType != null && productType!.isNotEmpty) count++;
    if (hasBarcode != null) count++;
    if (hasImage != null) count++;
    if (createdAfter != null) count++;
    if (createdBefore != null) count++;
    return count;
  }


  /// Returns a copy of the filter with updated values.
  ProductFilter copyWith({
    bool? canBeSold,
    bool? canBePurchased,
    String? productType,
    bool? hasBarcode,
    bool? hasImage,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool clearCanBeSold = false,
    bool clearCanBePurchased = false,
    bool clearProductType = false,
    bool clearHasBarcode = false,
    bool clearHasImage = false,
    bool clearCreatedAfter = false,
    bool clearCreatedBefore = false,
  }) {
    return ProductFilter(
      canBeSold: clearCanBeSold ? null : (canBeSold ?? this.canBeSold),
      canBePurchased: clearCanBePurchased ? null : (canBePurchased ?? this.canBePurchased),
      productType: clearProductType ? null : (productType ?? this.productType),
      hasBarcode: clearHasBarcode ? null : (hasBarcode ?? this.hasBarcode),
      hasImage: clearHasImage ? null : (hasImage ?? this.hasImage),
      createdAfter: clearCreatedAfter ? null : (createdAfter ?? this.createdAfter),
      createdBefore: clearCreatedBefore ? null : (createdBefore ?? this.createdBefore),
    );
  }

  @override
  String toString() {
    return 'ProductFilter(canBeSold: $canBeSold, canBePurchased: $canBePurchased, productType: $productType, hasBarcode: $hasBarcode, hasImage: $hasImage, createdAfter: $createdAfter, createdBefore: $createdBefore)';
  }
}
