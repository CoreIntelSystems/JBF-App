import '../../data/sync/sync_api.dart';

/// The election functions of the cloud, called with the caller's token.
/// All counting and checking happens in the cloud; nothing here decides
/// who may vote or what the result is.
class ElectionApi {
  ElectionApi(this._api, this.token);

  final SyncApi _api;
  final String token;

  Future<({bool isEc, List<Map<String, dynamic>> elections})> list() async {
    final r = Map<String, dynamic>.from(
      (await _api.rpc('election_list', {'token': token}))! as Map,
    );
    return (
      isEc: r['is_ec'] == true,
      elections: [
        for (final e in (r['elections'] as List))
          Map<String, dynamic>.from(e as Map),
      ],
    );
  }

  Future<Map<String, dynamic>> get(String id) async =>
      Map<String, dynamic>.from(
        (await _api.rpc('election_get', {'token': token, 'eid': id}))! as Map,
      );

  Future<Map<String, dynamic>> results(String id) async =>
      Map<String, dynamic>.from(
        (await _api.rpc('election_results', {'token': token, 'eid': id}))!
            as Map,
      );

  Future<List<Map<String, dynamic>>> history(String id) async => [
    for (final h
        in (await _api.rpc('election_history', {'token': token, 'eid': id}))!
            as List)
      Map<String, dynamic>.from(h as Map),
  ];

  /// [choices] maps each post id to a candidate id or `abstain`.
  Future<void> vote(String id, Map<String, String> choices) => _api.rpc(
    'election_vote',
    {'token': token, 'eid': id, 'choices': choices},
  );

  Future<String> create({
    required String title,
    required String notes,
    required DateTime closesAt,
    required List<({String title, int seats})> posts,
  }) async {
    final r = Map<String, dynamic>.from(
      (await _api.rpc('election_create', {
            'token': token,
            'title': title,
            'notes': notes,
            'closes_at': closesAt.toUtc().toIso8601String(),
            'posts': [
              for (final p in posts) {'title': p.title, 'seats': p.seats},
            ],
          }))!
          as Map,
    );
    return r['id'] as String;
  }

  Future<List<Map<String, dynamic>>> findMember(String q) async => [
    for (final m
        in (await _api.rpc('election_find_member', {'token': token, 'q': q}))!
            as List)
      Map<String, dynamic>.from(m as Map),
  ];

  Future<void> setCandidate({
    required String postId,
    required String memberKey,
    String? manifesto,
    String? photo,
  }) => _api.rpc('election_set_candidate', {
    'token': token,
    'post': postId,
    'member': memberKey,
    'manifesto': manifesto,
    'photo': photo,
  });

  Future<Map<String, dynamic>> commission() async => Map<String, dynamic>.from(
    (await _api.rpc('election_commission', {'token': token}))! as Map,
  );

  /// [role] is `chair`, `secretary` or `member`.
  Future<void> appoint(String memberKey, String role) => _api.rpc(
    'election_appoint',
    {'token': token, 'member': memberKey, 'role': role},
  );

  Future<void> removeOfficer(String memberKey) => _api.rpc(
    'election_remove_officer',
    {'token': token, 'member': memberKey},
  );

  Future<void> open(String id) =>
      _api.rpc('election_open', {'token': token, 'eid': id});

  Future<void> close(String id) =>
      _api.rpc('election_close', {'token': token, 'eid': id});

  Future<void> cancel(String id) =>
      _api.rpc('election_cancel', {'token': token, 'eid': id});
}

/// A message for the screen from a failed call.
String electionError(Object e) => e is SyncException
    ? (e.offline ? 'Voting needs internet. Connect and try again.' : e.message)
    : 'Something went wrong. Please try again.';
