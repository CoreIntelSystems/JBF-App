import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/sync/sync_api.dart';
import 'auth_cubit.dart';
import 'brand_header.dart';

/// Every member, executives included, signs in with their member ID. The
/// first time they activate: the phone number the association has for them
/// proves who they are, and they choose a password.
class MemberSignInScreen extends StatefulWidget {
  const MemberSignInScreen({super.key, this.activate = false});

  final bool activate;

  @override
  State<MemberSignInScreen> createState() => _MemberSignInScreenState();
}

class _MemberSignInScreenState extends State<MemberSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _memberNo = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late bool _activate = widget.activate;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_memberNo, _phone, _password, _confirm]) {
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
    final nav = Navigator.of(context);
    try {
      await context.read<AuthCubit>().memberOnline(
        memberNo: _memberNo.text,
        password: _password.text,
        phone: _activate ? _phone.text : null,
      );
      if (mounted) nav.popUntil((r) => r.isFirst);
    } on SyncException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.offline
              ? 'No internet connection. Connect and try again.'
              : e.message,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activate ? 'Activate my account' : 'Member sign in'),
      ),
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
                    BrandHeader(
                      subtitle: _activate
                          ? 'Enter your member ID and the phone number the '
                                'association has for you, then choose a '
                                'password.'
                          : 'Sign in with your member ID and password.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('memberNo'),
                      controller: _memberNo,
                      decoration: const InputDecoration(
                        labelText: 'Member ID',
                        hintText: 'On your ID card or receipts',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Enter your member ID.'
                          : null,
                    ),
                    if (_activate) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('memberPhone'),
                        controller: _phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: 'e.g. 024 123 4567',
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Enter your phone number.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('memberPassword'),
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: _activate ? 'Choose a password' : 'Password',
                      ),
                      obscureText: true,
                      validator: (v) => _activate
                          ? AuthRepository.validatePassword(v ?? '')
                          : (v ?? '').isEmpty
                          ? 'Enter your password.'
                          : null,
                      onFieldSubmitted: (_) => _activate ? null : _submit(),
                    ),
                    if (_activate) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const Key('memberConfirm'),
                        controller: _confirm,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        obscureText: true,
                        validator: (v) => v != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
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
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _activate ? 'Activate and sign in' : 'Sign in',
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _activate = !_activate;
                              _error = null;
                            }),
                      child: Text(
                        _activate
                            ? 'Already activated? Sign in'
                            : 'First time? Activate your account',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Forgot your password? Ask your Zone Secretary or Zone '
                      'Mayor to reset your sign-in, then activate again. '
                      'You need internet to sign in the first time.',
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
