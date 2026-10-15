import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import '../payments/member_ledger_section.dart';
import '../executives/executives_screen.dart';
import '../welfare/member_welfare_section.dart';
import 'id_card_pdf.dart';
import 'member_access_section.dart';
import 'member_form_screen.dart';
import 'members_screen.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({
    super.key,
    required this.memberId,
    this.self = false,
  });

  final String memberId;

  /// The signed-in person's own record, shown as their "My dues" tab.
  final bool self;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late final Stream<MemberWithZones?> _member = context
      .read<AppServices>()
      .members
      .watchMember(widget.memberId);

  Future<void> _changeStatus(MemberWithZones item) async {
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    final picked = await showDialog<MemberStatus>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Change membership status'),
        children: [
          for (final s in MemberStatus.values)
            ListTile(
              leading: Icon(
                s == item.member.status
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(capitalize(s.name)),
              onTap: () => Navigator.of(context).pop(s),
            ),
        ],
      ),
    );
    if (picked == null || picked == item.member.status) return;
    await services.members.changeStatus(
      item.member.id,
      picked,
      user.actor(services.deviceId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.user);
    final canEdit = user?.can(Perm.membersEdit) ?? false;
    final canStatus =
        !widget.self && (user?.can(Perm.membersChangeStatus) ?? false);
    return StreamBuilder<MemberWithZones?>(
      stream: _member,
      builder: (context, snap) {
        final item = snap.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('Member not found.'),
            ),
          );
        }
        final m = item.member;
        String? primary(Zone z) =>
            item.zones.length > 1 && z.id == item.primaryZoneId
            ? 'Primary'
            : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.self ? 'My dues and record' : m.memberNo),
            actions: [
              IconButton(
                tooltip: 'ID card',
                icon: const Icon(Icons.badge_outlined),
                onPressed: () async {
                  final org = await context.read<AppServices>().payments.org();
                  final bytes = await buildIdCardsPdf([item], org);
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'id-card-${m.memberNo}.pdf',
                  );
                },
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemberFormScreen(existing: item),
                    ),
                  ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  MemberAvatar(member: m, radius: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        StatusChip(status: m.status),
                      ],
                    ),
                  ),
                ],
              ),
              if (canStatus) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _changeStatus(item),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Change status'),
                ),
              ],
              MemberLedgerSection(member: m),
              MemberWelfareSection(member: m, own: widget.self),
              MemberPositionsSection(member: m),
              if (!widget.self && MemberAccessSection.visibleTo(user))
                MemberAccessSection(member: m, zones: item.zones),
              _Section('Zones', [
                for (final z in item.zones)
                  _Row(zoneDisplayName(z), primary(z) ?? ''),
              ]),
              _Section('Membership', [
                _Row('Member ID', m.memberNo),
                _Row('Date joined', formatDate(m.dateJoined)),
                if (m.statusDate != null)
                  _Row('Status since', formatDate(m.statusDate)),
              ]),
              _Section('Personal', [
                _Row('Gender', m.gender),
                _Row('Date of birth', formatDate(m.dateOfBirth)),
                _Row('Nationality', m.nationality),
                _Row('Occupation', m.occupation),
                _Row('Marital status', m.maritalStatus),
                _Row('Location', m.location),
              ]),
              _Section('Contact', [
                _Row('Mobile', m.phone),
                _Row('WhatsApp', m.whatsapp),
                _Row('Email', m.email),
                _Row('Address', m.address),
                _Row('GPS address', m.gpsAddress),
              ]),
              _Section('Emergency contact', [
                _Row('Name', m.emergencyName),
                _Row('Number', m.emergencyPhone),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.rows);
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(flex: 3, child: Text((value ?? '').isEmpty ? '-' : value!)),
        ],
      ),
    );
  }
}
