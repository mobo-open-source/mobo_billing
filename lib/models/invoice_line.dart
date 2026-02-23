/// Represents a single line within an Odoo invoice (account.move.line).
class InvoiceLine {
  final int? id;
  final int? productId;
  final String? productName;
  final double? quantity;
  final double? priceUnit;
  final double? discount;
  final double? priceSubtotal;
  final double? priceTotal;
  final int? productUomId;
  final String? productUomName;
  final List<int> taxIds;
  final List<String> taxNames;

  InvoiceLine({
    this.id,
    this.productId,
    this.productName,
    this.quantity,
    this.priceUnit,
    this.discount,
    this.priceSubtotal,
    this.priceTotal,
    this.productUomId,
    this.productUomName,
    this.taxIds = const [],
    this.taxNames = const [],
  });

  /// Creates an InvoiceLine from an Odoo RPC JSON map.
  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
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
      return null;
    }


    int? productId;
    String? productName;
    if (json['product_id'] is List && (json['product_id'] as List).isNotEmpty) {
      productId = json['product_id'][0] as int?;
      productName = json['product_id'].length > 1 ? json['product_id'][1]?.toString() : null;
    } else if (json['product_id'] is int) {
      productId = json['product_id'] as int;
    }


    int? uomId;
    String? uomName;
    if (json['product_uom_id'] is List && (json['product_uom_id'] as List).isNotEmpty) {
      uomId = json['product_uom_id'][0] as int?;
      uomName = json['product_uom_id'].length > 1 ? json['product_uom_id'][1]?.toString() : null;
    } else if (json['product_uom_id'] is int) {
      uomId = json['product_uom_id'] as int;
    }


    List<int> taxIds = [];
    List<String> taxNames = [];
    if (json['tax_ids'] is List) {
      for (var tax in json['tax_ids']) {
        if (tax is int) {
          taxIds.add(tax);
        } else if (tax is List && tax.isNotEmpty) {
          taxIds.add(tax[0] as int);
          if (tax.length > 1) taxNames.add(tax[1].toString());
        }
      }
    }

    return InvoiceLine(
      id: getInt(json['id']),
      productId: productId,
      productName: productName,
      quantity: getDouble(json['quantity']),
      priceUnit: getDouble(json['price_unit']),
      discount: getDouble(json['discount']),
      priceSubtotal: getDouble(json['price_subtotal']),
      priceTotal: getDouble(json['price_total']),
      productUomId: uomId,
      productUomName: uomName,
      taxIds: taxIds,
      taxNames: taxNames,
    );
  }

  /// Converts the invoice line to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId != null ? [productId, productName] : null,
      'quantity': quantity,
      'price_unit': priceUnit,
      'discount': discount,
      'price_subtotal': priceSubtotal,
      'price_total': priceTotal,
      'product_uom_id': productUomId != null ? [productUomId, productUomName] : null,
      'tax_ids': taxIds,
    };
  }
}
