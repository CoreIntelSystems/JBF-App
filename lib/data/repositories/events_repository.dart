import 'package:drift/drift.dart';

import '../../domain/member_qr.dart';
import '../database.dart';
import 'actor.dart';
import 'audit_repository.dart';

class EventsException implements Exception {
  EventsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class EventDraft {
  EventDraft({
    required this.name,
    required this.kind,
    required this.startsOn,
    this.venue,
    this.description,
    this.budget,
    this.transportNotes,
    this.accommodationNotes,
  });

  final String name;
  final EventKind kind;
  final DateTime startsOn;
  final String? venue;
  final String? description;
  final int? budget;
  final String? transportNotes;
  final String? accommodationNotes;
}

class MeetingDraft {
  MeetingDraft({
    required this.title,
    required this.kind,
    required this.heldOn,
    this.zoneId,
    this.venue,
    this.agenda,
  });

  final String title;
  final MeetingKind kind;
  final DateTime heldOn;
  final String? zoneId;
  final String? venue;
  final String? agenda;
}

/// Money in and out for one event.
class EventMoney {
  const EventMoney({
    required this.collected,
    required this.collections,
    required this.spent,
    required this.expenses,
  });

  final int collected;
  final int collections;
  final int spent;
  final int expenses;
  int get balance => collected - spent;
}

class AttendanceEntry {
  const AttendanceEntry(this.record, this.member);
  final AttendanceRecord record;
  final Member member;
}

class AttendanceCounts {
  const AttendanceCounts(this.present, this.absent, this.excused);
  final int present;
  final int absent;
  final int excused;
}

class ExecutiveView {
  const ExecutiveView(this.executive, this.member, this.position, this.zone);
  final Executive executive;
  final Member member;
  final ExecutivePosition position;
  final Zone? zone;

  bool get isCurrent => executive.endedOn == null;

  String get title => zone == null
      ? position.title
      : '${position.title}, ${zone!.nickname ?? zone!.name}';
}

/// Events, meetings, attendance and the executive.
class EventsRepository {
  EventsRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  static String? _clean(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  // ---- Events --------------------------------------------------------------

  Stream<List<Event>> watchEvents() =>
      (_db.select(_db.events)
            ..where((e) => e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.startsOn)]))
          .watch();

  Stream<Event> watchEvent(String id) =>
      (_db.select(_db.events)..where((e) => e.id.equals(id))).watchSingle();

  Future<Event> saveEvent(EventDraft d, Actor actor, {String? id}) async {
    final name = d.name.trim();
    if (name.isEmpty) throw EventsException('Enter the event name.');
    if ((d.budget ?? 0) < 0) {
      throw EventsException('Budget cannot be negative.');
    }
    final data = EventsCompanion(
      name: Value(name),
      kind: Value(d.kind),
      startsOn: Value(d.startsOn),
      venue: Value(_clean(d.venue)),
      description: Value(_clean(d.description)),
      budget: Value(d.budget),
      transportNotes: Value(_clean(d.transportNotes)),
      accommodationNotes: Value(_clean(d.accommodationNotes)),
      updatedAt: Value(_now()),
    );
    return _db.transaction(() async {
      final Event e;
      if (id == null) {
        e = await _db
            .into(_db.events)
            .insertReturning(
              data.copyWith(
                createdBy: Value(actor.userId),
                deviceId: Value(actor.deviceId),
              ),
            );
      } else {
        await (_db.update(
          _db.events,
        )..where((t) => t.id.equals(id))).write(data);
        e = await (_db.select(
          _db.events,
        )..where((t) => t.id.equals(id))).getSingle();
      }
      await _audit.log(
        actor,
        id == null ? 'event.create' : 'event.update',
        entity: 'events',
        entityId: e.id,
        newValue: {
          'name': name,
          'startsOn': d.startsOn.toIso8601String(),
          'budget': d.budget,
        },
      );
      return e;
    });
  }

  Future<void> setEventStatus(String id, EventStatus s, Actor actor) =>
      _db.transaction(() async {
        await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
          EventsCompanion(status: Value(s), updatedAt: Value(_now())),
        );
        await _audit.log(
          actor,
          'event.status',
          entity: 'events',
          entityId: id,
          newValue: {'status': s.name},
        );
      });

  Stream<EventMoney> watchEventMoney(String eventId) => _db
      .customSelect(
        'SELECT '
        "(SELECT COALESCE(SUM(amount), 0) FROM payments WHERE event_id = ?1 AND status = 'valid') AS collected, "
        "(SELECT COUNT(*) FROM payments WHERE event_id = ?1 AND status = 'valid') AS collections, "
        "(SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE event_id = ?1 AND status = 'valid') AS spent, "
        "(SELECT COUNT(*) FROM expenses WHERE event_id = ?1 AND status = 'valid') AS expenses",
        variables: [Variable.withString(eventId)],
        readsFrom: {_db.payments, _db.expenses},
      )
      .watchSingle()
      .map(
        (r) => EventMoney(
          collected: r.read<int>('collected'),
          collections: r.read<int>('collections'),
          spent: r.read<int>('spent'),
          expenses: r.read<int>('expenses'),
        ),
      );

  Stream<List<Payment>> watchEventPayments(String eventId) =>
      (_db.select(_db.payments)
            ..where((p) => p.eventId.equals(eventId))
            ..orderBy([(p) => OrderingTerm.desc(p.paidOn)]))
          .watch();

  // ---- Meetings ------------------------------------------------------------

  Stream<List<Meeting>> watchMeetings() =>
      (_db.select(_db.meetings)
            ..where((m) => m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm.desc(m.heldOn)]))
          .watch();

  Stream<Meeting> watchMeeting(String id) =>
      (_db.select(_db.meetings)..where((m) => m.id.equals(id))).watchSingle();

  Future<Meeting> saveMeeting(MeetingDraft d, Actor actor, {String? id}) async {
    final title = d.title.trim();
    if (title.isEmpty) throw EventsException('Enter a title.');
    if (d.kind == MeetingKind.zonal && d.zoneId == null) {
      throw EventsException('Choose the zone for a zone meeting.');
    }
    final data = MeetingsCompanion(
      title: Value(title),
      kind: Value(d.kind),
      zoneId: Value(d.kind == MeetingKind.zonal ? d.zoneId : null),
      heldOn: Value(d.heldOn),
      venue: Value(_clean(d.venue)),
      agenda: Value(_clean(d.agenda)),
      updatedAt: Value(_now()),
    );
    return _db.transaction(() async {
      final Meeting m;
      if (id == null) {
        m = await _db
            .into(_db.meetings)
            .insertReturning(
              data.copyWith(
                createdBy: Value(actor.userId),
                deviceId: Value(actor.deviceId),
              ),
            );
      } else {
        await (_db.update(
          _db.meetings,
        )..where((t) => t.id.equals(id))).write(data);
        m = await (_db.select(
          _db.meetings,
        )..where((t) => t.id.equals(id))).getSingle();
      }
      await _audit.log(
        actor,
        id == null ? 'meeting.create' : 'meeting.update',
        entity: 'meetings',
        entityId: m.id,
        newValue: {'title': title, 'heldOn': d.heldOn.toIso8601String()},
      );
      return m;
    });
  }

  Future<void> saveMinutes(String id, String minutes, Actor actor) =>
      _db.transaction(() async {
        await (_db.update(_db.meetings)..where((t) => t.id.equals(id))).write(
          MeetingsCompanion(
            minutes: Value(_clean(minutes)),
            updatedAt: Value(_now()),
          ),
        );
        await _audit.log(
          actor,
          'meeting.minutes',
          entity: 'meetings',
          entityId: id,
        );
      });

  // ---- Attendance ----------------------------------------------------------

  Stream<List<AttendanceEntry>> watchAttendance(String occasionId) {
    final q =
        _db.select(_db.attendanceRecords).join([
            innerJoin(
              _db.members,
              _db.members.id.equalsExp(_db.attendanceRecords.memberId),
            ),
          ])
          ..where(_db.attendanceRecords.occasionId.equals(occasionId))
          ..orderBy([OrderingTerm.asc(_db.members.fullName)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          AttendanceEntry(
            r.readTable(_db.attendanceRecords),
            r.readTable(_db.members),
          ),
      ],
    );
  }

  static AttendanceCounts count(List<AttendanceEntry> list) => AttendanceCounts(
    list.where((e) => e.record.status == AttendanceStatus.present).length,
    list.where((e) => e.record.status == AttendanceStatus.absent).length,
    list.where((e) => e.record.status == AttendanceStatus.excused).length,
  );

  Future<void> mark(
    String occasionId,
    String memberId,
    AttendanceStatus status,
    Actor actor, {
    AttendanceMethod method = AttendanceMethod.manual,
    String? recordedByName,
  }) async {
    await _db
        .into(_db.attendanceRecords)
        .insert(
          AttendanceRecordsCompanion.insert(
            occasionId: occasionId,
            memberId: memberId,
            status: status,
            method: Value(method),
            recordedByName: Value(recordedByName),
            createdBy: Value(actor.userId),
            deviceId: Value(actor.deviceId),
          ),
          onConflict: DoUpdate(
            (old) => AttendanceRecordsCompanion(
              status: Value(status),
              method: Value(method),
              recordedByName: Value(recordedByName),
              updatedAt: Value(_now()),
            ),
            target: [
              _db.attendanceRecords.occasionId,
              _db.attendanceRecords.memberId,
            ],
          ),
        );
  }

  /// Checks a member in from the QR code on their ID card. Returns the
  /// member and whether they were already marked present.
  Future<(Member, bool)> checkInByQr(
    String occasionId,
    String scanned,
    Actor actor, {
    String? recordedByName,
  }) async {
    final memberNo = MemberQr.decode(scanned);
    if (memberNo == null) {
      throw EventsException('This is not a member ID card.');
    }
    final member = await (_db.select(
      _db.members,
    )..where((m) => m.memberNo.equals(memberNo))).getSingleOrNull();
    if (member == null) {
      throw EventsException('No member with ID $memberNo on this phone.');
    }
    final existing =
        await (_db.select(_db.attendanceRecords)..where(
              (a) =>
                  a.occasionId.equals(occasionId) &
                  a.memberId.equals(member.id),
            ))
            .getSingleOrNull();
    final already = existing?.status == AttendanceStatus.present;
    if (!already) {
      await mark(
        occasionId,
        member.id,
        AttendanceStatus.present,
        actor,
        method: AttendanceMethod.qr,
        recordedByName: recordedByName,
      );
    }
    return (member, already);
  }

  /// Members expected at a meeting: everyone active for general meetings
  /// and events, the zone's members for zone meetings, and current office
  /// holders for executive and welfare meetings.
  Future<List<Member>> expected({Meeting? meeting}) async {
    final active = _db.members.status.equalsValue(MemberStatus.active);
    final notDeleted = _db.members.deletedAt.isNull();
    if (meeting == null || meeting.kind == MeetingKind.general) {
      return (_db.select(_db.members)
            ..where((m) => m.status.equalsValue(MemberStatus.active))
            ..where((m) => m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm.asc(m.fullName)]))
          .get();
    }
    if (meeting.kind == MeetingKind.zonal) {
      final q =
          _db.select(_db.members).join([
              innerJoin(
                _db.memberZones,
                _db.memberZones.memberId.equalsExp(_db.members.id),
              ),
            ])
            ..where(
              active &
                  notDeleted &
                  _db.memberZones.zoneId.equals(meeting.zoneId ?? '') &
                  _db.memberZones.deletedAt.isNull(),
            )
            ..orderBy([OrderingTerm.asc(_db.members.fullName)]);
      return [for (final r in await q.get()) r.readTable(_db.members)];
    }
    final execs = await currentExecutives();
    final seen = <String>{};
    return [
      for (final e in execs)
        if ((meeting.kind == MeetingKind.executive ||
                e.position.level == PositionLevel.welfare) &&
            seen.add(e.member.id))
          e.member,
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  /// Marks everyone expected but not yet recorded as absent.
  Future<int> markRestAbsent(
    String occasionId,
    List<Member> expected,
    Actor actor, {
    String? recordedByName,
  }) => _db.transaction(() async {
    final done = {
      for (final r in await (_db.select(
        _db.attendanceRecords,
      )..where((a) => a.occasionId.equals(occasionId))).get())
        r.memberId,
    };
    var n = 0;
    for (final m in expected) {
      if (done.contains(m.id)) continue;
      await mark(
        occasionId,
        m.id,
        AttendanceStatus.absent,
        actor,
        recordedByName: recordedByName,
      );
      n++;
    }
    await _audit.log(
      actor,
      'attendance.close',
      entity: 'attendance_records',
      entityId: occasionId,
      newValue: {'markedAbsent': n},
    );
    return n;
  });

  // ---- Executives ----------------------------------------------------------

  Stream<List<ExecutivePosition>> watchPositions() =>
      (_db.select(_db.executivePositions)
            ..where((p) => p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
          .watch();

  Future<void> addPosition(
    String title,
    PositionLevel level,
    Actor actor,
  ) async {
    final t = title.trim();
    if (t.isEmpty) throw EventsException('Enter the position title.');
    final row = await _db
        .into(_db.executivePositions)
        .insertReturning(
          ExecutivePositionsCompanion.insert(
            title: t,
            level: level,
            sortOrder: const Value(100),
            createdBy: Value(actor.userId),
            deviceId: Value(actor.deviceId),
          ),
        );
    await _audit.log(
      actor,
      'position.create',
      entity: 'executive_positions',
      entityId: row.id,
      newValue: {'title': t, 'level': level.name},
    );
  }

  JoinedSelectStatement<HasResultSet, dynamic> _executivesQuery() =>
      _db.select(_db.executives).join([
        innerJoin(
          _db.members,
          _db.members.id.equalsExp(_db.executives.memberId),
        ),
        innerJoin(
          _db.executivePositions,
          _db.executivePositions.id.equalsExp(_db.executives.positionId),
        ),
        leftOuterJoin(_db.zones, _db.zones.id.equalsExp(_db.executives.zoneId)),
      ])..orderBy([
        OrderingTerm.asc(_db.executivePositions.sortOrder),
        OrderingTerm.asc(_db.zones.sortOrder),
        OrderingTerm.desc(_db.executives.termStart),
      ]);

  ExecutiveView _view(TypedResult r) => ExecutiveView(
    r.readTable(_db.executives),
    r.readTable(_db.members),
    r.readTable(_db.executivePositions),
    r.readTableOrNull(_db.zones),
  );

  Stream<List<ExecutiveView>> watchExecutives({bool current = true}) {
    final q = _executivesQuery()
      ..where(
        _db.executives.deletedAt.isNull() &
            (current
                ? _db.executives.endedOn.isNull()
                : _db.executives.endedOn.isNotNull()),
      );
    return q.watch().map((rows) => rows.map(_view).toList());
  }

  Future<List<ExecutiveView>> currentExecutives() async {
    final q = _executivesQuery()
      ..where(
        _db.executives.deletedAt.isNull() & _db.executives.endedOn.isNull(),
      );
    return (await q.get()).map(_view).toList();
  }

  Stream<List<ExecutiveView>> watchMemberPositions(String memberId) {
    final q = _executivesQuery()
      ..where(
        _db.executives.deletedAt.isNull() &
            _db.executives.memberId.equals(memberId),
      );
    return q.watch().map((rows) => rows.map(_view).toList());
  }

  Future<Executive> appoint({
    required String memberId,
    required ExecutivePosition position,
    String? zoneId,
    required DateTime termStart,
    DateTime? termEnd,
    String? responsibilities,
    required Actor actor,
  }) async {
    if (position.level == PositionLevel.zone && zoneId == null) {
      throw EventsException('Choose the zone for this position.');
    }
    if (termEnd != null && !termEnd.isAfter(termStart)) {
      throw EventsException('The term must end after it starts.');
    }
    return _db.transaction(() async {
      final same =
          await (_db.select(_db.executives)..where(
                (e) =>
                    e.memberId.equals(memberId) &
                    e.positionId.equals(position.id) &
                    e.endedOn.isNull() &
                    e.deletedAt.isNull(),
              ))
              .get();
      if (same.isNotEmpty) {
        throw EventsException('This member already holds this position.');
      }
      final e = await _db
          .into(_db.executives)
          .insertReturning(
            ExecutivesCompanion.insert(
              memberId: memberId,
              positionId: position.id,
              zoneId: Value(
                position.level == PositionLevel.zone ? zoneId : null,
              ),
              termStart: termStart,
              termEnd: Value(termEnd),
              responsibilities: Value(_clean(responsibilities)),
              createdBy: Value(actor.userId),
              deviceId: Value(actor.deviceId),
            ),
          );
      await _audit.log(
        actor,
        'executive.appoint',
        entity: 'executives',
        entityId: e.id,
        newValue: {
          'memberId': memberId,
          'position': position.title,
          'zoneId': zoneId,
          'termStart': termStart.toIso8601String(),
        },
      );
      return e;
    });
  }

  Future<void> endTerm(
    String id,
    DateTime endedOn,
    String reason,
    Actor actor,
  ) => _db.transaction(() async {
    await (_db.update(_db.executives)..where((t) => t.id.equals(id))).write(
      ExecutivesCompanion(
        endedOn: Value(endedOn),
        endedReason: Value(_clean(reason)),
        updatedAt: Value(_now()),
      ),
    );
    await _audit.log(
      actor,
      'executive.end',
      entity: 'executives',
      entityId: id,
      newValue: {'endedOn': endedOn.toIso8601String(), 'reason': reason},
    );
  });

  /// Executive meetings held during [e]'s term, and how many they attended.
  Future<(int attended, int held)> meetingAttendance(ExecutiveView e) async {
    final end = e.executive.endedOn ?? _now();
    final meetings =
        await (_db.select(_db.meetings)..where(
              (m) =>
                  m.deletedAt.isNull() &
                  m.kind.equalsValue(MeetingKind.executive) &
                  m.heldOn.isBiggerOrEqualValue(e.executive.termStart) &
                  m.heldOn.isSmallerOrEqualValue(end),
            ))
            .get();
    if (meetings.isEmpty) return (0, 0);
    final present =
        await (_db.select(_db.attendanceRecords)..where(
              (a) =>
                  a.memberId.equals(e.member.id) &
                  a.occasionId.isIn(meetings.map((m) => m.id)) &
                  a.status.equalsValue(AttendanceStatus.present),
            ))
            .get();
    return (present.length, meetings.length);
  }
}
