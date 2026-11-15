import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/platform/notification_permission.dart';
import '../../state/app_settings_provider.dart';
import '../../state/onboarding_provider.dart';
import '../../state/source_settings_provider.dart';

/// Layar sambutan untuk instalasi baru: bahasa, cara kerja, dan pengaturan awal.
/// Muncul di atas aplikasi (lihat `HubReaderApp`), sekali saja.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  /// Jumlah halaman; dipakai tes.
  static const pageCount = 3;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with WidgetsBindingObserver {
  final _controller = PageController();
  int _page = 0;
  bool? _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationPermission.isGranted().then((v) {
      if (mounted) setState(() => _notifications = v);
    });
  }

  /// Tombol kembali: mundur satu halaman; di halaman pertama biarkan sistem
  /// menutup aplikasi. Layar ini berada di luar Navigator (di atas router), jadi
  /// PopScope tidak menerima tombol kembali; pengamat ini dipanggil setelah router
  /// (yang saat onboarding masih di rute awal dan tidak bisa mundur).
  /// Android hanya meneruskan tombol kembali ke Flutter bila ada yang menyatakan
  /// "framework menangani kembali" (biasanya Navigator/PopScope, yang tidak ada di
  /// atas router). Tanpa ini sistem langsung menutup aplikasi.
  void _syncBack() => SystemNavigator.setFrameworkHandlesBack(_page > 0);

  @override
  Future<bool> didPopRoute() async {
    if (_page == 0) return false;
    _go(_page - 1);
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemNavigator.setFrameworkHandlesBack(false);
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == OnboardingScreen.pageCount - 1;

  void _go(int page) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(page, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _next() => _last ? _finish() : _go(_page + 1);

  void _finish() => ref.read(onboardingDoneProvider.notifier).complete();

  Future<void> _askNotifications() async {
    final granted = await NotificationPermission.request();
    if (mounted) setState(() => _notifications = granted ?? _notifications);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: _last
                      // Ruang tetap supaya tata letak tidak bergeser di halaman terakhir.
                      ? const SizedBox(height: 48)
                      : TextButton(onPressed: _finish, child: Text(tr('Lewati'))),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    _syncBack();
                  },
                  children: [
                    _Page(
                      icon: Icons.auto_stories,
                      title: tr('Selamat datang di Hub Reader'),
                      body: tr('Baca komik dan novel langsung dari situsnya, di HP kamu. Tanpa akun dan tanpa server perantara.'),
                      extra: _LanguagePicker(),
                    ),
                    _Page(
                      icon: Icons.travel_explore,
                      title: tr('Cara kerjanya'),
                      extra: Column(children: [
                        _Point(Icons.extension_outlined, tr('Komik'), tr('Pilih dari ratusan sumber, lalu jelajahi dan baca.')),
                        _Point(Icons.menu_book_outlined, tr('Novel'), tr('Plugin LNReader dijalankan langsung di HP.')),
                        _Point(Icons.favorite_outline, tr('Favorit'), tr('Simpan favorit, lanjutkan bacaan, dan unduh bab untuk offline.')),
                        _Point(Icons.folder_open_outlined, tr('File sendiri'), tr('Impor CBZ atau EPUB sebagai sumber Lokal.')),
                      ]),
                    ),
                    _Page(
                      icon: Icons.tune,
                      title: tr('Atur sesuai kebutuhan'),
                      body: tr('Semuanya bisa diubah nanti di Pengaturan.'),
                      extra: _Preferences(notifications: _notifications, onAskNotifications: _askNotifications),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(children: [
                        for (var i = 0; i < OnboardingScreen.pageCount; i++)
                          Semantics(
                            label: trp('Halaman {i} dari {n}', {'i': i + 1, 'n': OnboardingScreen.pageCount}),
                            selected: i == _page,
                            child: AnimatedContainer(
                              duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _page ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _page ? scheme.primary : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    FilledButton(onPressed: _next, child: Text(_last ? tr('Mulai membaca') : tr('Lanjut'))),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.icon, required this.title, this.body, this.extra});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bisa digulir: di font besar isi halaman lebih tinggi dari layar.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 24),
              Semantics(header: true, child: Text(title, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700))),
              if (body != null) ...[
                const SizedBox(height: 12),
                Text(body!, style: theme.textTheme.bodyLarge),
              ],
              if (extra != null) ...[const SizedBox(height: 24), extra!],
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePicker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appSettingsProvider.select((s) => s.language));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Bahasa antarmuka aplikasi'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<AppLanguage>(
            segments: [for (final l in AppLanguage.values) ButtonSegment(value: l, label: Text(l.label))],
            selected: {language},
            onSelectionChanged: (v) => ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(language: v.first)),
          ),
        ),
      ],
    );
  }
}

class _Preferences extends ConsumerWidget {
  const _Preferences({required this.notifications, required this.onAskNotifications});

  final bool? notifications;
  final VoidCallback onAskNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final nsfw = ref.watch(showNsfwSourcesProvider);
    final granted = notifications == true;
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.wifi),
          title: Text(tr('Unduh hanya lewat Wi-Fi')),
          subtitle: Text(tr('Hemat kuota: antrean unduhan menunggu Wi-Fi')),
          value: settings.downloadWifiOnly,
          onChanged: (v) => ref.read(appSettingsProvider.notifier).update((s) => s.copyWith(downloadWifiOnly: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.eighteen_up_rating_outlined),
          title: Text(tr('Tampilkan sumber NSFW (18+)')),
          subtitle: Text(tr('Sumber khusus dewasa ikut tampil di daftar')),
          value: nsfw,
          onChanged: (v) => ref.read(showNsfwSourcesProvider.notifier).set(v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(granted ? Icons.notifications_active_outlined : Icons.notifications_none),
          title: Text(tr('Notifikasi bab baru')),
          subtitle: Text(granted ? tr('Diizinkan') : tr('Beri tahu saat favorit punya bab baru')),
          trailing: granted ? const Icon(Icons.check_circle_outline) : OutlinedButton(onPressed: onAskNotifications, child: Text(tr('Izinkan'))),
        ),
      ],
    );
  }
}
