/// Lightweight representation of an Odoo payment term.
class PaymentTerm {
  final int id;
  final String name;

  PaymentTerm({
    required this.id,
    required this.name,
  });

  /// Creates a PaymentTerm from an Odoo RPC JSON map.
  factory PaymentTerm.fromJson(Map<String, dynamic> json) {
    return PaymentTerm(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'Unknown',
    );
  }

  /// Converts the payment term to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'PaymentTerm(id: $id, name: $name)';
  }
}
