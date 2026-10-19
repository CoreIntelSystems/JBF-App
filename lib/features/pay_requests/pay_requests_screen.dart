import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../chats/chats_screen.dart' show ChatAccess;
import 'pay_api.dart';

String _officeName(String? o) =>
    o == 'welfare' ? 'Welfare Committee' : 'Treasury';

DateTime? _day(Object? v) => v == null ? null : DateTime.tryParse('$v');

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// What one request asks for, in one line: amount, what for, due date.
String _askLine(Map<String, dynamic> r) => [
  if (r['amount'] != null) formatMoney(_int(r['amount'])),
  if (r['type'] != null) '${r['type']}',
  if (r['period'] != null) formatPeriod('${r['period']}'),
  if (_day(r['due_on']) case final d?) 'due ${formatDate(d)}',
].join(' · ');

// ---------------------------------------------------------------------------
// Members

/// Payments the Treasury or the Welfare Committee has asked of the signed-in
/// member, each with what the member reported. Shows nothing when there are
/// none or the cloud cannot be reached, so it can sit on any home screen.
class MyPaymentRequests extends StatefulWidget {
  const MyPaymentRequests({super.key, required this.access});

  final ChatAccess access;

  @override
  State<MyPaymentRequests> createState() => _MyPaymentRequestsState();
}

class _MyPaymentRequestsState extends State<MyPaymentRequests> {
  late final _api = PayApi(
    context.read<AppServices>().sync.api,
    widget.access.token,
  );
  List<Map<String, dynamic>> _requests = const [];
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.mine();
      if (mounted) {
        setState(() {
          _requests = r;
          _online = true;
        });
      }
    } catch (_) {
      // No internet or no member sign-in: the cards simply stay hidden.
    }
  }

  Future<void> _pay(Map<String, dynamic> r) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => PaidDialog(api: _api, request: r),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reported. Awaiting confirmation.')),
      );
      _load();
    }
  }

  /// Pay without being asked: choose what for, then report the payment.
  Future<void> _payOwn() async {
    final r = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SelfPayDialog(api: _api),
    );
    if (r == null || !mounted) return;
    if (r['receipt_no'] != null && r['id'] == null) {
      // Paid by MoMo: the receipt is already written.
      _load();
      return;
    }
    final status = (r['mine'] as Map?)?['status'];
    if (status == 'pending' || status == 'confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'pending'
                ? 'You already told the Treasurer about this payment. '
                      'It is waiting to be confirmed.'
                : 'This payment is already confirmed.',
          ),
        ),
      );
      _load();
      return;
    }
    await _pay(r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_online && _requests.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: const IconBadge(Icons.payments_outlined, size: 36),
            title: const Text(
              'Pay my dues',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Pay by Mobile Money, then report it'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _payOwn,
          ),
        ),
        if (_requests.isNotEmpty) const SectionTitle('Payments asked of me'),
        for (final r in _requests) _card(r),
      ],
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final ink = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final mine = r['mine'] is Map
        ? Map<String, dynamic>.from(r['mine'] as Map)
        : null;
    final status = mine?['status'] as String?;
    final closed = r['closed'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  r['office'] == 'welfare'
                      ? Icons.volunteer_activism
                      : Icons.account_balance_wallet_outlined,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r['title']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'From the ${_officeName(r['office'] as String?)}',
                        style: TextStyle(color: ink.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(_askLine(r)),
            if (r['details'] != null) ...[
              const SizedBox(height: 6),
              Text('${r['details']}'),
            ],
            if (r['pay_to'] != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText('How to pay: ${r['pay_to']}'),
              ),
            ],
            const SizedBox(height: 12),
            switch (status) {
              'pending' => _state(
                Icons.hourglass_top_rounded,
                scheme.tertiary,
                'You reported ${formatMoney(_int(mine!['amount']))} by '
                '${payMethodLabel(mine['method'] as String?)}. '
                'Waiting for the Treasurer to confirm.',
              ),
              'confirmed' => _state(
                Icons.check_circle_rounded,
                scheme.primary,
                'Confirmed. Receipt ${mine!['receipt_no']}.',
              ),
              _ => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == 'rejected')
                    _state(
                      Icons.error_outline_rounded,
                      scheme.error,
                      'Your report was not accepted: '
                      '${mine!['decision_note'] ?? ''}',
                    ),
                  if (!closed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.icon(
                        onPressed: () => _pay(r),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(
                          status == 'rejected' ? 'Report again' : 'I have paid',
                        ),
                      ),
                    )
                  else
                    Text(
                      'This request is closed.',
                      style: TextStyle(color: ink.muted),
                    ),
                ],
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _state(IconData icon, Color color, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

/// A member pays their own dues: pick what for (and the month), then pay by
/// MTN MoMo right here when that is switched on, or pay by hand and report
/// it. Pops the request to report on (hand payment), or a map with
/// `receipt_no` once a MoMo payment went through.
class SelfPayDialog extends StatefulWidget {
  const SelfPayDialog({super.key, required this.api});

  final PayApi api;

  @override
  State<SelfPayDialog> createState() => _SelfPayDialogState();
}

class _SelfPayDialogState extends State<SelfPayDialog> {
  Map<String, dynamic>? _options;
  bool _momo = false;
  String? _typeId;
  late String _period = _monthKey(DateTime.now());
  final _amount = TextEditingController();
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;

  /// `form`, `wait` (waiting for the approval on the phone) or `done`.
  String _stage = 'form';
  String? _momoId;
  Timer? _timer;
  int _polls = 0;
  Map<String, dynamic>? _result;

  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// The last twelve months and the next two, newest first.
  List<String> get _months {
    final now = DateTime.now();
    return [
      for (var i = -2; i < 12; i++)
        _monthKey(DateTime(now.year, now.month - i)),
    ];
  }

  @override
  void initState() {
    super.initState();
    widget.api
        .selfOptions()
        .then((o) {
          if (!mounted) return;
          final types = (o['types'] as List? ?? const []);
          setState(() {
            _options = o;
            // Monthly dues first: it is what most members pay.
            final monthly = types.whereType<Map>().where(
              (t) => t['frequency'] == 'monthly',
            );
            _typeId =
                (monthly.isNotEmpty
                        ? monthly.first['id']
                        : types.isNotEmpty
                        ? (types.first as Map)['id']
                        : null)
                    as String?;
            _fillAmount();
          });
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = payError(e));
        });
    // Switched on only once MTN's details are in the cloud.
    widget.api
        .momoEnabled()
        .then((on) {
          if (mounted) setState(() => _momo = on);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _type {
    for (final t in (_options?['types'] as List? ?? const [])) {
      if (t is Map && t['id'] == _typeId) return Map<String, dynamic>.from(t);
    }
    return null;
  }

  void _fillAmount() {
    final a = _type?['amount'];
    _amount.text = a == null ? '' : moneyInput(_int(a));
  }

  String? get _periodOrNull =>
      _type?['frequency'] == 'monthly' ? _period : null;

  /// Hand payment: gets the request and lets the member report on it.
  Future<void> _report() async {
    final t = _type;
    if (t == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.api.selfRequest(_typeId!, period: _periodOrNull);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = payError(e);
        });
      }
    }
  }

  /// MoMo: asks MTN for approval on the member's phone, then waits.
  Future<void> _payMomo() async {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount you are paying.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.api.momoStart(
        typeId: _typeId!,
        period: _periodOrNull,
        amount: amount,
        phone: _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = 'wait';
        _momoId = id;
        _polls = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = payError(e);
        });
      }
    }
  }

  Future<void> _poll() async {
    if (_busy || _momoId == null) return;
    _busy = true;
    try {
      final r = await widget.api.momoStatus(_momoId!);
      _polls++;
      if (!mounted) return;
      if (r['status'] == 'pending' && _polls < 45) return;
      _timer?.cancel();
      setState(() {
        _stage = 'done';
        _result = r['status'] == 'pending'
            ? {
                'status': 'pending',
                'reason':
                    'We have not heard back from MTN yet. If you approved '
                    'the payment, it will show on your Payments soon.',
              }
            : r;
      });
    } catch (_) {
      // A dropped connection while waiting: keep trying.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_stage == 'wait') {
      return AlertDialog(
        title: const Text('Approve on your phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'MTN is asking for your approval. Check your phone and enter '
              'your Mobile Money PIN to pay.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_stage == 'done') {
      final r = _result ?? const <String, dynamic>{};
      final ok = r['status'] == 'successful';
      return AlertDialog(
        icon: Icon(
          ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          color: ok ? scheme.primary : scheme.error,
          size: 40,
        ),
        title: Text(ok ? 'Payment received' : 'Not paid'),
        content: Text(
          ok
              ? 'Thank you. Your receipt is ${r['receipt_no']}.'
              : '${r['reason'] ?? 'The payment did not go through.'}',
          textAlign: TextAlign.center,
        ),
        actions: [
          if (!ok && r['status'] == 'failed')
            TextButton(
              onPressed: () => setState(() {
                _stage = 'form';
                _error = null;
                _momoId = null;
              }),
              child: const Text('Try again'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              ok ? {'receipt_no': r['receipt_no']} : null,
            ),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final o = _options;
    final types = [
      for (final t in (o?['types'] as List? ?? const []))
        if (t is Map) Map<String, dynamic>.from(t),
    ];
    final payTo = o?['pay_to'] as String?;
    return AlertDialog(
      title: const Text('Pay my dues'),
      content: SingleChildScrollView(
        child: o == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Text(_error!),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _typeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'What are you paying for?',
                    ),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text('${t['name']}'),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _typeId = v;
                      _fillAmount();
                    }),
                  ),
                  if (_type?['frequency'] == 'monthly') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _period,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: [
                        for (final m in _months)
                          DropdownMenuItem(
                            value: m,
                            child: Text(formatPeriod(m)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _period = v ?? _period),
                    ),
                  ],
                  if (_momo) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount (GHS)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Your MTN Mobile Money number',
                        hintText: '024 123 4567',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    if (payTo == null)
                      const Text(
                        'The Treasurer has not yet said where to pay. Ask '
                        'them for the Mobile Money number, pay, then come '
                        'back here to tell them.',
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText('Pay to: $payTo'),
                      ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_momo) ...[
          TextButton(
            onPressed: _busy || _type == null ? null : _report,
            child: const Text('Paid already'),
          ),
          FilledButton(
            onPressed: _busy || _type == null ? null : _payMomo,
            child: const Text('Pay with MoMo'),
          ),
        ] else
          FilledButton(
            onPressed: _busy || _type == null ? null : _report,
            child: const Text('I have paid'),
          ),
      ],
    );
  }
}

/// Where a member says how they paid. Pops true once it is sent.
class PaidDialog extends StatefulWidget {
  const PaidDialog({super.key, required this.api, required this.request});

  final PayApi api;
  final Map<String, dynamic> request;

  @override
  State<PaidDialog> createState() => _PaidDialogState();
}

class _PaidDialogState extends State<PaidDialog> {
  late final _amount = TextEditingController(
    text: widget.request['amount'] == null
        ? ''
        : moneyInput(_int(widget.request['amount'])),
  );
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _method = 'momo';
  DateTime _paidOn = DateTime.now();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter the amount you paid.');
      return;
    }
    if (_method != 'cash' && _reference.text.trim().isEmpty) {
      setState(
        () => _error =
            'Enter the transaction ID from your Mobile Money or bank message.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.submit(
        '${widget.request['id']}',
        amount: amount,
        method: _method,
        reference: _reference.text.trim(),
        paidOn: _paidOn,
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = payError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('I have paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.request['title']}'),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                prefixText: 'GHS ',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'How you paid'),
              items: [
                for (final m in const ['momo', 'bank', 'cash'])
                  DropdownMenuItem(value: m, child: Text(payMethodLabel(m))),
              ],
              onChanged: (m) => setState(() => _method = m ?? 'momo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              decoration: InputDecoration(
                labelText: _method == 'cash'
                    ? 'Who you gave it to (optional)'
                    : 'Transaction ID',
                helperText: _method == 'cash'
                    ? null
                    : 'From your Mobile Money or bank message',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date paid'),
              subtitle: Text(formatDate(_paidOn)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _paidOn,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _paidOn = d);
              },
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note for the Treasurer (optional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _send,
          child: const Text('Send'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Officers

/// A tile to the payment requests for treasurers and the Welfare team, with
/// how many reported payments wait to be confirmed. Shows nothing for
/// everyone else, or when the cloud cannot be reached.
class PayRequestsEntry extends StatefulWidget {
  const PayRequestsEntry({super.key, this.access, this.api, this.office})
    : assert(access != null || api != null);

  final ChatAccess? access;

  /// Used instead of [access] where the caller already has the API.
  final PayApi? api;

  /// `treasury` or `welfare` to count and show one office's requests only.
  final String? office;

  @override
  State<PayRequestsEntry> createState() => _PayRequestsEntryState();
}

class _PayRequestsEntryState extends State<PayRequestsEntry> {
  late final _api =
      widget.api ??
      PayApi(context.read<AppServices>().sync.api, widget.access!.token);
  int? _waiting;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await _api.list();
      final n = [
        for (final r in (l['requests'] as List? ?? const []))
          if (r is Map &&
              (widget.office == null || r['office'] == widget.office))
            _int(r['pending']),
      ].fold(0, (a, b) => a + b);
      if (mounted) setState(() => _waiting = n);
    } catch (_) {
      // Not a treasurer or Welfare officer, or offline: stay hidden.
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _waiting;
    if (waiting == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      child: ListTile(
        leading: const IconBadge(Icons.request_quote_outlined, size: 36),
        title: const Text(
          'Payment requests',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          waiting > 0
              ? '$waiting ${waiting == 1 ? 'payment' : 'payments'} to confirm'
              : 'Ask members to pay and confirm what they paid',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PayRequestsScreen(api: _api, office: widget.office),
            ),
          );
          _load();
        },
      ),
    );
  }
}

/// Requests to pay, for treasurers and the Welfare team: ask members to
/// pay, see who reported paying, and confirm the money arrived.
class PayRequestsScreen extends StatefulWidget {
  const PayRequestsScreen({super.key, required this.api, this.office});

  final PayApi api;

  /// `treasury` or `welfare` to show one office's requests only.
  final String? office;

  @override
  State<PayRequestsScreen> createState() => _PayRequestsScreenState();
}

class _PayRequestsScreenState extends State<PayRequestsScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.list();
      if (mounted) {
        setState(() {
          _data = d;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = payError(e));
    }
  }

  List<String> get _offices => [
    if (_data?['can_ask_treasury'] == true && widget.office != 'welfare')
      'treasury',
    if (_data?['can_ask_welfare'] == true && widget.office != 'treasury')
      'welfare',
  ];

  /// The Mobile Money number members pay to when they pay their own dues.
  Future<void> _setPayTo() async {
    String current = '';
    try {
      current = ((await widget.api.selfOptions())['pay_to'] as String?) ?? '';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(payError(e))));
      }
      return;
    }
    if (!mounted) return;
    final c = TextEditingController(text: current);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Where members pay'),
        content: TextField(
          controller: c,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'e.g. MoMo 024 000 0000 (JBF Treasury)',
            helperText: 'Shown to every member who pays their own dues.',
            helperMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (text == null) return;
    try {
      await widget.api.setPayTo(text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(payError(e))));
      }
    }
  }

  Future<void> _new() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewPayRequestScreen(
          api: widget.api,
          data: _data!,
          offices: _offices,
        ),
      ),
    );
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final requests = [
      for (final r in (d?['requests'] as List? ?? const []))
        if (r is Map && (widget.office == null || r['office'] == widget.office))
          Map<String, dynamic>.from(r),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment requests'),
        actions: [
          if (d?['can_confirm'] == true)
            IconButton(
              tooltip: 'Where members pay',
              icon: const Icon(Icons.phone_android_rounded),
              onPressed: _setPayTo,
            ),
        ],
      ),
      floatingActionButton: d != null && _offices.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _new,
              icon: const Icon(Icons.add),
              label: const Text('Ask members to pay'),
            )
          : null,
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (d['zone_only'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'You see the members of your own zones only.',
                      ),
                    ),
                  if (requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No requests yet. When you ask members to pay, they '
                        'see it in their app and can tell you how they paid.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final r in requests) _requestTile(r),
                ],
              ),
            ),
    );
  }

  Widget _requestTile(Map<String, dynamic> r) {
    final scheme = Theme.of(context).colorScheme;
    final pending = _int(r['pending']);
    return Card(
      child: ListTile(
        title: Text(
          '${r['title']}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_askLine(r)}\n'
          '${_int(r['confirmed'])} of ${_int(r['asked'])} paid · '
          '${formatMoney(_int(r['collected']))} collected',
        ),
        isThreeLine: true,
        trailing: r['closed'] == true
            ? const Pill('Closed', color: Colors.grey)
            : pending > 0
            ? Pill('$pending to confirm', color: scheme.tertiary)
            : null,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PayRequestScreen(
                api: widget.api,
                request: r,
                canConfirm: _data?['can_confirm'] == true,
              ),
            ),
          );
          _load();
        },
      ),
    );
  }
}

/// One request: what was asked, and every payment members reported, with
/// Confirm and Reject for treasurers.
class PayRequestScreen extends StatefulWidget {
  const PayRequestScreen({
    super.key,
    required this.api,
    required this.request,
    required this.canConfirm,
  });

  final PayApi api;
  final Map<String, dynamic> request;
  final bool canConfirm;

  @override
  State<PayRequestScreen> createState() => _PayRequestScreenState();
}

class _PayRequestScreenState extends State<PayRequestScreen> {
  List<Map<String, dynamic>>? _claims;
  String? _error;
  bool _busy = false;
  late bool _closed = widget.request['closed'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await widget.api.claims('${widget.request['id']}');
      if (mounted) setState(() => _claims = c);
    } catch (e) {
      if (mounted) setState(() => _error = payError(e));
    }
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _decide(Map<String, dynamic> c, bool confirm) async {
    String? note;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm this payment?'),
          content: Text(
            'Only confirm once you have seen ${formatMoney(_int(c['amount']))}'
            ' from ${c['member_name']} arrive'
            '${c['reference'] != null ? ' (transaction ${c['reference']})' : ''}.'
            ' A receipt is written for the member.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      final reason = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject this payment?'),
          content: TextField(
            controller: reason,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Reason, for the member',
              hintText: 'e.g. No money arrived with this transaction ID',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(reason.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (note == null || note.isEmpty) return;
    }
    setState(() => _busy = true);
    try {
      final r = await widget.api.decide(
        '${c['id']}',
        confirm: confirm,
        note: note,
      );
      _say(confirm ? 'Confirmed. Receipt ${r['receipt_no']}.' : 'Rejected.');
      await _load();
    } catch (e) {
      _say(payError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _close() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this request?'),
        content: const Text(
          'Members can no longer report paying it. Payments already '
          'reported can still be confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.close('${widget.request['id']}');
      if (mounted) setState(() => _closed = true);
    } catch (e) {
      _say(payError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final claims = _claims;
    final ink = Tones.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${r['title']}'),
        actions: [
          if (!_closed)
            IconButton(
              tooltip: 'Close request',
              onPressed: _close,
              icon: const Icon(Icons.lock_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_askLine(r)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'From the ${_officeName(r['office'] as String?)}',
                        if (r['by'] != null) 'by ${r['by']}',
                        if (r['zones'] is List)
                          (r['zones'] as List).join(', ')
                        else
                          'All members',
                      ].join(' · '),
                      style: TextStyle(color: ink.muted, fontSize: 13),
                    ),
                    if (r['details'] != null) ...[
                      const SizedBox(height: 8),
                      Text('${r['details']}'),
                    ],
                    if (r['pay_to'] != null) ...[
                      const SizedBox(height: 8),
                      Text('How to pay: ${r['pay_to']}'),
                    ],
                    if (_closed) ...[
                      const SizedBox(height: 8),
                      const Pill('Closed', color: Colors.grey),
                    ],
                  ],
                ),
              ),
            ),
            const SectionTitle('Reported payments'),
            if (claims == null)
              Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(_error!),
              )
            else if (claims.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No member has reported paying yet.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final c in claims) _claimCard(c),
          ],
        ),
      ),
    );
  }

  Widget _claimCard(Map<String, dynamic> c) {
    final scheme = Theme.of(context).colorScheme;
    final ink = Tones.of(context);
    final status = c['status'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar('${c['member_name'] ?? ''}', size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c['member_name'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${c['member_no'] ?? ''}',
                        style: TextStyle(color: ink.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                switch (status) {
                  'confirmed' => Pill('Confirmed', color: scheme.primary),
                  'rejected' => Pill('Rejected', color: scheme.error),
                  _ => Pill('To confirm', color: scheme.tertiary),
                },
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                formatMoney(_int(c['amount'])),
                payMethodLabel(c['method'] as String?),
                if (_day(c['paid_on']) case final d?) 'paid ${formatDate(d)}',
              ].join(' · '),
            ),
            if (c['reference'] != null)
              Row(
                children: [
                  Expanded(
                    child: SelectableText('Transaction: ${c['reference']}'),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: '${c['reference']}'),
                    ),
                  ),
                ],
              ),
            if (c['note'] != null) Text('Note: ${c['note']}'),
            if (status == 'confirmed')
              Text(
                'Receipt ${c['receipt_no']} · confirmed by ${c['decided_by']}',
                style: TextStyle(color: ink.muted, fontSize: 13),
              ),
            if (status == 'rejected')
              Text(
                'Rejected by ${c['decided_by']}: ${c['decision_note'] ?? ''}',
                style: TextStyle(color: ink.muted, fontSize: 13),
              ),
            if (status == 'pending' && widget.canConfirm) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _decide(c, false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _decide(c, true),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The form to ask members to pay. Pops true once the request is sent.
class NewPayRequestScreen extends StatefulWidget {
  const NewPayRequestScreen({
    super.key,
    required this.api,
    required this.data,
    required this.offices,
  });

  final PayApi api;

  /// What [PayApi.list] returned: the types and zones to choose from.
  final Map<String, dynamic> data;
  final List<String> offices;

  @override
  State<NewPayRequestScreen> createState() => _NewPayRequestScreenState();
}

class _NewPayRequestScreenState extends State<NewPayRequestScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _payTo = TextEditingController();
  final _details = TextEditingController();
  late String _office = widget.offices.first;
  String? _typeId;
  late String _period = _thisMonth();
  DateTime? _dueOn;
  final Set<String> _zones = {};
  String? _error;
  bool _busy = false;

  static String _thisMonth() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _items(String key) => [
    for (final x in (widget.data[key] as List? ?? const []))
      if (x is Map) Map<String, dynamic>.from(x),
  ];

  Map<String, dynamic>? get _type =>
      _items('types').where((t) => t['id'] == _typeId).firstOrNull;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _payTo.dispose();
    _details.dispose();
    super.dispose();
  }

  void _pickType(String? id) {
    setState(() => _typeId = id);
    final t = _type;
    if (t == null) return;
    if (_title.text.trim().isEmpty) _title.text = '${t['name']}';
    if (_amount.text.trim().isEmpty && t['amount'] != null) {
      _amount.text = moneyInput(_int(t['amount']));
    }
  }

  Future<void> _send() async {
    final title = _title.text.trim();
    final amountText = _amount.text.trim();
    final amount = amountText.isEmpty ? null : parseMoney(amountText);
    if (_typeId == null) {
      setState(() => _error = 'Choose what the payment is for.');
      return;
    }
    if (title.isEmpty) {
      setState(() => _error = 'Give the request a title.');
      return;
    }
    if (amountText.isNotEmpty && (amount == null || amount <= 0)) {
      setState(() => _error = 'Enter a valid amount, or leave it empty.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.create(
        office: _office,
        title: title,
        typeId: _typeId!,
        amount: amount,
        period: _type?['frequency'] == 'monthly' ? _period : null,
        dueOn: _dueOn,
        zoneIds: _zones.isEmpty ? null : _zones.toList(),
        payTo: _payTo.text.trim(),
        details: _details.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = payError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _items('types');
    final zones = _items('zones');
    final monthly = _type?['frequency'] == 'monthly';
    final now = DateTime.now();
    final months = [
      for (var i = -2; i <= 3; i++)
        () {
          final d = DateTime(now.year, now.month + i);
          return '${d.year}-${d.month.toString().padLeft(2, '0')}';
        }(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Ask members to pay')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.offices.length > 1) ...[
            SegmentedButton<String>(
              segments: [
                for (final o in widget.offices)
                  ButtonSegment(value: o, label: Text(_officeName(o))),
              ],
              selected: {_office},
              onSelectionChanged: (s) => setState(() => _office = s.first),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _typeId,
            decoration: const InputDecoration(labelText: 'Payment for'),
            items: [
              for (final t in types)
                DropdownMenuItem(
                  value: '${t['id']}',
                  child: Text('${t['name']}'),
                ),
            ],
            onChanged: _pickType,
          ),
          if (monthly) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Month'),
              items: [
                for (final m in months)
                  DropdownMenuItem(value: m, child: Text(formatPeriod(m))),
              ],
              onChanged: (m) => setState(() => _period = m ?? _period),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'e.g. Silver Collection for the end-of-year party',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount each member pays',
              prefixText: 'GHS ',
              helperText: 'Leave empty if members give what they can',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payTo,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'How to pay',
              hintText: 'e.g. MoMo 024 000 0000 (JBF Treasury)',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Pay by (optional)'),
            subtitle: Text(_dueOn == null ? 'No date' : formatDate(_dueOn)),
            trailing: _dueOn == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueOn = null),
                  ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _dueOn ?? now.add(const Duration(days: 7)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _dueOn = d);
            },
          ),
          TextField(
            controller: _details,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message to members (optional)',
            ),
          ),
          const SectionTitle('Who is asked'),
          Text(
            widget.data['zone_only'] == true
                ? 'Leave every zone unticked to ask all your zones.'
                : 'Leave every zone unticked to ask all active members.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final z in zones)
                FilterChip(
                  label: Text('${z['name']}'),
                  selected: _zones.contains(z['id']),
                  onSelected: (on) => setState(
                    () => on
                        ? _zones.add('${z['id']}')
                        : _zones.remove('${z['id']}'),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send to members'),
          ),
        ],
      ),
    );
  }
}
