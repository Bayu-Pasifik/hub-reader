import 'package:flutter/material.dart';
import '../../../core/i18n/strings.dart';

import '../../../novels/novel_models.dart';
import '../../../novels/novel_source.dart';

/// Pengaturan plugin LNReader (`pluginSettings`), mis. link login dan mode
/// terjemahan WTR-LAB. Mengembalikan true bila ada yang disimpan.
class NovelSettingsSheet extends StatefulWidget {
  const NovelSettingsSheet({super.key, required this.source});

  final NovelSource source;

  @override
  State<NovelSettingsSheet> createState() => _NovelSettingsSheetState();
}

class _NovelSettingsSheetState extends State<NovelSettingsSheet> {
  late final Map<String, Object?> _values = {
    for (final s in widget.source.settings) s.key: widget.source.settingValue(s),
  };
  late final Map<String, TextEditingController> _text = {
    for (final s in widget.source.settings)
      if (s.type == NovelSettingType.text) s.key: TextEditingController(text: '${_values[s.key] ?? ''}'),
  };

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    for (final s in widget.source.settings) {
      final value = s.type == NovelSettingType.text ? _text[s.key]!.text.trim() : _values[s.key];
      widget.source.setSetting(s, value);
    }
    Navigator.of(context).pop(true);
  }

  Widget _field(NovelPluginSetting s) {
    switch (s.type) {
      case NovelSettingType.text:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _text[s.key],
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: s.key,
              helperText: s.label,
              helperMaxLines: 6,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: tr('Kosongkan'),
                icon: const Icon(Icons.clear),
                onPressed: () => _text[s.key]!.clear(),
              ),
            ),
          ),
        );
      case NovelSettingType.toggle:
        return SwitchListTile(
          title: Text(s.label),
          value: _values[s.key] == true,
          onChanged: (v) => setState(() => _values[s.key] = v),
        );
      case NovelSettingType.select:
        final current = '${_values[s.key] ?? ''}';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: s.options.any((o) => o.value == current) ? current : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.label, border: const OutlineInputBorder()),
            items: [
              for (final o in s.options) DropdownMenuItem(value: o.value, child: Text(o.label)),
            ],
            onChanged: (v) => setState(() => _values[s.key] = v),
          ),
        );
      case NovelSettingType.checkboxGroup:
        final selected = {...(_values[s.key] as List? ?? const []).map((e) => '$e')};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(s.label, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final o in s.options)
              CheckboxListTile(
                dense: true,
                title: Text(o.label),
                value: selected.contains(o.value),
                onChanged: (v) => setState(() {
                  v == true ? selected.add(o.value) : selected.remove(o.value);
                  _values[s.key] = selected.toList();
                }),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pengaturan ${widget.source.name}', style: Theme.of(context).textTheme.titleMedium),
                ),
                FilledButton(onPressed: _save, child: Text(tr('Simpan'))),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.only(bottom: 16 + MediaQuery.viewInsetsOf(context).bottom),
              children: [for (final s in widget.source.settings) _field(s)],
            ),
          ),
        ],
      ),
    );
  }
}
