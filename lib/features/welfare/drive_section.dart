import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/drive_repository.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'welfare_common.dart';

/// The collection drive on a welfare case: family and funeral details,
/// pledges and gifts, closing, and the approved hand-over to the family.
class DriveSection extends StatefulWidget {
  const DriveSection({super.key, required this.view});

  final WelfareCaseView view;

  @override
  State<DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<DriveSection> {
  bool _busy = false;

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on WelfareException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details({required bool opening}) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final c = widget.view.welfareCase;
    final venue = TextEditingController(text: c.funeralVenue);
    final contact = TextEditingController(text: c.familyContact);
    final phone = TextEditingController(text: c.familyPhone);
    DateTime? date = c.funeralOn;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(opening ? 'Start a collection' : 'Family and funeral'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Funeral date (optional)'),
                  subtitle: Text(date == null ? 'Not set' : formatDate(date)),
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date ?? now,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 2),
                    );
                    if (d != null) setLocal(() => date = d);
                  },
                ),
                TextField(
                  controller: venue,
                  decoration: const InputDecoration(labelText: 'Venue'),
                ),
                TextField(
                  controller: contact,
                  decoration: const InputDecoration(
                    labelText: 'Family contact person',
                  ),
                ),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Family contact phone',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(opening ? 'Start' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final by = user.welfareActor(services.deviceId);
    await _run(
      () => opening
          ? services.drives.openDrive(
              c.id,
              by,
              funeralOn: date,
              funeralVenue: venue.text,
              familyContact: contact.text,
              familyPhone: phone.text,
            )
          : services.drives.updateDriveDetails(
              c.id,
              by,
              funeralOn: date,
              funeralVenue: venue.text,
              familyContact: contact.text,
              familyPhone: phone.text,
            ),
    );
  }

  Future<void> _addGift() async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final result = await showDialog<_GiftInput>(
      context: context,
      builder: (_) => _GiftDialog(canTakeMoney: user.can(Perm.welfarePay)),
    );
    if (result == null) return;
    await _run(
      () => services.drives.addGift(
        widget.view.welfareCase.id,
        user.welfareActor(services.deviceId),
        giverName: result.name,
        amount: result.amount,
        anonymous: result.anonymous,
        method: result.method,
        reference: result.reference,
      ),
    );
  }

  Future<void> _receive(WelfareDriveGift g) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final r = await showDialog<(PaymentMethod, String)>(
      context: context,
      builder: (_) => _MethodDialog(
        title: 'Received ${formatMoney(g.amount)} from ${g.giverName}',
        action: 'Mark received',
      ),
    );
    if (r == null) return;
    await _run(
      () => services.drives.receiveGift(
        g.id,
        user.welfareActor(services.deviceId),
        method: r.$1,
        reference: r.$2,
      ),
    );
  }

  Future<void> _void(WelfareDriveGift g) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Void ${formatMoney(g.amount)} from ${g.giverName}?'),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => services.drives.voidGift(
        g.id,
        user.welfareActor(services.deviceId),
        reason.text,
      ),
    );
  }

  Future<void> _close(DriveTotals t) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this collection?'),
        content: Text(
          'Gifts will be locked. ${formatMoney(t.received)} received'
          '${t.pledged > 0 ? ', and ${formatMoney(t.pledged)} still pledged '
                    'will not be part of the hand-over' : ''}. '
          'A different officer then approves handing it to the family.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close collection'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => services.drives.closeDrive(
        widget.view.welfareCase.id,
        user.welfareActor(services.deviceId),
      ),
    );
  }

  Future<void> _handover(DriveTotals t) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final r = await showDialog<(PaymentMethod, String)>(
      context: context,
      builder: (_) => _MethodDialog(
        title: 'Hand ${formatMoney(t.received)} to the family',
        action: 'Approve hand-over',
      ),
    );
    if (r == null) return;
    await _run(
      () => services.drives.approveHandover(
        widget.view.welfareCase.id,
        user.welfareActor(services.deviceId),
        method: r.$1,
        handedOn: DateTime.now(),
        reference: r.$2,
      ),
    );
  }

  Future<void> _share(List<WelfareDriveGift> gifts) async {
    final text = driveSummaryText(
      welfareCase: widget.view.welfareCase,
      memberName: widget.view.member.fullName,
      gifts: gifts,
    );
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canRecord =
        (user?.can(Perm.welfarePrepare) ?? false) ||
        (user?.can(Perm.welfarePay) ?? false);
    final canReceive = user?.can(Perm.welfarePay) ?? false;
    final canApprove = user?.can(Perm.welfareApprove) ?? false;
    final services = context.read<AppServices>();
    final c = widget.view.welfareCase;
    final theme = Theme.of(context);

    if (c.driveStatus == DriveStatus.none) {
      if (!canRecord) return const SizedBox.shrink();
      return OutlinedButton.icon(
        onPressed: _busy ? null : () => _details(opening: true),
        icon: const Icon(Icons.volunteer_activism),
        label: const Text('Start a collection for the family'),
      );
    }

    return StreamBuilder<List<WelfareDriveGift>>(
      stream: services.drives.watchGifts(c.id),
      builder: (context, snap) {
        final gifts = snap.data ?? const <WelfareDriveGift>[];
        final t = driveTotals(gifts);
        final open = c.driveStatus == DriveStatus.open;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Collection', style: theme.textTheme.titleMedium),
                ),
                Chip(label: Text(c.driveStatus.label)),
              ],
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoney(t.received),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'received from ${t.givers} '
                      '${t.givers == 1 ? 'giver' : 'givers'}'
                      '${t.pledged > 0 ? ' · ${formatMoney(t.pledged)} '
                                'pledged, not yet collected' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Divider(height: 24),
                    _line('Funeral', formatDate(c.funeralOn)),
                    _line('Venue', c.funeralVenue ?? ''),
                    _line(
                      'Family contact',
                      [
                        c.familyContact,
                        c.familyPhone,
                      ].whereType<String>().join(' · '),
                    ),
                    _line('Started by', c.driveOpenedByName ?? ''),
                    if (c.driveClosedByName != null)
                      _line(
                        'Closed by',
                        '${c.driveClosedByName}, ${formatDate(c.driveClosedOn)}',
                      ),
                    if (c.handoverAmount != null)
                      _line(
                        'Handed over',
                        '${formatMoney(c.handoverAmount!)} on '
                            '${formatDate(c.handoverOn)} by '
                            '${c.handoverByName} '
                            '(${c.handoverMethod?.label ?? ''})',
                      ),
                    if (open && canRecord)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => _details(opening: false),
                          child: const Text('Edit family and funeral details'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (final g in gifts) _giftTile(g, open, canReceive, canRecord),
            const SizedBox(height: 8),
            if (open && canRecord)
              FilledButton.icon(
                onPressed: _busy ? null : _addGift,
                icon: const Icon(Icons.add),
                label: const Text('Add a gift or pledge'),
              ),
            if (open && canRecord)
              TextButton(
                onPressed: _busy ? null : () => _close(t),
                child: const Text('Close the collection'),
              ),
            if (c.driveStatus == DriveStatus.closed && canApprove)
              FilledButton.icon(
                onPressed: _busy || t.received <= 0 ? null : () => _handover(t),
                icon: const Icon(Icons.check),
                label: const Text('Approve hand-over to the family'),
              ),
            if (c.driveStatus == DriveStatus.closed && !canApprove)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Waiting for the Welfare Chairman (or General Secretary) '
                  'to approve the hand-over.',
                ),
              ),
            TextButton.icon(
              onPressed: () => _share(gifts),
              icon: const Icon(Icons.share),
              label: const Text('Share a summary with members'),
            ),
          ],
        );
      },
    );
  }

  Widget _line(String label, String value) => value.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(flex: 3, child: Text(value)),
            ],
          ),
        );

  Widget _giftTile(
    WelfareDriveGift g,
    bool open,
    bool canReceive,
    bool canRecord,
  ) {
    final voided = g.status == GiftStatus.voided;
    final style = voided
        ? const TextStyle(decoration: TextDecoration.lineThrough)
        : null;
    return Card(
      child: ListTile(
        title: Text(
          '${g.giverName}${g.anonymous ? ' (anonymous)' : ''}',
          style: style,
        ),
        subtitle: Text(
          [
            g.status.label,
            if (g.status == GiftStatus.received)
              '${formatDate(g.receivedOn)}, ${g.method?.label ?? ''}',
            if (voided && g.voidReason != null) g.voidReason!,
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatMoney(g.amount), style: style),
            if (open && !voided && (canReceive || canRecord))
              PopupMenuButton<String>(
                onSelected: (v) => v == 'receive' ? _receive(g) : _void(g),
                itemBuilder: (_) => [
                  if (g.status == GiftStatus.pledged && canReceive)
                    const PopupMenuItem(
                      value: 'receive',
                      child: Text('Mark received'),
                    ),
                  if (canRecord)
                    const PopupMenuItem(value: 'void', child: Text('Void')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GiftInput {
  const _GiftInput(
    this.name,
    this.amount,
    this.anonymous,
    this.method,
    this.reference,
  );
  final String name;
  final int amount;
  final bool anonymous;
  final PaymentMethod? method;
  final String reference;
}

class _GiftDialog extends StatefulWidget {
  const _GiftDialog({required this.canTakeMoney});
  final bool canTakeMoney;

  @override
  State<_GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<_GiftDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  bool _anonymous = false;
  bool _paidNow = false;
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseMoney(_amount.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter who is giving.');
    } else if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount above zero.');
    } else {
      Navigator.of(context).pop(
        _GiftInput(
          _name.text,
          amount,
          _anonymous,
          _paidNow ? _method : null,
          _reference.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a gift or pledge'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Given by'),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (GHS)'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide the name in the shared summary'),
            value: _anonymous,
            onChanged: (v) => setState(() => _anonymous = v),
          ),
          if (widget.canTakeMoney) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Money received now'),
              subtitle: const Text('Off means a pledge to collect later'),
              value: _paidNow,
              onChanged: (v) => setState(() => _paidNow = v),
            ),
            if (_paidNow) ...[
              DropdownButtonFormField<PaymentMethod>(
                isExpanded: true,
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setState(() => _method = m!),
              ),
              TextField(
                controller: _reference,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
              ),
            ],
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save')),
    ],
  );
}

class _MethodDialog extends StatefulWidget {
  const _MethodDialog({required this.title, required this.action});
  final String title;
  final String action;

  @override
  State<_MethodDialog> createState() => _MethodDialogState();
}

class _MethodDialogState extends State<_MethodDialog> {
  PaymentMethod _method = PaymentMethod.momo;
  final _reference = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<PaymentMethod>(
          isExpanded: true,
          initialValue: _method,
          decoration: const InputDecoration(labelText: 'Method'),
          items: [
            for (final m in PaymentMethod.values)
              DropdownMenuItem(value: m, child: Text(m.label)),
          ],
          onChanged: (m) => setState(() => _method = m!),
        ),
        TextField(
          controller: _reference,
          decoration: const InputDecoration(labelText: 'Reference (optional)'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop((_method, _reference.text)),
        child: Text(widget.action),
      ),
    ],
  );
}
