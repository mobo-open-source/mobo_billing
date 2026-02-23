import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/services/payment_service.dart';

void main() {
  late PaymentService paymentService;

  setUp(() {
    paymentService = PaymentService();
  });

  group('PaymentService Tests', () {
    test('getAvailablePaymentMethods returns correct list', () {
      final methods = paymentService.getAvailablePaymentMethods();
      expect(methods, contains(PaymentMethod.cash));
      expect(methods, contains(PaymentMethod.bank));
      expect(methods.length, 2);
    });

    test('getPaymentMethodName returns correct names', () {
      expect(paymentService.getPaymentMethodName(PaymentMethod.cash), 'Cash');
      expect(paymentService.getPaymentMethodName(PaymentMethod.bank), 'Bank Transfer');
    });

    test('processPayment handles Cash correctly', () async {
      final result = await paymentService.processPayment(
        amount: 100.0,
        method: PaymentMethod.cash,
        currency: 'USD',
        description: 'Test Payment',
      );

      expect(result.success, isTrue);
      expect(result.amount, 100.0);
      expect(result.method, PaymentMethod.cash);
      expect(result.status, PaymentStatus.pending);
      expect(result.additionalData?['requires_verification'], isTrue);
    });

    test('processPayment handles Bank Transfer correctly', () async {
      final result = await paymentService.processPayment(
        amount: 50.0,
        method: PaymentMethod.bank,
        currency: 'EUR',
      );

      expect(result.success, isTrue);
      expect(result.status, PaymentStatus.pending);
      expect(result.method, PaymentMethod.bank);
    });
    
    test('PaymentResult model serialization', () {
        final result = PaymentResult(
            success: true,
            amount: 100,
            method: PaymentMethod.cash,
            status: PaymentStatus.completed,
            transactionId: 'TX123'
        );
        
        final json = result.toJson();
        expect(json['success'], true);
        expect(json['amount'], 100.0);
        expect(json['method'], 'cash');
        expect(json['transaction_id'], 'TX123');
    });
  });
}
