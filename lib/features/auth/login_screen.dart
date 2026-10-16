import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/org_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../portal/member_statement_screen.dart';
import 'auth_cubit.dart';
import 'member_sign_in_screen.dart';
import 'brand_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final AuthSignedOut state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _username = TextEditingController(
    text: widget.state.lastUsername ?? '',
  );
  final _secret = TextEditingController();
  LoginMethod _method = LoginMethod.password;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.state.biometricReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() => _run(() async {
    if (_username.text.trim().isEmpty || _secret.text.isEmpty) {
      throw AuthException(
        'Enter your member ID and '
        '${_method == LoginMethod.pin ? 'PIN' : 'password'}.',
      );
    }
    await context.read<AuthCubit>().login(
      _username.text,
      _secret.text,
      _method,
    );
  });

  Future<void> _biometric() =>
      _run(() => context.read<AuthCubit>().loginWithBiometrics());

  @override
  Widget build(BuildContext context) {
    final isPin = _method == LoginMethod.pin;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const BrandHeader(subtitle: 'Sign in to continue'),
                    const SizedBox(height: 24),
                    SegmentedButton<LoginMethod>(
                      segments: const [
                        ButtonSegment(
                          value: LoginMethod.password,
                          label: Text('Password'),
                          icon: Icon(Icons.password),
                        ),
                        ButtonSegment(
                          value: LoginMethod.pin,
                          label: Text('PIN'),
                          icon: Icon(Icons.pin),
                        ),
                      ],
                      selected: {_method},
                      onSelectionChanged: (s) => setState(() {
                        _method = s.first;
                        _secret.clear();
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'Member ID or username',
                      ),
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _secret,
                      decoration: InputDecoration(
                        labelText: isPin ? 'PIN' : 'Password',
                      ),
                      obscureText: true,
                      keyboardType: isPin
                          ? TextInputType.number
                          : TextInputType.visiblePassword,
                      maxLength: isPin ? 6 : null,
                      autofillHints: isPin
                          ? null
                          : const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
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
                      child: const Text('Sign in'),
                    ),
                    if (widget.state.biometricReady) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _biometric,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          'Use fingerprint (${widget.state.lastUsername})',
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MemberSignInScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('Sign in online with member ID'),
                    ),
                    TextButton(
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
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const MemberStatementScreen(),
                              ),
                            ),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: const Text('Member? Check my dues'),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Powered by ${OrgDefaults.poweredBy}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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
