# June Borns Family app

Offline-first membership and welfare app for June Borns Family (JBF).
A configurable **CoreIntel Systems** product: organisation name, logo, zones,
contribution types and roles live in the database, so the same app can be set
up for another association.

## What's in the app

- **Security:** encrypted local database (SQLite3 Multiple Ciphers), key in
  the Android Keystore; sign in with password, PIN or fingerprint; roles and
  permissions; zone officers see only their own zone(s); append-only audit
  log.
- **Members and zones:** registration, auto member IDs, 1 or 2 zones per
  member (enforced by a database trigger), statuses, ID cards with QR codes.
- **Money:** contribution types and monthly dues with arrears, receipts
  (PDF), meeting collections, voids instead of deletes, defaulters with
  WhatsApp reminders, expenses with vouchers, financial reports (PDF, Excel,
  CSV), charts.
- **Welfare:** fixed benefit amounts (Treasurer proposes, Welfare Chairman
  approves), cases with approval (General Secretary stands in) and payouts.
- **Events and meetings:** budgets, collections and spending per event,
  agendas and minutes, attendance by hand or QR scan, reminders.
- **Executives:** positions, terms, history and meeting attendance.
- **Data safety and multi-phone:** password-protected backups, restore on a
  new phone, daily automatic copies, field phones that send collections to
  the main phone as files.

Guides: [installation](docs/installation-guide.md),
[user](docs/user-guide.md), [administrator](docs/admin-guide.md),
[backup and restore](docs/backup-restore-guide.md).

## Getting a test APK

Every push runs the **Android build** workflow. When it passes it publishes a
pre-release named **Test build N** on the Releases page with a plain `.apk`:
open it on the phone, tap the `.apk` to download, then install. The same APK is
also attached to the run as the `jbf-app-test-apk` artifact (a zip).

Test builds are release-mode APKs signed with a shared test key
(`android/app/test-builds.jks`), so each one installs over the last. Builds for
the Play Store must use a separate key kept in repository secrets.

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
