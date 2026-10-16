import 'core/org_config.dart';
import 'core/reminders.dart';
import 'data/access_scope.dart';
import 'data/backup_service.dart';
import 'data/collection_batch.dart';
import 'data/database.dart';
import 'data/repositories/analytics_repository.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/events_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/member_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/welfare_repository.dart';
import 'data/secure_store.dart';
import 'data/sync/sync_api.dart';
import 'data/sync/sync_service.dart';

/// Everything the screens need, created once at start-up.
class AppServices {
  AppServices({
    required this.db,
    required this.store,
    required this.deviceId,
    this.backup,
    Reminders? reminders,
    SyncApi? syncApi,
    SyncPrefs? syncPrefs,
  }) : audit = AuditRepository(db),
       reminders = reminders ?? MemoryReminders(),
       prefs = syncPrefs ?? SecureSyncPrefs(store) {
    sync = SyncService(db, syncApi ?? SyncApi.http(), prefs);
    auth = AuthRepository(
      db,
      audit,
      memberCredentials: prefs,
      cloudCheck: (memberNo, password, {newPassword}) => sync.api.memberAuth(
        action: newPassword == null ? 'sign_in' : 'change_password',
        org: OrgDefaults.shortName,
        memberNo: memberNo,
        password: password,
        newPassword: newPassword,
        check: true,
      ),
    );
    members = MemberRepository(db, audit, scope: scope);
    dashboard = DashboardRepository(db, scope: scope);
    payments = PaymentRepository(db, audit, scope: scope);
    welfare = WelfareRepository(db, audit, scope: scope);
    finance = FinanceRepository(db, audit);
    events = EventsRepository(db, audit, scope: scope);
    analytics = AnalyticsRepository(db, scope: scope);
    batches = CollectionBatches(db, audit);
  }

  final AppDatabase db;
  final SecureStore store;
  final String deviceId;
  final AuditRepository audit;

  /// Small per-phone values kept outside the database.
  final SyncPrefs prefs;

  /// What the signed-in user may see; set by the sign-in flow.
  final AccessScope scope = AccessScope();
  late final AuthRepository auth;
  late final MemberRepository members;
  late final DashboardRepository dashboard;
  late final PaymentRepository payments;
  late final WelfareRepository welfare;
  late final FinanceRepository finance;
  late final EventsRepository events;
  late final AnalyticsRepository analytics;
  late final CollectionBatches batches;

  /// Cloud sync with the organisation's other phones.
  late final SyncService sync;

  /// Null in tests that do not use a database file.
  final BackupService? backup;

  /// Local notifications on this phone.
  final Reminders reminders;
}
