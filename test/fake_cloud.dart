import 'package:jbf_app/data/sync/sync_api.dart';
import 'package:jbf_app/domain/password_hasher.dart';

/// The cloud functions of supabase/migrations, in memory.
class FakeCloud {
  final devices = <String, ({String id, bool admin, String? series})>{};
  final _codes = <String, bool>{};
  final _records = <String, CloudRecord>{};
  var _seq = 0;
  var _n = 0;
  final revoked = <String>{};

  String newCode({bool admin = false}) {
    final code = 'CODE${_n++}';
    _codes[code] = admin;
    return code;
  }

  int get count => _records.length;

  SyncApi get api => SyncApi(call);

  /// Member passwords (plain, for tests) by member key.
  final memberPasswords = <String, String>{};
  final memberSessions = <String, String>{};

  /// The member each phone signed in as, by token.
  final deviceMember = <String, String>{};

  Future<Object?> call(String fn, Map<String, Object?> a) async {
    if (fn == 'fn:sync-sign-in') return _signIn(a);
    if (fn == 'fn:member-auth') return _memberAuth(a);
    if (fn == 'member_home') {
      final key = memberSessions[a['token']];
      if (key == null) throw SyncException('Please sign in again.');
      final m = _records['members|$key']!.data;
      return {
        'org': 'June Borns Family',
        'member': {
          'name': m['full_name'],
          'member_no': m['member_no'],
          'status': m['status'],
          'joined': '2026-01-01',
          'zones': <String>[],
        },
        'dues': <Object>[],
        'payments': <Object>[],
        'officer': _isOfficer(key),
        'welfare': <Object>[],
        'events': <Object>[],
        'executives': <Object>[],
        'directory': [
          for (final r in _records.values)
            if (r.t == 'members') {'name': r.data['full_name'], 'zones': []},
        ],
        'announcements': <Object>[],
      };
    }
    if (fn == 'member_sign_out') {
      memberSessions.remove(a['token']);
      return null;
    }
    if (fn == 'sync_enroll') {
      final admin = _codes.remove(a['code']);
      if (admin == null) {
        throw SyncException('This code is not valid. Ask for a new one.');
      }
      if (a['series'] == null && devices.isNotEmpty) {
        throw SyncException('Give this phone a number series, such as Z3.');
      }
      final token = 'tok${_n++}';
      devices[token] = (
        id: 'dev${_n++}',
        admin: admin,
        series: a['series'] as String?,
      );
      return {
        'token': token,
        'device_id': devices[token]!.id,
        'org_id': 'org1',
        'org_name': 'June Borns Family',
        'is_admin': admin,
        'records': _records.length,
      };
    }
    final d = devices[a['token']];
    if (d == null || revoked.contains(d.id)) {
      throw SyncException('This phone has been removed from cloud sync.');
    }
    switch (fn) {
      case 'sync_push':
        var accepted = 0;
        for (final r in (a['rows']! as List).cast<Map<String, Object?>>()) {
          final key = '${r['t']}|${r['k']}';
          final u = DateTime.parse(r['u']! as String);
          var data = Map<String, Object?>.from(r['d']! as Map);
          final old = _records[key];
          if (old != null && u.isBefore(old.u)) continue;
          var by = d.id;
          if (old != null) {
            if (r['t'] == 'audit_logs') data = old.data;
            if (r['t'] == 'payments' || r['t'] == 'expenses') {
              for (final k in [
                'amount',
                'member_id',
                'receipt_no',
                'paid_on',
              ]) {
                if (old.data.containsKey(k)) data[k] = old.data[k];
              }
              if (old.data['status'] == 'voided') {
                for (final k in ['status', 'void_reason', 'voided_at']) {
                  data[k] = old.data[k];
                }
              }
            }
            if (data.toString() != (r['d']! as Map).toString()) by = '';
          }
          _records[key] = CloudRecord(
            r['t']! as String,
            r['k']! as String,
            data,
            u,
            by,
            ++_seq,
          );
          accepted++;
        }
        return {'accepted': accepted};
      case 'sync_pull':
        final since = a['since']! as int;
        final max = a['max_rows']! as int;
        final zones = _zonesOf(a['token']! as String);
        final members = zones == null ? null : _zoneMembers(zones);
        bool visible(CloudRecord r) =>
            members == null ||
            switch (r.t) {
              'members' => members.contains(r.k),
              'member_zones' ||
              'payments' ||
              'welfare_cases' ||
              'attendance_records' => members.contains(r.data['member_id']),
              'users' || 'audit_logs' || 'expenses' => false,
              _ => true,
            };
        final page =
            (_records.values.where((r) => r.seq > since).toList()
                  ..sort((x, y) => x.seq.compareTo(y.seq)))
                .take(max)
                .toList();
        final last = page.isEmpty ? since : page.last.seq;
        final scopeSeq = zones == null
            ? 0
            : _records.values
                  .where(
                    (r) =>
                        r.t == 'member_zones' &&
                        zones.contains(r.data['zone_id']) &&
                        r.by != d.id,
                  )
                  .fold(0, (m, r) => r.seq > m ? r.seq : m);
        return {
          'scope': zones == null ? 'all' : '${zones.join(',')}|$scopeSeq',
          'zones': zones?.toList(),
          'rows': [
            for (final r in page)
              if (r.by != d.id && visible(r))
                {
                  't': r.t,
                  'k': r.k,
                  'd': r.data,
                  'u': r.u.toUtc().toIso8601String(),
                },
          ],
          'last_seq': last,
          'more': _records.values.any((r) => r.seq > last),
        };
      case 'member_reset_sign_in':
        memberPasswords.remove(a['member']);
        memberSessions.removeWhere((_, k) => k == a['member']);
        return {'ok': true};
      case 'activation_summary':
        return {'members': 453, 'activated': memberPasswords.length};
      case 'member_account_status':
        return {'activated': memberPasswords.containsKey(a['member'])};
      case 'sync_list_devices':
        return [
          for (final e in devices.entries)
            {
              'id': e.value.id,
              'name': 'Phone',
              'series': e.value.series,
              'is_admin': e.value.admin,
              'last_seen_at': null,
              'revoked': false,
              'me': e.key == a['token'],
            },
        ];
      case 'sync_create_code':
        if (!d.admin) {
          throw SyncException('Only the main phone can add phones.');
        }
        return newCode(admin: a['admin']! as bool);
    }
    throw UnimplementedError(fn);
  }
}

extension on FakeCloud {
  /// Zones a phone is limited to (zone executives), or null.
  Set<String>? _zonesOf(String token) {
    final key = deviceMember[token];
    if (key == null) return null;
    final roles = {
      for (final r in _records.values)
        if (r.t == 'roles') r.k: r.data,
    };
    final held = [
      for (final r in _records.values)
        if (r.t == 'role_assignments' &&
            r.data['member_id'] == key &&
            r.data['ends_on'] == null &&
            r.data['deleted_at'] == null &&
            roles[r.data['role_id']]?['key'] != 'member')
          r.data,
    ];
    if (held.any((h) => roles[h['role_id']]?['level'] != 'zone')) return null;
    return {for (final h in held) ...'${h['zone_ids'] ?? ''}'.split(',')}
      ..remove('');
  }

  Set<String> _zoneMembers(Set<String> zones) => {
    for (final r in _records.values)
      if (r.t == 'member_zones' &&
          r.data['deleted_at'] == null &&
          zones.contains(r.data['zone_id']))
        r.data['member_id']! as String,
  };

  bool _isOfficer(String memberKey) => _records.values.any(
    (r) =>
        (r.t == 'role_assignments' &&
            r.data['member_id'] == memberKey &&
            r.data['ends_on'] == null &&
            r.data['deleted_at'] == null) ||
        (r.t == 'users' &&
            r.data['member_id'] == memberKey &&
            r.data['is_active'] == 1),
  );

  Future<Object?> _memberAuth(Map<String, Object?> a) async {
    final no = (a['member_no']! as String).trim().toUpperCase();
    final m = _records.values
        .where(
          (r) =>
              r.t == 'members' &&
              (r.data['member_no']! as String).toUpperCase() == no,
        )
        .firstOrNull;
    final key = m?.k;
    String digits(Object? v) {
      final d = '${v ?? ''}'.replaceAll(RegExp(r'\D'), '');
      return d.length > 9 ? d.substring(d.length - 9) : d;
    }

    switch (a['action']) {
      case 'activate':
        if (key == null ||
            digits(a['phone']).length != 9 ||
            digits(a['phone']) != digits(m!.data['phone'])) {
          throw SyncException(
            'Member ID and phone number do not match our records.',
          );
        }
        memberPasswords[key] = a['new_password']! as String;
      case 'sign_in' || 'change_password':
        if (key != null && !memberPasswords.containsKey(key)) {
          throw SyncException(
            'Activate your account first with your member ID and phone '
            'number.',
          );
        }
        if (key == null || memberPasswords[key] != a['password']) {
          throw SyncException('Wrong member ID or password.');
        }
        if (a['action'] == 'change_password') {
          memberPasswords[key] = a['new_password']! as String;
          return {'kind': 'checked'};
        }
    }
    if (a['check'] == true) return {'kind': 'checked'};
    if (_isOfficer(key!)) {
      var n = 2;
      while (devices.values.any((d) => d.series == 'P$n')) {
        n++;
      }
      final token = 'tok${_n++}';
      devices[token] = (id: 'dev${_n++}', admin: false, series: 'P$n');
      deviceMember[token] = key;
      return {
        'kind': 'officer',
        'member_key': key,
        'token': token,
        'device_id': devices[token]!.id,
        'org_id': 'org1',
        'org_name': 'June Borns Family',
        'is_admin': false,
        'series': 'P$n',
        'records': _records.length,
      };
    }
    final token = 'mem${_n++}';
    memberSessions[token] = key;
    return {
      'kind': 'member',
      'token': token,
      'member_key': key,
      'member_no': m!.data['member_no'],
      'name': m.data['full_name'],
      'org_name': 'June Borns Family',
    };
  }

  Future<Object?> _signIn(Map<String, Object?> a) async {
    if ((a['org']! as String).toUpperCase() != 'JBF') {
      throw SyncException('No organisation called ${a['org']}.');
    }
    if (devices.isEmpty) {
      throw SyncException('June Borns Family is not online yet.');
    }
    final user = _records.values
        .where(
          (r) =>
              r.t == 'users' &&
              (r.data['username']! as String).toLowerCase() ==
                  (a['username']! as String).toLowerCase(),
        )
        .firstOrNull;
    final ok =
        user != null &&
        user.data['is_active'] == 1 &&
        await const PasswordHasher().verify(
          a['password']! as String,
          user.data['password_hash']! as String,
        );
    if (!ok) throw SyncException('Wrong username or password.');
    var n = 2;
    while (devices.values.any((d) => d.series == 'P$n')) {
      n++;
    }
    final token = 'tok${_n++}';
    devices[token] = (id: 'dev${_n++}', admin: false, series: 'P$n');
    return {
      'token': token,
      'device_id': devices[token]!.id,
      'org_id': 'org1',
      'org_name': 'June Borns Family',
      'is_admin': false,
      'series': 'P$n',
      'records': _records.length,
    };
  }
}

class CloudRecord {
  CloudRecord(this.t, this.k, this.data, this.u, this.by, this.seq);
  final String t;
  final String k;
  final Map<String, Object?> data;
  final DateTime u;
  final String by;
  final int seq;
}
