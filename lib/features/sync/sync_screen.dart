import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../core/share_file.dart';
import '../../data/collection_batch.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../reports/report_export.dart' show ymd;

/// Moving collections between phones without internet.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _phoneName = TextEditingController();
  DateTime? _lastSent;
  bool _onlyNew = true;
  bool _busy = false;

  static const _nameKey = 'phone_name';
  static const _lastSentKey = 'last_batch_export';

  @override
  void initState() {
    super.initState();
    final store = context.read<AppServices>().store;
    store.pref(_nameKey).then((v) => _phoneName.text = v ?? '');
    store.pref(_lastSentKey).then((v) {
      if (mounted) setState(() => _lastSent = DateTime.tryParse(v ?? ''));
    });
  }

  @override
  void dispose() {
    _phoneName.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _password(String title) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Agree one password between the field phone and the main '
              'phone, and do not send it in the same chat as the file.',
            ),
            TextField(
              controller: ctl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctl.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final services = context.read<AppServices>();
    final name = _phoneName.text.trim();
    if (name.isEmpty) {
      _snack('Give this phone a name first, e.g. "Zone 3 treasurer".');
      return;
    }
    await services.store.setPref(_nameKey, name);
    final password = await _password('Password for this batch');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final started = DateTime.now();
      final bytes = await services.batches.export(
        deviceId: services.deviceId,
        deviceName: name,
        password: password,
        since: _onlyNew ? _lastSent : null,
      );
      await shareBytes(
        bytes,
        'collections-${name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}-'
        '${ymd(started)}.jbfc',
        mimeType: 'application/octet-stream',
        text: 'Collections from $name',
      );
      await services.store.setPref(_lastSentKey, started.toIso8601String());
      if (mounted) setState(() => _lastSent = started);
    } on BatchException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose a collections file',
    );
    if (picked == null) return;
    final bytes = await picked.xFile.readAsBytes();
    final password = await _password('Batch password');
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final (summary, rows) = await services.batches.read(bytes, password);
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import from ${summary.fromDevice}?'),
          content: Text(
            '${summary.count} payments, ${formatMoney(summary.total)}, '
            'sent ${formatDateTime(summary.exportedAt)}. Payments already '
            'on this phone are skipped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final r = await services.batches.import(
        rows,
        user.actor(services.deviceId),
        fromDevice: summary.fromDevice,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import finished'),
          content: SingleChildScrollView(
            child: Text(
              [
                '${r.added} new payments added.',
                if (r.alreadyHad > 0) '${r.alreadyHad} were already here.',
                if (r.voidsApplied > 0) '${r.voidsApplied} voids applied.',
                if (r.skipped.isNotEmpty) ...[
                  '\n${r.skipped.length} could not be imported:',
                  ...r.skipped,
                ],
              ].join('\n'),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } on BatchException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canReceive = user?.can(Perm.backupManage) ?? false;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Field phones')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text('How it works', style: text.titleMedium),
            const SizedBox(height: 4),
            const Text(
              '1. On the main phone, make a backup (More > Backup and '
              'restore).\n'
              '2. On the field phone, restore that backup, then give it its '
              'own receipt prefix in Organisation settings (e.g. Z3).\n'
              '3. The field phone records payments, then sends them here as '
              'a file by WhatsApp or Bluetooth.\n'
              '4. The main phone imports the file. Sending the same file '
              'twice is safe.',
            ),
            const SizedBox(height: 24),
            Text('Send collections from this phone', style: text.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneName,
              decoration: const InputDecoration(
                labelText: 'Name of this phone',
                hintText: 'e.g. Zone 3 treasurer',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only payments since the last send'),
              subtitle: Text(
                _lastSent == null
                    ? 'Nothing sent yet'
                    : 'Last sent ${formatDateTime(_lastSent!)}',
              ),
              value: _onlyNew,
              onChanged: (v) => setState(() => _onlyNew = v),
            ),
            FilledButton.icon(
              onPressed: _send,
              icon: const Icon(Icons.upload_file),
              label: const Text('Send collections'),
            ),
            if (canReceive) ...[
              const SizedBox(height: 32),
              Text('Receive on the main phone', style: text.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _receive,
                icon: const Icon(Icons.download),
                label: const Text('Import a collections file'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
