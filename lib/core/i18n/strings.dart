import 'package:flutter/widgets.dart';

import 'strings_en.dart';

/// Bahasa tampilan aplikasi. Teks sumber ditulis dalam bahasa Indonesia;
/// bahasa lain memakai tabel terjemahan (lihat `strings_en.dart`).
enum AppLanguage {
  id('Indonesia'),
  en('English');

  const AppLanguage(this.label);

  final String label;

  static AppLanguage? byName(String? name) => values.where((l) => l.name == name).firstOrNull;
}

/// Bahasa yang sedang dipakai; diset oleh pengaturan aplikasi.
AppLanguage currentLanguage = AppLanguage.id;

/// Terjemahkan teks antarmuka (kunci = teks Indonesia). Teks yang belum
/// punya terjemahan tampil apa adanya.
String tr(String id) => currentLanguage == AppLanguage.id ? id : (stringsEn[id] ?? id);

/// Bangun ulang seluruh pohon widget (tanpa kehilangan state) agar [tr]
/// dievaluasi lagi setelah bahasa berganti.
void rebuildAllWidgets() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
