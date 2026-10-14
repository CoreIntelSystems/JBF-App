import 'package:drift/drift.dart';
import 'package:jbf_app/data/connection.dart';
import 'package:jbf_app/data/database.dart';
import 'package:jbf_app/data/repositories/actor.dart';
import 'package:jbf_app/data/repositories/audit_repository.dart';
import 'package:jbf_app/data/repositories/auth_repository.dart';
import 'package:jbf_app/data/repositories/member_repository.dart';
import 'package:jbf_app/data/repositories/payment_repository.dart';
import 'package:jbf_app/data/repositories/welfare_repository.dart';
import 'package:jbf_app/domain/password_hasher.dart';

class TestEnv {
  TestEnv({DateTime Function()? clock}) : db = openInMemoryDatabase() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    audit = AuditRepository(db);
    auth = AuthRepository(
      db,
      audit,
      hasher: const PasswordHasher(iterations: 10),
    );
    members = MemberRepository(db, audit, clock: clock);
    payments = PaymentRepository(db, audit, clock: clock);
    welfare = WelfareRepository(db, audit, clock: clock);
  }

  final AppDatabase db;
  late final AuditRepository audit;
  late final AuthRepository auth;
  late final MemberRepository members;
  late final PaymentRepository payments;
  late final WelfareRepository welfare;

  static const actor = Actor(userId: 'u1', username: 'tester', deviceId: 'd1');

  Future<Map<int, String>> zoneIdsByCode() async => {
    for (final z in await members.zones()) z.code: z.id,
  };

  MemberDraft draft(String name, List<String> zoneIds) => MemberDraft(
    fullName: name,
    dateJoined: DateTime(2026, 1, 1),
    zoneIds: zoneIds,
    phone: '0240000000',
  );
}
