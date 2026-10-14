/// Organisation defaults used to seed a fresh database.
///
/// The app is a configurable CoreIntel Systems welfare platform: everything
/// here is copied into the `org_settings` table on first run and can change
/// later without a new build.
class OrgDefaults {
  static const name = 'June Borns Family';
  static const shortName = 'JBF';
  static const memberIdPrefix = 'JBF';
  static const currency = 'GHS';
  static const poweredBy = 'CoreIntel Systems';

  /// Bundled logo, used until an organisation sets its own in settings.
  static const logoAsset = 'assets/branding/logo_shield.png';

  /// Seeded zones: (code, name, nickname, active).
  /// Zone 6 is kept in the list but switched off until it has a name and
  /// is ready to receive members.
  static const zones = <(int, String, String?, bool)>[
    (1, 'Zone 1', 'Legends', true),
    (2, 'Zone 2', 'Pacesetters', true),
    (3, 'Zone 3', 'Elite', true),
    (4, 'Zone 4', 'Conqueror', true),
    (5, 'Zone 5', 'Diamond', true),
    (6, 'Zone 6', null, false),
    (7, 'Zone 7', 'Royals', true),
    (8, 'Zone 8', 'Abrempong', true),
  ];
}
