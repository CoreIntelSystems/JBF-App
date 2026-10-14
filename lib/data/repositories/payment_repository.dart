import 'package:drift/drift.dart';

import '../../domain/dues.dart';
import '../database.dart';
import 'actor.dart';
import 'audit_repository.dart';

class PaymentException implements Exception {
  PaymentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the record-payment form collects.
class PaymentDraft {
  PaymentDraft({
    required this.memberId,
    required this.contributionTypeId,
    required this.amount,
    required this.method,
    required this.paidOn,
    this.period,
    this.reference,
    this.remarks,
  });

  final String? memberId;
  final String contributionTypeId;
  final int amount;
  final PaymentMethod method;
  final DateTime paidOn;
  final String? period;
  final String? reference;
  final String? remarks;
}

/// A payment joined with its member and contribution type, for lists and
/// receipts.
class PaymentView {
  const PaymentView(this.payment, this.type, this.member);
  final Payment payment;
  final ContributionType type;
  final Member? member;

  String get payerName => member?.fullName ?? 'Anonymous';
}

class DuesStatus {
  const DuesStatus(this.type, this.summary);
  final ContributionType type;
  final DuesSummary summary;
}

/// Everything shown on a member's account page.
class MemberLedger {
  const MemberLedger({
    required this.payments,
    required this.dues,
    required this.totalPaid,
    required this.paidByCategory,
  });

  final List<PaymentView> payments;
  final List<DuesStatus> dues;
  final int totalPaid;
  final Map<ContributionCategory, int> paidByCategory;

  int get outstanding => dues.fold(0, (a, d) => a + d.summary.outstanding);
  DateTime? get lastPaymentDate {
    for (final p in payments) {
      if (p.payment.status == PaymentStatus.valid) return p.payment.paidOn;
    }
    return null;
  }
}

class CollectionStats {
  const CollectionStats({
    required this.today,
    required this.thisMonth,
    required this.outstanding,
    required this.defaulters,
    required this.recent,
    required this.duesConfigured,
  });

  final int today;
  final int thisMonth;
  final int outstanding;
  final int defaulters;
  final List<PaymentView> recent;

  /// False until someone sets the monthly dues amount.
  final bool duesConfigured;
}

class PaymentRepository {
  PaymentRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  Future<OrgSetting> org() => _db.select(_db.orgSettings).getSingle();

  // ---- Contribution types -------------------------------------------------

  Stream<List<ContributionType>> watchTypes() =>
      (_db.select(_db.contributionTypes)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.category),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  Future<List<ContributionType>> activeTypes() =>
      (_db.select(_db.contributionTypes)
            ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();

  /// Creates ([id] null) or updates a contribution type.
  Future<String> saveType(
    String? id,
    ContributionTypesCompanion data,
    Actor actor,
  ) async {
    if ((data.name.present && data.name.value.trim().isEmpty)) {
      throw PaymentException('Enter a name.');
    }
    return _db.transaction(() async {
      if (id == null) {
        final row = await _db
            .into(_db.contributionTypes)
            .insertReturning(
              data.copyWith(
                createdBy: Value(actor.userId),
                deviceId: Value(actor.deviceId),
              ),
            );
        await _audit.log(
          actor,
          'contribution_type.create',
          entity: 'contribution_types',
          entityId: row.id,
          newValue: _typeJson(row),
        );
        return row.id;
      }
      final before = await _type(id);
      await (_db.update(_db.contributionTypes)..where((t) => t.id.equals(id)))
          .write(data.copyWith(updatedAt: Value(_now())));
      final after = await _type(id);
      await _audit.log(
        actor,
        'contribution_type.update',
        entity: 'contribution_types',
        entityId: id,
        oldValue: _typeJson(before),
        newValue: _typeJson(after),
      );
      return id;
    });
  }

  Future<ContributionType> _type(String id) => (_db.select(
    _db.contributionTypes,
  )..where((t) => t.id.equals(id))).getSingle();

  Map<String, Object?> _typeJson(ContributionType t) => {
    'name': t.name,
    'category': t.category.name,
    'frequency': t.frequency.name,
    'amount': t.amount,
    'isActive': t.isActive,
  };

  // ---- Payments -----------------------------------------------------------

  /// Records a payment and allocates its receipt number in one transaction,
  /// so there is never a receipt without a ledger entry.
  Future<Payment> record(
    PaymentDraft d,
    Actor actor, {
    required String collectorName,
  }) async {
    if (d.amount <= 0) throw PaymentException('Enter an amount above zero.');
    final type = await _type(d.contributionTypeId);
    if (type.frequency == ContributionFrequency.monthly && d.memberId == null) {
      throw PaymentException('Choose the member paying dues.');
    }
    if (type.frequency == ContributionFrequency.monthly && d.period == null) {
      throw PaymentException('Choose the month being paid for.');
    }
    return _db.transaction(() async {
      final org = await _db.select(_db.orgSettings).getSingle();
      final receiptNo =
          '${org.receiptPrefix}-${d.paidOn.year}-'
          '${org.nextReceiptNo.toString().padLeft(6, '0')}';
      await _db
          .update(_db.orgSettings)
          .write(
            OrgSettingsCompanion(nextReceiptNo: Value(org.nextReceiptNo + 1)),
          );
      final p = await _db
          .into(_db.payments)
          .insertReturning(
            PaymentsCompanion.insert(
              receiptNo: receiptNo,
              memberId: Value(d.memberId),
              contributionTypeId: d.contributionTypeId,
              period: Value(d.period),
              amount: d.amount,
              method: d.method,
              reference: Value(_clean(d.reference)),
              paidOn: d.paidOn,
              collectedBy: Value(actor.userId),
              collectorName: collectorName,
              remarks: Value(_clean(d.remarks)),
              createdBy: Value(actor.userId),
              deviceId: Value(actor.deviceId),
            ),
          );
      await _audit.log(
        actor,
        'payment.record',
        entity: 'payments',
        entityId: p.id,
        newValue: {
          'receiptNo': receiptNo,
          'memberId': d.memberId,
          'type': type.name,
          'amount': d.amount,
          'method': d.method.name,
          'period': d.period,
        },
      );
      return p;
    });
  }

  /// Voids a payment. The row stays for the audit trail.
  Future<void> voidPayment(String id, String reason, Actor actor) async {
    if (reason.trim().length < 3) {
      throw PaymentException('Give a reason for voiding.');
    }
    final p = await (_db.select(
      _db.payments,
    )..where((t) => t.id.equals(id))).getSingle();
    if (p.status == PaymentStatus.voided) return;
    await _db.transaction(() async {
      await (_db.update(_db.payments)..where((t) => t.id.equals(id))).write(
        PaymentsCompanion(
          status: const Value(PaymentStatus.voided),
          voidReason: Value(reason.trim()),
          voidedBy: Value(actor.userId),
          voidedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        actor,
        'payment.void',
        entity: 'payments',
        entityId: id,
        oldValue: {'receiptNo': p.receiptNo, 'amount': p.amount},
        newValue: {'reason': reason.trim()},
      );
    });
  }

  JoinedSelectStatement<HasResultSet, dynamic> _viewQuery() =>
      _db.select(_db.payments).join([
        innerJoin(
          _db.contributionTypes,
          _db.contributionTypes.id.equalsExp(_db.payments.contributionTypeId),
        ),
        leftOuterJoin(
          _db.members,
          _db.members.id.equalsExp(_db.payments.memberId),
        ),
      ]);

  PaymentView _toView(TypedResult r) => PaymentView(
    r.readTable(_db.payments),
    r.readTable(_db.contributionTypes),
    r.readTableOrNull(_db.members),
  );

  Stream<List<PaymentView>> watchRecent({int limit = 100}) {
    final q = _viewQuery()
      ..orderBy([
        OrderingTerm.desc(_db.payments.paidOn),
        OrderingTerm.desc(_db.payments.createdAt),
      ])
      ..limit(limit);
    return q.watch().map((rows) => rows.map(_toView).toList());
  }

  Stream<PaymentView?> watchPayment(String id) {
    final q = _viewQuery()..where(_db.payments.id.equals(id));
    return q.watchSingleOrNull().map((r) => r == null ? null : _toView(r));
  }

  Future<List<PaymentView>> _memberPayments(String memberId) async {
    final q = _viewQuery()
      ..where(_db.payments.memberId.equals(memberId))
      ..orderBy([
        OrderingTerm.desc(_db.payments.paidOn),
        OrderingTerm.desc(_db.payments.createdAt),
      ]);
    return (await q.get()).map(_toView).toList();
  }

  /// Monthly types with an amount set that apply to every member.
  Future<List<ContributionType>> _duesTypes() =>
      (_db.select(_db.contributionTypes)..where(
            (t) =>
                t.deletedAt.isNull() &
                t.isActive.equals(true) &
                t.appliesToAll.equals(true) &
                t.frequency.equalsValue(ContributionFrequency.monthly) &
                t.amount.isNotNull(),
          ))
          .get();

  DuesSummary _summary(
    Member m,
    ContributionType t,
    Iterable<Payment> payments,
  ) {
    final paidByPeriod = <String?, int>{};
    for (final p in payments) {
      if (p.contributionTypeId != t.id || p.status != PaymentStatus.valid) {
        continue;
      }
      paidByPeriod[p.period] = (paidByPeriod[p.period] ?? 0) + p.amount;
    }
    return Dues.summarise(
      monthlyAmount: t.amount!,
      liableMonths: Dues.liableMonths(
        joined: m.dateJoined,
        now: _now(),
        duesStart: t.startDate,
        duesEnd: t.endDate,
        stoppedOn: m.status == MemberStatus.active ? null : m.statusDate,
      ),
      paidByPeriod: paidByPeriod,
    );
  }

  /// The member's account page. Re-emits when payments, types or the member
  /// change.
  Stream<MemberLedger> watchLedger(String memberId) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.payments, _db.contributionTypes, _db.members},
        )
        .watch()
        .asyncMap((_) => ledger(memberId));
  }

  Future<MemberLedger> ledger(String memberId) async {
    final member = await (_db.select(
      _db.members,
    )..where((m) => m.id.equals(memberId))).getSingle();
    final views = await _memberPayments(memberId);
    final valid = views.where((v) => v.payment.status == PaymentStatus.valid);
    final byCategory = <ContributionCategory, int>{};
    for (final v in valid) {
      byCategory[v.type.category] =
          (byCategory[v.type.category] ?? 0) + v.payment.amount;
    }
    final dues = [
      for (final t in await _duesTypes())
        DuesStatus(t, _summary(member, t, views.map((v) => v.payment))),
    ];
    return MemberLedger(
      payments: views,
      dues: dues,
      totalPaid: valid.fold(0, (a, v) => a + v.payment.amount),
      paidByCategory: byCategory,
    );
  }

  /// Dues status for one member and type, used to pre-fill the payment form.
  Future<DuesSummary?> duesFor(String memberId, String typeId) async {
    final t = await _type(typeId);
    if (t.frequency != ContributionFrequency.monthly || t.amount == null) {
      return null;
    }
    final member = await (_db.select(
      _db.members,
    )..where((m) => m.id.equals(memberId))).getSingle();
    final payments = await (_db.select(
      _db.payments,
    )..where((p) => p.memberId.equals(memberId))).get();
    return _summary(member, t, payments);
  }

  /// Defaulters for every dues type, largest balance first.
  Future<List<(Member, int)>> defaulters() async {
    final types = await _duesTypes();
    if (types.isEmpty) return const [];
    final members = await (_db.select(
      _db.members,
    )..where((m) => m.deletedAt.isNull())).get();
    final payments = await (_db.select(
      _db.payments,
    )..where((p) => p.memberId.isNotNull())).get();
    final byMember = <String, List<Payment>>{};
    for (final p in payments) {
      byMember.putIfAbsent(p.memberId!, () => []).add(p);
    }
    final out = <(Member, int)>[];
    for (final m in members) {
      var owed = 0;
      for (final t in types) {
        owed += _summary(m, t, byMember[m.id] ?? const []).outstanding;
      }
      if (owed > 0) out.add((m, owed));
    }
    out.sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  Stream<CollectionStats> watchCollectionStats() {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.payments, _db.contributionTypes, _db.members},
        )
        .watch()
        .asyncMap((_) => _collectionStats());
  }

  Future<CollectionStats> _collectionStats() async {
    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month);
    Future<int> sumSince(DateTime from) async {
      final sum = _db.payments.amount.sum();
      final row =
          await (_db.selectOnly(_db.payments)
                ..addColumns([sum])
                ..where(
                  _db.payments.status.equalsValue(PaymentStatus.valid) &
                      _db.payments.paidOn.isBiggerOrEqualValue(from),
                ))
              .getSingle();
      return row.read(sum) ?? 0;
    }

    final defaulters = await this.defaulters();
    final recentQ = _viewQuery()
      ..where(_db.payments.status.equalsValue(PaymentStatus.valid))
      ..orderBy([
        OrderingTerm.desc(_db.payments.paidOn),
        OrderingTerm.desc(_db.payments.createdAt),
      ])
      ..limit(5);
    return CollectionStats(
      today: await sumSince(dayStart),
      thisMonth: await sumSince(monthStart),
      outstanding: defaulters.fold(0, (a, d) => a + d.$2),
      defaulters: defaulters.length,
      recent: (await recentQ.get()).map(_toView).toList(),
      duesConfigured: (await _duesTypes()).isNotEmpty,
    );
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
