import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../database.dart';
import 'actor.dart';
import 'audit_repository.dart';

class FinanceException implements Exception {
  FinanceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExpenseDraft {
  ExpenseDraft({
    required this.categoryId,
    required this.amount,
    required this.description,
    required this.method,
    required this.paidOn,
    this.paidTo,
    this.reference,
    this.eventId,
  });

  final String categoryId;
  final int amount;
  final String description;
  final PaymentMethod method;
  final DateTime paidOn;
  final String? paidTo;
  final String? reference;
  final String? eventId;
}

class ExpenseView {
  const ExpenseView(this.expense, this.category);
  final Expense expense;
  final ExpenseCategory category;
}

/// A reporting window: [from] inclusive, [to] exclusive.
enum ReportPeriod {
  day('Daily'),
  week('Weekly'),
  month('Monthly'),
  year('Annual');

  const ReportPeriod(this.label);
  final String label;

  (DateTime, DateTime) rangeFor(DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    return switch (this) {
      ReportPeriod.day => (d, d.add(const Duration(days: 1))),
      ReportPeriod.week => () {
        final start = d.subtract(Duration(days: d.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      }(),
      ReportPeriod.month => (
        DateTime(d.year, d.month),
        DateTime(d.year, d.month + 1),
      ),
      ReportPeriod.year => (DateTime(d.year), DateTime(d.year + 1)),
    };
  }
}

class ReportLine {
  const ReportLine(this.label, this.amount, this.count);
  final String label;
  final int amount;
  final int count;
}

/// One money movement in a report.
class FinanceTxn {
  const FinanceTxn({
    required this.date,
    required this.ref,
    required this.description,
    required this.party,
    required this.method,
    this.income = 0,
    this.expense = 0,
  });

  final DateTime date;
  final String ref;
  final String description;
  final String party;
  final String method;
  final int income;
  final int expense;
}

class FinanceReport {
  const FinanceReport({
    required this.title,
    required this.from,
    required this.to,
    required this.opening,
    required this.incomeByType,
    required this.incomeByCategory,
    required this.incomeByMethod,
    required this.incomeByZone,
    required this.expenseByCategory,
    required this.transactions,
  });

  final String title;
  final DateTime from;

  /// Exclusive.
  final DateTime to;

  /// Cash position before [from]: all valid income minus all spending.
  final int opening;
  final List<ReportLine> incomeByType;
  final List<ReportLine> incomeByCategory;
  final List<ReportLine> incomeByMethod;
  final List<ReportLine> incomeByZone;
  final List<ReportLine> expenseByCategory;
  final List<FinanceTxn> transactions;

  int get totalIncome => transactions.fold(0, (a, t) => a + t.income);
  int get totalExpense => transactions.fold(0, (a, t) => a + t.expense);
  int get net => totalIncome - totalExpense;
  int get closing => opening + net;
}

class FinanceRepository {
  FinanceRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  // ---- Expenses ------------------------------------------------------------

  Stream<List<ExpenseCategory>> watchCategories() =>
      (_db.select(_db.expenseCategories)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .watch();

  Future<List<ExpenseCategory>> activeCategories() =>
      (_db.select(_db.expenseCategories)
            ..where((c) => c.deletedAt.isNull() & c.isActive.equals(true))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();

  Future<void> addCategory(String name, Actor actor) async {
    final n = name.trim();
    if (n.isEmpty) throw FinanceException('Enter a name.');
    final row = await _db
        .into(_db.expenseCategories)
        .insertReturning(
          ExpenseCategoriesCompanion.insert(
            name: n,
            sortOrder: const Value(100),
            createdBy: Value(actor.userId),
            deviceId: Value(actor.deviceId),
          ),
        );
    await _audit.log(
      actor,
      'expense_category.create',
      entity: 'expense_categories',
      entityId: row.id,
      newValue: {'name': n},
    );
  }

  Future<Expense> recordExpense(
    ExpenseDraft d,
    Actor actor, {
    required String recordedByName,
  }) async {
    if (d.amount <= 0) throw FinanceException('Enter an amount above zero.');
    if (d.description.trim().isEmpty) {
      throw FinanceException('Say what the money was spent on.');
    }
    return _db.transaction(() async {
      final org = await _db.select(_db.orgSettings).getSingle();
      final (voucherNo, next) = await _db.allocateNumber(
        'expenses',
        'voucher_no',
        org.nextExpenseNo,
        (n) =>
            '${withSeries('EXP', org.deviceSeries)}-${d.paidOn.year}-'
            '${n.toString().padLeft(6, '0')}',
      );
      await _db
          .update(_db.orgSettings)
          .write(OrgSettingsCompanion(nextExpenseNo: Value(next)));
      final e = await _db
          .into(_db.expenses)
          .insertReturning(
            ExpensesCompanion.insert(
              voucherNo: voucherNo,
              categoryId: d.categoryId,
              amount: d.amount,
              description: d.description.trim(),
              paidTo: Value(_clean(d.paidTo)),
              paidOn: d.paidOn,
              method: d.method,
              reference: Value(_clean(d.reference)),
              recordedByName: recordedByName,
              eventId: Value(d.eventId),
              createdBy: Value(actor.userId),
              deviceId: Value(actor.deviceId),
            ),
          );
      await _audit.log(
        actor,
        'expense.record',
        entity: 'expenses',
        entityId: e.id,
        newValue: {
          'voucherNo': voucherNo,
          'amount': d.amount,
          'description': d.description.trim(),
        },
      );
      return e;
    });
  }

  Future<void> voidExpense(String id, String reason, Actor actor) async {
    if (reason.trim().length < 3) {
      throw FinanceException('Give a reason for voiding.');
    }
    final e = await (_db.select(
      _db.expenses,
    )..where((t) => t.id.equals(id))).getSingle();
    if (e.status == PaymentStatus.voided) return;
    await _db.transaction(() async {
      await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
        ExpensesCompanion(
          status: const Value(PaymentStatus.voided),
          voidReason: Value(reason.trim()),
          voidedBy: Value(actor.userId),
          voidedAt: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        actor,
        'expense.void',
        entity: 'expenses',
        entityId: id,
        oldValue: {'voucherNo': e.voucherNo, 'amount': e.amount},
        newValue: {'reason': reason.trim()},
      );
    });
  }

  Stream<List<ExpenseView>> watchExpenses({String? eventId, int limit = 200}) {
    final q =
        _db.select(_db.expenses).join([
            innerJoin(
              _db.expenseCategories,
              _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
            ),
          ])
          ..orderBy([
            OrderingTerm.desc(_db.expenses.paidOn),
            OrderingTerm.desc(_db.expenses.createdAt),
          ])
          ..limit(limit);
    if (eventId != null) q.where(_db.expenses.eventId.equals(eventId));
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          ExpenseView(
            r.readTable(_db.expenses),
            r.readTable(_db.expenseCategories),
          ),
      ],
    );
  }

  // ---- Reports -------------------------------------------------------------

  Future<FinanceReport> report(
    DateTime from,
    DateTime to, {
    required String title,
  }) async {
    final payments = await (_db.select(_db.payments).join([
      innerJoin(
        _db.contributionTypes,
        _db.contributionTypes.id.equalsExp(_db.payments.contributionTypeId),
      ),
      leftOuterJoin(
        _db.members,
        _db.members.id.equalsExp(_db.payments.memberId),
      ),
    ])..where(_db.payments.status.equalsValue(PaymentStatus.valid))).get();
    final expenses = await (_db.select(_db.expenses).join([
      innerJoin(
        _db.expenseCategories,
        _db.expenseCategories.id.equalsExp(_db.expenses.categoryId),
      ),
    ])..where(_db.expenses.status.equalsValue(PaymentStatus.valid))).get();
    final payouts = await (_db.select(_db.welfareCases).join([
      innerJoin(
        _db.welfareCaseTypes,
        _db.welfareCaseTypes.id.equalsExp(_db.welfareCases.caseTypeId),
      ),
      innerJoin(
        _db.members,
        _db.members.id.equalsExp(_db.welfareCases.memberId),
      ),
    ])..where(_db.welfareCases.status.equalsValue(WelfareStatus.paid))).get();
    final zoneOf = await _primaryZoneNames();

    bool inRange(DateTime d) => !d.isBefore(from) && d.isBefore(to);
    var opening = 0;
    final txns = <FinanceTxn>[];
    final byType = <String, (int, int)>{};
    final byCategory = <String, (int, int)>{};
    final byMethod = <String, (int, int)>{};
    final byZone = <String, (int, int)>{};
    final outByCategory = <String, (int, int)>{};
    void add(Map<String, (int, int)> m, String k, int amount) {
      final (a, c) = m[k] ?? (0, 0);
      m[k] = (a + amount, c + 1);
    }

    for (final r in payments) {
      final p = r.readTable(_db.payments);
      if (p.paidOn.isBefore(from)) opening += p.amount;
      if (!inRange(p.paidOn)) continue;
      final t = r.readTable(_db.contributionTypes);
      final m = r.readTableOrNull(_db.members);
      add(byType, t.name, p.amount);
      add(byCategory, t.category.label, p.amount);
      add(byMethod, p.method.label, p.amount);
      add(
        byZone,
        m == null ? 'No member' : (zoneOf[m.id] ?? 'No zone'),
        p.amount,
      );
      txns.add(
        FinanceTxn(
          date: p.paidOn,
          ref: p.receiptNo,
          description: p.period == null ? t.name : '${t.name} ${p.period}',
          party: m?.fullName ?? 'Anonymous',
          method: p.method.label,
          income: p.amount,
        ),
      );
    }
    for (final r in expenses) {
      final e = r.readTable(_db.expenses);
      if (e.paidOn.isBefore(from)) opening -= e.amount;
      if (!inRange(e.paidOn)) continue;
      final c = r.readTable(_db.expenseCategories);
      add(outByCategory, c.name, e.amount);
      txns.add(
        FinanceTxn(
          date: e.paidOn,
          ref: e.voucherNo,
          description: '${c.name}: ${e.description}',
          party: e.paidTo ?? '',
          method: e.method.label,
          expense: e.amount,
        ),
      );
    }
    for (final r in payouts) {
      final w = r.readTable(_db.welfareCases);
      final paidOn = w.paidOn!;
      if (paidOn.isBefore(from)) opening -= w.amount;
      if (!inRange(paidOn)) continue;
      final t = r.readTable(_db.welfareCaseTypes);
      add(outByCategory, 'Welfare payouts', w.amount);
      txns.add(
        FinanceTxn(
          date: paidOn,
          ref: w.caseNo,
          description: 'Welfare: ${t.name}',
          party: r.readTable(_db.members).fullName,
          method: w.payMethod?.label ?? '',
          expense: w.amount,
        ),
      );
    }
    txns.sort((a, b) => a.date.compareTo(b.date));
    List<ReportLine> lines(Map<String, (int, int)> m) => [
      for (final MapEntry(:key, :value) in m.entries)
        ReportLine(key, value.$1, value.$2),
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    return FinanceReport(
      title: title,
      from: from,
      to: to,
      opening: opening,
      incomeByType: lines(byType),
      incomeByCategory: lines(byCategory),
      incomeByMethod: lines(byMethod),
      incomeByZone: lines(byZone),
      expenseByCategory: lines(outByCategory),
      transactions: txns,
    );
  }

  /// Member id -> the zone their money is reported under (primary zone, or
  /// their only zone).
  Future<Map<String, String>> _primaryZoneNames() async {
    final rows = await (_db.select(_db.memberZones).join([
      innerJoin(_db.zones, _db.zones.id.equalsExp(_db.memberZones.zoneId)),
    ])..where(_db.memberZones.deletedAt.isNull())).get();
    final out = <String, String>{};
    for (final r in rows) {
      final mz = r.readTable(_db.memberZones);
      final z = r.readTable(_db.zones);
      if (mz.isPrimary || !out.containsKey(mz.memberId)) {
        out[mz.memberId] = z.name;
      }
    }
    return out;
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
