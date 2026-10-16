import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_services.dart';
import '../../data/repositories/member_repository.dart';
import '../../domain/whatsapp_invite.dart';

/// One tap per member opens WhatsApp with their ID message ready to send.
class SendIdsScreen extends StatefulWidget {
  const SendIdsScreen({super.key, this.filter = const MemberFilter()});

  final MemberFilter filter;

  @override
  State<SendIdsScreen> createState() => _SendIdsScreenState();
}

class _SendIdsScreenState extends State<SendIdsScreen> {
  final _opened = <String>{};
  late final Future<(List<MemberWithZones>, String)> _load = _loadAll();
  String _query = '';

  Future<(List<MemberWithZones>, String)> _loadAll() async {
    final services = context.read<AppServices>();
    final members = await services.members.watchMembers(widget.filter).first;
    final org = await services.payments.org();
    return (members, org.name);
  }

  /// Opens WhatsApp for the next member not yet opened, in list order.
  Future<void> _sendNext(List<MemberWithZones> all, String orgName) async {
    for (final mz in all) {
      if (_opened.contains(mz.member.id)) continue;
      final m = mz.member;
      if (whatsappNumber(m.phone) == null &&
          whatsappNumber(m.whatsapp) == null) {
        continue;
      }
      await _send(mz, orgName);
      return;
    }
  }

  Future<void> _send(MemberWithZones mz, String orgName) async {
    final m = mz.member;
    final number = whatsappNumber(m.phone) ?? whatsappNumber(m.whatsapp);
    final messenger = ScaffoldMessenger.of(context);
    if (number == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('${m.fullName} has no usable phone number.')),
      );
      return;
    }
    final link = whatsappLink(
      number,
      idInviteMessage(name: m.fullName, memberNo: m.memberNo, orgName: orgName),
    );
    final ok = await launchUrl(link, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (ok) {
      setState(() => _opened.add(m.id));
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('WhatsApp could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send IDs on WhatsApp')),
      body: FutureBuilder(
        future: _load,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (all, orgName) = snap.data!;
          final q = _query.trim().toLowerCase();
          final shown = [
            for (final mz in all)
              if (q.isEmpty ||
                  mz.member.fullName.toLowerCase().contains(q) ||
                  mz.member.memberNo.toLowerCase().contains(q))
                mz,
          ];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  key: const Key('send_ids_search'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name or member ID',
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Tap "Send to the next person" again and again to go through '
                  'everyone, or tap Send on one member. ${_opened.length} of ${all.length} opened.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('send_next'),
                    icon: const Icon(Icons.send),
                    label: const Text('Send to the next person'),
                    onPressed: () => _sendNext(all, orgName),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final mz = shown[i];
                    final m = mz.member;
                    final hasNumber =
                        whatsappNumber(m.phone) != null ||
                        whatsappNumber(m.whatsapp) != null;
                    return ListTile(
                      title: Text(m.fullName),
                      subtitle: Text(
                        '${m.memberNo}  ·  ${hasNumber ? (m.phone ?? m.whatsapp) : 'no phone number'}',
                      ),
                      trailing: _opened.contains(m.id)
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : TextButton(
                              onPressed: hasNumber
                                  ? () => _send(mz, orgName)
                                  : null,
                              child: const Text('Send'),
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
