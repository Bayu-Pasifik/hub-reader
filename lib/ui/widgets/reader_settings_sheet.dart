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

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet({required this.seriesKey});

  final String seriesKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = ref.watch(effectiveReaderProvider(seriesKey));
    final global = ref.watch(readerDisplayProvider);
    final override = ref.watch(seriesReaderOverridesProvider)[seriesKey];
    final perSeries = override != null;
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
