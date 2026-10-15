import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/permissions.dart';
import '../auth/auth_cubit.dart';
import 'id_card_pdf.dart';
import 'member_detail_screen.dart';
import 'member_form_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  MemberFilter _filter = const MemberFilter();
  late Stream<List<MemberWithZones>> _members;
  late final Stream<List<Zone>> _zones;

  MemberRepository get _repo => context.read<AppServices>().members;

  @override
  void initState() {
    super.initState();
    _members = _repo.watchMembers(_filter);
    _zones = _repo.watchZones();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _apply(MemberFilter f) => setState(() {
    _filter = f;
    _members = _repo.watchMembers(f);
  });

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _apply(
        MemberFilter(
          query: text,
          zoneId: _filter.zoneId,
          status: _filter.status,
        ),
      ),
    );
  }

  Future<void> _printCards() async {
    final services = context.read<AppServices>();
    final members = await _repo.watchMembers(_filter).first;
    final org = await services.payments.org();
    final roles = await services.auth.roleLabels([
      for (final m in members) m.member.id,
    ]);
    final bytes = await buildIdCardsPdf(members, org, roles: roles);
    await Printing.sharePdf(bytes: bytes, filename: 'id-cards.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        context.select((AuthCubit c) => c.user?.can(Perm.membersCreate)) ??
        false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          IconButton(
            tooltip: 'ID cards for this list',
            icon: const Icon(Icons.badge_outlined),
            onPressed: _printCards,
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MemberFormScreen(),
                ),
              ),
              icon: const Icon(Icons.person_add),
              label: const Text('Add member'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, phone or member ID',
              ),
            ),
          ),
          StreamBuilder<List<Zone>>(
            stream: _zones,
            builder: (context, snap) {
              final scope = context.read<AppServices>().scope;
              final zones = (snap.data ?? const <Zone>[])
                  .where((z) => scope.allowsZone(z.id))
                  .toList();
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _Dropdown<MemberStatus?>(
                      label: 'Status',
                      value: _filter.status,
                      items: {
                        null: 'All statuses',
                        for (final s in MemberStatus.values)
                          s: capitalize(s.name),
                      },
                      onChanged: (s) => _apply(
                        MemberFilter(
                          query: _filter.query,
                          zoneId: _filter.zoneId,
                          status: s,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Dropdown<String?>(
                      label: 'Zone',
                      value: _filter.zoneId,
                      items: {
                        null: 'All zones',
                        for (final z in zones) z.id: zoneDisplayName(z),
                      },
                      onChanged: (z) => _apply(
                        MemberFilter(
                          query: _filter.query,
                          zoneId: z,
                          status: _filter.status,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: StreamBuilder<List<MemberWithZones>>(
              stream: _members,
              builder: (context, snap) {
                final list = snap.data;
                if (list == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (list.isEmpty) {
                  return const Center(child: Text('No members found.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => MemberTile(list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MemberTile extends StatelessWidget {
  const MemberTile(this.item, {super.key});

  final MemberWithZones item;

  @override
  Widget build(BuildContext context) {
    final m = item.member;
    return ListTile(
      leading: MemberAvatar(member: m),
      title: Text(m.fullName),
      subtitle: Text(
        '${m.memberNo} · ${item.zoneLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: m.status == MemberStatus.active
          ? null
          : StatusChip(status: m.status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MemberDetailScreen(memberId: m.id),
        ),
      ),
    );
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.radius = 22});

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = member.photoPath;
    if (path != null && File(path).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(path)),
      );
    }
    final initials = member.fullName
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return CircleAvatar(radius: radius, child: Text(initials));
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final MemberStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status) {
      MemberStatus.active => Colors.green,
      MemberStatus.inactive => Colors.grey,
      MemberStatus.suspended => scheme.error,
      MemberStatus.deceased => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(capitalize(status.name), style: TextStyle(color: color)),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DropdownButton<T>(
        value: items.containsKey(value) ? value : null,
        hint: Text(label),
        underline: const SizedBox.shrink(),
        items: [
          for (final e in items.entries)
            DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
        ],
        onChanged: (v) => onChanged(v as T),
      ),
    );
  }
}
