import 'data/database.dart';
import 'data/repositories/audit_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/member_repository.dart';
import 'data/repositories/payment_repository.dart';
import 'data/secure_store.dart';

/// Everything the screens need, created once at start-up.
class AppServices {
  AppServices({required this.db, required this.store, required this.deviceId})
    : audit = AuditRepository(db) {
    auth = AuthRepository(db, audit);
    members = MemberRepository(db, audit);
    dashboard = DashboardRepository(db);
    payments = PaymentRepository(db, audit);
  }

  final AppDatabase db;
  final SecureStore store;
  final String deviceId;
  final AuditRepository audit;
  late final AuthRepository auth;
  late final MemberRepository members;
  late final DashboardRepository dashboard;
  late final PaymentRepository payments;
}
