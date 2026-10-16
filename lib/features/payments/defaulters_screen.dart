import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../domain/phone.dart';
import '../members/member_detail_screen.dart';

/// Members who owe monthly dues, largest balance first.
class DefaultersScreen extends StatefulWidget {
  const DefaultersScreen({super.key});

  @override
  State<DefaultersScreen> createState() => _DefaultersScreenState();
}

class _DefaultersScreenState extends State<DefaultersScreen> {
  late final Future<List<(Member, int)>> _list = context
      .read<AppServices>()
      .payments
      .defaulters();

  late final Future<OrgSetting> _org = context
      .read<AppServices>()
      .payments
      .org();

  Future<void> _whatsApp(Member m, int owed) async {
    final org = await _org;
    final uri = PhoneNumbers.whatsApp(
      m.phone,
      'Hello ${m.fullName}, this is a friendly reminder from '
      '${org.shortName} that your dues balance is ${formatMoney(owed)}. '
      'Thank you.',
    );
    if (!mounted) return;
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No usable phone number for this member.'),
        ),
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  Future<void> _shareList(List<(Member, int)> items) async {
    final org = await _org;
    final total = items.fold(0, (a, d) => a + d.$2);
    final lines = [
      '${org.shortName} dues outstanding',
      for (final (m, owed) in items)
        '${m.fullName} (${m.memberNo}): '
            '${formatMoney(owed)}',
      'Total: ${formatMoney(total)}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defaulters'),
        actions: [
          FutureBuilder<List<(Member, int)>>(
            future: _list,
            builder: (context, snap) => IconButton(
              tooltip: 'Share list',
              icon: const Icon(Icons.share),
              onPressed: (snap.data?.isEmpty ?? true)
                  ? null
                  : () => _shareList(snap.data!),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<(Member, int)>>(
        future: _list,
        builder: (context, snap) {
          final items = snap.data;
          if (items == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nobody owes dues. If you expected names here, check the '
                  'monthly dues amount under More > Contribution types.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final total = items.fold(0, (a, d) => a + d.$2);
          return ListView(
            children: [
              ListTile(
                title: Text('${items.length} members owe'),
                trailing: Text(
                  formatMoney(total),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              for (final (m, owed) in items)
                ListTile(
                  title: Text(m.fullName),
                  subtitle: Text('${m.memberNo} · ${m.phone ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatMoney(owed)),
                      IconButton(
                        tooltip: 'Remind on WhatsApp',
                        icon: const Icon(Icons.chat_outlined),
                        onPressed: m.phone == null
                            ? null
                            : () => _whatsApp(m, owed),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MemberDetailScreen(memberId: m.id),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
