import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';

import '../../domain/password_hasher.dart';
import '../database.dart';
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

class AuthRepository {
  AuthRepository(
    this._db,
    this._audit, {
    PasswordHasher hasher = const PasswordHasher(),
    DateTime Function()? clock,
  }) : _hasher = hasher,
       _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final AuditRepository _audit;
  final PasswordHasher _hasher;
  final DateTime Function() _now;

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
    final actor = Actor(userId: user?.id, username: name, deviceId: deviceId);

    if (user == null || !user.isActive || user.deletedAt != null) {
      await _audit.log(actor, 'login.failed', newValue: {'reason': 'unknown'});
      throw AuthException('Wrong username or password.');
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
            : 'Wrong username or password.',
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
    );
  }
}
