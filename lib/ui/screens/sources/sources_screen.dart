import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/download_providers.dart';
import '../../../state/source_providers.dart';
import '../../router.dart';
import '../../widgets/source_widgets.dart';

/// Tab "Sumber": daftar extension on-device (scraping langsung dari HP).
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourceRegistryProvider).sources;
    final scheme = Theme.of(context).colorScheme;
    final queueCount = ref.watch(downloadQueueProvider.select((q) => q.length));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sumber'),
        actions: [
          IconButton(
            tooltip: 'Unduhan',
            icon: Badge(
              isLabelVisible: queueCount > 0,
              label: Text('$queueCount'),
              child: const Icon(Icons.download_outlined),
            ),
            onPressed: () => context.push('/downloads'),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: sources.length + 1,
        separatorBuilder: (_, i) => i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Konten diambil langsung dari situs oleh HP ini, tanpa lewat server scraper-hub.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            );
          }
          final source = sources[i - 1];
          final host = Uri.tryParse(source.baseUrl)?.host ?? source.baseUrl;
          return ListTile(
            leading: CircleAvatar(child: Text(source.name.characters.first.toUpperCase())),
            title: Text(source.name),
            subtitle: Text('${source.lang.toUpperCase()} · $host'),
            trailing: ContentWarningChip(warning: source.contentWarning),
            onTap: () => context.push(sourceBrowseLocation(source.id)),
          );
        },
      ),
    );
  }
}
