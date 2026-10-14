import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_services.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/auth_cubit.dart';

/// The signed-in user's own password, PIN and fingerprint settings.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool? _biometricAvailable;

  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().biometricsAvailable().then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guard(Future<AppUser> Function() action, String done) async {
    final cubit = context.read<AuthCubit>();
    try {
      cubit.updateUser(await action());
      _toast(done);
    } on AuthException catch (e) {
      _toast(e.message);
    }
  }

  Future<List<String>?> _ask(
    String title,
    List<String> labels, {
    bool numeric = false,
  }) {
    final controllers = [for (final _ in labels) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: controllers[i],
                  obscureText: true,
                  keyboardType: numeric ? TextInputType.number : null,
                  maxLength: numeric ? 6 : null,
                  decoration: InputDecoration(labelText: labels[i]),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () =>
                Navigator.pop(context, [for (final c in controllers) c.text]),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    final auth = services.auth;
    final deviceId = services.deviceId;
    final user = context.select((AuthCubit c) => c.user);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('My login and security')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change password'),
            onTap: () async {
              final v = await _ask('Change password', [
                'Current password',
                'New password',
                'Repeat new password',
              ]);
              if (v == null) return;
              if (v[1] != v[2]) return _toast('New passwords do not match.');
              await _guard(
                () => auth.changePassword(user, v[0], v[1], deviceId: deviceId),
                'Password changed.',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.pin),
            title: Text(user.hasPin ? 'Change PIN' : 'Set a quick PIN'),
            subtitle: const Text('4 to 6 digits for faster sign in'),
            onTap: () async {
              final v = await _ask('Quick PIN', [
                'New PIN',
                'Repeat PIN',
              ], numeric: true);
              if (v == null) return;
              if (v[0] != v[1]) return _toast('PINs do not match.');
              await _guard(
                () => auth.setPin(user, v[0], deviceId: deviceId),
                'PIN saved.',
              );
            },
          ),
          if (user.hasPin)
            ListTile(
              leading: const Icon(Icons.backspace_outlined),
              title: const Text('Remove PIN'),
              onTap: () => _guard(
                () => auth.setPin(user, null, deviceId: deviceId),
                'PIN removed.',
              ),
            ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Fingerprint sign in'),
            subtitle: Text(
              _biometricAvailable == false
                  ? 'This phone has no fingerprint set up.'
                  : 'Sign in on this phone with your fingerprint.',
            ),
            value: user.biometricEnabled,
            onChanged: _biometricAvailable != true
                ? null
                : (on) async {
                    final cubit = context.read<AuthCubit>();
                    if (on &&
                        !await cubit.confirmBiometrics(
                          'Confirm your fingerprint to switch this on',
                        )) {
                      return;
                    }
                    await _guard(
                      () => auth.setBiometric(user, on, deviceId: deviceId),
                      on
                          ? 'Fingerprint sign in is on.'
                          : 'Fingerprint sign in is off.',
                    );
                  },
          ),
        ],
      ),
    );
  }
}
