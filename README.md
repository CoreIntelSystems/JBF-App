# June Borns Family app

Offline-first membership and welfare app for June Borns Family (JBF).
A configurable **CoreIntel Systems** product: organisation name, logo, zones,
contribution types and roles live in the database, so the same app can be set
up for another association.

## What's in this release (Phase 1 preview)

- **Encrypted local database**: SQLite3 Multiple Ciphers via Drift. The key is
  generated on first launch and kept in the Android Keystore.
- **First-run setup** creates the Super Administrator on the device.
- **Sign in** with password, a 4 to 6 digit PIN, or fingerprint. Five wrong
  attempts lock the account for 5 minutes.
- **Roles and permissions** seeded from the JBF spec (Super Admin, Founder,
  Directors, General Secretary, Organizer, Treasurer, Welfare Chairman and team,
  zone executives, Auditor, Electoral Commission, Ordinary Member).
  Monthly dues: Founder, Treasurer or General Secretary. Welfare benefit
  amounts: set by the Treasurer, approved by the Welfare Chairman, or the
  General Secretary when the Chairman is away.
- **Members**: full registration form, auto member IDs (`JBF-000001`),
  photo, search by name / phone / ID, filters by zone and status,
  status changes (active, inactive, suspended, deceased).
- **Zones**: 8 zones seeded; Zone 6 is listed but closed to new members.
  Every member is in 1 or 2 zones. The form warns on a third, and a database
  trigger refuses it as well.
- **Dashboard**: member totals, status breakdown, active members per zone,
  recent registrations.
- **Users and roles** screen and an append-only **audit log** (logins, edits,
  status changes).

Payments, receipts, dues, welfare, events, reports and backup follow in later
phases (see the build plan).

## Getting a test APK

Every push and pull request runs the **Android build** workflow. Open the run
in the Actions tab and download `jbf-app-debug-apk` from the Artifacts list.

## Development

```sh
flutter pub get
dart run build_runner build   # after changing tables in lib/data/database.dart
flutter analyze
flutter test
flutter run
```

Layout:

```
lib/core       theme, org defaults, formatting, ids
lib/data       Drift database, encryption, repositories
lib/domain     business rules (zone limit, permissions, password hashing)
lib/features   screens: auth, dashboard, members, users, audit, more
```
