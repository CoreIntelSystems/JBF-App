import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/database.dart';
import '../auth/auth_cubit.dart';

/// Organisation details used across the app, receipts and reports, so the
/// app can be set up for another association (CoreIntel product).
class OrgSettingsScreen extends StatefulWidget {
  const OrgSettingsScreen({super.key});

  @override
  State<OrgSettingsScreen> createState() => _OrgSettingsScreenState();
}

class _OrgSettingsScreenState extends State<OrgSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _short = TextEditingController();
  final _memberPrefix = TextEditingController();
  final _receiptPrefix = TextEditingController();
  int? _primary;
  int? _accent;
  OrgSetting? _org;

  static const _primaries = <(String, int)>[
    ('Green', 0xFF0B6B3A),
    ('Dark blue', 0xFF0D3B66),
    ('Maroon', 0xFF7B1E2B),
    ('Purple', 0xFF4A2C6F),
    ('Black', 0xFF1B1B1B),
  ];
  static const _accents = <(String, int)>[
    ('Gold', 0xFFC9A227),
    ('Orange', 0xFFE07A1F),
    ('Red', 0xFFC0392B),
    ('Light blue', 0xFF4FA3D1),
    ('White', 0xFFF5F5F5),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AppServices>().payments.org().then((o) {
      if (!mounted) return;
      setState(() {
        _org = o;
        _name.text = o.name;
        _short.text = o.shortName;
        _memberPrefix.text = o.memberIdPrefix;
        _receiptPrefix.text = o.receiptPrefix;
        _primary = o.primaryColor;
        _accent = o.accentColor;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _short, _memberPrefix, _receiptPrefix]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final before = _org!;
    final data = OrgSettingsCompanion(
      name: Value(_name.text.trim()),
      shortName: Value(_short.text.trim()),
      memberIdPrefix: Value(_memberPrefix.text.trim().toUpperCase()),
      receiptPrefix: Value(_receiptPrefix.text.trim().toUpperCase()),
      primaryColor: Value(_primary!),
      accentColor: Value(_accent!),
    );
    await services.db.transaction(() async {
      await services.db.update(services.db.orgSettings).write(data);
      await services.audit.log(
        user.actor(services.deviceId),
        'settings.update',
        entity: 'org_settings',
        oldValue: {
          'name': before.name,
          'memberIdPrefix': before.memberIdPrefix,
          'receiptPrefix': before.receiptPrefix,
        },
        newValue: {
          'name': _name.text.trim(),
          'memberIdPrefix': _memberPrefix.text.trim().toUpperCase(),
          'receiptPrefix': _receiptPrefix.text.trim().toUpperCase(),
        },
      );
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved. Colours change the next time the app opens.'),
      ),
    );
    Navigator.of(context).pop();
  }

  String? _prefix(String? v) {
    final t = (v ?? '').trim();
    if (!RegExp(r'^[A-Za-z0-9]{1,6}$').hasMatch(t)) {
      return 'Use 1 to 6 letters or digits';
    }
    return null;
  }

  Widget _swatches(
    String label,
    List<(String, int)> options,
    int? value,
    ValueChanged<int> onPick,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final (name, c) in options)
            Tooltip(
              message: name,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onPick(c),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(c),
                  child: value == c
                      ? Icon(
                          Icons.check,
                          color: Color(c).computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organisation settings')),
      body: _org == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Organisation name',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _short,
                    decoration: const InputDecoration(labelText: 'Short name'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a short name' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _memberPrefix,
                    decoration: const InputDecoration(
                      labelText: 'Member ID prefix',
                      helperText: 'New members get IDs like JBF-000123',
                    ),
                    validator: _prefix,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiptPrefix,
                    decoration: const InputDecoration(
                      labelText: 'Receipt prefix on this phone',
                      helperText:
                          'Give each field phone its own, e.g. Z3 for Zone 3',
                    ),
                    validator: _prefix,
                  ),
                  _swatches(
                    'Main colour',
                    _primaries,
                    _primary,
                    (c) => setState(() => _primary = c),
                  ),
                  _swatches(
                    'Accent colour',
                    _accents,
                    _accent,
                    (c) => setState(() => _accent = c),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ),
    );
  }
}
