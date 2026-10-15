import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/cloud_config.dart';

/// A message fit to show on screen.
class SyncException implements Exception {
  SyncException(this.message, {this.offline = false});
  final String message;

  /// No connection: nothing is wrong, it will work later.
  final bool offline;

  @override
  String toString() => message;
}

/// One page of changes from other phones.
class SyncPage {
  const SyncPage({
    required this.rows,
    required this.lastSeq,
    required this.more,
  });
  final List<SyncRow> rows;
  final int lastSeq;
  final bool more;
}

/// A row as stored in the cloud: table, key, when it last changed, data.
class SyncRow {
  const SyncRow(this.table, this.key, this.updatedAt, this.data);
  final String table;
  final String key;
  final DateTime updatedAt;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
    't': table,
    'k': key,
    'u': updatedAt.toUtc().toIso8601String(),
    'd': data,
  };

  factory SyncRow.fromJson(Map<String, Object?> j) => SyncRow(
    j['t']! as String,
    j['k']! as String,
    DateTime.parse(j['u']! as String),
    (j['d']! as Map).cast<String, Object?>(),
  );
}

class Enrollment {
  const Enrollment({
    required this.token,
    required this.deviceId,
    required this.orgId,
    required this.orgName,
    required this.isAdmin,
    required this.records,
    this.series,
  });
  final String token;
  final String deviceId;
  final String orgId;
  final String orgName;
  final bool isAdmin;

  /// How many records the organisation already has in the cloud.
  final int records;

  /// Number series the cloud gave this phone, if any.
  final String? series;

  factory Enrollment.fromJson(Map r) => Enrollment(
    token: r['token'] as String,
    deviceId: r['device_id'] as String,
    orgId: r['org_id'] as String,
    orgName: r['org_name'] as String,
    isAdmin: r['is_admin'] as bool,
    records: (r['records'] as num).toInt(),
    series: r['series'] as String?,
  );
}

class CloudDevice {
  const CloudDevice({
    required this.id,
    required this.name,
    required this.series,
    required this.isAdmin,
    required this.lastSeenAt,
    required this.revoked,
    required this.isThisPhone,
  });
  final String id;
  final String name;
  final String? series;
  final bool isAdmin;
  final DateTime? lastSeenAt;
  final bool revoked;
  final bool isThisPhone;
}

/// Calls one cloud function with JSON arguments.
typedef SyncTransport =
    Future<Object?> Function(String function, Map<String, Object?> args);

/// The cloud sync functions (see supabase/migrations).
class SyncApi {
  SyncApi(this._call);

  /// Talks to the CoreIntel cloud over HTTPS.
  factory SyncApi.http({http.Client? client}) =>
      SyncApi(httpTransport(client ?? http.Client()));

  final SyncTransport _call;

  Future<Enrollment> enroll(
    String code,
    String deviceName, {
    String? series,
  }) async {
    final r =
        (await _call('sync_enroll', {
              'code': code,
              'device_name': deviceName,
              'series': series,
            }))!
            as Map;
    return Enrollment.fromJson(r);
  }

  /// Joins by signing in with an officer's app username and password.
  Future<Enrollment> signIn(
    String org,
    String username,
    String password,
    String deviceName,
  ) async {
    final r =
        (await _call('fn:sync-sign-in', {
              'org': org,
              'username': username,
              'password': password,
              'device_name': deviceName,
            }))!
            as Map;
    return Enrollment.fromJson(r);
  }

  Future<int> push(String token, List<SyncRow> rows) async {
    final r =
        (await _call('sync_push', {
              'token': token,
              'rows': [for (final row in rows) row.toJson()],
            }))!
            as Map;
    return (r['accepted'] as num).toInt();
  }

  Future<SyncPage> pull(String token, int since, {int max = 500}) async {
    final r =
        (await _call('sync_pull', {
              'token': token,
              'since': since,
              'max_rows': max,
            }))!
            as Map;
    return SyncPage(
      rows: [
        for (final row in r['rows'] as List)
          SyncRow.fromJson((row as Map).cast<String, Object?>()),
      ],
      lastSeq: (r['last_seq'] as num).toInt(),
      more: r['more'] as bool,
    );
  }

  /// A one-time code another phone uses to join (main phones only).
  Future<String> createCode(String token, {bool admin = false}) async =>
      (await _call('sync_create_code', {'token': token, 'admin': admin}))!
          as String;

  Future<List<CloudDevice>> devices(String token) async {
    final r = (await _call('sync_list_devices', {'token': token}))! as List;
    return [
      for (final d in r.cast<Map>())
        CloudDevice(
          id: d['id'] as String,
          name: d['name'] as String,
          series: d['series'] as String?,
          isAdmin: d['is_admin'] as bool,
          lastSeenAt: d['last_seen_at'] == null
              ? null
              : DateTime.parse(d['last_seen_at'] as String).toLocal(),
          revoked: d['revoked'] as bool,
          isThisPhone: d['me'] as bool,
        ),
    ];
  }

  Future<void> revoke(String token, String deviceId) =>
      _call('sync_revoke_device', {'token': token, 'device': deviceId});

  /// A member's own dues and payments, checked with their member ID and
  /// phone number. Needs no sign-in; the cloud locks repeated wrong tries.
  Future<MemberStatement> memberStatement(
    String org,
    String memberNo,
    String phone,
  ) async {
    final r =
        (await _call('portal_statement', {
              'org': org,
              'member_no': memberNo,
              'phone': phone,
            }))!
            as Map;
    if (r['error'] is String) throw SyncException(r['error'] as String);
    return MemberStatement.fromJson(r);
  }
}

/// What a member sees about themselves (see portal_statement).
class MemberStatement {
  const MemberStatement({
    required this.name,
    required this.memberNo,
    required this.status,
    required this.joined,
    required this.zones,
    required this.dues,
    required this.payments,
    this.updated,
  });
  final String name;
  final String memberNo;
  final String status;
  final DateTime? joined;
  final List<String> zones;
  final List<StatementDues> dues;
  final List<StatementPayment> payments;
  final DateTime? updated;

  factory MemberStatement.fromJson(Map r) {
    final m = r['member'] as Map;
    return MemberStatement(
      name: m['name'] as String? ?? '',
      memberNo: m['member_no'] as String? ?? '',
      status: m['status'] as String? ?? '',
      joined: DateTime.tryParse(m['joined'] as String? ?? ''),
      zones: [for (final z in (m['zones'] as List? ?? const [])) '$z'],
      dues: [
        for (final d in (r['dues'] as List? ?? const []).cast<Map>())
          StatementDues(
            name: d['name'] as String? ?? 'Dues',
            monthly: (d['monthly'] as num).toInt(),
            months: (d['months'] as num).toInt(),
            expected: (d['expected'] as num).toInt(),
            paid: (d['paid'] as num).toInt(),
            outstanding: (d['outstanding'] as num).toInt(),
            monthsBehind: (d['months_behind'] as num).toInt(),
            nextUnpaid: d['next_unpaid'] as String?,
          ),
      ],
      payments: [
        for (final p in (r['payments'] as List? ?? const []).cast<Map>())
          StatementPayment(
            receiptNo: p['receipt_no'] as String?,
            paidOn: DateTime.tryParse(p['paid_on'] as String? ?? ''),
            type: p['type'] as String?,
            period: p['period'] as String?,
            amount: (p['amount'] as num).toInt(),
            method: p['method'] as String?,
          ),
      ],
      updated: r['updated'] == null
          ? null
          : DateTime.tryParse(r['updated'] as String)?.toLocal(),
    );
  }
}

class StatementDues {
  const StatementDues({
    required this.name,
    required this.monthly,
    required this.months,
    required this.expected,
    required this.paid,
    required this.outstanding,
    required this.monthsBehind,
    this.nextUnpaid,
  });
  final String name;
  final int monthly;
  final int months;
  final int expected;
  final int paid;
  final int outstanding;
  final int monthsBehind;

  /// First month not yet covered, as `YYYY-MM`.
  final String? nextUnpaid;
}

class StatementPayment {
  const StatementPayment({
    required this.amount,
    this.receiptNo,
    this.paidOn,
    this.type,
    this.period,
    this.method,
  });
  final String? receiptNo;
  final DateTime? paidOn;
  final String? type;
  final String? period;
  final int amount;
  final String? method;
}

/// Calls `POST /rest/v1/rpc/<function>` on the Supabase project, or the
/// edge function `fn:<name>` at `/functions/v1/<name>`.
SyncTransport httpTransport(http.Client client) => (function, args) async {
  final http.Response res;
  try {
    res = await client
        .post(
          Uri.parse(
            function.startsWith('fn:')
                ? '${CloudConfig.url}/functions/v1/${function.substring(3)}'
                : '${CloudConfig.url}/rest/v1/rpc/$function',
          ),
          headers: {
            'apikey': CloudConfig.publishableKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(args),
        )
        .timeout(const Duration(seconds: 60));
  } on SocketException {
    throw SyncException(_offline, offline: true);
  } on TimeoutException {
    throw SyncException(_offline, offline: true);
  } on http.ClientException {
    throw SyncException(_offline, offline: true);
  }
  final body = res.body.isEmpty ? null : jsonDecode(res.body);
  if (res.statusCode >= 200 && res.statusCode < 300) return body;
  // Messages raised by the sync functions are written for people.
  if (body is Map && body['code'] == 'P0001' && body['message'] is String) {
    throw SyncException(body['message'] as String);
  }
  throw SyncException(
    'The cloud did not accept the request (${res.statusCode}). '
    'Try again later.',
  );
};

const _offline =
    'No internet connection. Your work is saved on this phone and will '
    'sync when you are back online.';
