import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';

/// Reminders shown as notifications on this phone.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool _loaded = false;
  int? _day;

  @override
  void initState() {
    super.initState();
    context.read<AppServices>().reminders.duesDay().then((d) {
      if (mounted) {
        setState(() {
          _day = d;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _set(int? day) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _day = day);
    final allowed = await context.read<AppServices>().reminders.setDuesDay(day);
    if (!allowed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked for this app. Allow them in the '
            'phone settings to see reminders.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Monthly dues reminder'),
                  subtitle: const Text(
                    'A notification on this phone at 9 am on the dues day, '
                    'so you remember to follow up members.',
                  ),
                  value: _day != null,
                  onChanged: (on) => _set(on ? 1 : null),
                ),
                if (_day != null)
                  DropdownButtonFormField<int>(
                    initialValue: _day,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Day of the month',
                    ),
                    items: [
                      for (var d = 1; d <= 28; d++)
                        DropdownMenuItem(value: d, child: Text('Day $d')),
                    ],
                    onChanged: (d) => _set(d),
                  ),
                const SizedBox(height: 24),
                const Text(
                  'To remind members themselves, open Payments > Defaulters '
                  'and tap the WhatsApp button next to a name, or share the '
                  'whole list to a group. Meeting and event reminders are set '
                  'when you create the meeting or event.',
                ),
              ],
            ),
    );
  }
}
