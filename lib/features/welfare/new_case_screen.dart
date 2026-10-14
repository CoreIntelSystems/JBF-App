import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/repositories/welfare_repository.dart';
import '../auth/auth_cubit.dart';
import '../members/member_picker.dart';
import 'case_detail_screen.dart';
import 'welfare_common.dart';

/// A welfare team member reports a case for approval.
class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key, this.member});

  final Member? member;

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _beneficiary = TextEditingController();
  final _description = TextEditingController();

  List<WelfareCaseType>? _types;
  Member? _member;
  WelfareCaseType? _type;
  DateTime _occurredOn = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    context.read<AppServices>().welfare.activeCaseTypes().then((t) {
      if (mounted) setState(() => _types = t);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _beneficiary.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickMember() async {
    final m = await Navigator.of(
      context,
    ).push<Member>(MaterialPageRoute(builder: (_) => const MemberPicker()));
    if (m != null) setState(() => _member = m);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _occurredOn = d);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_member == null) {
      setState(() => _error = 'Choose the member.');
      return;
    }
    if (_type == null) {
      setState(() => _error = 'Choose the type of case.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    setState(() => _saving = true);
    try {
      final c = await services.welfare.createCase(
        WelfareCaseDraft(
          memberId: _member!.id,
          caseTypeId: _type!.id,
          occurredOn: _occurredOn,
          requestedAmount: parseMoney(_amount.text),
          beneficiary: _beneficiary.text,
          description: _description.text,
        ),
        user.welfareActor(services.deviceId),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => CaseDetailScreen(caseId: c.id)),
      );
    } on WelfareException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    final fixed = _type?.benefitAmount;
    return Scaffold(
      appBar: AppBar(title: const Text('New welfare case')),
      body: types == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.person_search),
                      title: Text(_member?.fullName ?? 'Choose member'),
                      subtitle: _member == null
                          ? null
                          : Text(_member!.memberNo),
                      onTap: widget.member == null ? _pickMember : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<WelfareCaseType>(
                    isExpanded: true,
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type of case',
                    ),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(value: t, child: Text(t.name)),
                    ],
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  if (_type != null) ...[
                    const SizedBox(height: 16),
                    if (fixed != null)
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(formatMoney(fixed)),
                          subtitle: const Text(
                            'Fixed benefit for this type of case',
                          ),
                        ),
                      )
                    else
                      TextFormField(
                        controller: _amount,
                        decoration: const InputDecoration(
                          labelText: 'Amount requested',
                          helperText:
                              'No fixed amount has been approved for this type',
                          prefixText: 'GHS ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final a = parseMoney(v ?? '');
                          return a == null || a <= 0 ? 'Enter an amount' : null;
                        },
                      ),
                  ],
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Date it happened'),
                    subtitle: Text(formatDate(_occurredOn)),
                    onTap: _pickDate,
                  ),
                  TextFormField(
                    controller: _beneficiary,
                    decoration: const InputDecoration(
                      labelText: 'For whom, if not the member',
                      hintText: 'e.g. Mother, Akosua Mensah',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Details'),
                    maxLines: 3,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.send),
                    label: const Text('Submit for approval'),
                  ),
                ],
              ),
            ),
    );
  }
}
