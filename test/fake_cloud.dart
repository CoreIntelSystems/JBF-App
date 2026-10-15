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

  Future<Object?> call(String fn, Map<String, Object?> a) async {
    if (fn == 'fn:sync-sign-in') return _signIn(a);
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
        final page =
            (_records.values.where((r) => r.seq > since).toList()
                  ..sort((x, y) => x.seq.compareTo(y.seq)))
                .take(max)
                .toList();
        final last = page.isEmpty ? since : page.last.seq;
        return {
          'rows': [
            for (final r in page)
              if (r.by != d.id)
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
