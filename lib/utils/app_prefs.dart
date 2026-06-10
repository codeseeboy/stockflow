import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// App-wide key-value persistence. [init] must complete before `runApp`.
///
/// Backed by SharedPreferences (localStorage on web, SharedPreferences on
/// Android/iOS), so reads are synchronous after init and writes persist
/// across app restarts.
class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _sp;

  static Future<void> init() async {
    _sp ??= await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _sp?.getString(key);
  static void setString(String key, String value) => _sp?.setString(key, value);
  static bool getBool(String key) => _sp?.getBool(key) ?? false;
  static void setBool(String key, bool value) => _sp?.setBool(key, value);
  static void remove(String key) => _sp?.remove(key);
}

/// The locally remembered customer profile.
///
/// Saved when the user logs in, registers or continues as guest, so the app
/// opens straight into the shell on the next launch — no repeated logins.
/// Cleared on explicit logout.
class SavedProfile {
  final String name;
  final String phone;
  final String email;
  final String address;
  final bool guest;
  final DateTime? accountCreatedAt;

  const SavedProfile({
    required this.name,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.guest = false,
    this.accountCreatedAt,
  });

  static const _key = 'customer_profile';
  static const _onboardKey = 'onboarding_done';

  void save() {
    final existing = load();
    final created = accountCreatedAt ?? existing?.accountCreatedAt;
    final data = <String, dynamic>{
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'guest': guest,
    };
    if (created != null) data['accountCreatedAt'] = created.toIso8601String();
    AppPrefs.setString(_key, jsonEncode(data));
  }

  static SavedProfile? load() {
    final raw = AppPrefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final name = (m['name'] as String?) ?? '';
      if (name.isEmpty) return null;
      final createdRaw = m['accountCreatedAt'] as String?;
      return SavedProfile(
        name: name,
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        guest: (m['guest'] as bool?) ?? false,
        accountCreatedAt: createdRaw != null ? DateTime.tryParse(createdRaw) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static void clear() => AppPrefs.remove(_key);

  static bool get onboardingDone => AppPrefs.getBool(_onboardKey);
  static void markOnboardingDone() => AppPrefs.setBool(_onboardKey, true);
}

/// Remembers admin/staff login on web — opens straight into the console on reload.
class SavedAdminSession {
  final String email;
  final UserRole role;

  const SavedAdminSession({required this.email, required this.role});

  static const _key = 'admin_session';

  void save() => AppPrefs.setString(
        _key,
        jsonEncode({'email': email, 'role': role.name}),
      );

  static SavedAdminSession? load() {
    final raw = AppPrefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final roleName = (m['role'] as String?) ?? 'admin';
      return SavedAdminSession(
        email: (m['email'] as String?) ?? '',
        role: UserRole.values.byName(roleName),
      );
    } catch (_) {
      return null;
    }
  }

  static void clear() => AppPrefs.remove(_key);
}
