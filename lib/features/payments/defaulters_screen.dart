import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/money.dart';
import '../../data/database.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Defaulters')),
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
                  trailing: Text(formatMoney(owed)),
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
