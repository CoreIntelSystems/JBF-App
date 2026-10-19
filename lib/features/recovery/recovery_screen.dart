import 'package:flutter/material.dart';

/// Shown instead of a blank screen when the phone's records cannot be
/// opened, for example after the phone's secure storage was reset.
class RecoveryApp extends StatefulWidget {
  const RecoveryApp({super.key, required this.error, required this.onReset});

  /// What went wrong, for the technical line at the bottom.
  final Object error;

  /// Erases this phone's local records and starts the app again. Returns
  /// an error message if the restart fails again.
  final Future<void> Function() onReset;

  @override
  State<RecoveryApp> createState() => _RecoveryAppState();
}

class _RecoveryAppState extends State<RecoveryApp> {
  bool _busy = false;
  String? _failed;

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erase this phone’s data?'),
        content: const Text(
          'This removes the records stored on this phone only. Anything this '
          'phone had already synced to the cloud is not lost: set the phone '
          'up again and sign in online. Records that were never synced can '
          'only come back from a backup file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmErase'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Erase and start again'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _failed = null;
    });
    try {
      await widget.onReset();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B6E3B),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.lock_reset, size: 56),
                const SizedBox(height: 16),
                Text(
                  'This phone’s records cannot be opened',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The key that protects the records on this phone was lost, '
                  'which can happen after a phone reset or a system update. '
                  'Your data is not shown to anyone.\n\n'
                  'You can set this phone up again. If it was connected to the '
                  'cloud, sign in online to get everything back. Otherwise use '
                  '“New phone? Restore from a backup” on the first screen.',
                ),
                const SizedBox(height: 24),
                if (_failed != null) ...[
                  Text(
                    'That did not work: $_failed',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  key: const Key('eraseAndRestart'),
                  onPressed: _busy ? null : () => _reset(context),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(_busy ? 'Working…' : 'Set this phone up again'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Technical detail: ${widget.error}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
