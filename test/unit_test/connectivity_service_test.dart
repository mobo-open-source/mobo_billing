import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_billing/services/connectivity_service.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  late ConnectivityService connectivityService;
  late MockConnectivity mockConnectivity;

  setUp(() {
    mockConnectivity = MockConnectivity();


    connectivityService = ConnectivityService.instance;
    connectivityService.connectivity = mockConnectivity;
  });

  group('ConnectivityService Tests', () {
    test('checkConnectivityOnce returns true when connected', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final result = await connectivityService.checkConnectivityOnce();
      expect(result, isTrue);
    });

    test('checkConnectivityOnce returns false when disconnected', () async {
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.none]);

      final result = await connectivityService.checkConnectivityOnce();
      expect(result, isFalse);
    });

    test('initialize sets up listener and updates status', () async {
      final controller = StreamController<List<ConnectivityResult>>();
      
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => controller.stream);

      await connectivityService.initialize();

      expect(connectivityService.isConnected, isTrue);
      expect(connectivityService.isInitialized, isTrue);


      controller.add([ConnectivityResult.none]);
      await Future.delayed(Duration.zero);
      
      expect(connectivityService.isConnected, isFalse);

      await controller.close();
    });
  });
}
