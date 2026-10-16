import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/sheet_reader.dart';
import '../../core/share_file.dart';
import '../../core/xlsx.dart';
import '../../data/database.dart';
import '../../data/repositories/actor.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/member_import.dart';
import '../auth/auth_cubit.dart';

/// Registers many members at once from an Excel or CSV list: headings
/// Name, Phone 1, Phone 2, Phone 3 and, optionally, Zone and Zone 2 (zone
/// numbers). People already registered with the same number are skipped.
class ImportMembersScreen extends StatefulWidget {
  const ImportMembersScreen({super.key});

  @override
  State<ImportMembersScreen> createState() => _ImportMembersScreenState();
}

class _ImportMembersScreenState extends State<ImportMembersScreen> {
  ImportPlan? _plan;
  String? _fileName;
  String? _error;
  List<Zone> _zones = const [];
  String? _fallbackZone;

  /// Dropdown value for "register them without a zone; they choose".
  static const _unassigned = 'unassigned';
  bool _busy = false;
  int _done = 0;
  int _total = 0;
  List<ImportSkip> _skipped = const [];
  bool _finished = false;

  AppServices get _services => context.read<AppServices>();

  Future<void> _pick() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Choose the member list (.xlsx or .csv)',
    );
    if (picked == null) return;
    try {
      final bytes = await picked.xFile.readAsBytes();
      final rows = readSheetRows(bytes, picked.name);
      final repo = _services.members;
      final existing = {
        for (final m in await repo.watchMembers(MemberFilter()).first) ...[
          phoneKey(m.member.phone),
          phoneKey(m.member.whatsapp),
        ],
      }..remove('');
      final zones = (await repo.zones())
          .where(
            (z) => z.isActive && z.code != MemberRepository.holdingZoneCode,
          )
          .toList();
      final plan = planMemberImport(rows, existing: existing);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _fileName = picked.name;
        _zones = zones;
        _skipped = plan.skipped;
        _error = null;
        _finished = false;
        _fallbackZone = plan.withoutZone > 0 ? _unassigned : null;
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _import() async {
    final plan = _plan!;
    final repo = _services.members;
    final user = context.read<AuthCubit>().user;
    final actor =
        user?.actor(_services.deviceId) ??
        Actor.system(deviceId: _services.deviceId);
    final byCode = {for (final z in _zones) z.code: z.id};
    final holding = _fallbackZone == _unassigned
        ? await repo.ensureHoldingZone()
        : _fallbackZone;
    final skipped = [...plan.skipped];
    final todo = <(ImportMember, List<String>)>[];
    for (final m in plan.members) {
      final ids = [
        for (final c in m.zones)
          if (byCode[c] != null) byCode[c]!,
      ];
      if (m.zones.isNotEmpty && ids.length != m.zones.length) {
        skipped.add(
          ImportSkip(
            m.line,
            m.name,
            m.phone,
            'Zone ${m.zones.join(' and ')} is not open for members',
          ),
        );
      } else if (ids.isEmpty && holding == null) {
        skipped.add(ImportSkip(m.line, m.name, m.phone, 'No zone given'));
      } else {
        todo.add((m, ids.isEmpty ? [holding!] : ids));
      }
    }
    setState(() {
      _busy = true;
      _done = 0;
      _total = todo.length;
    });
    final joined = DateTime.now();
    for (final (m, zoneIds) in todo) {
      try {
        await repo.create(
          MemberDraft(
            fullName: m.name,
            gender: m.gender,
            phone: m.phone,
            whatsapp: m.whatsapp,
            address: m.otherNumbers.isEmpty
                ? null
                : 'Other numbers: ${m.otherNumbers.join(', ')}',
            dateJoined: joined,
            zoneIds: zoneIds,
            primaryZoneId: zoneIds.first,
            selfEdit: true,
          ),
          actor,
        );
      } on Object catch (e) {
        skipped.add(ImportSkip(m.line, m.name, m.phone, '$e'));
      }
      if (!mounted) return;
      if (++_done % 10 == 0) setState(() {});
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _finished = true;
      _skipped = skipped;
      _total = todo.length;
    });
  }

  Future<void> _shareSkipped() async {
    final bytes = buildXlsx([
      XlsxSheet('Not imported', [
        ['Row', 'Name in list', 'Phone', 'Why'],
        for (final s in _skipped) [s.line, s.name, s.phones, s.reason],
      ]),
    ]);
    await shareBytes(
      bytes,
      'members-not-imported.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final theme = Theme.of(context);
    final reasons = <String, int>{};
    for (final s in _skipped) {
      reasons[s.reason] = (reasons[s.reason] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Import members')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose an Excel (.xlsx) or CSV list with the headings Name, '
            'Phone 1, Phone 2, Phone 3. Add a Zone column (1 to 8) to put '
            'people in their zones. People already registered with the '
            'same number are left out.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.upload_file),
            label: Text(plan == null ? 'Choose list' : 'Choose another list'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (plan != null && !_finished) ...[
            const SizedBox(height: 16),
            Text(_fileName ?? '', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('${plan.members.length} people ready to register.'),
            if (plan.unnamed > 0)
              Text(
                '${plan.unnamed} of them have no name in the list. They are '
                'added as "Member <number>" and give their own name when '
                'they sign in.',
              ),
            if (_skipped.isNotEmpty)
              Text('${_skipped.length} rows will be left out:'),
            for (final e in reasons.entries) Text('  ${e.value}  ${e.key}'),
            if (plan.withoutZone > 0) ...[
              const SizedBox(height: 16),
              Text(
                '${plan.withoutZone} people have no zone in the list. '
                'Put them in Unassigned so each chooses their own zone once, '
                'pick one zone for all of them, or leave them out.',
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey(_fallbackZone),
                initialValue: _fallbackZone,
                decoration: const InputDecoration(
                  labelText: 'Zone for people without one',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: _unassigned,
                    child: Text('Unassigned (they choose their own zone)'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Leave them out'),
                  ),
                  for (final z in _zones)
                    DropdownMenuItem<String?>(value: z.id, child: Text(z.name)),
                ],
                onChanged: (v) => setState(() => _fallbackZone = v),
              ),
            ],
            const SizedBox(height: 16),
            if (_busy) ...[
              LinearProgressIndicator(
                value: _total == 0 ? null : _done / _total,
              ),
              const SizedBox(height: 4),
              Text('Registering $_done of $_total...'),
            ] else
              FilledButton(
                onPressed: plan.members.isEmpty ? null : _import,
                child: const Text('Register members'),
              ),
          ],
          if (_finished) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_total members registered.',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (_skipped.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${_skipped.length} rows were left out:'),
                      for (final e in reasons.entries)
                        Text('  ${e.value}  ${e.key}'),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _shareSkipped,
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share the list left out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
