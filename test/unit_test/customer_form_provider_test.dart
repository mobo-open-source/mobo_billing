import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/providers/customer_form_provider.dart';
import '../mocks/mock_services.dart';

void main() {
  group('CustomerFormProvider Tests', () {
    late MockOdooApiService mockApiService;
    late MockImagePicker mockImagePicker;
    late CustomerFormProvider provider;

    setUp(() {
      mockApiService = MockOdooApiService();
      mockImagePicker = MockImagePicker();
      provider = CustomerFormProvider(
        apiService: mockApiService,
        picker: mockImagePicker,
      );
    });

    test('loadDropdownData should fetch options and update lists', () async {

      when(() => mockApiService.searchRead('res.country', any(), any(), any(), any(), any()))
          .thenAnswer((_) async => [{'id': 1, 'name': 'USA'}]);
      

      when(() => mockApiService.searchRead('res.partner.title', any(), any()))
          .thenAnswer((_) async => [{'id': 1, 'name': 'Mr.'}]);
      

      when(() => mockApiService.searchRead('res.currency', any(), any()))
          .thenAnswer((_) async => [{'id': 1, 'name': 'USD'}]);
      

      when(() => mockApiService.searchRead('res.lang', any(), any()))
          .thenAnswer((_) async => [{'code': 'en_US', 'name': 'English'}]);

      await provider.loadDropdownData();

      expect(provider.countryOptions.length, 1);
      expect(provider.countryOptions.first['name'], 'USA');
      expect(provider.titleOptions.length, 1);
      expect(provider.currencyOptions.length, 1);
      expect(provider.languageOptions.length, 1);
      expect(provider.isDropdownLoading, false);
    });

    test('fetchStates should update stateOptions', () async {
      when(() => mockApiService.searchRead('res.country.state', any(), any(), any(), any(), any()))
          .thenAnswer((_) async => [{'id': 10, 'name': 'New York'}]);

      await provider.fetchStates(1);

      expect(provider.stateOptions.length, 1);
      expect(provider.stateOptions.first['name'], 'New York');
    });

    test('reset should clear form state', () {
      provider.reset();
      expect(provider.pickedImage, isNull);
      expect(provider.stateOptions, isEmpty);
    });
  });
}
