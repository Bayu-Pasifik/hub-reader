// Membuat assets/sources/catalog.json dari checkout keiyoushi/extensions-source
// (Apache-2.0). Hanya extension yang memakai template yang sudah di-port ke Dart
// (lib/sources/templates/) yang diambil.
//
// Pemakaian:
//   node tool/generate_source_catalog.mjs <path/ke/extensions-source> [output.json]
//
// Per situs dibaca dari build.gradle.kts: name, contentWarning, theme, dan tiap
// blok `source { lang, baseUrl }`. Opsi template yang sederhana (mis.
// mangaSubString, chapterMode) diambil dari override di file Kotlin situs.
// Override selector yang rumit tidak ikut, jadi sebagian situs bisa butuh
// penyesuaian manual.

import fs from 'node:fs';
import path from 'node:path';

const SUPPORTED = new Set(['madara', 'mangathemesia', 'zeistmanga', 'loneseal', 'natsuid', 'colorlibanime', 'hwalumi', 'keyoapp', 'vinetheme']);

const [root, outArg] = process.argv.slice(2);
if (!root) {
  console.error('Pemakaian: node tool/generate_source_catalog.mjs <extensions-source> [output.json]');
  process.exit(1);
}
const out = outArg ?? path.join(path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, '$1')), '..', 'assets', 'sources', 'catalog.json');

const listDirs = (p) => fs.readdirSync(p, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);

function kotlinSources(dir) {
  const result = [];
  const walk = (p) => {
    for (const e of fs.readdirSync(p, { withFileTypes: true })) {
      const full = path.join(p, e.name);
      if (e.isDirectory()) walk(full);
      else if (e.name.endsWith('.kt')) result.push(fs.readFileSync(full, 'utf8'));
    }
  };
  if (fs.existsSync(dir)) walk(dir);
  return result.join('\n');
}

const str = (text, re) => text.match(re)?.[1];

/** Blok `source { ... }` dengan kurung kurawal bersarang. */
function sourceBlocks(gradle) {
  const blocks = [];
  let i = 0;
  while ((i = gradle.indexOf('source {', i)) !== -1) {
    let depth = 0;
    let j = gradle.indexOf('{', i);
    const start = j;
    for (; j < gradle.length; j++) {
      if (gradle[j] === '{') depth++;
      else if (gradle[j] === '}' && --depth === 0) break;
    }
    blocks.push(gradle.slice(start + 1, j));
    i = j;
  }
  return blocks;
}

const entries = [];
const skipped = { theme: 0, noUrl: 0 };

for (const langDir of listDirs(path.join(root, 'src'))) {
  for (const ext of listDirs(path.join(root, 'src', langDir))) {
    const extDir = path.join(root, 'src', langDir, ext);
    const gradlePath = path.join(extDir, 'build.gradle.kts');
    if (!fs.existsSync(gradlePath)) continue;
    const gradle = fs.readFileSync(gradlePath, 'utf8');
    const theme = str(gradle, /theme\s*=\s*"([^"]+)"/);
    if (!SUPPORTED.has(theme)) {
      skipped.theme++;
      continue;
    }
    const name = str(gradle, /^\s*name\s*=\s*"([^"]+)"/m) ?? ext;
    const cw = (str(gradle, /ContentWarning\.([A-Z]+)/) ?? 'SAFE').toLowerCase();
    const kt = kotlinSources(path.join(extDir, 'src'));

    const options = {};
    if (theme === 'madara') {
      if (/:\s*MadaraNoAjax\s*\(/.test(kt)) options.noAjax = true;
      const mode = str(kt, /chapterMode[^=\n]*=\s*ChapterMode\.(\w+)/);
      if (mode) options.chapterMode = mode;
      const sub = str(kt, /mangaSubString[^=\n]*=\s*"([^"]*)"/);
      if (sub && sub !== 'manga') options.mangaSubString = sub;
      if (/filterNonMangaItems[^=\n]*=\s*false/.test(kt)) options.filterNonMangaItems = false;
    } else if (theme === 'keyoapp') {
      // Varian: KeyoappV2, atau Livewire (override ArtLapsa & kawan-kawan).
      if (/:\s*KeyoappV2\s*\(/.test(kt)) options.variant = 'v2';
      else if (/wire:model\.live/.test(kt)) options.variant = 'livewire';
      if (/getPopularManga\(page: Int\)\s*=\s*getSearchMangaList/.test(kt)) options.popularFromSearch = true;
    } else {
      const dir = str(kt, /mangaUrlDirectory\s*=\s*"([^"]*)"/);
      if (dir != null && dir !== '/manga') options.mangaUrlDirectory = dir;
      const pageSel = str(kt, /pageSelector\s*=\s*"([^"]*)"/);
      if (pageSel) options.pageSelector = pageSel;
    }
    // Override sederhana generik: `override val nama = "teks"` atau true/false.
    const vals = {};
    for (const m of kt.matchAll(/override\s+val\s+(\w+)(?:\s*:\s*\w+)?\s*=\s*("(?:[^"\\]|\\.)*"|true|false)/g)) {
      vals[m[1]] = m[2] === 'true' ? true : m[2] === 'false' ? false : JSON.parse(m[2]);
    }
    // Nilai enum, mis. `override val urlLayout = UrlLayout.LEGACY_COMIC`.
    for (const m of kt.matchAll(/override\s+val\s+(\w+)\s*=\s*[A-Z]\w*\.([A-Z][A-Z0-9_]+)\b/g)) vals[m[1]] = m[2];
    // API LoneSeal di <baseUrl>/api.
    if (/apiUrl[^\n]*"\$baseUrl\/api"/.test(kt)) vals.apiOnBase = true;
    // NatsuId (Kiryuu): daftar bab memakai page=1.
    if (/setQueryParameter\("page", "1"\)/.test(kt)) vals.chapterPageOne = true;
    if (Object.keys(vals).length) options.vals = vals;
    // Keyoapp: override yang dikenal (Livewire, V2, populer via pencarian) sudah ditangani port Dart.
    if (theme !== 'keyoapp' && /getPopularManga|getSearchMangaList|parseArchive|pageListParse|parsePages|mangaDetailsParse|parseDetails|getChapterFeedUrl|parsePopularManga|parseSearchManga/.test(kt)) {
      options.customized = true; // Kotlin meng-override logika inti; port Dart bisa kurang pas.
    }

    for (const block of sourceBlocks(gradle)) {
      const lang = str(block, /lang\s*=\s*"([^"]+)"/) ?? langDir;
      const baseUrl = str(block, /baseUrl\s*=\s*"([^"]+)"/) ?? str(block, /custom\("([^"]+)"\)/) ?? str(block, /"(https?:\/\/[^"]+)"/);
      if (!baseUrl) {
        skipped.noUrl++;
        continue;
      }
      entries.push({
        id: `${lang}.${ext.toLowerCase()}`,
        name: str(block, /name\s*=\s*"([^"]+)"/) ?? name,
        lang,
        baseUrl: baseUrl.replace(/\/+$/, ''),
        contentWarning: cw,
        theme,
        ...(Object.keys(options).length ? { options } : {}),
      });
    }
  }
}

// ID harus unik; tambahkan akhiran bila bentrok.
const seen = new Map();
for (const e of entries) {
  const n = seen.get(e.id) ?? 0;
  seen.set(e.id, n + 1);
  if (n > 0) e.id = `${e.id}.${n + 1}`;
}
entries.sort((a, b) => a.lang.localeCompare(b.lang) || a.name.localeCompare(b.name));

const catalog = {
  source: 'https://github.com/keiyoushi/extensions-source',
  license: 'Apache-2.0',
  generatedAt: new Date().toISOString().slice(0, 10),
  count: entries.length,
  sources: entries,
};
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, JSON.stringify(catalog, null, 1) + '\n');

const byTheme = entries.reduce((m, e) => ((m[e.theme] = (m[e.theme] ?? 0) + 1), m), {});
const byLang = entries.reduce((m, e) => ((m[e.lang] = (m[e.lang] ?? 0) + 1), m), {});
console.log(`Tulis ${entries.length} sumber ke ${out}`);
console.log('per template:', byTheme);
console.log('per bahasa:', byLang);
console.log('dilewati (template belum didukung):', skipped.theme, '| tanpa baseUrl:', skipped.noUrl);
