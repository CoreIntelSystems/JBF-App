import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../core/format.dart';
import '../../data/database.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late final Stream<List<AuditLog>> _logs = context
      .read<AppServices>()
      .audit
      .watchRecent();

  static const _labels = {
    'login.success': 'Signed in',
    'login.failed': 'Failed sign in',
    'logout': 'Signed out',
    'member.create': 'Registered member',
    'member.update': 'Edited member',
    'member.status': 'Changed member status',
    'user.create': 'Created user',
    'user.update': 'Changed user',
    'user.password_change': 'Changed own password',
    'user.password_reset': 'Reset a password',
    'user.pin_set': 'Set PIN',
    'user.pin_remove': 'Removed PIN',
    'user.biometric_on': 'Turned fingerprint on',
    'user.biometric_off': 'Turned fingerprint off',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: StreamBuilder<List<AuditLog>>(
        stream: _logs,
        builder: (context, snap) {
          final logs = snap.data;
          if (logs == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (logs.isEmpty) return const Center(child: Text('Nothing yet.'));
          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final l = logs[i];
              return ExpansionTile(
                leading: Icon(
                  l.action == 'login.failed'
                      ? Icons.warning_amber
                      : Icons.history,
                ),
                title: Text(_labels[l.action] ?? l.action),
                subtitle: Text(
                  '${l.username ?? 'unknown'} · ${formatDateTime(l.at)}',
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  if (l.oldValue != null)
                    SelectableText('Before: ${l.oldValue}'),
                  if (l.newValue != null)
                    SelectableText('After: ${l.newValue}'),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
