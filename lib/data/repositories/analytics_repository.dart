import 'package:drift/drift.dart';

import '../access_scope.dart';
import '../database.dart';

/// One bar or point: a label and a value (money in pesewas or a count).
class ChartPoint {
  const ChartPoint(this.label, this.value);
  final String label;
  final int value;
}

class Analytics {
  const Analytics({
    required this.monthlyCollections,
    required this.zoneCollections,
    required this.welfareCases,
    required this.welfarePayouts,
    required this.memberTotals,
    required this.newMembers,
  });

  /// Last 12 months, oldest first.
  final List<ChartPoint> monthlyCollections;

  /// This year's collections by the payer's primary zone.
  final List<ChartPoint> zoneCollections;

  /// Last 12 months: cases reported and money paid out.
  final List<ChartPoint> welfareCases;
  final List<ChartPoint> welfarePayouts;

  /// Last 12 months: members at the end of each month, and joiners.
  final List<ChartPoint> memberTotals;
  final List<ChartPoint> newMembers;
}

/// Figures for the charts screen. Respects zone-only access.
class AnalyticsRepository {
  AnalyticsRepository(
    this._db, {
    DateTime Function()? clock,
    AccessScope? scope,
  }) : _now = clock ?? DateTime.now,
       _scope = scope ?? AccessScope();

  final AppDatabase _db;
  final DateTime Function() _now;
  final AccessScope _scope;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  Future<Analytics> load() async {
    final now = _now();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final from = months.first;
    int index(DateTime d) => (d.year - from.year) * 12 + d.month - from.month;
    String label(DateTime m) => _months[m.month - 1];

    // Collections per month.
    final payments =
        await (_db.select(_db.payments)..where(
              (p) =>
                  p.status.equalsValue(PaymentStatus.valid) &
                  p.paidOn.isBiggerOrEqualValue(from) &
                  _scope.member(_db, p.memberId),
            ))
            .get();
    final perMonth = List<int>.filled(12, 0);
    for (final p in payments) {
      final i = index(p.paidOn);
      if (i >= 0 && i < 12) perMonth[i] += p.amount;
    }

    // Collections by primary zone this year.
    final zoneRows = await _db
        .customSelect(
          'SELECT mz.zone_id AS zone_id, SUM(p.amount) AS total '
          'FROM payments p '
          'JOIN member_zones mz ON mz.member_id = p.member_id '
          '  AND mz.deleted_at IS NULL AND mz.is_primary = 1 '
          "WHERE p.status = 'valid' AND p.paid_on >= ? "
          'GROUP BY mz.zone_id',
          variables: [Variable.withDateTime(DateTime(now.year))],
          readsFrom: {_db.payments, _db.memberZones},
        )
        .get();
    final byZone = {
      for (final r in zoneRows)
        r.read<String>('zone_id'): r.read<int?>('total') ?? 0,
    };
    final zones =
        await (_db.select(_db.zones)
              ..where((z) => z.deletedAt.isNull() & z.isActive.equals(true))
              ..orderBy([(z) => OrderingTerm.asc(z.sortOrder)]))
            .get();

    // Welfare cases reported and paid out.
    final cases =
        await (_db.select(_db.welfareCases)..where(
              (c) => c.deletedAt.isNull() & _scope.member(_db, c.memberId),
            ))
            .get();
    final casesPerMonth = List<int>.filled(12, 0);
    final payoutsPerMonth = List<int>.filled(12, 0);
    for (final c in cases) {
      final i = index(c.createdAt);
      if (i >= 0 && i < 12) casesPerMonth[i]++;
      if (c.status == WelfareStatus.paid && c.paidOn != null) {
        final j = index(c.paidOn!);
        if (j >= 0 && j < 12) payoutsPerMonth[j] += c.amount;
      }
    }

    // Membership growth (deceased and inactive members still count as
    // having joined; the line shows everyone registered).
    final members = await (_db.select(
      _db.members,
    )..where((m) => m.deletedAt.isNull() & _scope.member(_db, m.id))).get();
    final joined = List<int>.filled(12, 0);
    var before = 0;
    for (final m in members) {
      final i = index(m.dateJoined);
      if (i < 0) {
        before++;
      } else if (i < 12) {
        joined[i]++;
      }
    }
    var running = before;
    final totals = <int>[];
    for (final n in joined) {
      running += n;
      totals.add(running);
    }

    return Analytics(
      monthlyCollections: [
        for (var i = 0; i < 12; i++) ChartPoint(label(months[i]), perMonth[i]),
      ],
      zoneCollections: [
        for (final z in zones)
          if (_scope.allowsZone(z.id))
            ChartPoint('Z${z.code}', byZone[z.id] ?? 0),
      ],
      welfareCases: [
        for (var i = 0; i < 12; i++)
          ChartPoint(label(months[i]), casesPerMonth[i]),
      ],
      welfarePayouts: [
        for (var i = 0; i < 12; i++)
          ChartPoint(label(months[i]), payoutsPerMonth[i]),
      ],
      memberTotals: [
        for (var i = 0; i < 12; i++) ChartPoint(label(months[i]), totals[i]),
      ],
      newMembers: [
        for (var i = 0; i < 12; i++) ChartPoint(label(months[i]), joined[i]),
      ],
    );
  }
}
