/// Where cloud sync lives. One CoreIntel cloud serves every organisation;
/// each organisation's phones only ever see its own records.
abstract final class CloudConfig {
  static const url = 'https://ucheilfvkovukzunkvrl.supabase.co';

  /// Public by design: it only lets a phone call the sync functions, and
  /// every function checks the phone's own secret token.
  static const publishableKey =
      'sb_publishable__fqy0XUzs6MG7zkEEWigTQ_Ez15BGoL';

  /// How often a signed-in phone syncs in the background.
  static const autoSyncEvery = Duration(minutes: 5);
}
