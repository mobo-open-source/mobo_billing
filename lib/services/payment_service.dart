enum PaymentMethod { cash, bank }

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
}

/// Encapsulates the result of a payment operation.
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? paymentMethodId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? errorMessage;
  final String? errorCode;
  final DateTime? paymentDate;
  final Map<String, dynamic>? additionalData;

  const PaymentResult({
    required this.success,
    this.transactionId,
    this.paymentMethodId,
    required this.amount,
    required this.method,
    required this.status,
    this.errorMessage,
    this.errorCode,
    this.paymentDate,
    this.additionalData,
  });

  String? get paymentMethod {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bank:
        return 'Bank Transfer';
    }
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'transaction_id': transactionId,
    'payment_method_id': paymentMethodId,
    'amount': amount,
    'method': method.name,
    'status': status.name,
    'error_message': errorMessage,
    'error_code': errorCode,
    'payment_date': paymentDate?.toIso8601String(),
    'additional_data': additionalData,
  };
}

/// Service for processing payments (cash, bank) and managing payment methods.
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() => _instance;

  PaymentService._internal();

  /// The main entry point for processing a payment with the specified method and amount.
  Future<PaymentResult> processPayment({
    required double amount,
    required PaymentMethod method,
    required String currency,
    String? description,
    Map<String, dynamic>? customerData,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      switch (method) {
        case PaymentMethod.cash:
        case PaymentMethod.bank:
          return _processOfflinePayment(amount, method, currency, description);
      }
    } catch (e) {
      return PaymentResult(
        success: false,
        amount: amount,
        method: method,
        status: PaymentStatus.failed,
        errorMessage: e.toString(),
        errorCode: 'PROCESSING_ERROR',
        paymentDate: DateTime.now(),
      );
    }
  }

  PaymentResult _processOfflinePayment(
    double amount,
    PaymentMethod method,
    String currency,
    String? description,
  ) {
    return PaymentResult(
      success: true,
      transactionId: 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      method: method,
      status: PaymentStatus.pending,
      paymentDate: DateTime.now(),
      additionalData: {
        'currency': currency,
        'description': description,
        'requires_verification': true,
      },
    );
  }

  /// Returns the list of currently supported payment methods.
  List<PaymentMethod> getAvailablePaymentMethods() {
    return [PaymentMethod.cash, PaymentMethod.bank];
  }

  /// Returns a human-readable name for a given payment method.
  String getPaymentMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bank:
        return 'Bank Transfer';
    }
  }
}
