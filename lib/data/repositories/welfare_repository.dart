import 'package:drift/drift.dart';

import '../database.dart';
import 'actor.dart';
import 'audit_repository.dart';

class WelfareException implements Exception {
  WelfareException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Who is acting, with the names shown on cases.
class WelfareActor {
  const WelfareActor(this.actor, {required this.name, required this.roleName});
  final Actor actor;
  final String name;
  final String roleName;
}

class WelfareCaseDraft {
  WelfareCaseDraft({
    required this.memberId,
    required this.caseTypeId,
    required this.occurredOn,
    this.requestedAmount,
    this.beneficiary,
    this.description,
  });

  final String memberId;
  final String caseTypeId;
  final DateTime occurredOn;

  /// Used only when the case type has no approved benefit amount.
  final int? requestedAmount;
  final String? beneficiary;
  final String? description;
}

class WelfareCaseView {
  const WelfareCaseView(this.welfareCase, this.type, this.member);
  final WelfareCase welfareCase;
  final WelfareCaseType type;
  final Member member;
}

class WelfareSummary {
  const WelfareSummary({
    required this.pendingCases,
    required this.approvedUnpaid,
    required this.pendingBenefitChanges,
    required this.fundCollected,
    required this.fundPaidOut,
    required this.paidThisMonth,
  });

  final int pendingCases;
  final int approvedUnpaid;
  final int pendingBenefitChanges;

  /// Valid payments into welfare-category contribution types.
  final int fundCollected;

  /// Welfare cases paid out.
  final int fundPaidOut;
  final int paidThisMonth;

  int get fundBalance => fundCollected - fundPaidOut;
}

class WelfareRepository {
  WelfareRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  // ---- Case types and benefit amounts ------------------------------------

  Stream<List<WelfareCaseType>> watchCaseTypes() =>
      (_db.select(_db.welfareCaseTypes)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .watch();

  Future<List<WelfareCaseType>> activeCaseTypes() =>
      (_db.select(_db.welfareCaseTypes)
            ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.name),
            ]))
          .get();

  Future<WelfareCaseType> _caseType(String id) => (_db.select(
    _db.welfareCaseTypes,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<String> addCaseType(String name, WelfareActor by) async {
    final n = name.trim();
    if (n.isEmpty) throw WelfareException('Enter a name.');
    final row = await _db
        .into(_db.welfareCaseTypes)
        .insertReturning(
          WelfareCaseTypesCompanion.insert(
            name: n,
            sortOrder: const Value(100),
            createdBy: Value(by.actor.userId),
            deviceId: Value(by.actor.deviceId),
          ),
        );
    await _audit.log(
      by.actor,
      'welfare_type.create',
      entity: 'welfare_case_types',
      entityId: row.id,
      newValue: {'name': n},
    );
    return row.id;
  }

  /// The Treasurer proposes a new fixed amount. It applies to new cases
  /// only after approval.
  Future<void> proposeBenefit(
    String typeId,
    int amount,
    WelfareActor by,
  ) async {
    if (amount <= 0) throw WelfareException('Enter an amount above zero.');
    final t = await _caseType(typeId);
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareCaseTypes,
      )..where((r) => r.id.equals(typeId))).write(
        WelfareCaseTypesCompanion(
          proposedAmount: Value(amount),
          proposedBy: Value(by.actor.userId),
          proposedByName: Value(by.name),
          proposedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_benefit.propose',
        entity: 'welfare_case_types',
        entityId: typeId,
        oldValue: {'name': t.name, 'benefitAmount': t.benefitAmount},
        newValue: {'proposedAmount': amount},
      );
    });
  }

  Future<void> decideBenefit(
    String typeId,
    WelfareActor by, {
    required bool approve,
  }) async {
    final t = await _caseType(typeId);
    final proposed = t.proposedAmount;
    if (proposed == null) {
      throw WelfareException('There is no amount waiting for approval.');
    }
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareCaseTypes,
      )..where((r) => r.id.equals(typeId))).write(
        WelfareCaseTypesCompanion(
          benefitAmount: approve ? Value(proposed) : const Value.absent(),
          benefitApprovedBy: approve
              ? Value(by.actor.userId)
              : const Value.absent(),
          benefitApprovedByName: approve
              ? Value(by.name)
              : const Value.absent(),
          benefitApprovedAt: approve ? Value(_now()) : const Value.absent(),
          proposedAmount: const Value(null),
          proposedBy: const Value(null),
          proposedByName: const Value(null),
          proposedAt: const Value(null),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        approve ? 'welfare_benefit.approve' : 'welfare_benefit.reject',
        entity: 'welfare_case_types',
        entityId: typeId,
        oldValue: {'name': t.name, 'benefitAmount': t.benefitAmount},
        newValue: {
          'proposedAmount': proposed,
          'proposedBy': t.proposedByName,
          'decidedBy': by.name,
          'role': by.roleName,
        },
      );
    });
  }

  // ---- Cases --------------------------------------------------------------

  Future<WelfareCase> createCase(WelfareCaseDraft d, WelfareActor by) async {
    final type = await _caseType(d.caseTypeId);
    final fixed = type.benefitAmount;
    final amount = fixed ?? d.requestedAmount;
    if (amount == null || amount <= 0) {
      throw WelfareException('Enter the amount requested.');
    }
    if (d.occurredOn.isAfter(_now())) {
      throw WelfareException('The date cannot be in the future.');
    }
    return _db.transaction(() async {
      final org = await _db.select(_db.orgSettings).getSingle();
      final year = _now().year;
      final caseNo =
          'WEL-$year-${org.nextWelfareCaseNo.toString().padLeft(4, '0')}';
      await _db
          .update(_db.orgSettings)
          .write(
            OrgSettingsCompanion(
              nextWelfareCaseNo: Value(org.nextWelfareCaseNo + 1),
            ),
          );
      final c = await _db
          .into(_db.welfareCases)
          .insertReturning(
            WelfareCasesCompanion.insert(
              caseNo: caseNo,
              memberId: d.memberId,
              caseTypeId: d.caseTypeId,
              beneficiary: Value(_clean(d.beneficiary)),
              description: Value(_clean(d.description)),
              occurredOn: d.occurredOn,
              amount: amount,
              amountIsFixed: Value(fixed != null),
              preparedByName: by.name,
              createdBy: Value(by.actor.userId),
              deviceId: Value(by.actor.deviceId),
            ),
          );
      await _audit.log(
        by.actor,
        'welfare_case.create',
        entity: 'welfare_cases',
        entityId: c.id,
        newValue: {
          'caseNo': caseNo,
          'memberId': d.memberId,
          'type': type.name,
          'amount': amount,
        },
      );
      return c;
    });
  }

  Future<WelfareCase> _case(String id) =>
      (_db.select(_db.welfareCases)..where((c) => c.id.equals(id))).getSingle();

  Future<void> decideCase(
    String id,
    WelfareActor by, {
    required bool approve,
    String? note,
  }) async {
    final c = await _case(id);
    if (c.status != WelfareStatus.pending) {
      throw WelfareException('This case has already been decided.');
    }
    if (!approve && (note == null || note.trim().length < 3)) {
      throw WelfareException('Give a reason for rejecting.');
    }
    final status = approve ? WelfareStatus.approved : WelfareStatus.rejected;
    await _db.transaction(() async {
      await (_db.update(_db.welfareCases)..where((r) => r.id.equals(id))).write(
        WelfareCasesCompanion(
          status: Value(status),
          decidedBy: Value(by.actor.userId),
          decidedByName: Value(by.name),
          decidedByRole: Value(by.roleName),
          decidedAt: Value(_now()),
          decisionNote: Value(_clean(note)),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        approve ? 'welfare_case.approve' : 'welfare_case.reject',
        entity: 'welfare_cases',
        entityId: id,
        oldValue: {'caseNo': c.caseNo, 'status': c.status.name},
        newValue: {
          'status': status.name,
          'role': by.roleName,
          'note': _clean(note),
        },
      );
    });
  }

  Future<void> markPaid(
    String id,
    WelfareActor by, {
    required PaymentMethod method,
    required DateTime paidOn,
    String? reference,
  }) async {
    final c = await _case(id);
    if (c.status != WelfareStatus.approved) {
      throw WelfareException('Only approved cases can be paid.');
    }
    await _db.transaction(() async {
      await (_db.update(_db.welfareCases)..where((r) => r.id.equals(id))).write(
        WelfareCasesCompanion(
          status: const Value(WelfareStatus.paid),
          paidOn: Value(paidOn),
          payMethod: Value(method),
          payReference: Value(_clean(reference)),
          paidBy: Value(by.actor.userId),
          paidByName: Value(by.name),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_case.pay',
        entity: 'welfare_cases',
        entityId: id,
        newValue: {
          'caseNo': c.caseNo,
          'amount': c.amount,
          'method': method.name,
          'reference': _clean(reference),
        },
      );
    });
  }

  JoinedSelectStatement<HasResultSet, dynamic> _viewQuery() =>
      _db.select(_db.welfareCases).join([
        innerJoin(
          _db.welfareCaseTypes,
          _db.welfareCaseTypes.id.equalsExp(_db.welfareCases.caseTypeId),
        ),
        innerJoin(
          _db.members,
          _db.members.id.equalsExp(_db.welfareCases.memberId),
        ),
      ]);

  WelfareCaseView _toView(TypedResult r) => WelfareCaseView(
    r.readTable(_db.welfareCases),
    r.readTable(_db.welfareCaseTypes),
    r.readTable(_db.members),
  );

  /// Cases with [status], or all when null; newest first.
  Stream<List<WelfareCaseView>> watchCases({
    WelfareStatus? status,
    String? memberId,
  }) {
    final q = _viewQuery()
      ..orderBy([OrderingTerm.desc(_db.welfareCases.createdAt)]);
    if (status != null) {
      q.where(_db.welfareCases.status.equalsValue(status));
    }
    if (memberId != null) {
      q.where(_db.welfareCases.memberId.equals(memberId));
    }
    return q.watch().map((rows) => rows.map(_toView).toList());
  }

  Stream<WelfareCaseView?> watchCase(String id) {
    final q = _viewQuery()..where(_db.welfareCases.id.equals(id));
    return q.watchSingleOrNull().map((r) => r == null ? null : _toView(r));
  }

  Stream<WelfareSummary> watchSummary() => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.welfareCases,
          _db.welfareCaseTypes,
          _db.payments,
          _db.contributionTypes,
        },
      )
      .watch()
      .asyncMap((_) => summary());

  Future<WelfareSummary> summary() async {
    Future<int> count(WelfareStatus s) async {
      final n = _db.welfareCases.id.count();
      final row =
          await (_db.selectOnly(_db.welfareCases)
                ..addColumns([n])
                ..where(_db.welfareCases.status.equalsValue(s)))
              .getSingle();
      return row.read(n) ?? 0;
    }

    Future<int> paidSince(DateTime? from) async {
      final sum = _db.welfareCases.amount.sum();
      var where = _db.welfareCases.status.equalsValue(WelfareStatus.paid);
      if (from != null) {
        where = where & _db.welfareCases.paidOn.isBiggerOrEqualValue(from);
      }
      final row =
          await (_db.selectOnly(_db.welfareCases)
                ..addColumns([sum])
                ..where(where))
              .getSingle();
      return row.read(sum) ?? 0;
    }

    final collected = _db.payments.amount.sum();
    final collectedRow =
        await (_db.selectOnly(_db.payments).join([
                innerJoin(
                  _db.contributionTypes,
                  _db.contributionTypes.id.equalsExp(
                    _db.payments.contributionTypeId,
                  ),
                  useColumns: false,
                ),
              ])
              ..addColumns([collected])
              ..where(
                _db.payments.status.equalsValue(PaymentStatus.valid) &
                    _db.contributionTypes.category.equalsValue(
                      ContributionCategory.welfare,
                    ),
              ))
            .getSingle();

    final pendingTypes = _db.welfareCaseTypes.id.count();
    final pendingTypesRow =
        await (_db.selectOnly(_db.welfareCaseTypes)
              ..addColumns([pendingTypes])
              ..where(
                _db.welfareCaseTypes.proposedAmount.isNotNull() &
                    _db.welfareCaseTypes.deletedAt.isNull(),
              ))
            .getSingle();

    final now = _now();
    return WelfareSummary(
      pendingCases: await count(WelfareStatus.pending),
      approvedUnpaid: await count(WelfareStatus.approved),
      pendingBenefitChanges: pendingTypesRow.read(pendingTypes) ?? 0,
      fundCollected: collectedRow.read(collected) ?? 0,
      fundPaidOut: await paidSince(null),
      paidThisMonth: await paidSince(DateTime(now.year, now.month)),
    );
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
