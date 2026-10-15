import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../backup/backup_screen.dart';
import '../cloud/cloud_sync_screen.dart';
import 'auth_cubit.dart';
import 'brand_header.dart';
import 'member_sign_in_screen.dart';

/// First run on a new device: create the Super Administrator.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _username, _password, _confirm, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthCubit>().setup(
        displayName: _name.text,
        username: _username.text,
        password: _password.text,
        pin: _pin.text.isEmpty ? null : _pin.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(subtitle: 'Welcome'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('memberSignIn'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MemberSignInScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Sign in with your member ID'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const MemberSignInScreen(activate: true),
                              ),
                            ),
                      child: const Text('First time? Activate your account'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Setting up the app for a new organisation? Create the '
                      'Super Administrator account for this device.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Your name'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter your name.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username'),
                      autocorrect: false,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter a username.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) =>
                          AuthRepository.validatePassword(v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                      obscureText: true,
                      validator: (v) => v != _password.text
                          ? 'Passwords do not match.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pin,
                      decoration: const InputDecoration(
                        labelText: 'Quick PIN (optional, 4 to 6 digits)',
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      validator: (v) => (v ?? '').isEmpty
                          ? null
                          : AuthRepository.validatePin(v!),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const BackupScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.restore),
                      label: const Text('New phone? Restore from a backup'),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const JoinCloudScreen(fromSetup: true),
                              ),
                            ),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Sign in online with an old username'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
