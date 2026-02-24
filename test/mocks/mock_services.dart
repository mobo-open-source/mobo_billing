import 'package:mocktail/mocktail.dart';
import 'package:mobo_billing/services/odoo_api_service.dart';
import 'package:mobo_billing/services/session_service.dart';
import 'package:mobo_billing/services/connectivity_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobo_billing/services/invoice_service.dart';
import 'package:mobo_billing/services/payment_service.dart';
import 'package:mobo_billing/services/biometric_service.dart';
import 'package:mobo_billing/services/runtime_permission_service.dart';
import 'package:mobo_billing/services/currency_service.dart';
import 'package:mobo_billing/services/company_local_datasource.dart';

class MockOdooApiService extends Mock implements OdooApiService {}
class MockSessionService extends Mock implements SessionService {}
class MockConnectivityService extends Mock implements ConnectivityService {}
class MockInvoiceService extends Mock implements InvoiceService {}
class MockPaymentService extends Mock implements PaymentService {}
class MockBiometricService extends Mock implements BiometricService {}
class MockRuntimePermissionService extends Mock implements RuntimePermissionService {}
class MockCompanyLocalDataSource extends Mock implements CompanyLocalDataSource {}
class MockCurrencyService extends Mock implements CurrencyService {}

class MockImagePicker extends Mock implements ImagePicker {}
