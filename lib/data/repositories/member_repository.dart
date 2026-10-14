import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../domain/zone_rules.dart';
import '../database.dart';
import 'actor.dart';
import 'audit_repository.dart';

/// Editable member fields, used by the registration and edit forms.
class MemberDraft {
  MemberDraft({
    required this.fullName,
    this.gender,
    this.dateOfBirth,
    this.nationality,
    this.occupation,
    this.maritalStatus,
    this.location,
    this.phone,
    this.whatsapp,
    this.email,
    this.address,
    this.gpsAddress,
    this.emergencyName,
    this.emergencyPhone,
    required this.dateJoined,
    this.photoPath,
    required this.zoneIds,
    this.primaryZoneId,
  });

  factory MemberDraft.fromMember(
    Member m,
    List<String> zoneIds, {
    String? primaryZoneId,
  }) {
    return MemberDraft(
      fullName: m.fullName,
      gender: m.gender,
      dateOfBirth: m.dateOfBirth,
      nationality: m.nationality,
      occupation: m.occupation,
      maritalStatus: m.maritalStatus,
      location: m.location,
      phone: m.phone,
      whatsapp: m.whatsapp,
      email: m.email,
      address: m.address,
      gpsAddress: m.gpsAddress,
      emergencyName: m.emergencyName,
      emergencyPhone: m.emergencyPhone,
      dateJoined: m.dateJoined,
      photoPath: m.photoPath,
      zoneIds: zoneIds,
      primaryZoneId: primaryZoneId,
    );
  }

  String fullName;
  String? gender;
  DateTime? dateOfBirth;
  String? nationality;
  String? occupation;
  String? maritalStatus;
  String? location;
  String? phone;
  String? whatsapp;
  String? email;
  String? address;
  String? gpsAddress;
  String? emergencyName;
  String? emergencyPhone;
  DateTime dateJoined;
  String? photoPath;
  List<String> zoneIds;
  String? primaryZoneId;

  MembersCompanion _companion() => MembersCompanion(
    fullName: Value(fullName.trim()),
    gender: Value(_clean(gender)),
    dateOfBirth: Value(dateOfBirth),
    nationality: Value(_clean(nationality)),
    occupation: Value(_clean(occupation)),
    maritalStatus: Value(_clean(maritalStatus)),
    location: Value(_clean(location)),
    phone: Value(_clean(phone)),
    whatsapp: Value(_clean(whatsapp)),
    email: Value(_clean(email)),
    address: Value(_clean(address)),
    gpsAddress: Value(_clean(gpsAddress)),
    emergencyName: Value(_clean(emergencyName)),
    emergencyPhone: Value(_clean(emergencyPhone)),
    dateJoined: Value(dateJoined),
    photoPath: Value(photoPath),
  );

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}

/// A member with their current zone assignments.
class MemberWithZones {
  const MemberWithZones(this.member, this.zones, {this.primaryZoneId});
  final Member member;
  final List<Zone> zones;
  final String? primaryZoneId;

  String get zoneLabel => zones.map(zoneDisplayName).join(', ');
}

String zoneDisplayName(Zone z) =>
    z.nickname == null ? z.name : '${z.name} (${z.nickname})';

class MemberFilter {
  const MemberFilter({this.query = '', this.zoneId, this.status});
  final String query;
  final String? zoneId;
  final MemberStatus? status;
}

class MemberRepository {
  MemberRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  Stream<List<Zone>> watchZones() =>
      (_db.select(_db.zones)
            ..where((z) => z.deletedAt.isNull())
            ..orderBy([(z) => OrderingTerm.asc(z.sortOrder)]))
          .watch();

  Future<List<Zone>> zones() =>
      (_db.select(_db.zones)
            ..where((z) => z.deletedAt.isNull())
            ..orderBy([(z) => OrderingTerm.asc(z.sortOrder)]))
          .get();

  /// Members matching [filter], newest first by member number.
  /// Searches name, phone, WhatsApp and member ID.
  Stream<List<MemberWithZones>> watchMembers(MemberFilter filter) {
    final q = _db.select(_db.members)..where((m) => m.deletedAt.isNull());
    final text = filter.query.trim();
    if (text.isNotEmpty) {
      final like = '%${text.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
      q.where(
        (m) =>
            m.fullName.like(like, escapeChar: r'\') |
            m.memberNo.like(like, escapeChar: r'\') |
            m.phone.like(like, escapeChar: r'\') |
            m.whatsapp.like(like, escapeChar: r'\'),
      );
    }
    if (filter.status != null) {
      q.where((m) => m.status.equalsValue(filter.status));
    }
    if (filter.zoneId != null) {
      q.where(
        (m) => existsQuery(
          _db.select(_db.memberZones)..where(
            (mz) =>
                mz.memberId.equalsExp(m.id) &
                mz.zoneId.equals(filter.zoneId!) &
                mz.deletedAt.isNull(),
          ),
        ),
      );
    }
    q.orderBy([(m) => OrderingTerm.asc(m.fullName)]);
    return q.watch().asyncMap(_withZones);
  }

  Future<List<MemberWithZones>> _withZones(List<Member> members) async {
    if (members.isEmpty) return const [];
    final ids = members.map((m) => m.id).toList();
    final rows =
        await (_db.select(_db.memberZones).join([
              innerJoin(
                _db.zones,
                _db.zones.id.equalsExp(_db.memberZones.zoneId),
              ),
            ])..where(
              _db.memberZones.memberId.isIn(ids) &
                  _db.memberZones.deletedAt.isNull(),
            ))
            .get();
    final byMember = <String, List<(MemberZone, Zone)>>{};
    for (final r in rows) {
      final mz = r.readTable(_db.memberZones);
      byMember.putIfAbsent(mz.memberId, () => []).add((
        mz,
        r.readTable(_db.zones),
      ));
    }
    return [
      for (final m in members)
        () {
          final links = (byMember[m.id] ?? [])
            ..sort((a, b) => a.$2.sortOrder.compareTo(b.$2.sortOrder));
          return MemberWithZones(
            m,
            links.map((l) => l.$2).toList(),
            primaryZoneId: links
                .where((l) => l.$1.isPrimary)
                .map((l) => l.$2.id)
                .firstOrNull,
          );
        }(),
    ];
  }

  Stream<MemberWithZones?> watchMember(String id) {
    final memberStream = (_db.select(
      _db.members,
    )..where((m) => m.id.equals(id))).watchSingleOrNull();
    return memberStream.asyncMap((m) async {
      if (m == null) return null;
      return (await _withZones([m])).single;
    });
  }

  Future<MemberWithZones?> getMember(String id) async {
    final m = await (_db.select(
      _db.members,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
    if (m == null) return null;
    return (await _withZones([m])).single;
  }

  Future<String?> _validate(
    MemberDraft d, {
    Set<String> current = const {},
  }) async {
    if (d.fullName.trim().isEmpty) return 'Enter the member\'s full name.';
    final active = (await zones())
        .where((z) => z.isActive)
        .map((z) => z.id)
        .toSet();
    return ZoneRules.validate(
      d.zoneIds,
      activeZoneIds: active,
      alreadyAssigned: current,
    );
  }

  /// Registers a member, allocating the next member ID in the same
  /// transaction. Throws [ZoneRuleException] when the draft is invalid.
  Future<Member> create(MemberDraft draft, Actor actor) async {
    final error = await _validate(draft);
    if (error != null) throw ZoneRuleException(error);

    return _db.transaction(() async {
      final org = await _db.select(_db.orgSettings).getSingle();
      final memberNo = formatMemberNo(org.memberIdPrefix, org.nextMemberNo);
      await _db
          .update(_db.orgSettings)
          .write(
            OrgSettingsCompanion(nextMemberNo: Value(org.nextMemberNo + 1)),
          );

      final member = await _db
          .into(_db.members)
          .insertReturning(
            draft._companion().copyWith(
              memberNo: Value(memberNo),
              createdBy: Value(actor.userId),
              deviceId: Value(actor.deviceId),
            ),
          );
      await _setZones(member.id, draft, actor, const {});
      await _audit.log(
        actor,
        'member.create',
        entity: 'members',
        entityId: member.id,
        newValue: _snapshot(member, draft.zoneIds),
      );
      return member;
    });
  }

  Future<void> update(String memberId, MemberDraft draft, Actor actor) async {
    final before = await getMember(memberId);
    if (before == null) throw StateError('Member not found');
    final current = before.zones.map((z) => z.id).toSet();
    final error = await _validate(draft, current: current);
    if (error != null) throw ZoneRuleException(error);

    await _db.transaction(() async {
      await (_db.update(_db.members)..where((m) => m.id.equals(memberId)))
          .write(draft._companion().copyWith(updatedAt: Value(_now())));
      await _setZones(memberId, draft, actor, current);
      final after = await (_db.select(
        _db.members,
      )..where((m) => m.id.equals(memberId))).getSingle();
      await _audit.log(
        actor,
        'member.update',
        entity: 'members',
        entityId: memberId,
        oldValue: _snapshot(before.member, current.toList()),
        newValue: _snapshot(after, draft.zoneIds),
      );
    });
  }

  Future<void> changeStatus(
    String memberId,
    MemberStatus status,
    Actor actor, {
    String? reason,
  }) async {
    final before = await (_db.select(
      _db.members,
    )..where((m) => m.id.equals(memberId))).getSingle();
    if (before.status == status) return;
    await _db.transaction(() async {
      await (_db.update(
        _db.members,
      )..where((m) => m.id.equals(memberId))).write(
        MembersCompanion(
          status: Value(status),
          statusDate: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        actor,
        'member.status',
        entity: 'members',
        entityId: memberId,
        oldValue: {'status': before.status.name},
        newValue: {'status': status.name, 'reason': ?reason},
      );
    });
  }

  /// Applies the draft's zone list. Removals happen before additions so the
  /// two-zone database guard never sees three live rows during a swap.
  Future<void> _setZones(
    String memberId,
    MemberDraft draft,
    Actor actor,
    Set<String> current,
  ) async {
    final wanted = draft.zoneIds.toSet();
    final primary =
        draft.primaryZoneId != null && wanted.contains(draft.primaryZoneId)
        ? draft.primaryZoneId
        : draft.zoneIds.first;
    final now = _now();

    final removed = current.difference(wanted);
    if (removed.isNotEmpty) {
      await (_db.update(_db.memberZones)..where(
            (mz) =>
                mz.memberId.equals(memberId) &
                mz.zoneId.isIn(removed) &
                mz.deletedAt.isNull(),
          ))
          .write(
            MemberZonesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
    }

    for (final zoneId in wanted.difference(current)) {
      final existing =
          await (_db.select(_db.memberZones)..where(
                (mz) => mz.memberId.equals(memberId) & mz.zoneId.equals(zoneId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        await (_db.update(
          _db.memberZones,
        )..where((mz) => mz.id.equals(existing.id))).write(
          MemberZonesCompanion(
            deletedAt: const Value(null),
            assignedOn: Value(now),
            updatedAt: Value(now),
          ),
        );
      } else {
        await _db
            .into(_db.memberZones)
            .insert(
              MemberZonesCompanion.insert(
                memberId: memberId,
                zoneId: zoneId,
                createdBy: Value(actor.userId),
                deviceId: Value(actor.deviceId),
              ),
            );
      }
    }

    for (final zoneId in wanted) {
      await (_db.update(_db.memberZones)..where(
            (mz) =>
                mz.memberId.equals(memberId) &
                mz.zoneId.equals(zoneId) &
                mz.deletedAt.isNull(),
          ))
          .write(MemberZonesCompanion(isPrimary: Value(zoneId == primary)));
    }
  }

  Map<String, Object?> _snapshot(Member m, List<String> zoneIds) => {
    ...m.toJson()..removeWhere((k, _) => k == 'createdAt' || k == 'updatedAt'),
    'zoneIds': zoneIds,
  };
}
