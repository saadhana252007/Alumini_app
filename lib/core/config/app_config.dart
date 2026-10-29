/// Application-wide environment configuration.
/// Only the public anon key belongs here - NEVER the service-role key.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rfwddsrzanudnjmjmylj.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_NVnU4yDko1jf58WipRNQog_h9Cg5v39',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
