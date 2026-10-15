import 'core/reminders.dart';
import 'data/backup_service.dart';
import 'data/collection_batch.dart';
import 'data/database.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'data/repositories/member_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/repositories/welfare_repository.dart';
import 'data/secure_store.dart';

/// Everything the screens need, created once at start-up.
class AppServices {
  AppServices({
    required this.db,
    required this.store,
    required this.deviceId,
    this.backup,
    Reminders? reminders,
  }) : audit = AuditRepository(db),
       reminders = reminders ?? MemoryReminders() {
    auth = AuthRepository(db, audit);
    members = MemberRepository(db, audit);
    dashboard = DashboardRepository(db);
    payments = PaymentRepository(db, audit);
    welfare = WelfareRepository(db, audit);
    finance = FinanceRepository(db, audit);
    batches = CollectionBatches(db, audit);
  }

  final AppDatabase db;
  final SecureStore store;
  final String deviceId;
  final AuditRepository audit;
  late final AuthRepository auth;
  late final MemberRepository members;
  late final DashboardRepository dashboard;
  late final PaymentRepository payments;
  late final WelfareRepository welfare;
  late final FinanceRepository finance;
  late final CollectionBatches batches;

  /// Null in tests that do not use a database file.
  final BackupService? backup;

  /// Local notifications on this phone.
  final Reminders reminders;
}
