import 'package:drift/drift.dart';

import '../database.dart';

class ZoneCount {
  const ZoneCount(this.zone, this.members);
  final Zone zone;
  final int members;
}

class DashboardStats {
  const DashboardStats({
    required this.byStatus,
    required this.byZone,
    required this.recent,
  });

  final Map<MemberStatus, int> byStatus;
  final List<ZoneCount> byZone;
  final List<Member> recent;

  int get total => byStatus.values.fold(0, (a, b) => a + b);
  int count(MemberStatus s) => byStatus[s] ?? 0;
}

class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  /// Live member statistics. Re-emits whenever members or zones change.
  Stream<DashboardStats> watchStats() {
    final trigger = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.members, _db.memberZones, _db.zones},
        )
        .watch();
    return trigger.asyncMap((_) => _load());
  }

  Future<DashboardStats> _load() async {
    final count = _db.members.id.count();
    final statusRows =
        await (_db.selectOnly(_db.members)
              ..addColumns([_db.members.status, count])
              ..where(_db.members.deletedAt.isNull())
              ..groupBy([_db.members.status]))
            .get();
    final byStatus = <MemberStatus, int>{
      for (final r in statusRows)
        $MembersTable.$converterstatus.fromSql(r.read(_db.members.status)!):
            r.read(count) ?? 0,
    };

    final zoneRows = await _db
        .customSelect(
          'SELECT z.id AS zone_id, COUNT(m.id) AS n '
          'FROM zones z '
          'LEFT JOIN member_zones mz '
          '  ON mz.zone_id = z.id AND mz.deleted_at IS NULL '
          'LEFT JOIN members m '
          '  ON m.id = mz.member_id AND m.deleted_at IS NULL '
          "  AND m.status = 'active' "
          'WHERE z.deleted_at IS NULL '
          'GROUP BY z.id',
          readsFrom: {_db.zones, _db.memberZones, _db.members},
        )
        .get();
    final counts = {
      for (final r in zoneRows) r.read<String>('zone_id'): r.read<int>('n'),
    };
    final zones =
        await (_db.select(_db.zones)
              ..where((z) => z.deletedAt.isNull())
              ..orderBy([(z) => OrderingTerm.asc(z.sortOrder)]))
            .get();

    final recent =
        await (_db.select(_db.members)
              ..where((m) => m.deletedAt.isNull())
              ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
              ..limit(5))
            .get();

    return DashboardStats(
      byStatus: byStatus,
      byZone: [for (final z in zones) ZoneCount(z, counts[z.id] ?? 0)],
      recent: recent,
    );
  }
}
