// Persistent storage for the Supabase session refresh token.
// Backed by AppPrefs (SharedPreferences), so it works on Android, iOS and web —
// users stay logged in across app restarts until they explicitly log out.
import 'app_prefs.dart';

const _key = 'stockflow_session';

String? readSession() => AppPrefs.getString(_key);
void writeSession(String value) => AppPrefs.setString(_key, value);
void clearSession() => AppPrefs.remove(_key);
