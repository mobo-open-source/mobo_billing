import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobo_billing/services/currency_service.dart';
import 'package:mobo_billing/services/odoo_session_manager.dart';
import 'package:mobo_billing/services/self_signed.dart' as network;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late CurrencyService currencyService;
  late MockClient mockHttpClient;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() async {

    SharedPreferences.setMockInitialValues({
      'isLoggedIn': true,
      'sessionId': 'test_session_id',
      'serverUrl': 'https://test.odoo.com',
      'database': 'test_db',
      'userLogin': 'test_user',
      'password': 'test_password',
      'userId': 1,
    });
    

    await OdooSessionManager.getCurrentSession();



    mockHttpClient = MockClient((request) async {
      final body = jsonDecode(request.body);
      final method = body['params']['method'];
      
      if (method == 'search_read' || method == 'read') {
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [],
        }), 200);
      }
      
      return http.Response('Not Found', 404);
    });


    network.ioClient = mockHttpClient;
    
    currencyService = CurrencyService();
  });

  group('CurrencyService Tests', () {
    test('fetchUserCompany calls API with correct parameters', () async {

      mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['params']['model'], 'res.users');
        expect(body['params']['method'], 'search_read');
        expect(body['params']['args'][0][0][0], 'login');
        expect(body['params']['args'][0][0][2], 'test@example.com');
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [{'company_id': [1, 'My Company']}],
        }), 200);
      });
      network.ioClient = mockHttpClient;

      final result = await currencyService.fetchUserCompany('test@example.com');
      expect(result, isNotEmpty);
      expect(result[0]['company_id'][0], 1);
    });

    test('fetchCompanyCurrency calls API with correct parameters', () async {
      mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['params']['model'], 'res.company');
        expect(body['params']['method'], 'search_read');
        expect(body['params']['args'][0][0][0], 'id');
        expect(body['params']['args'][0][0][2], 1);
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [{'currency_id': [2, 'USD']}],
        }), 200);
      });
      network.ioClient = mockHttpClient;

      final result = await currencyService.fetchCompanyCurrency(1);
      expect(result, isNotEmpty);
      expect(result[0]['currency_id'][0], 2);
    });

    test('fetchCurrencyDetails calls API with correct parameters', () async {
      mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['params']['model'], 'res.currency');
        expect(body['params']['method'], 'read');
        expect(body['params']['args'][0][0], 2);
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [{'name': 'USD', 'symbol': '\$'}],
        }), 200);
      });
      network.ioClient = mockHttpClient;

      final result = await currencyService.fetchCurrencyDetails(2);
      expect(result, isNotEmpty);
      expect(result[0]['name'], 'USD');
    });

    test('fetchAllActiveCurrencies calls API with correct parameters', () async {
      mockHttpClient = MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(body['params']['model'], 'res.currency');
        expect(body['params']['method'], 'search_read');
        expect(body['params']['args'][0][0][0], 'active');
        expect(body['params']['args'][0][0][2], true);
        
        return http.Response(jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': [
            {'name': 'USD', 'symbol': '\$'},
            {'name': 'EUR', 'symbol': '€'}
          ],
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });
      network.ioClient = mockHttpClient;

      final result = await currencyService.fetchAllActiveCurrencies();
      expect(result, hasLength(2));
      expect(result[0]['name'], 'USD');
    });
    
    test('fetchUserCompany validation failure should throw exception', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(jsonEncode({
             'jsonrpc': '2.0',
             'error': {'message': 'Odoo Server Error', 'code': 200, 'data': {'message': 'Access Denied'}}
          }), 200);
        });
        network.ioClient = mockHttpClient;
        
        expect(() => currencyService.fetchUserCompany('fail'), throwsException);
    });
  });
}
