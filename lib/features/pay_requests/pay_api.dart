import '../../data/sync/sync_api.dart';

/// The payment-request functions of the cloud, called with the caller's
/// token (supabase/migrations/..._payment_requests.sql). The Treasury or
/// the Welfare Committee asks members to pay; members say how they paid;
/// a treasurer confirms, which writes a normal receipt.
class PayApi {
  PayApi(this._api, this.token);

  final SyncApi _api;
  final String token;

  static List<Map<String, dynamic>> _list(Object? o) => [
    for (final x in (o as List?) ?? const [])
      Map<String, dynamic>.from(x as Map),
  ];

  /// Open requests addressed to the signed-in member, each with `mine`
  /// (what they reported, or null).
  Future<List<Map<String, dynamic>>> mine() async =>
      _list(await _api.rpc('pay_requests_mine', {'token': token}));

  /// [method] is `momo`, `bank` or `cash`.
  Future<void> submit(
    String requestId, {
    required int amount,
    required String method,
    String? reference,
    DateTime? paidOn,
    String? note,
  }) => _api.rpc('pay_claim_submit', {
    'token': token,
    'request': requestId,
    'amount': amount,
    'method': method,
    'reference': reference,
    'paid_on': paidOn == null ? null : _day(paidOn),
    'note': note,
  });

  /// For officers: what they may do, the contribution types and zones to
  /// choose from, and the requests they can see.
  Future<Map<String, dynamic>> list() async => Map<String, dynamic>.from(
    await _api.rpc('pay_requests_list', {'token': token}) as Map,
  );

  /// [office] is `treasury` or `welfare`. [zoneIds] null asks every
  /// active member.
  Future<void> create({
    required String office,
    required String title,
    required String typeId,
    int? amount,
    String? period,
    DateTime? dueOn,
    List<String>? zoneIds,
    String? payTo,
    String? details,
  }) => _api.rpc('pay_request_create', {
    'token': token,
    'office': office,
    'title': title,
    'type_id': typeId,
    'amount': amount,
    'period': period,
    'due_on': dueOn == null ? null : _day(dueOn),
    'zones': zoneIds,
    'pay_to': payTo,
    'details': details,
  });

  Future<void> close(String requestId) =>
      _api.rpc('pay_request_close', {'token': token, 'id': requestId});

  Future<List<Map<String, dynamic>>> claims(String requestId) async => _list(
    await _api.rpc('pay_claims_for', {'token': token, 'request': requestId}),
  );

  /// Confirms that the money arrived (writes the receipt) or rejects the
  /// report; a rejection needs a [note] for the member.
  Future<Map<String, dynamic>> decide(
    String claimId, {
    required bool confirm,
    String? note,
  }) async => Map<String, dynamic>.from(
    await _api.rpc('pay_claim_decide', {
          'token': token,
          'claim': claimId,
          'confirm': confirm,
          'note': note,
        })
        as Map,
  );

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String payMethodLabel(String? m) => switch (m) {
  'momo' => 'Mobile Money',
  'bank' => 'Bank',
  'cash' => 'Cash',
  _ => m ?? '',
};

String payError(Object e) => e is SyncException
    ? (e.offline ? 'This needs internet. Connect and try again.' : e.message)
    : 'Something went wrong. Please try again.';
