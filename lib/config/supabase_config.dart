/// Supabase connection settings.
///
/// 👉 Paste your two values here (from Supabase → Project Settings → API):
///    - url      = Project URL          (e.g. https://abcd1234.supabase.co)
///    - anonKey  = anon public key      (the long "eyJ..." one, NOT service_role)
///
/// While these stay as placeholders, the app runs on local demo data.
/// The moment you paste real values, it connects to Supabase automatically —
/// no other code changes needed.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://wbzalhumtpetmmuoaitm.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndiemFsaHVtdHBldG1tdW9haXRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3Mzg5ODAsImV4cCI6MjA5NjMxNDk4MH0.1Ym3PoQ6tNvXHW3Ft-pwpz15_7CLaDwwr09Uw79fGxM';

  /// True only once both values have been replaced with real ones.
  static bool get isConfigured =>
      url.startsWith('http') &&
      !url.contains('YOUR_') &&
      anonKey.length > 30 &&
      !anonKey.contains('YOUR_');
}
