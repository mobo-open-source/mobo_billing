import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/odoo_api_service.dart';
import '../services/odoo_error_handler.dart';

/// Provider for managing the current user's profile data and preferences.
class ProfileProvider with ChangeNotifier {
  final OdooApiService _apiService;

  ProfileProvider({OdooApiService? apiService})
    : _apiService = apiService ?? OdooApiService();

  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _error;
  bool _hasError = false;

  List<Map<String, String>> _timezones = [];
  List<Map<String, String>> _languages = [];
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];

  Map<String, dynamic>? get profile => _profile;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get hasError => _hasError;

  List<Map<String, String>> get timezones => _timezones;

  List<Map<String, String>> get languages => _languages;

  List<Map<String, dynamic>> get countries => _countries;

  List<Map<String, dynamic>> get states => _states;

  /// Resets the profile state to its initial values.
  Future<void> clearData() async {
    _profile = null;
    _isLoading = false;
    _error = null;
    _hasError = false;
    _timezones = [];
    _languages = [];
    _countries = [];
    _states = [];
    notifyListeners();
  }

  /// Fetches the user profile and corresponding partner information from Odoo.
  Future<void> loadProfile() async {
    _setLoading(true);
    _setError(null);
    _hasError = false;

    try {
      await Future(() async {
        if (_apiService.userInfo['uid'] == null) {
          await _apiService.restoreFromPrefs();
        }

        final uid = _apiService.userInfo['uid'] as int?;
        if (uid == null) {
          throw Exception('User not authenticated');
        }

        final users = await _apiService.read(
          'res.users',
          [uid],
          [
            'name',
            'login',
            'email',
            'partner_id',

            'avatar_128',

            'image_128',
            'tz',
            'lang',
            'company_id',
            'signature',
          ],
        );

        if (users.isEmpty) {
          throw Exception('User not found');
        }

        final user = users.first;

        String? phone;
        String? mobile;
        String? street;
        String? street2;
        String? city;
        String? zip;
        String? vat;
        String? website;
        String? jobTitle;
        int? partnerId;
        int? stateId;
        String? stateName;
        int? countryId;
        String? countryName;

        String? companyName;
        if (user['company_id'] is List && user['company_id'].length > 1) {
          companyName = user['company_id'][1]?.toString();
        }

        if (user['partner_id'] is List && user['partner_id'].isNotEmpty) {
          partnerId = user['partner_id'][0] as int;
          try {
            final partners = await _apiService.read(
              'res.partner',
              [partnerId],
              [
                'phone',
                'street',
                'street2',
                'city',
                'state_id',
                'country_id',
                'zip',
                'vat',
                'website',
                'function',
              ],
            );
            if (partners.isNotEmpty) {
              final p = partners.first;
              phone = p['phone']?.toString();
              mobile = p['mobile']?.toString();
              street = p['street']?.toString();
              street2 = p['street2']?.toString();
              city = p['city']?.toString();
              zip = p['zip']?.toString();
              vat = p['vat']?.toString();
              website = p['website']?.toString();
              jobTitle = p['function']?.toString();

              if (p['state_id'] is List && p['state_id'].isNotEmpty) {
                stateId = p['state_id'][0] as int;
                stateName = p['state_id'].length > 1
                    ? p['state_id'][1]?.toString()
                    : null;
              }
              if (p['country_id'] is List && p['country_id'].isNotEmpty) {
                countryId = p['country_id'][0] as int;
                countryName = p['country_id'].length > 1
                    ? p['country_id'][1]?.toString()
                    : null;
              }
            }
          } catch (_) {}
        }

        dynamic profileImage = user['avatar_128'];
        String _imgSource = 'avatar_128';
        if (profileImage == null ||
            (profileImage is bool && profileImage == false) ||
            (profileImage is String && profileImage.isEmpty)) {
          profileImage = user['image_128'];
          _imgSource = 'image_128';
        }
        if (profileImage is bool && profileImage == false) {
          profileImage = null;
        }

        if (profileImage is String && profileImage.trim().isNotEmpty) {
          try {
            var raw = profileImage.trim();
            final dataUrlPrefix = RegExp(
              r'^data:image\/[a-zA-Z0-9.+-]+;base64,',
            );
            raw = raw.replaceFirst(dataUrlPrefix, '');
            final clean = raw.replaceAll(RegExp(r'\s+'), '');
            if (clean.isEmpty) {
              profileImage = null;
            } else {
              final bytes = base64Decode(clean);

              bool looksLikeImage(List<int> b) {
                if (b.length < 4) return false;
                if (b[0] == 0x89 &&
                    b[1] == 0x50 &&
                    b[2] == 0x4E &&
                    b[3] == 0x47)
                  return true;
                if (b[0] == 0xFF && b[1] == 0xD8) return true;
                if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) return true;
                if (b.length >= 12 &&
                    b[0] == 0x52 &&
                    b[1] == 0x49 &&
                    b[2] == 0x46 &&
                    b[3] == 0x46 &&
                    b[8] == 0x57 &&
                    b[9] == 0x45 &&
                    b[10] == 0x42 &&
                    b[11] == 0x50)
                  return true;
                return false;
              }

              if (!looksLikeImage(bytes)) {
              } else {}
            }
          } catch (_) {
            profileImage = null;
          }
        }

        _profile = {
          'id': uid,
          'name': user['name'] ?? '',
          'login': user['login'] ?? '',
          'email': user['email'] ?? '',

          'image_128': profileImage,
          'tz': user['tz'] ?? '',
          'lang': user['lang'] ?? '',
          'company_id':
              (user['company_id'] is List && user['company_id'].isNotEmpty)
              ? user['company_id'][0]
              : null,
          'company_name': companyName ?? '',
          'signature': user['signature'] ?? '',

          'partner_id': partnerId,
          'phone': phone ?? '',
          'mobile': mobile ?? '',
          'street': street ?? '',
          'street2': street2 ?? '',
          'city': city ?? '',
          'zip': zip ?? '',
          'vat': vat ?? '',
          'website': website ?? '',
          'job_title': jobTitle ?? '',
          'state_id': stateId,
          'state_name': stateName ?? '',
          'country_id': countryId,
          'country_name': countryName ?? '',
        };

        await loadMetaOptions();
        if (countryId != null) {
          await loadStatesForCountry(countryId);
        }

        _setLoading(false);
        notifyListeners();
      }).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw TimeoutException('Profile request timed out');
        },
      );
    } catch (e) {
      _setError(OdooErrorHandler.toUserMessage(e));
      _hasError = true;
      _setLoading(false);
    }
  }

  /// Batch fetches metadata like timezones, languages, and countries.
  Future<void> loadMetaOptions() async {
    try {
      final fields = await _apiService.call(
        'res.users',
        'fields_get',
        [
          ['tz', 'lang'],
        ],
        {
          'attributes': [' '],
        },
      );
      _timezones = [];
      _languages = [];
      if (fields is Map) {
        final tzSel = fields['tz']?['selection'];
        if (tzSel is List) {
          _timezones = tzSel
              .whereType<List>()
              .where((e) => e.length >= 2)
              .map((e) => {'value': e[0].toString(), 'label': e[1].toString()})
              .toList();
        }
        final langSel = fields['lang']?['selection'];
        if (langSel is List) {
          _languages = langSel
              .whereType<List>()
              .where((e) => e.length >= 2)
              .map((e) => {'value': e[0].toString(), 'label': e[1].toString()})
              .toList();
        }
      }
    } catch (_) {
      try {
        final langs = await _apiService.searchRead(
          'res.lang',
          [
            ['active', '=', true],
          ],
          ['code', 'name'],
          0,
          200,
        );
        _languages = langs
            .map(
              (l) => {
                'value': (l['code'] ?? '').toString(),
                'label': (l['name'] ?? '').toString(),
              },
            )
            .where((m) => m['value']!.isNotEmpty && m['label']!.isNotEmpty)
            .toList();
      } catch (_) {}
    }

    try {
      final res = await _apiService.searchRead(
        'res.country',
        [],
        ['name'],
        0,
        200,
      );
      _countries = res
          .map((c) => {'id': c['id'], 'name': c['name']})
          .where(
            (c) =>
                c['id'] != null && (c['name']?.toString().isNotEmpty ?? false),
          )
          .toList();
    } catch (_) {}

    notifyListeners();
  }

  /// Fetches states for a selected country to populate address forms.
  Future<void> loadStatesForCountry(int countryId) async {
    _states = [];
    try {
      final res = await _apiService.searchRead(
        'res.country.state',
        [
          ['country_id', '=', countryId],
        ],
        ['name'],
        0,
        200,
      );
      _states = res
          .map((s) => {'id': s['id'], 'name': s['name']})
          .where(
            (s) =>
                s['id'] != null && (s['name']?.toString().isNotEmpty ?? false),
          )
          .toList();
    } catch (_) {}
    notifyListeners();
  }

  /// Updates user profile and partner info on the Odoo server.
  Future<bool> updateProfile({
    required String name,
    required String email,
    String? tz,
    String? lang,
    String? phone,
    String? mobile,
    String? website,
    String? jobTitle,
    String? street,
    String? street2,
    String? city,
    String? zip,
    String? vat,
    int? countryId,
    int? stateId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      final uid = _apiService.userInfo['uid'] as int?;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final userValues = <String, dynamic>{'name': name, 'email': email};
      if (tz != null) userValues['tz'] = tz;
      if (lang != null) userValues['lang'] = lang;

      await _apiService.write('res.users', [uid], userValues);

      final partnerId = _profile?['partner_id'] as int?;
      final partnerValues = <String, dynamic>{};
      if (phone != null) partnerValues['phone'] = phone;
      if (mobile != null) partnerValues['mobile'] = mobile;
      if (website != null) partnerValues['website'] = website;
      if (jobTitle != null) partnerValues['function'] = jobTitle;
      if (street != null) partnerValues['street'] = street;
      if (street2 != null) partnerValues['street2'] = street2;
      if (city != null) partnerValues['city'] = city;
      if (zip != null) partnerValues['zip'] = zip;
      if (vat != null) partnerValues['vat'] = vat;
      if (countryId != null) partnerValues['country_id'] = countryId;
      if (stateId != null) partnerValues['state_id'] = stateId;

      if (partnerId != null && partnerValues.isNotEmpty) {
        await _apiService.write('res.partner', [partnerId], partnerValues);
      }
      await loadProfile();
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Clears the current error message.
  void clearError() {
    _setError(null);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
