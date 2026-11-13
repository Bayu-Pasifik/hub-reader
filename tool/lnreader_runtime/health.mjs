// Turns check-report.json (from check.mjs) into assets/lnreader/health.json,
// the baseline plugin status the app shows before checking on the phone.
//
//   node check.mjs && node health.mjs
import fs from 'node:fs';

const report = JSON.parse(fs.readFileSync(new URL('check-report.json', import.meta.url), 'utf8'));

/** Status names match HealthStatus in lib/state/source_health_provider.dart. */
function classify(r) {
  if (!r.error) return { s: 'ok' };
  const e = String(r.error);
  // Node lacks some intermediate certificates Android has; not a plugin fault.
  if (/UNABLE_TO_GET_ISSUER_CERT|CERT_HAS_EXPIRED|SELF_SIGNED|unable to verify/i.test(e)) return null;
  const http = e.match(/HTTP (\d{3})/)?.[1];
  if (/cloudflare|just a moment|captcha|webview/i.test(e) || http === '403' || http === '503')
    return { s: 'cloudflare', d: http ? `HTTP ${http}` : 'Cloudflare' };
  if (/ENOTFOUND|EAI_AGAIN|ECONNREFUSED|ECONNRESET|timed? ?out|ETIMEDOUT/i.test(e)) return { s: 'dead', d: 'Situs tidak bisa dihubungi' };
  if (http && /^(404|410|5\d\d)$/.test(http)) return { s: 'dead', d: `HTTP ${http}` };
  const stage = { popular: 'Daftar', novel: 'Detail', page: 'Daftar bab', chapter: 'Isi bab' }[r.stage] ?? r.stage;
  return { s: 'broken', d: /empty/i.test(e) ? `${stage} kosong` : `${stage} gagal` };
}

const plugins = {};
for (const r of report) {
  const c = classify(r);
  if (c) plugins[r.id] = c;
}
const out = { checked_at: new Date().toISOString(), plugins };
fs.writeFileSync(new URL('../../assets/lnreader/health.json', import.meta.url), JSON.stringify(out));
const counts = Object.values(plugins).reduce((m, p) => ((m[p.s] = (m[p.s] || 0) + 1), m), {});
console.log(report.length, 'plugins ->', counts);
