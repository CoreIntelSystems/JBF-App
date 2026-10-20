import 'package:drift/drift.dart';

import '../../core/format.dart';
import '../../core/money.dart';
import '../database.dart';
import 'audit_repository.dart';
import 'welfare_repository.dart';

/// What a collection drive has gathered so far.
class DriveTotals {
  const DriveTotals({
    required this.received,
    required this.pledged,
    required this.givers,
  });

  /// Money actually in hand.
  final int received;

  /// Promised and not yet collected.
  final int pledged;

  /// People who have given or promised.
  final int givers;
}

DriveTotals driveTotals(Iterable<WelfareDriveGift> gifts) {
  var received = 0;
  var pledged = 0;
  var givers = 0;
  for (final g in gifts) {
    switch (g.status) {
      case GiftStatus.received:
        received += g.amount;
        givers++;
      case GiftStatus.pledged:
        pledged += g.amount;
        givers++;
      case GiftStatus.voided:
        break;
    }
  }
  return DriveTotals(received: received, pledged: pledged, givers: givers);
}

/// The text officers share with members: what the family needs to know and
/// where the money stands. Voided gifts never appear and anonymous givers
/// are listed without a name.
String driveSummaryText({
  required WelfareCase welfareCase,
  required String memberName,
  required Iterable<WelfareDriveGift> gifts,
  String orgName = '',
}) {
  final c = welfareCase;
  final live = gifts.where((g) => g.status != GiftStatus.voided).toList()
    ..sort((a, b) => a.pledgedOn.compareTo(b.pledgedOn));
  final t = driveTotals(live);
  final b = StringBuffer();
  if (orgName.isNotEmpty) b.writeln(orgName);
  b.writeln('Bereavement collection: $memberName');
  if (c.beneficiary != null) b.writeln('For: ${c.beneficiary}');
  if (c.funeralOn != null) b.writeln('Funeral: ${formatDate(c.funeralOn)}');
  if (c.funeralVenue != null) b.writeln('Venue: ${c.funeralVenue}');
  if (c.familyContact != null) {
    b.writeln(
      'Family contact: ${c.familyContact}'
      '${c.familyPhone == null ? '' : ' (${c.familyPhone})'}',
    );
  }
  b.writeln('Status: ${c.driveStatus.label}');
  b.writeln();
  b.writeln('Received: ${formatMoney(t.received)}');
  if (t.pledged > 0) {
    b.writeln('Pledged, to be collected: ${formatMoney(t.pledged)}');
  }
  if (c.handoverAmount != null) {
    b.writeln(
      'Handed to the family: ${formatMoney(c.handoverAmount!)} on '
      '${formatDate(c.handoverOn)}',
    );
  }
  if (live.isNotEmpty) {
    b.writeln();
    b.writeln('Thank you to everyone who gave:');
    for (final g in live) {
      final who = g.anonymous ? 'A well-wisher' : g.giverName;
      final pending = g.status == GiftStatus.pledged ? ' (pledged)' : '';
      b.writeln('- $who: ${formatMoney(g.amount)}$pending');
    }
  }
  return b.toString().trimRight();
}

class DriveRepository {
  DriveRepository(this._db, this._audit, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final DateTime Function() _now;

  Future<WelfareCase> _case(String id) =>
      (_db.select(_db.welfareCases)..where((c) => c.id.equals(id))).getSingle();

  Future<WelfareDriveGift> _gift(String id) => (_db.select(
    _db.welfareDriveGifts,
  )..where((g) => g.id.equals(id))).getSingle();

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  // ---- Reading -------------------------------------------------------------

  Stream<List<WelfareDriveGift>> watchGifts(String caseId) =>
      (_db.select(_db.welfareDriveGifts)
            ..where((g) => g.caseId.equals(caseId) & g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.desc(g.createdAt)]))
          .watch();

  Future<List<WelfareDriveGift>> gifts(String caseId) =>
      (_db.select(_db.welfareDriveGifts)
            ..where((g) => g.caseId.equals(caseId) & g.deletedAt.isNull())
            ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
          .get();

  // ---- The drive -------------------------------------------------------------

  /// Starts collecting for [caseId]. Rejected cases cannot have a drive.
  Future<void> openDrive(
    String caseId,
    WelfareActor by, {
    DateTime? funeralOn,
    String? funeralVenue,
    String? familyContact,
    String? familyPhone,
  }) async {
    final c = await _case(caseId);
    if (c.status == WelfareStatus.rejected) {
      throw WelfareException('A rejected case cannot have a collection.');
    }
    if (c.driveStatus != DriveStatus.none) {
      throw WelfareException('This case already has a collection.');
    }
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareCases,
      )..where((r) => r.id.equals(caseId))).write(
        WelfareCasesCompanion(
          driveStatus: const Value(DriveStatus.open),
          funeralOn: Value(funeralOn),
          funeralVenue: Value(_clean(funeralVenue)),
          familyContact: Value(_clean(familyContact)),
          familyPhone: Value(_clean(familyPhone)),
          driveOpenedByName: Value(by.name),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_drive.open',
        entity: 'welfare_cases',
        entityId: caseId,
        newValue: {'caseNo': c.caseNo, 'by': by.name},
      );
    });
  }

  /// Funeral date, venue and family contact can change while collecting.
  Future<void> updateDriveDetails(
    String caseId,
    WelfareActor by, {
    DateTime? funeralOn,
    String? funeralVenue,
    String? familyContact,
    String? familyPhone,
  }) async {
    final c = await _case(caseId);
    if (c.driveStatus != DriveStatus.open) {
      throw WelfareException('The collection is no longer open.');
    }
    await (_db.update(
      _db.welfareCases,
    )..where((r) => r.id.equals(caseId))).write(
      WelfareCasesCompanion(
        funeralOn: Value(funeralOn),
        funeralVenue: Value(_clean(funeralVenue)),
        familyContact: Value(_clean(familyContact)),
        familyPhone: Value(_clean(familyPhone)),
        updatedAt: Value(_now()),
      ),
    );
    await _audit.log(
      by.actor,
      'welfare_drive.update',
      entity: 'welfare_cases',
      entityId: caseId,
      newValue: {'caseNo': c.caseNo, 'by': by.name},
    );
  }

  // ---- Gifts -------------------------------------------------------------------

  /// A promise, or money already in hand when [method] is given.
  Future<WelfareDriveGift> addGift(
    String caseId,
    WelfareActor by, {
    required String giverName,
    required int amount,
    String? memberId,
    bool anonymous = false,
    PaymentMethod? method,
    String? reference,
    String? note,
  }) async {
    final c = await _case(caseId);
    if (c.driveStatus != DriveStatus.open) {
      throw WelfareException('This collection is not open.');
    }
    final name = giverName.trim();
    if (name.isEmpty) throw WelfareException('Enter who is giving.');
    if (amount <= 0) throw WelfareException('Enter an amount above zero.');
    final now = _now();
    final inHand = method != null;
    return _db.transaction(() async {
      final g = await _db
          .into(_db.welfareDriveGifts)
          .insertReturning(
            WelfareDriveGiftsCompanion.insert(
              caseId: caseId,
              memberId: Value(memberId),
              giverName: name,
              amount: amount,
              anonymous: Value(anonymous),
              status: Value(inHand ? GiftStatus.received : GiftStatus.pledged),
              pledgedOn: now,
              receivedOn: Value(inHand ? now : null),
              method: Value(method),
              reference: Value(_clean(reference)),
              note: Value(_clean(note)),
              recordedByName: by.name,
              receivedByName: Value(inHand ? by.name : null),
              createdBy: Value(by.actor.userId),
              deviceId: Value(by.actor.deviceId),
            ),
          );
      await _audit.log(
        by.actor,
        inHand ? 'welfare_gift.receive' : 'welfare_gift.pledge',
        entity: 'welfare_drive_gifts',
        entityId: g.id,
        newValue: {
          'caseNo': c.caseNo,
          'giver': name,
          'amount': amount,
          if (inHand) 'method': method.name,
        },
      );
      return g;
    });
  }

  /// A pledge has been paid: the money is now in hand.
  Future<void> receiveGift(
    String giftId,
    WelfareActor by, {
    required PaymentMethod method,
    DateTime? receivedOn,
    String? reference,
  }) async {
    final g = await _gift(giftId);
    if (g.status != GiftStatus.pledged) {
      throw WelfareException('Only a pledge can be marked received.');
    }
    final c = await _case(g.caseId);
    if (c.driveStatus != DriveStatus.open) {
      throw WelfareException('This collection is not open.');
    }
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareDriveGifts,
      )..where((r) => r.id.equals(giftId))).write(
        WelfareDriveGiftsCompanion(
          status: const Value(GiftStatus.received),
          receivedOn: Value(receivedOn ?? _now()),
          method: Value(method),
          reference: Value(_clean(reference)),
          receivedByName: Value(by.name),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_gift.receive',
        entity: 'welfare_drive_gifts',
        entityId: giftId,
        newValue: {
          'caseNo': c.caseNo,
          'giver': g.giverName,
          'amount': g.amount,
          'method': method.name,
        },
      );
    });
  }

  /// Cancels a wrong or withdrawn entry. The row stays for the record.
  Future<void> voidGift(String giftId, WelfareActor by, String reason) async {
    final g = await _gift(giftId);
    if (g.status == GiftStatus.voided) return;
    final c = await _case(g.caseId);
    if (c.driveStatus != DriveStatus.open) {
      throw WelfareException('The collection is closed, so gifts are locked.');
    }
    if (reason.trim().length < 3) throw WelfareException('Give a reason.');
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareDriveGifts,
      )..where((r) => r.id.equals(giftId))).write(
        WelfareDriveGiftsCompanion(
          status: const Value(GiftStatus.voided),
          voidReason: Value(reason.trim()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_gift.void',
        entity: 'welfare_drive_gifts',
        entityId: giftId,
        oldValue: {'status': g.status.name, 'amount': g.amount},
        newValue: {'caseNo': c.caseNo, 'reason': reason.trim()},
      );
    });
  }

  // ---- Closing and hand-over -----------------------------------------------

  /// Stops the collection. Gifts are locked and the total is ready for a
  /// different officer to approve the hand-over.
  Future<void> closeDrive(String caseId, WelfareActor by) async {
    final c = await _case(caseId);
    if (c.driveStatus != DriveStatus.open) {
      throw WelfareException('The collection is not open.');
    }
    final totals = driveTotals(await gifts(caseId));
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareCases,
      )..where((r) => r.id.equals(caseId))).write(
        WelfareCasesCompanion(
          driveStatus: const Value(DriveStatus.closed),
          driveClosedOn: Value(_now()),
          driveClosedBy: Value(by.actor.userId),
          driveClosedByName: Value(by.name),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_drive.close',
        entity: 'welfare_cases',
        entityId: caseId,
        newValue: {
          'caseNo': c.caseNo,
          'received': totals.received,
          'pledgedNotCollected': totals.pledged,
        },
      );
    });
  }

  /// A different officer approves paying the money received to the family.
  /// The amount is what was received when the drive closed.
  Future<void> approveHandover(
    String caseId,
    WelfareActor by, {
    required PaymentMethod method,
    required DateTime handedOn,
    String? reference,
  }) async {
    final c = await _case(caseId);
    if (c.driveStatus != DriveStatus.closed) {
      throw WelfareException('Close the collection first.');
    }
    final own = by.isSamePerson(c.driveClosedBy);
    if (own && !by.mayApproveOwn) {
      throw WelfareException(
        'A different officer must approve the hand-over of a collection you '
        'closed.',
      );
    }
    final totals = driveTotals(await gifts(caseId));
    if (totals.received <= 0) {
      throw WelfareException('Nothing has been received to hand over.');
    }
    await _db.transaction(() async {
      await (_db.update(
        _db.welfareCases,
      )..where((r) => r.id.equals(caseId))).write(
        WelfareCasesCompanion(
          driveStatus: const Value(DriveStatus.handedOver),
          handoverAmount: Value(totals.received),
          handoverOn: Value(handedOn),
          handoverMethod: Value(method),
          handoverReference: Value(_clean(reference)),
          handoverBy: Value(by.actor.userId),
          handoverByName: Value(by.name),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor,
        'welfare_drive.handover',
        entity: 'welfare_cases',
        entityId: caseId,
        newValue: {
          'caseNo': c.caseNo,
          'amount': totals.received,
          'method': method.name,
          'reference': _clean(reference),
          if (own) 'approvedOwnClosing': true,
        },
      );
    });
  }
}
