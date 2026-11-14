import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../state/app_settings_provider.dart';

/// Minta sidik jari / PIN / pola perangkat sebelum isi aplikasi tampil,
/// saat dibuka dan setelah di latar lebih lama dari `lockAfter`.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  /// Verifikasi pemilik perangkat (dipakai juga saat menyalakan kunci).
  static Future<bool> authenticate(String reason) async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      return await auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  late bool _locked = ref.read(appSettingsProvider).appLock;
  DateTime? _pausedAt;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dialog sidik jari sendiri membuat aplikasi "paused"; abaikan saat itu.
    if (_authenticating) return;
    final settings = ref.read(appSettingsProvider);
    if (!settings.appLock) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at != null && DateTime.now().difference(at) >= settings.lockAfter) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await AppLockGate.authenticate('Buka Hub Reader');
    _authenticating = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appSettingsProvider.select((s) => s.appLock));
    if (!enabled || !_locked) return widget.child;
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Isi tetap dibangun (state tab terjaga) tapi tertutup.
        Offstage(child: widget.child),
        Positioned.fill(
          child: Material(
            color: theme.colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(tr('Hub Reader terkunci'), style: theme.textTheme.titleMedium),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(tr('Buka')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
