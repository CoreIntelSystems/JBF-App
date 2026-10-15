import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app_services.dart';
import '../../data/repositories/events_repository.dart';
import '../auth/auth_cubit.dart';

/// Checks members in by scanning the QR code on their ID card. Works
/// offline; the member ID can also be typed in.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.occasionId, required this.title});

  final String occasionId;
  final String title;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  final _typed = TextEditingController();
  String? _lastRaw;
  DateTime _lastAt = DateTime(2000);
  bool _busy = false;
  int _count = 0;

  /// (message, ok) for the banner at the bottom.
  (String, bool)? _result;

  @override
  void dispose() {
    _controller.dispose();
    _typed.dispose();
    super.dispose();
  }

  Future<void> _checkIn(String raw) async {
    final now = DateTime.now();
    if (_busy) return;
    if (raw == _lastRaw && now.difference(_lastAt).inSeconds < 3) return;
    _lastRaw = raw;
    _lastAt = now;
    _busy = true;
    final services = context.read<AppServices>();
    final user = context.read<AuthCubit>().user!;
    try {
      final (member, already) = await services.events.checkInByQr(
        widget.occasionId,
        raw,
        user.actor(services.deviceId),
        recordedByName: user.displayName,
      );
      if (!already) _count++;
      HapticFeedback.mediumImpact();
      setState(
        () => _result = (
          already
              ? '${member.fullName} is already checked in'
              : '${member.fullName} checked in',
          true,
        ),
      );
    } on EventsException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _result = (e.message, false));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: Text('Scan: ${widget.title}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw != null) _checkIn(raw);
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'The camera is not available '
                    '(${error.errorCode.name}). Allow camera access in the '
                    'phone settings, or type the member ID below.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          if (result != null)
            Container(
              color: result.$2 ? Colors.green.shade700 : scheme.error,
              padding: const EdgeInsets.all(16),
              child: Text(
                result.$1,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('$_count checked in on this screen'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _typed,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Or type the member ID',
                      hintText: 'e.g. JBF-000123',
                      suffixIcon: IconButton(
                        tooltip: 'Check in',
                        icon: const Icon(Icons.login),
                        onPressed: () {
                          _lastRaw = null;
                          _checkIn(_typed.text.trim().toUpperCase());
                          _typed.clear();
                        },
                      ),
                    ),
                    onSubmitted: (v) {
                      _lastRaw = null;
                      _checkIn(v.trim().toUpperCase());
                      _typed.clear();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
