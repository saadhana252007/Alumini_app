/// Build-time configuration. Supply values with
/// `flutter run --dart-define-from-file=env.json` (see README).
/// Only the public anon key belongs here - NEVER the service-role key.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
