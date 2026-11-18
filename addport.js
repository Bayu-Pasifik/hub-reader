// usage: node addport.js <srcfile> <fnName> [imports...]
const fs = require('fs');
const [, , src, fn, ...imports] = process.argv;
const p = 'lib/sources/en/ports_aa.dart';
let s = fs.readFileSync(p, 'utf8');
for (const i of imports) if (!s.includes(i)) s = s.replace("import '../html_utils.dart';", i + "\nimport '../html_utils.dart';");
const code = fs.readFileSync(src, 'utf8');
s = s.replace(/\nList<MangaSource> portsAa\(\) => \[(.*)\];\n?$/, (m, list) => '\n' + code + '\nList<MangaSource> portsAa() => [' + list + ', ' + fn + '()];\n');
fs.writeFileSync(p, s);
