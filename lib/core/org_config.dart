import '../data/database.dart';

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

  /// JBF green and gold.
  static const primaryColor = 0xFF0B6B3A;
  static const accentColor = 0xFFC9A227;

  /// Bundled logo, used until an organisation sets its own in settings.
  static const logoAsset = 'assets/branding/logo_shield.png';

  /// Seeded contribution types. Amounts start unset: the Founder, Treasurer
  /// or General Secretary sets the monthly dues in the app.
  static const contributionTypes =
      <(String, ContributionCategory, ContributionFrequency, String?)>[
        (
          'Monthly welfare dues',
          ContributionCategory.welfare,
          ContributionFrequency.monthly,
          'Set the monthly amount before recording dues.',
        ),
        (
          'Silver collection',
          ContributionCategory.welfare,
          ContributionFrequency.perEvent,
          'Impromptu collection taken at an event.',
        ),
        (
          'Emergency levy',
          ContributionCategory.emergency,
          ContributionFrequency.oneOff,
          'Funeral, hospital or disaster support.',
        ),
        (
          'Charity project',
          ContributionCategory.charity,
          ContributionFrequency.open,
          null,
        ),
        (
          'Executive council dues',
          ContributionCategory.executive,
          ContributionFrequency.monthly,
          'Executives only.',
        ),
        (
          'Event contribution',
          ContributionCategory.event,
          ContributionFrequency.perEvent,
          null,
        ),
        (
          'Voluntary donation',
          ContributionCategory.voluntary,
          ContributionFrequency.open,
          null,
        ),
      ];

  /// Seeded leadership positions.
  static const positions = <(String, PositionLevel)>[
    ('Founder', PositionLevel.board),
    ('Director', PositionLevel.board),
    ('General Secretary', PositionLevel.national),
    ('Organizer', PositionLevel.national),
    ('Treasurer', PositionLevel.national),
    ('Welfare Chairman', PositionLevel.welfare),
    ('Welfare Secretary', PositionLevel.welfare),
    ('Welfare Team Member', PositionLevel.welfare),
    ('Zone Mayor', PositionLevel.zone),
    ('Zone Deputy Mayor', PositionLevel.zone),
    ('Zone Secretary', PositionLevel.zone),
    ('Zone Treasurer', PositionLevel.zone),
    ('Zone Organizer', PositionLevel.zone),
    ('Zone Welfare Officer', PositionLevel.zone),
    ('Auditor', PositionLevel.oversight),
    ('Electoral Commission', PositionLevel.oversight),
  ];

  /// Seeded welfare case types: (name, description). Benefit amounts start
  /// unset; the Treasurer proposes them and the Welfare Chairman approves.
  static const welfareCaseTypes = <(String, String?)>[
    ('Death of a member', 'Support to the family of a member who has died.'),
    ('Death of spouse, parent or child', null),
    ('Hospitalisation', 'Member admitted to hospital.'),
    ('Childbirth', 'Member or spouse has had a baby.'),
    ('Wedding', 'Member is getting married.'),
    ('Fire, flood or disaster', null),
    ('Other support', 'Amount decided case by case.'),
  ];

  /// Seeded expense categories. Welfare payouts are recorded on the
  /// welfare case, not as expenses.
  static const expenseCategories = <String>[
    'Event costs',
    'Venue and hall hire',
    'Food and refreshments',
    'Transport',
    'Printing and stationery',
    'Charity project',
    'Gifts and donations given',
    'Bank and MoMo charges',
    'Administration',
    'Other',
  ];

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
