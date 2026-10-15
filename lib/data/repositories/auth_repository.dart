import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

import '../../domain/password_hasher.dart';
import '../../domain/permissions.dart';
import '../database.dart';
import '../sync/sync_api.dart';
import '../sync/sync_service.dart';
import 'actor.dart';
import 'audit_repository.dart';

/// The signed-in user with their resolved permissions.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.roleKey,
    required this.roleName,
    required this.permissions,
    required this.biometricEnabled,
    required this.hasPin,
    this.zoneScope,
    this.memberId,
    this.memberAccount = false,
    this.roleKeys = const {},
  });

  final String id;
  final String username;
  final String displayName;
  final String roleKey;
  final String roleName;
  final Set<String> permissions;
  final bool biometricEnabled;
  final bool hasPin;

  /// For zone-level roles, the zones this user may see; null for no limit.
  final Set<String>? zoneScope;

  /// The member record of the person behind this account. Executives are
  /// members too, so they see their own dues alongside their role's work.
  final String? memberId;

  /// Signed in with a member ID (rather than an old username login). Its
  /// password lives in the cloud; this phone keeps a copy to work offline.
  final bool memberAccount;

  /// Every role this person holds (the [roleKey] is the main one).
  final Set<String> roleKeys;

  bool can(String permission) => permissions.contains(permission);

  Actor actor(String deviceId) =>
      Actor(userId: id, username: username, deviceId: deviceId);

  @override
  List<Object?> get props => [
    id,
    username,
    displayName,
    roleKey,
    roleName,
    permissions,
    biometricEnabled,
    hasPin,
    zoneScope,
    memberId,
    memberAccount,
    roleKeys,
  ];
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A user row joined with its role, for the users screen.
class UserWithRole {
  const UserWithRole(this.user, this.role);
  final User user;
  final Role role;
}

enum LoginMethod { password, pin, biometric }

/// Checks a member's password in the cloud ([newPassword] changes it).
/// Throws [SyncException].
typedef MemberPasswordCheck =
    Future<void> Function(
      String memberNo,
      String password, {
      String? newPassword,
    });

/// A role someone holds, for the member page.
class HeldRole {
  const HeldRole(this.assignment, this.role);
  final RoleAssignment assignment;
  final Role role;

  List<String> get zoneIds =>
      (assignment.zoneIds ?? '').split(',').where((z) => z.isNotEmpty).toList();
}

class AuthRepository {
  AuthRepository(
    this._db,
    this._audit, {
    PasswordHasher hasher = const PasswordHasher(),
    DateTime Function()? clock,
    SyncPrefs? memberCredentials,
    this.cloudCheck,
  }) : _hasher = hasher,
       _now = clock ?? DateTime.now,
       _creds = memberCredentials ?? MemorySyncPrefs();

  final AppDatabase _db;
  final AuditRepository _audit;
  final PasswordHasher _hasher;
  final DateTime Function() _now;

  /// This phone's copies of member passwords, PINs and fingerprint choice.
  final SyncPrefs _creds;

  /// Confirms a member's password online; null when there is no cloud.
  MemberPasswordCheck? cloudCheck;

  static const maxFailedAttempts = 5;
  static const lockoutDuration = Duration(minutes: 5);
  static const minPasswordLength = 6;

  static String normalizeUsername(String username) =>
      username.trim().toLowerCase();

  static String? validatePassword(String password) =>
      password.length < minPasswordLength
      ? 'Use at least $minPasswordLength characters.'
      : null;

  static String? validatePin(String pin) =>
      RegExp(r'^\d{4,6}$').hasMatch(pin) ? null : 'PIN must be 4 to 6 digits.';

  Future<bool> hasUsers() async {
    final count = _db.users.id.count();
    final row = await (_db.selectOnly(
      _db.users,
    )..addColumns([count])).getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<List<Role>> roles() =>
      (_db.select(_db.roles)..orderBy([(r) => OrderingTerm.asc(r.name)])).get();

  /// Creates the first Super Administrator. Only allowed on an empty device.
  Future<AppUser> createInitialAdmin({
    required String displayName,
    required String username,
    required String password,
    String? pin,
    required String deviceId,
  }) async {
    if (await hasUsers()) {
      throw AuthException('This device is already set up.');
    }
    final role = await (_db.select(
      _db.roles,
    )..where((r) => r.key.equals('super_admin'))).getSingle();
    final userId = await _insertUser(
      displayName: displayName,
      username: username,
      password: password,
      pin: pin,
      roleId: role.id,
      actor: Actor.system(deviceId: deviceId),
    );
    return _loadAppUser(userId);
  }

  Future<String> createUser({
    required String displayName,
    required String username,
    required String password,
    required String roleId,
    List<String> zoneIds = const [],
    String? memberId,
    required Actor actor,
  }) {
    return _insertUser(
      displayName: displayName,
      username: username,
      password: password,
      roleId: roleId,
      zoneIds: zoneIds,
      memberId: memberId,
      actor: actor,
    );
  }

  Future<String> _insertUser({
    required String displayName,
    required String username,
    required String password,
    String? pin,
    required String roleId,
    List<String> zoneIds = const [],
    String? memberId,
    required Actor actor,
  }) async {
    final name = normalizeUsername(username);
    await _checkZones(roleId, zoneIds);
    await _checkMember(memberId);
    if (name.isEmpty) throw AuthException('Enter a username.');
    if (displayName.trim().isEmpty) throw AuthException('Enter a name.');
    final pwError = validatePassword(password);
    if (pwError != null) throw AuthException(pwError);
    if (pin != null && pin.isNotEmpty && validatePin(pin) != null) {
      throw AuthException(validatePin(pin)!);
    }
    final taken = await (_db.select(
      _db.users,
    )..where((u) => u.username.equals(name))).getSingleOrNull();
    if (taken != null) throw AuthException('That username is taken.');

    final passwordHash = await _hasher.hash(password);
    final pinHash = (pin == null || pin.isEmpty)
        ? null
        : await _hasher.hash(pin);
    return _db.transaction(() async {
      final user = await _db
          .into(_db.users)
          .insertReturning(
            UsersCompanion.insert(
              username: name,
              displayName: displayName.trim(),
              roleId: roleId,
              passwordHash: passwordHash,
              pinHash: Value(pinHash),
              zoneIds: Value(zoneIds.isEmpty ? null : zoneIds.join(',')),
              memberId: Value(memberId),
              createdBy: Value(actor.userId),
              deviceId: Value(actor.deviceId),
            ),
          );
      await _audit.log(
        actor,
        'user.create',
        entity: 'users',
        entityId: user.id,
        newValue: {
          'username': name,
          'displayName': user.displayName,
          'roleId': roleId,
          if (zoneIds.isNotEmpty) 'zoneIds': zoneIds,
          'memberId': ?memberId,
        },
      );
      return user.id;
    });
  }

  /// Checks credentials and returns the signed-in user.
  /// Throws [AuthException] with a message safe to show on screen.
  Future<AppUser> login(
    String username,
    String secret, {
    required LoginMethod method,
    required String deviceId,
  }) async {
    final name = normalizeUsername(username);
    final user = await (_db.select(
      _db.users,
    )..where((u) => u.username.equals(name))).getSingleOrNull();
    if (user == null) {
      final member = await _memberByNo(username);
      if (member != null) {
        return _memberLogin(member, secret, method, deviceId);
      }
    }
    final actor = Actor(userId: user?.id, username: name, deviceId: deviceId);

    if (user == null || !user.isActive || user.deletedAt != null) {
      await _audit.log(actor, 'login.failed', newValue: {'reason': 'unknown'});
      throw AuthException('Wrong member ID or password.');
    }
    final now = _now();
    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      final mins = user.lockedUntil!.difference(now).inMinutes + 1;
      throw AuthException(
        'Too many wrong attempts. Try again in $mins minute(s).',
      );
    }

    final bool ok;
    switch (method) {
      case LoginMethod.password:
        ok = await _hasher.verify(secret, user.passwordHash);
      case LoginMethod.pin:
        if (user.pinHash == null) {
          throw AuthException('No PIN is set for this user.');
        }
        ok = await _hasher.verify(secret, user.pinHash!);
      case LoginMethod.biometric:
        // The fingerprint check itself happens on the device; it only
        // unlocks users who switched it on.
        if (!user.biometricEnabled) {
          throw AuthException('Fingerprint login is off for this user.');
        }
        ok = true;
    }

    if (!ok) {
      final attempts = user.failedAttempts + 1;
      final locked = attempts >= maxFailedAttempts;
      await _db.transaction(() async {
        await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
          UsersCompanion(
            failedAttempts: Value(locked ? 0 : attempts),
            lockedUntil: Value(locked ? now.add(lockoutDuration) : null),
          ),
        );
        await _audit.log(
          actor,
          'login.failed',
          entity: 'users',
          entityId: user.id,
          newValue: {'method': method.name, 'locked': locked},
        );
      });
      throw AuthException(
        locked
            ? 'Too many wrong attempts. Try again in '
                  '${lockoutDuration.inMinutes} minutes.'
            : method == LoginMethod.pin
            ? 'Wrong PIN.'
            : 'Wrong member ID or password.',
      );
    }

    await _db.transaction(() async {
      await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
        UsersCompanion(
          failedAttempts: const Value(0),
          lockedUntil: const Value(null),
          lastLoginAt: Value(now),
        ),
      );
      await _audit.log(
        actor,
        'login.success',
        entity: 'users',
        entityId: user.id,
        newValue: {'method': method.name},
      );
    });
    return _loadAppUser(user.id);
  }

  Future<void> logout(AppUser user, String deviceId) => _audit.log(
    user.actor(deviceId),
    'logout',
    entity: 'users',
    entityId: user.id,
  );

  Future<AppUser> changePassword(
    AppUser user,
    String current,
    String next, {
    required String deviceId,
  }) async {
    if (user.memberAccount) {
      return _memberChangePassword(user, current, next, deviceId);
    }
    final row = await _userRow(user.id);
    if (!await _hasher.verify(current, row.passwordHash)) {
      throw AuthException('Current password is wrong.');
    }
    final err = validatePassword(next);
    if (err != null) throw AuthException(err);
    final hash = await _hasher.hash(next);
    await _db.transaction(() async {
      await _touchUser(user.id, UsersCompanion(passwordHash: Value(hash)));
      await _audit.log(
        user.actor(deviceId),
        'user.password_change',
        entity: 'users',
        entityId: user.id,
      );
    });
    return _loadAppUser(user.id);
  }

  Future<AppUser> setPin(
    AppUser user,
    String? pin, {
    required String deviceId,
  }) async {
    if (pin != null) {
      final err = validatePin(pin);
      if (err != null) throw AuthException(err);
    }
    final hash = pin == null ? null : await _hasher.hash(pin);
    if (user.memberAccount) {
      await _updateCreds(user.id, (c) => c..['pin'] = hash);
      await _audit.log(
        user.actor(deviceId),
        pin == null ? 'user.pin_remove' : 'user.pin_set',
        entity: 'members',
        entityId: user.id,
      );
      return loadMemberUser(user.id);
    }
    await _db.transaction(() async {
      await _touchUser(user.id, UsersCompanion(pinHash: Value(hash)));
      await _audit.log(
        user.actor(deviceId),
        pin == null ? 'user.pin_remove' : 'user.pin_set',
        entity: 'users',
        entityId: user.id,
      );
    });
    return _loadAppUser(user.id);
  }

  Future<AppUser> setBiometric(
    AppUser user,
    bool enabled, {
    required String deviceId,
  }) async {
    if (user.memberAccount) {
      await _updateCreds(user.id, (c) => c..['bio'] = enabled);
      return loadMemberUser(user.id);
    }
    await _db.transaction(() async {
      await _touchUser(
        user.id,
        UsersCompanion(biometricEnabled: Value(enabled)),
      );
      await _audit.log(
        user.actor(deviceId),
        enabled ? 'user.biometric_on' : 'user.biometric_off',
        entity: 'users',
        entityId: user.id,
      );
    });
    return _loadAppUser(user.id);
  }

  Future<bool> biometricEnabledFor(String username) async {
    final member = await _memberByNo(username);
    if (member != null) return (await _readCreds(member.id))['bio'] == true;
    final row =
        await (_db.select(_db.users)
              ..where((u) => u.username.equals(normalizeUsername(username))))
            .getSingleOrNull();
    return row != null && row.isActive && row.biometricEnabled;
  }

  Stream<List<UserWithRole>> watchUsers() {
    final q = _db.select(_db.users).join([
      innerJoin(_db.roles, _db.roles.id.equalsExp(_db.users.roleId)),
    ])..orderBy([OrderingTerm.asc(_db.users.displayName)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          UserWithRole(r.readTable(_db.users), r.readTable(_db.roles)),
      ],
    );
  }

  Future<void> updateUser(
    String userId, {
    String? roleId,
    bool? isActive,
    List<String>? zoneIds,

    /// The member record to link; an empty string unlinks it.
    String? memberId,
    required Actor actor,
  }) async {
    if (userId == actor.userId && isActive == false) {
      throw AuthException('You cannot deactivate your own account.');
    }
    final before = await _userRow(userId);
    if (zoneIds != null) await _checkZones(roleId ?? before.roleId, zoneIds);
    if (memberId != null && memberId.isNotEmpty) {
      await _checkMember(memberId, userId: userId);
    }
    await _db.transaction(() async {
      await _touchUser(
        userId,
        UsersCompanion(
          roleId: roleId == null ? const Value.absent() : Value(roleId),
          isActive: isActive == null ? const Value.absent() : Value(isActive),
          zoneIds: zoneIds == null
              ? const Value.absent()
              : Value(zoneIds.isEmpty ? null : zoneIds.join(',')),
          memberId: memberId == null
              ? const Value.absent()
              : Value(memberId.isEmpty ? null : memberId),
        ),
      );
      await _audit.log(
        actor,
        'user.update',
        entity: 'users',
        entityId: userId,
        oldValue: {
          'roleId': before.roleId,
          'isActive': before.isActive,
          'zoneIds': before.zoneIds,
          'memberId': before.memberId,
        },
        newValue: {
          'roleId': ?roleId,
          'isActive': ?isActive,
          if (zoneIds != null) 'zoneIds': zoneIds.join(','),
          'memberId': ?memberId,
        },
      );
    });
  }

  Future<void> resetPassword(
    String userId,
    String newPassword, {
    required Actor actor,
  }) async {
    final err = validatePassword(newPassword);
    if (err != null) throw AuthException(err);
    final hash = await _hasher.hash(newPassword);
    await _db.transaction(() async {
      await _touchUser(
        userId,
        UsersCompanion(
          passwordHash: Value(hash),
          failedAttempts: const Value(0),
          lockedUntil: const Value(null),
        ),
      );
      await _audit.log(
        actor,
        'user.password_reset',
        entity: 'users',
        entityId: userId,
      );
    });
  }

  /// Zone roles need one or two zones; other roles none.
  Future<void> _checkZones(String roleId, List<String> zoneIds) async {
    final role = await (_db.select(
      _db.roles,
    )..where((r) => r.id.equals(roleId))).getSingle();
    if (role.level == 'zone') {
      if (zoneIds.isEmpty) {
        throw AuthException('Choose the zone this officer looks after.');
      }
      if (zoneIds.length > 2) {
        throw AuthException('Choose at most 2 zones.');
      }
    }
  }

  /// One account per member.
  Future<void> _checkMember(String? memberId, {String? userId}) async {
    if (memberId == null) return;
    final other =
        await (_db.select(_db.users)..where(
              (u) =>
                  u.memberId.equals(memberId) &
                  u.deletedAt.isNull() &
                  (userId == null
                      ? const Constant(true)
                      : u.id.equals(userId).not()),
            ))
            .getSingleOrNull();
    if (other != null) {
      throw AuthException(
        'That member already has an account (${other.username}).',
      );
    }
  }

  // ---- Member ID sign-in -------------------------------------------------

  Future<Member?> _memberByNo(String memberNo) {
    final no = memberNo.trim().toUpperCase();
    if (no.isEmpty) return Future.value();
    return (_db.select(_db.members)
          ..where((m) => m.memberNo.upper().equals(no) & m.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Map<String, Object?>> _readCreds(String memberId) async {
    final raw = await _creds.read('member_cred_$memberId');
    return raw == null
        ? <String, Object?>{}
        : (jsonDecode(raw) as Map).cast<String, Object?>();
  }

  Future<void> _updateCreds(
    String memberId,
    Map<String, Object?> Function(Map<String, Object?>) change,
  ) async {
    final next = change(await _readCreds(memberId));
    await _creds.write('member_cred_$memberId', jsonEncode(next));
  }

  /// Keeps a copy of a member's password on this phone (after the cloud
  /// confirmed it) so they can sign in offline.
  Future<void> rememberMemberPassword(String memberId, String password) async {
    final hash = await _hasher.hash(password);
    await _updateCreds(memberId, (c) => c..['pw'] = hash);
  }

  /// Forgets a member's saved password, PIN and fingerprint on this phone.
  Future<void> forgetMember(String memberId) =>
      _creds.write('member_cred_$memberId', null);

  Future<AppUser> _memberLogin(
    Member member,
    String secret,
    LoginMethod method,
    String deviceId,
  ) async {
    final actor = Actor(
      userId: member.id,
      username: member.memberNo,
      deviceId: deviceId,
    );
    final creds = await _readCreds(member.id);
    final now = _now();
    final lockedUntil = DateTime.tryParse('${creds['locked_until']}');
    if (lockedUntil != null && lockedUntil.isAfter(now)) {
      final mins = lockedUntil.difference(now).inMinutes + 1;
      throw AuthException(
        'Too many wrong attempts. Try again in $mins minute(s).',
      );
    }
    final user = await loadMemberUser(member.id);
    if (user.permissions.isEmpty) {
      throw AuthException(
        'This phone holds the association\'s records and is only for '
        'executives. Sign in on your own phone to see your dues.',
      );
    }

    var ok = false;
    switch (method) {
      case LoginMethod.password:
        final saved = creds['pw'] as String?;
        ok = saved != null && await _hasher.verify(secret, saved);
        final check = cloudCheck;
        if (!ok && check != null) {
          // First sign-in on this phone, or the password was changed on
          // another phone: ask the cloud.
          try {
            await check(member.memberNo, secret);
            ok = true;
            await rememberMemberPassword(member.id, secret);
          } on SyncException catch (e) {
            if (e.offline && saved == null) {
              throw AuthException(
                'Connect to the internet the first time you sign in on '
                'this phone.',
              );
            }
            if (!e.offline && !e.message.startsWith('Wrong')) {
              throw AuthException(e.message);
            }
          }
        }
      case LoginMethod.pin:
        final pin = creds['pin'] as String?;
        if (pin == null) throw AuthException('No PIN is set for this user.');
        ok = await _hasher.verify(secret, pin);
      case LoginMethod.biometric:
        if (creds['bio'] != true) {
          throw AuthException('Fingerprint login is off for this user.');
        }
        ok = true;
    }

    if (!ok) {
      final attempts = ((creds['fails'] as num?)?.toInt() ?? 0) + 1;
      final locked = attempts >= maxFailedAttempts;
      await _updateCreds(
        member.id,
        (c) => c
          ..['fails'] = locked ? 0 : attempts
          ..['locked_until'] = locked
              ? now.add(lockoutDuration).toIso8601String()
              : null,
      );
      await _audit.log(
        actor,
        'login.failed',
        entity: 'members',
        entityId: member.id,
        newValue: {'method': method.name, 'locked': locked},
      );
      throw AuthException(
        locked
            ? 'Too many wrong attempts. Try again in '
                  '${lockoutDuration.inMinutes} minutes.'
            : method == LoginMethod.pin
            ? 'Wrong PIN.'
            : 'Wrong member ID or password.',
      );
    }
    await _updateCreds(
      member.id,
      (c) => c
        ..remove('fails')
        ..remove('locked_until'),
    );
    await _audit.log(
      actor,
      'login.success',
      entity: 'members',
      entityId: member.id,
      newValue: {'method': method.name},
    );
    return loadMemberUser(member.id);
  }

  Future<AppUser> _memberChangePassword(
    AppUser user,
    String current,
    String next,
    String deviceId,
  ) async {
    final err = validatePassword(next);
    if (err != null) throw AuthException(err);
    final check = cloudCheck;
    if (check == null) {
      throw AuthException('Connect to the internet to change your password.');
    }
    try {
      await check(user.username, current, newPassword: next);
    } on SyncException catch (e) {
      throw AuthException(
        e.offline
            ? 'Connect to the internet to change your password.'
            : e.message.startsWith('Wrong')
            ? 'Current password is wrong.'
            : e.message,
      );
    }
    await rememberMemberPassword(user.id, next);
    await _audit.log(
      user.actor(deviceId),
      'user.password_change',
      entity: 'members',
      entityId: user.id,
    );
    return loadMemberUser(user.id);
  }

  /// The roles a member holds today: assigned roles plus any old username
  /// login linked to them.
  Future<List<HeldRole>> heldRoles(String memberId) async {
    final now = _now();
    final q =
        _db.select(_db.roleAssignments).join([
            innerJoin(
              _db.roles,
              _db.roles.id.equalsExp(_db.roleAssignments.roleId),
            ),
          ])
          ..where(
            _db.roleAssignments.memberId.equals(memberId) &
                _db.roleAssignments.deletedAt.isNull() &
                _db.roleAssignments.startsOn.isSmallerOrEqualValue(now) &
                (_db.roleAssignments.endsOn.isNull() |
                    _db.roleAssignments.endsOn.isBiggerThanValue(now)),
          )
          ..orderBy([OrderingTerm.asc(_db.roleAssignments.startsOn)]);
    return [
      for (final r in await q.get())
        HeldRole(r.readTable(_db.roleAssignments), r.readTable(_db.roles)),
    ];
  }

  /// Short role labels for ID cards, by member id: "Zone Mayor (Zone 5)".
  /// The plain member role and CoreIntel support are left out.
  Future<Map<String, List<String>>> roleLabels(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return {};
    final zones = {
      for (final z in await _db.select(_db.zones).get()) z.id: z.name,
    };
    final out = <String, List<String>>{};
    for (final id in wanted) {
      final labels = <String>[];
      for (final h in await heldRoles(id)) {
        if (h.role.level == 'member' || h.role.level == 'system') continue;
        final names = [
          for (final z in h.zoneIds)
            if (zones[z] != null) zones[z]!,
        ];
        final label = names.isEmpty
            ? h.role.name
            : '${h.role.name} (${names.join(', ')})';
        if (!labels.contains(label)) labels.add(label);
      }
      if (labels.isNotEmpty) out[id] = labels;
    }
    return out;
  }

  Stream<List<HeldRole>> watchHeldRoles(String memberId) {
    final q =
        _db.select(_db.roleAssignments).join([
            innerJoin(
              _db.roles,
              _db.roles.id.equalsExp(_db.roleAssignments.roleId),
            ),
          ])
          ..where(
            _db.roleAssignments.memberId.equals(memberId) &
                _db.roleAssignments.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.asc(_db.roleAssignments.startsOn)]);
    return q.watch().map((rows) {
      final now = _now();
      return [
        for (final r in rows)
          if (r.readTable(_db.roleAssignments) case final a
              when !a.startsOn.isAfter(now) &&
                  (a.endsOn == null || a.endsOn!.isAfter(now)))
            HeldRole(a, r.readTable(_db.roles)),
      ];
    });
  }

  Future<Set<String>> _rolePermissions(Role role) async {
    if (role.permissions != null) return decodePermissions(role.permissions);
    final rows = await (_db.select(
      _db.rolePermissions,
    )..where((p) => p.roleId.equals(role.id))).get();
    return {for (final p in rows) p.permission};
  }

  /// The signed-in user for a member: the permissions of every role they
  /// hold. Zone executives are limited to their zones unless they also
  /// hold a wider role.
  Future<AppUser> loadMemberUser(String memberId) async {
    final member = await (_db.select(
      _db.members,
    )..where((m) => m.id.equals(memberId))).getSingle();
    final held = <(Role, List<String>)>[
      for (final h in await heldRoles(memberId)) (h.role, h.zoneIds),
    ];
    final linked =
        await (_db.select(_db.users)..where(
              (u) =>
                  u.memberId.equals(memberId) &
                  u.isActive.equals(true) &
                  u.deletedAt.isNull(),
            ))
            .get();
    for (final u in linked) {
      final role = await (_db.select(
        _db.roles,
      )..where((r) => r.id.equals(u.roleId))).getSingle();
      held.add((
        role,
        (u.zoneIds ?? '').split(',')..removeWhere((z) => z.isEmpty),
      ));
    }
    final officer = [
      for (final h in held)
        if (h.$1.key != 'member') h,
    ];
    final perms = <String>{};
    final permsByRole = <Role, Set<String>>{};
    for (final (role, _) in officer) {
      final p = permsByRole[role] ??= await _rolePermissions(role);
      perms.addAll(p);
    }
    officer.sort(
      (a, b) => permsByRole[b.$1]!.length.compareTo(permsByRole[a.$1]!.length),
    );
    final Set<String>? scope =
        officer.isEmpty || officer.any((h) => h.$1.level != 'zone')
        ? null
        : {for (final h in officer) ...h.$2};
    final names = <String>[];
    for (final (role, _) in officer) {
      if (!names.contains(role.name)) names.add(role.name);
    }
    final creds = await _readCreds(memberId);
    return AppUser(
      id: member.id,
      username: member.memberNo,
      displayName: member.fullName,
      roleKey: officer.isEmpty ? 'member' : officer.first.$1.key,
      roleName: names.isEmpty ? 'Member' : names.join(', '),
      permissions: perms,
      biometricEnabled: creds['bio'] == true,
      hasPin: creds['pin'] != null,
      zoneScope: scope,
      memberId: member.id,
      memberAccount: true,
      roleKeys: {for (final h in officer) h.$1.key},
    );
  }

  /// Gives a member a role. Holders of [Perm.rolesAssign] may give any
  /// role; Zone Mayors ([Perm.zoneRolesAssign]) only zone roles in their
  /// own zones.
  Future<void> assignRole({
    required String memberId,
    required String roleId,
    List<String> zoneIds = const [],
    required AppUser by,
    required String deviceId,
  }) async {
    final role = await (_db.select(
      _db.roles,
    )..where((r) => r.id.equals(roleId))).getSingle();
    _checkCanAssign(by, role, zoneIds);
    if (role.level == 'zone') {
      if (zoneIds.isEmpty) {
        throw AuthException('Choose the zone this role looks after.');
      }
      if (zoneIds.length > 2) throw AuthException('Choose at most 2 zones.');
    }
    final dup = (await heldRoles(memberId)).any(
      (h) =>
          h.role.id == roleId &&
          (role.level != 'zone' ||
              h.zoneIds.toSet().containsAll(zoneIds.toSet())),
    );
    if (dup) throw AuthException('They already hold that role.');
    final actor = by.actor(deviceId);
    await _db.transaction(() async {
      final a = await _db
          .into(_db.roleAssignments)
          .insertReturning(
            RoleAssignmentsCompanion.insert(
              memberId: memberId,
              roleId: roleId,
              zoneIds: Value(
                role.level == 'zone' && zoneIds.isNotEmpty
                    ? zoneIds.join(',')
                    : null,
              ),
              startsOn: Value(_now()),
              assignedByName: Value(by.displayName),
              createdBy: Value(by.id),
              deviceId: Value(deviceId),
            ),
          );
      await _audit.log(
        actor,
        'role.assign',
        entity: 'role_assignments',
        entityId: a.id,
        newValue: {
          'memberId': memberId,
          'role': role.key,
          if (zoneIds.isNotEmpty) 'zoneIds': zoneIds,
        },
      );
    });
  }

  /// Ends a role from now on.
  Future<void> endRole(
    HeldRole held, {
    required AppUser by,
    required String deviceId,
  }) async {
    _checkCanAssign(by, held.role, held.zoneIds);
    if (held.assignment.memberId == by.memberId &&
        held.role.key == by.roleKey &&
        by.can(Perm.rolesAssign)) {
      throw AuthException(
        'You cannot remove your own main role. Ask another officer.',
      );
    }
    await _db.transaction(() async {
      await (_db.update(
        _db.roleAssignments,
      )..where((a) => a.id.equals(held.assignment.id))).write(
        RoleAssignmentsCompanion(
          endsOn: Value(_now()),
          updatedAt: Value(_now()),
        ),
      );
      await _audit.log(
        by.actor(deviceId),
        'role.end',
        entity: 'role_assignments',
        entityId: held.assignment.id,
        oldValue: {'memberId': held.assignment.memberId, 'role': held.role.key},
      );
    });
  }

  /// Roles [by] may give: any (except Super Administrator, which only
  /// CoreIntel support gives) with [Perm.rolesAssign]; zone roles with
  /// [Perm.zoneRolesAssign].
  static bool canGive(AppUser by, Role role) {
    if (role.key == 'super_admin') return by.roleKey == 'super_admin';
    if (role.key == 'member') return false;
    if (by.can(Perm.rolesAssign)) return true;
    if (role.level != 'zone') return false;
    if (by.can(Perm.zoneRolesAssign)) return true;
    return by.can(Perm.helpersAssign) &&
        by.roleKeys.any((k) => helperRoles[k] == role.key);
  }

  /// Whether [by] may change what [role] can do: the Founder (or anyone
  /// with [Perm.rolesManage]) any role but the Super Administrator; a Zone
  /// Mayor only the zone roles they added.
  static bool canEditRole(AppUser by, Role role) {
    if (role.key == 'super_admin') return false;
    if (by.can(Perm.rolesManage)) return true;
    return by.can(Perm.zoneRolesAssign) &&
        role.level == 'zone' &&
        role.createdBy == by.id;
  }

  /// Adds a role, or changes one's name and permissions. A Zone Mayor may
  /// only add zone roles, with permissions they hold themselves.
  Future<void> saveRole({
    Role? existing,
    required String name,
    required String level,
    required Set<String> permissions,
    required AppUser by,
    required String deviceId,
  }) async {
    final full = by.can(Perm.rolesManage);
    if (existing != null && !canEditRole(by, existing)) {
      throw AuthException('Your role cannot change that role.');
    }
    if (existing == null && !full && !by.can(Perm.zoneRolesAssign)) {
      throw AuthException('Your role cannot add roles.');
    }
    if (!full) {
      if (level != 'zone') {
        throw AuthException('You can only add zone roles.');
      }
      final extra = permissions.difference(by.permissions);
      if (extra.isNotEmpty) {
        throw AuthException(
          'You can only give access you have yourself '
          '(${extra.map((p) => Perm.labels[p] ?? p).join(', ')}).',
        );
      }
    }
    final clean = name.trim();
    if (clean.isEmpty) throw AuthException('Enter a name for the role.');
    final taken =
        await (_db.select(_db.roles)..where(
              (r) =>
                  r.name.lower().equals(clean.toLowerCase()) &
                  r.deletedAt.isNull() &
                  (existing == null
                      ? const Constant(true)
                      : r.id.equals(existing.id).not()),
            ))
            .get();
    if (taken.isNotEmpty) throw AuthException('A role with that name exists.');
    final encoded = encodePermissions(permissions);
    await _db.transaction(() async {
      final String id;
      if (existing == null) {
        final row = await _db
            .into(_db.roles)
            .insertReturning(
              RolesCompanion.insert(
                key: 'custom_${DateTime.now().microsecondsSinceEpoch}',
                name: clean,
                level: level,
                permissions: Value(encoded),
                createdBy: Value(by.id),
                deviceId: Value(deviceId),
              ),
            );
        id = row.id;
      } else {
        id = existing.id;
        await (_db.update(_db.roles)..where((r) => r.id.equals(id))).write(
          RolesCompanion(
            name: Value(clean),
            permissions: Value(encoded),
            updatedAt: Value(_now()),
          ),
        );
      }
      await _audit.log(
        by.actor(deviceId),
        existing == null ? 'role.create' : 'role.update',
        entity: 'roles',
        entityId: id,
        oldValue: existing == null
            ? null
            : {
                'name': existing.name,
                'permissions': decodePermissions(existing.permissions).toList(),
              },
        newValue: {'name': clean, 'permissions': permissions.toList()},
      );
    });
  }

  Stream<List<Role>> watchRoles() =>
      (_db.select(_db.roles)
            ..where((r) => r.deletedAt.isNull())
            ..orderBy([(r) => OrderingTerm.asc(r.name)]))
          .watch();

  /// A role's permissions, from its stored list.
  static Set<String> permissionsOf(Role role) =>
      decodePermissions(role.permissions);

  void _checkCanAssign(AppUser by, Role role, List<String> zoneIds) {
    if (!canGive(by, role)) {
      throw AuthException('Your role cannot give or remove that role.');
    }
    final scope = by.zoneScope;
    if (!by.can(Perm.rolesAssign) &&
        scope != null &&
        zoneIds.any((z) => !scope.contains(z))) {
      throw AuthException('You can only give roles in your own zone.');
    }
  }

  static Set<String>? scopeFor(Role role, User user) => role.level == 'zone'
      ? (user.zoneIds ?? '').split(',').where((z) => z.isNotEmpty).toSet()
      : null;

  Future<User> _userRow(String id) =>
      (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingle();

  Future<void> _touchUser(String id, UsersCompanion changes) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(_now())),
    );
  }

  Future<AppUser> _loadAppUser(String userId) async {
    final user = await _userRow(userId);
    final role = await (_db.select(
      _db.roles,
    )..where((r) => r.id.equals(user.roleId))).getSingle();
    final perms = await (_db.select(
      _db.rolePermissions,
    )..where((p) => p.roleId.equals(role.id))).get();
    return AppUser(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      roleKey: role.key,
      roleName: role.name,
      permissions: perms.map((p) => p.permission).toSet(),
      biometricEnabled: user.biometricEnabled,
      hasPin: user.pinHash != null,
      zoneScope: scopeFor(role, user),
      memberId: user.memberId,
      roleKeys: {role.key},
    );
  }
}
