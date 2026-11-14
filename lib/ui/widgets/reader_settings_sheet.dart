import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/reader_settings_provider.dart';

/// Lembar pengaturan reader komik: mode, potong tepi, filter warna.
///
/// Mode dan potong tepi bisa disimpan khusus untuk seri [seriesKey]; filter
/// warna selalu berlaku umum.
Future<void> showReaderSettingsSheet(BuildContext context, String seriesKey) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ReaderSettingsSheet(seriesKey: seriesKey),
    );

/// Pratinjau layar: zona kiri/kanan berlabel "Maju" / "Mundur".
class _TapZonePreview extends StatelessWidget {
  const _TapZonePreview({required this.zones, required this.rtl});

  final TapZones zones;
  final bool rtl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Titik uji di tengah tiap zona; lebar 1 supaya x = pecahan layar.
    final edge = zones.layout.zone;
    final leftForward = zones.resolve(edge / 2, 1, rtl: rtl) ?? false;
    Widget zone(bool forward) => Expanded(
          flex: (edge * 100).round(),
          child: ColoredBox(
            color: (forward ? scheme.primaryContainer : scheme.tertiaryContainer),
            child: Center(
              child: Text(
                forward ? 'Maju' : 'Mundur',
                style: TextStyle(
                  fontSize: 12,
                  color: forward ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            zone(leftForward),
            if (edge < 0.5)
              Expanded(
                flex: ((1 - 2 * edge) * 100).round(),
                child: ColoredBox(color: scheme.surfaceContainerHighest),
              ),
            zone(!leftForward),
          ],
        ),
      ),
    );
  }
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.seriesKey});

  final String seriesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = ref.watch(effectiveReaderProvider(seriesKey));
    final global = ref.watch(readerDisplayProvider);
    final override = ref.watch(seriesReaderOverridesProvider)[seriesKey];
    final perSeries = override != null;
    final tapZones = ref.watch(tapZonesProvider);
    final autoSpeed = ref.watch(webtoonAutoScrollSpeedProvider);
    final theme = Theme.of(context);

    void setMode(ReaderMode mode) {
      if (perSeries) {
        ref.read(seriesReaderOverridesProvider.notifier).set(
              seriesKey,
              SeriesReaderOverride(mode: mode, cropBorders: override.cropBorders),
            );
      } else {
        ref.read(readerModeProvider.notifier).set(mode);
      }
    }

    void setCrop(bool crop) {
      if (perSeries) {
        ref.read(seriesReaderOverridesProvider.notifier).set(
              seriesKey,
              SeriesReaderOverride(mode: override.mode, cropBorders: crop),
            );
      } else {
        ref.read(readerDisplayProvider.notifier).set(global.copyWith(cropBorders: crop));
      }
    }

    void setPerSeries(bool on) => ref.read(seriesReaderOverridesProvider.notifier).set(
          seriesKey,
          // Mulai dari pengaturan yang sedang berlaku, supaya tidak berubah tiba-tiba.
          on ? SeriesReaderOverride(mode: effective.mode, cropBorders: effective.display.cropBorders) : null,
        );

    void setDisplay(ReaderDisplay value) => ref.read(readerDisplayProvider.notifier).set(value);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('Khusus seri ini'),
              subtitle: Text(
                perSeries ? 'Mode & potong tepi disimpan untuk seri ini' : 'Mengikuti pengaturan umum',
              ),
              value: perSeries,
              onChanged: setPerSeries,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Mode baca', style: theme.textTheme.titleSmall),
            ),
            RadioGroup<ReaderMode>(
              groupValue: effective.mode,
              onChanged: (m) {
                if (m != null) setMode(m);
              },
              child: Column(
                children: [
                  for (final m in ReaderMode.values) RadioListTile<ReaderMode>(value: m, title: Text(m.label)),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Potong tepi kosong'),
              subtitle: Text(
                effective.mode.isPaged
                    ? 'Buang margin putih/hitam di sekeliling halaman'
                    : 'Mode webtoon: hanya margin kiri dan kanan',
              ),
              value: effective.display.cropBorders,
              onChanged: setCrop,
            ),
            SwitchListTile(
              title: const Text('Dua halaman (tablet landscape)'),
              subtitle: const Text('Per halaman: tampilkan dua halaman berdampingan di layar lebar'),
              value: global.spread,
              onChanged: (v) => setDisplay(global.copyWith(spread: v)),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Gulir otomatis (webtoon)', style: theme.textTheme.titleSmall),
            ),
            ListTile(
              title: const Text('Kecepatan'),
              trailing: Text('${autoSpeed.round()} dp/dtk'),
            ),
            Slider(
              value: autoSpeed,
              min: autoScrollMin,
              max: autoScrollMax,
              divisions: 19,
              label: '${autoSpeed.round()}',
              onChanged: (v) => ref.read(webtoonAutoScrollSpeedProvider.notifier).set(v),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Zona ketuk', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ketuk pinggir layar untuk pindah halaman (mode per halaman).',
                style: theme.textTheme.bodySmall,
              ),
            ),
            RadioGroup<TapZoneLayout>(
              groupValue: tapZones.layout,
              onChanged: (l) {
                if (l != null) ref.read(tapZonesProvider.notifier).set(tapZones.copyWith(layout: l));
              },
              child: Column(
                children: [
                  for (final l in TapZoneLayout.values) RadioListTile<TapZoneLayout>(value: l, title: Text(l.label)),
                ],
              ),
            ),
            if (tapZones.layout != TapZoneLayout.off) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _TapZonePreview(
                  zones: tapZones,
                  rtl: effective.mode == ReaderMode.pagedRtl,
                ),
              ),
              SwitchListTile(
                title: const Text('Tukar kiri / kanan'),
                subtitle: const Text('Ketuk kiri maju, ketuk kanan mundur'),
                value: tapZones.swap,
                onChanged: (v) => ref.read(tapZonesProvider.notifier).set(tapZones.copyWith(swap: v)),
              ),
            ],
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Filter warna', style: theme.textTheme.titleSmall),
            ),
            SwitchListTile(
              title: const Text('Hitam putih'),
              value: global.grayscale,
              onChanged: (v) => setDisplay(global.copyWith(grayscale: v)),
            ),
            SwitchListTile(
              title: const Text('Balik warna'),
              subtitle: const Text('Halaman putih jadi gelap untuk baca malam'),
              value: global.invert,
              onChanged: (v) => setDisplay(global.copyWith(invert: v)),
            ),
            ListTile(
              title: const Text('Redupkan'),
              trailing: Text('${(global.dim * 100).round()}%'),
            ),
            Slider(
              value: global.dim,
              max: 0.8,
              divisions: 16,
              label: '${(global.dim * 100).round()}%',
              onChanged: (v) => setDisplay(global.copyWith(dim: v)),
            ),
          ],
        ),
      ),
    );
  }
}
