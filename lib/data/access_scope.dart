import 'package:drift/drift.dart';

import 'database.dart';

/// What the signed-in user may see. Zone leaders are limited to the
/// members of their own zone(s); everyone else sees the whole association.
///
/// One instance is shared by the repositories and updated on sign-in.
class AccessScope {
  AccessScope([this.zoneIds]);

  /// Null for no limit; otherwise the zones the user may see.
  Set<String>? zoneIds;

  bool get limited => zoneIds != null;

  bool allowsZone(String zoneId) => zoneIds?.contains(zoneId) ?? true;

  /// True when [memberId] belongs to one of the allowed zones. Anonymous
  /// (null) members are only visible without a limit.
  Expression<bool> member(AppDatabase db, Expression<String> memberId) {
    final zones = zoneIds;
    if (zones == null) return const Constant(true);
    final mz = db.alias(db.memberZones, 'scope_mz');
    return existsQuery(
      db.select(mz)..where(
        (t) =>
            t.memberId.equalsExp(memberId) &
            t.zoneId.isIn(zones) &
            t.deletedAt.isNull(),
      ),
    );
  }

  /// Plain-Dart check for lists already loaded.
  bool allowsMemberZones(Iterable<String> memberZoneIds) =>
      zoneIds == null || memberZoneIds.any(zoneIds!.contains);
}
