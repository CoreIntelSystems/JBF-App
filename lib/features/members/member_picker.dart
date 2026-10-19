import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/repositories/member_repository.dart';

/// Search and pick a member.
class MemberPicker extends StatefulWidget {
  const MemberPicker({super.key});

  @override
  State<MemberPicker> createState() => MemberPickerState();
}

class MemberPickerState extends State<MemberPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final members = context.read<AppServices>().members;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search name, username, phone or ID',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: StreamBuilder<List<MemberWithZones>>(
        stream: members.watchMembers(MemberFilter(query: _query)),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          return ListView(
            children: [
              for (final item in items)
                ListTile(
                  title: Text(item.member.fullName),
                  subtitle: Text('${item.member.memberNo} · ${item.zoneLabel}'),
                  onTap: () => Navigator.of(context).pop(item.member),
                ),
            ],
          );
        },
      ),
    );
  }
}
