import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crash/crash_log.dart';
import '../../core/i18n/strings.dart';

/// Log error lokal (lihat `CrashLog`): baca, bagikan untuk laporan bug, hapus.
class CrashLogScreen extends StatefulWidget {
  const CrashLogScreen({super.key});

  @override
  State<CrashLogScreen> createState() => _CrashLogScreenState();
}

class _CrashLogScreenState extends State<CrashLogScreen> {
  late String _text = CrashLog.read();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Log error')),
        actions: [
          IconButton(
            tooltip: tr('Bagikan'),
            icon: const Icon(Icons.share_outlined),
            onPressed: _text.isEmpty
                ? null
                : () => SharePlus.instance.share(ShareParams(text: CrashLog.redact(_text), subject: 'Hub Reader error log')),
          ),
          IconButton(
            tooltip: tr('Hapus'),
            icon: const Icon(Icons.delete_outline),
            onPressed: _text.isEmpty
                ? null
                : () {
                    CrashLog.clear();
                    setState(() => _text = '');
                  },
          ),
        ],
      ),
      body: _text.isEmpty
          ? Center(child: Text(tr('Belum ada error tercatat')))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
    );
  }
}
