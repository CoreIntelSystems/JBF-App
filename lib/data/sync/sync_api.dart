import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
    this.scope,
    this.zones,
  });
  final List<SyncRow> rows;
  final int lastSeq;
  final bool more;

  /// Changes when the zones this phone may hold, or who is in them,
  /// change; the phone then downloads again from the start.
  final String? scope;

  /// The zones this phone is limited to; null for the whole association.
  final List<String>? zones;
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

  /// Calls a cloud function by name and returns its JSON answer. Used by
  /// elections, which pass the answers straight to their screens.
  Future<Object?> rpc(String fn, Map<String, Object?> args) => _call(fn, args);

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
      scope: r['scope'] as String?,
      zones: r['zones'] == null
          ? null
          : [for (final z in r['zones'] as List) '$z'],
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

  /// Member ID sign-in (see supabase/functions/member-auth). [action] is
  /// `activate` (first time, checked with [phone]), `sign_in` or
  /// `change_password`. With [check] the password is only confirmed.
  Future<MemberAuthResult> memberAuth({
    required String action,
    required String org,
    required String memberNo,
    String? password,
    String? newPassword,
    String? phone,
    String? deviceName,
    bool check = false,
  }) async {
    final r =
        (await _call('fn:member-auth', {
              'action': action,
              'org': org,
              'member_no': memberNo,
              'password': ?password,
              'new_password': ?newPassword,
              'phone': ?phone,
              'device_name': ?deviceName,
              'check': check,
            }))!
            as Map;
    return MemberAuthResult.fromJson(r);
  }

  /// Everything a member sees in the app, as JSON (cached for offline use).
  Future<Map<String, Object?>> memberHome(String sessionToken) async =>
      ((await _call('member_home', {'token': sessionToken}))! as Map)
          .cast<String, Object?>();

  /// A member from the founding list corrects their own details and
  /// zones. [zoneIds] null leaves their zones as they are.
  Future<void> memberUpdateProfile(
    String sessionToken,
    Map<String, String?> patch, {
    List<String>? zoneIds,
  }) => _call('member_update_profile', {
    'token': sessionToken,
    'patch': patch,
    'zone_ids': zoneIds,
  });

  /// A member chooses to be in welfare, or leaves it.
  Future<void> welfareJoin(String sessionToken) =>
      _call('welfare_join', {'token': sessionToken});
  Future<void> welfareLeave(String sessionToken) =>
      _call('welfare_leave', {'token': sessionToken});

  Future<void> memberSignOut(String sessionToken) =>
      _call('member_sign_out', {'token': sessionToken});

  /// An officer clears a member's password so they activate again.
  Future<void> memberResetSignIn(String token, String memberId) =>
      _call('member_reset_sign_in', {'token': token, 'member': memberId});

  /// The chats this person is in. [asName] names the person on phones
  /// joined before member sign-in.
  Future<List<ChatChannel>> chatChannels(String token, {String? asName}) async {
    final r =
        (await _call('chat_channels', {'token': token, 'as_name': asName}))!
            as List;
    return [
      for (final c in r.cast<Map>())
        ChatChannel(
          id: c['id'] as String,
          name: c['name'] as String,
          canPost: c['post'] == true,
          last: c['last'] as String?,
          lastAt: DateTime.tryParse('${c['last_at']}')?.toLocal(),
        ),
    ];
  }

  Future<List<ChatMessage>> chatMessages(
    String token,
    String channel, {
    DateTime? after,
    String? asName,
  }) async {
    final r =
        (await _call('chat_messages', {
              'token': token,
              'channel': channel,
              'after': after?.toUtc().toIso8601String(),
              'as_name': asName,
            }))!
            as List;
    return [
      for (final m in r.cast<Map>())
        ChatMessage(
          id: m['id'] as String,
          author: m['author'] as String? ?? '',
          authorKey: m['author_key'] as String?,
          authorWhatsapp: m['author_whatsapp'] as String?,
          zones: [for (final z in (m['zones'] as List? ?? [])) '$z'],
          body: m['body'] as String? ?? '',
          at: DateTime.parse(m['at'] as String).toLocal(),
          mine: m['mine'] == true,
          kind: m['kind'] as String? ?? 'text',
          file: m['file'] is Map
              ? ChatFile(
                  id: (m['file'] as Map)['id'] as String,
                  name: (m['file'] as Map)['name'] as String? ?? 'file',
                  mime: (m['file'] as Map)['mime'] as String? ?? '',
                  size: ((m['file'] as Map)['size'] as num?)?.toInt() ?? 0,
                )
              : null,
          reply: m['reply'] is Map
              ? ChatQuote(
                  id: (m['reply'] as Map)['id'] as String,
                  author: (m['reply'] as Map)['author'] as String? ?? '',
                  body: (m['reply'] as Map)['body'] as String? ?? '',
                  kind: (m['reply'] as Map)['kind'] as String? ?? 'text',
                )
              : null,
        ),
    ];
  }

  Future<void> chatSend(
    String token,
    String channel,
    String body, {
    String? asName,
  }) => _call('chat_send', {
    'token': token,
    'channel': channel,
    'body': body,
    'as_name': asName,
  });

  /// Sends a message, optionally answering [replyTo], or a sticker, a
  /// picture or a document ([kind] 'sticker', 'image' or 'file'; the file
  /// goes as base64 in [fileData]).
  Future<void> chatPost(
    String token,
    String channel,
    String body, {
    String? replyTo,
    String kind = 'text',
    String? fileName,
    String? fileMime,
    String? fileData,
    String? asName,
  }) => _call('chat_post', {
    'token': token,
    'channel': channel,
    'body': body,
    'reply_to': replyTo,
    'kind': kind,
    'file_name': fileName,
    'file_mime': fileMime,
    'file_data': fileData,
    'as_name': asName,
  });

  /// The bytes of a picture or document in a chat.
  Future<Uint8List> chatFile(
    String token,
    String channel,
    String fileId, {
    String? asName,
  }) async {
    final r =
        (await _call('chat_file', {
              'token': token,
              'channel': channel,
              'file_id': fileId,
              'as_name': asName,
            }))!
            as Map;
    return base64Decode(r['data'] as String);
  }

  /// Profile pictures (data URLs) of the people writing in a chat, by
  /// member key.
  Future<Map<String, String>> chatAvatars(
    String token,
    String channel, {
    String? asName,
  }) async {
    final r =
        (await _call('chat_avatars', {
              'token': token,
              'channel': channel,
              'as_name': asName,
            }))!
            as Map;
    return {for (final e in r.entries) '${e.key}': '${e.value}'};
  }

  /// My own chat picture as a data URL, or null when none is set.
  Future<String?> avatarGet(String token, {String? asName}) async {
    final r =
        (await _call('avatar_get', {'token': token, 'as_name': asName}))!
            as Map;
    return r['photo'] as String?;
  }

  /// Sets my chat picture (a data URL), or clears it with null.
  Future<void> avatarSet(String token, String? photo, {String? asName}) =>
      _call('avatar_set', {'token': token, 'photo': photo, 'as_name': asName});

  /// Sends a complaint about a member to the Disciplinary Committee.
  Future<void> disciplineFile(
    String token,
    String memberId,
    String details, {
    String? asName,
  }) => _call('discipline_file', {
    'token': token,
    'member': memberId,
    'details': details,
    'as_name': asName,
  });

  Future<List<DisciplineCase>> disciplineList(
    String token, {
    String? memberId,
    String? asName,
  }) async {
    final r =
        (await _call('discipline_list', {
              'token': token,
              'member': memberId,
              'as_name': asName,
            }))!
            as List;
    return [
      for (final c in r.cast<Map>())
        DisciplineCase(
          id: c['id'] as String,
          memberId: c['member'] as String,
          memberName: c['member_name'] as String? ?? 'Unknown member',
          memberNo: c['member_no'] as String?,
          kind: c['kind'] as String,
          details: c['details'] as String? ?? '',
          by: c['by'] as String? ?? '',
          open: c['status'] == 'open',
          at: DateTime.parse(c['at'] as String).toLocal(),
        ),
    ];
  }

  /// Sends a warning to a member and/or closes a complaint.
  Future<void> disciplineWarn(
    String token,
    String memberId, {
    String? warning,
    String? closeCase,
    String? asName,
  }) => _call('discipline_warn', {
    'token': token,
    'member': memberId,
    'details': warning,
    'close_case': closeCase,
    'as_name': asName,
  });

  /// How many members there are and how many have activated sign-in.
  Future<({int members, int activated})> activationSummary(String token) async {
    final r = (await _call('activation_summary', {'token': token}))! as Map;
    return (
      members: (r['members'] as num).toInt(),
      activated: (r['activated'] as num).toInt(),
    );
  }

  Future<MemberAccountStatus> memberAccountStatus(
    String token,
    String memberId,
  ) async {
    final r =
        (await _call('member_account_status', {
              'token': token,
              'member': memberId,
            }))!
            as Map;
    return MemberAccountStatus(
      activated: r['activated'] == true,
      activatedAt: DateTime.tryParse('${r['activated_at']}')?.toLocal(),
      resetAt: DateTime.tryParse('${r['reset_at']}')?.toLocal(),
      resetBy: r['reset_by'] as String?,
    );
  }
}

/// A group chat someone is in.
class ChatChannel {
  const ChatChannel({
    required this.id,
    required this.name,
    required this.canPost,
    this.last,
    this.lastAt,
  });
  final String id;
  final String name;
  final bool canPost;
  final String? last;
  final DateTime? lastAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.at,
    required this.mine,
    this.authorKey,
    this.authorWhatsapp,
    this.zones = const [],
    this.kind = 'text',
    this.file,
    this.reply,
  });
  final String id;
  final String author;
  final String? authorKey;

  /// The sender's WhatsApp name, so people recognise them from the group.
  final String? authorWhatsapp;

  /// The sender's zones.
  final List<String> zones;
  final String body;
  final DateTime at;
  final bool mine;

  /// 'text', 'image', 'file' or 'sticker'.
  final String kind;
  final ChatFile? file;

  /// The message this one answers.
  final ChatQuote? reply;
}

class ChatFile {
  const ChatFile({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
  });
  final String id;
  final String name;
  final String mime;
  final int size;
}

/// The message a reply quotes.
class ChatQuote {
  const ChatQuote({
    required this.id,
    required this.author,
    required this.body,
    this.kind = 'text',
  });
  final String id;
  final String author;
  final String body;
  final String kind;
}

/// A complaint or warning about a member (Disciplinary Committee).
class DisciplineCase {
  const DisciplineCase({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.kind,
    required this.details,
    required this.by,
    required this.open,
    required this.at,
    this.memberNo,
  });
  final String id;
  final String memberId;
  final String memberName;
  final String? memberNo;

  /// `complaint` or `warning`.
  final String kind;
  final String details;
  final String by;
  final bool open;
  final DateTime at;
}

/// The outcome of a member ID sign-in: a member session for ordinary
/// members, a synced phone for people with an executive role, or just a
/// confirmed password.
sealed class MemberAuthResult {
  const MemberAuthResult();

  factory MemberAuthResult.fromJson(Map r) => switch (r['kind']) {
    'member' => MemberSession(
      token: r['token'] as String,
      memberKey: r['member_key'] as String,
      memberNo: r['member_no'] as String? ?? '',
      name: r['name'] as String? ?? '',
      orgName: r['org_name'] as String? ?? '',
    ),
    'officer' => OfficerSignIn(
      Enrollment.fromJson(r),
      r['member_key'] as String,
    ),
    _ => const MemberChecked(),
  };
}

class MemberChecked extends MemberAuthResult {
  const MemberChecked();
}

class OfficerSignIn extends MemberAuthResult {
  const OfficerSignIn(this.enrollment, this.memberKey);
  final Enrollment enrollment;
  final String memberKey;
}

class MemberSession extends MemberAuthResult {
  const MemberSession({
    required this.token,
    required this.memberKey,
    required this.memberNo,
    required this.name,
    required this.orgName,
  });
  final String token;
  final String memberKey;
  final String memberNo;
  final String name;
  final String orgName;

  Map<String, Object?> toJson() => {
    'kind': 'member',
    'token': token,
    'member_key': memberKey,
    'member_no': memberNo,
    'name': name,
    'org_name': orgName,
  };
}

class MemberAccountStatus {
  const MemberAccountStatus({
    required this.activated,
    this.activatedAt,
    this.resetAt,
    this.resetBy,
  });
  final bool activated;
  final DateTime? activatedAt;
  final DateTime? resetAt;
  final String? resetBy;
}

/// What an ordinary member sees in the app (see member_home).
class MemberHome {
  const MemberHome({
    required this.statement,
    required this.officer,
    required this.welfare,
    required this.events,
    required this.executives,
    required this.directory,
    required this.announcements,
    this.warnings = const [],
    this.roles = const [],
    this.selfEdit = false,
    this.profile = const {},
    this.zoneOptions = const [],
    this.zoneIds = const [],
    this.zonesLocked = false,
    this.whatsappName,
    this.standing = const WelfareStanding(),
  });
  final MemberStatement statement;

  /// Whether they are in welfare (a choice), and how they are doing.
  final WelfareStanding standing;

  /// The name the member uses on WhatsApp. Every member may change it.
  final String? whatsappName;

  /// The member has been given an executive role since signing in.
  final bool officer;
  final List<HomeWelfareCase> welfare;
  final List<HomeEvent> events;
  final List<HomeExecutive> executives;
  final List<HomeDirectoryEntry> directory;
  final List<String> announcements;

  /// Warnings from the Disciplinary Committee: (when, what).
  final List<(DateTime?, String)> warnings;

  /// The executive roles this member holds, for their ID card.
  final List<String> roles;

  /// The member may correct their own details and zones.
  final bool selfEdit;

  /// Their current details, by field name (only when [selfEdit]).
  final Map<String, String> profile;

  /// Zones they can choose from: (id, name).
  final List<(String, String)> zoneOptions;

  /// Their current zones' ids, main zone first.
  final List<String> zoneIds;

  /// They have already used their one chance to choose their zones.
  final bool zonesLocked;

  static List<Map> _list(Object? v) => (v as List? ?? const []).cast<Map>();

  factory MemberHome.fromJson(Map r) => MemberHome(
    statement: MemberStatement.fromJson(r),
    officer: r['officer'] == true,
    welfare: [
      for (final w in _list(r['welfare']))
        HomeWelfareCase(
          caseNo: w['case_no'] as String? ?? '',
          type: w['type'] as String?,
          status: w['status'] as String? ?? '',
          amount: (w['amount'] as num?)?.toInt() ?? 0,
          occurredOn: DateTime.tryParse('${w['occurred_on']}'),
          beneficiary: w['beneficiary'] as String?,
        ),
    ],
    events: [
      for (final e in _list(r['events']))
        HomeEvent(
          name: e['name'] as String? ?? '',
          meeting: e['kind'] == 'meeting',
          date: DateTime.tryParse('${e['date']}'),
          venue: e['venue'] as String?,
          description: e['description'] as String?,
        ),
    ],
    executives: [
      for (final x in _list(r['executives']))
        HomeExecutive(
          name: x['name'] as String? ?? '',
          position: x['position'] as String? ?? '',
          zone: x['zone'] as String?,
        ),
    ],
    directory: [
      for (final d in _list(r['directory']))
        HomeDirectoryEntry(
          name: d['name'] as String? ?? '',
          whatsappName: d['whatsapp_name'] as String?,
          zones: [for (final z in (d['zones'] as List? ?? const [])) '$z'],
        ),
    ],
    announcements: [
      for (final a in (r['announcements'] as List? ?? const [])) '$a',
    ],
    roles: [for (final x in (r['roles'] as List? ?? const [])) '$x'],
    selfEdit: r['self_edit'] == true,
    profile: {
      for (final e in ((r['profile'] as Map?) ?? const {}).entries)
        if (e.value != null) '${e.key}': '${e.value}',
    },
    zoneOptions: [
      for (final z in _list(r['zone_options']))
        if (z['code'] != 0) ('${z['id']}', '${z['name']}'),
    ],
    zoneIds: [for (final z in (r['zone_ids'] as List? ?? const [])) '$z'],
    zonesLocked: r['zones_locked'] == true,
    whatsappName: r['whatsapp_name'] as String?,
    standing: WelfareStanding.fromJson(
      (r['welfare_standing'] as Map?) ?? const {},
    ),
    warnings: [
      for (final w in _list(r['warnings']))
        (DateTime.tryParse('${w['at']}')?.toLocal(), '${w['details']}'),
    ],
  );
}

class WelfareStanding {
  const WelfareStanding({
    this.status = 'none',
    this.since,
    this.note,
    this.duesBehind = 0,
    this.roundsMissed = 0,
  });
  factory WelfareStanding.fromJson(Map r) => WelfareStanding(
    status: r['status'] as String? ?? 'none',
    since: DateTime.tryParse('${r['since']}'),
    note: r['note'] as String?,
    duesBehind: (r['dues_behind'] as num?)?.toInt() ?? 0,
    roundsMissed: (r['rounds_missed'] as num?)?.toInt() ?? 0,
  );

  /// none, member or disqualified.
  final String status;
  final DateTime? since;
  final String? note;

  /// Finished months of welfare dues not paid, and finished welfare
  /// contribution requests not paid. Three in a row disqualifies.
  final int duesBehind;
  final int roundsMissed;

  bool get isMember => status == 'member';
  bool get disqualified => status == 'disqualified';
}

class HomeWelfareCase {
  const HomeWelfareCase({
    required this.caseNo,
    required this.status,
    required this.amount,
    this.type,
    this.occurredOn,
    this.beneficiary,
  });
  final String caseNo;
  final String? type;
  final String status;
  final int amount;
  final DateTime? occurredOn;
  final String? beneficiary;
}

class HomeEvent {
  const HomeEvent({
    required this.name,
    required this.meeting,
    this.date,
    this.venue,
    this.description,
  });
  final String name;
  final bool meeting;
  final DateTime? date;
  final String? venue;
  final String? description;
}

class HomeExecutive {
  const HomeExecutive({required this.name, required this.position, this.zone});
  final String name;
  final String position;
  final String? zone;
}

class HomeDirectoryEntry {
  const HomeDirectoryEntry({
    required this.name,
    required this.zones,
    this.whatsappName,
  });
  final String name;
  final String? whatsappName;
  final List<String> zones;
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
