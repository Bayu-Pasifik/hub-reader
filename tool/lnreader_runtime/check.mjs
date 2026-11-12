// Live check of LNReader plugins against the bundled runtime, outside Flutter.
//
// Runs assets/lnreader/runtime.js inside a bare `vm` context (only ECMAScript
// built-ins, like QuickJS) with a Node implementation of the Dart host, then
// calls popularNovels -> parseNovel -> parsePage? -> parseChapter per plugin.
//
//   node check.mjs [manifest.json|url] [--only id1,id2] [--lang English] [--limit N] [--jobs 8]
//
// Prints one line per plugin and a summary; writes check-report.json.
import fs from 'node:fs';
import vm from 'node:vm';

const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf('--' + name);
  return i >= 0 ? args[i + 1] : def;
};
const MANIFEST =
  args[0] && !args[0].startsWith('--')
    ? args[0]
    : 'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.dist/plugins.min.json';
const ONLY = opt('only', '') ? opt('only').split(',') : null;
const LANG = opt('lang', null);
const LIMIT = Number(opt('limit', '0'));
const JOBS = Number(opt('jobs', '8'));
const TIMEOUT = Number(opt('timeout', '45000'));
const VERBOSE = args.includes('--verbose');
const UA =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
const runtimeCode = fs.readFileSync(new URL('../../assets/lnreader/runtime.js', import.meta.url), 'utf8');

const readText = async src => (src.startsWith('http') ? (await fetch(src)).text() : fs.readFileSync(src, 'utf8'));

/** One isolated runtime per plugin, mirroring lib/novels/lnreader/js_engine.dart. */
function createRuntime() {
  const bodies = new Map();
  const aborts = new Map();
  const calls = new Map();
  const timers = new Map();
  const store = new Map();
  let ctx;
  const callJs = code => vm.runInContext(code, ctx);
  const hostFn = (op, payload) => {
    switch (op) {
      case 'log':
        if (VERBOSE) console.log('  log:', payload.slice(0, 300));
        return null;
      case 'timer': {
        const { id, ms } = JSON.parse(payload);
        timers.set(id, setTimeout(() => (timers.delete(id), callJs(`__lnr.fireTimer(${id})`)), ms));
        return null;
      }
      case 'clearTimer':
        clearTimeout(timers.get(Number(payload)));
        timers.delete(Number(payload));
        return null;
      case 'fetch': {
        const req = JSON.parse(payload);
        const ac = new AbortController();
        aborts.set(req.id, ac);
        const headers = { 'user-agent': UA, ...req.headers };
        let body;
        if (req.body.type === 'text') body = req.body.value;
        else if (req.body.type === 'base64') body = Buffer.from(req.body.value, 'base64');
        else if (req.body.type === 'multipart') {
          body = new FormData();
          for (const [k, v] of req.body.fields) body.append(k, v);
          delete headers['content-type'];
        }
        fetch(req.url, { method: req.method, headers, body, signal: ac.signal, redirect: req.redirect })
          .then(async res => {
            const buf = new Uint8Array(await res.arrayBuffer());
            bodies.set(req.id, buf);
            if (VERBOSE) console.log(`  ${req.method} ${res.status} ${req.url} (${buf.length} B)`);
            const h = {};
            res.headers.forEach((v, k) => (h[k] = v));
            const meta = { status: res.status, statusText: res.statusText, url: res.url, redirected: res.redirected, headers: h };
            callJs(`__lnr.resolveFetch(${req.id}, ${JSON.stringify(JSON.stringify(meta))})`);
          })
          .catch(e => callJs(`__lnr.rejectFetch(${req.id}, ${JSON.stringify(String(e.cause?.code || e.message))})`))
          .finally(() => aborts.delete(req.id));
        return null;
      }
      case 'abort':
        aborts.get(Number(payload))?.abort();
        return null;
      case 'body.text':
        return new TextDecoder().decode(bodies.get(Number(payload)) || new Uint8Array());
      case 'body.bytes': {
        const b = bodies.get(Number(payload)) || new Uint8Array();
        // Return an ArrayBuffer created in the context realm, like flutter_js does.
        const out = vm.runInContext(`new ArrayBuffer(${b.length})`, ctx);
        vm.runInContext("Uint8Array", ctx).prototype.set.call(new (vm.runInContext("Uint8Array", ctx))(out), b);
        return out;
      }
      case 'decode': {
        const { encoding, data } = JSON.parse(payload);
        try {
          return new TextDecoder(encoding).decode(Buffer.from(data, 'base64'));
        } catch (_) {
          return Buffer.from(data, 'base64').toString('latin1');
        }
      }
      case 'storage.get':
        return store.get(payload) ?? null;
      case 'storage.set': {
        const { key, value } = JSON.parse(payload);
        store.set(key, value);
        return null;
      }
      case 'storage.delete':
        store.delete(payload);
        return null;
      case 'storage.keys':
        return JSON.stringify([...store.keys()].filter(k => k.startsWith(payload)));
      case 'done': {
        const msg = JSON.parse(payload);
        const c = calls.get(msg.id);
        calls.delete(msg.id);
        if (c) msg.ok ? c.resolve(msg.value) : c.reject(new Error(msg.error));
        return null;
      }
      default:
        throw new Error('unknown host op ' + op);
    }
  };
  ctx = vm.createContext({ __host: hostFn });
  vm.runInContext(runtimeCode, ctx);
  let seq = 0;
  return {
    load: (key, code) => JSON.parse(vm.runInContext(`__lnr.load(${JSON.stringify(key)}, ${JSON.stringify(code)})`, ctx)),
    invoke: (key, method, params) =>
      new Promise((resolve, reject) => {
        const id = ++seq;
        calls.set(id, { resolve, reject });
        callJs(`__lnr.invoke(${id}, ${JSON.stringify(key)}, ${JSON.stringify(method)}, ${JSON.stringify(JSON.stringify(params))})`);
      }),
    dispose: () => {
      timers.forEach(t => clearTimeout(t));
      aborts.forEach(a => a.abort());
    },
  };
}

const defaultFilterValues = filters => {
  if (!filters) return undefined;
  const out = {};
  for (const [k, f] of Object.entries(filters)) out[k] = { type: f.type, value: f.value };
  return out;
};

const withTimeout = (p, ms, what) =>
  Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error('timeout ' + what)), ms))]);

async function checkPlugin(item) {
  const rt = createRuntime();
  const r = { id: item.id, name: item.name, lang: item.lang, stage: 'load' };
  try {
    const code = await readText(item.url);
    const meta = rt.load(item.id, code);
    r.stage = 'popular';
    const t0 = Date.now();
    const novels = await withTimeout(
      rt.invoke(item.id, 'popularNovels', [1, { showLatestNovels: false, filters: defaultFilterValues(meta.filters) }]),
      TIMEOUT,
      'popular',
    );
    if (!Array.isArray(novels) || novels.length === 0) throw new Error('empty popular list');
    r.popular = novels.length;
    r.stage = 'novel';
    const novel = await withTimeout(rt.invoke(item.id, 'parseNovel', [novels[0].path]), TIMEOUT, 'novel');
    let chapters = novel.chapters || [];
    if (meta.hasParsePage && chapters.length === 0) {
      r.stage = 'page';
      const page = await withTimeout(rt.invoke(item.id, 'parsePage', [novels[0].path, '1']), TIMEOUT, 'page');
      chapters = page.chapters || [];
    }
    if (chapters.length === 0) throw new Error('no chapters');
    r.chapters = chapters.length;
    r.stage = 'chapter';
    const html = await withTimeout(rt.invoke(item.id, 'parseChapter', [chapters[0].path]), TIMEOUT, 'chapter');
    if (typeof html !== 'string' || html.replace(/<[^>]+>/g, '').trim().length < 20) throw new Error('empty chapter');
    r.chapterChars = html.length;
    r.stage = 'ok';
    r.ms = Date.now() - t0;
  } catch (e) {
    r.error = String(e.message || e).slice(0, 160);
  } finally {
    rt.dispose();
  }
  return r;
}

const manifest = JSON.parse(await readText(MANIFEST));
let items = manifest.filter(p => (!ONLY || ONLY.includes(p.id)) && (!LANG || p.lang === LANG));
if (LIMIT) items = items.slice(0, LIMIT);
console.log(`checking ${items.length} plugins, ${JOBS} at a time`);
const results = [];
let next = 0;
await Promise.all(
  Array.from({ length: JOBS }, async () => {
    while (next < items.length) {
      const item = items[next++];
      const r = await checkPlugin(item);
      results.push(r);
      console.log(`${r.stage === 'ok' ? 'OK  ' : 'FAIL'} ${r.id.padEnd(28)} ${r.stage.padEnd(8)} ${r.error || `${r.popular} novels, ${r.chapters} ch, ${r.ms}ms`}`);
    }
  }),
);
const ok = results.filter(r => r.stage === 'ok').length;
const byStage = {};
results.filter(r => r.stage !== 'ok').forEach(r => (byStage[r.stage] = (byStage[r.stage] || 0) + 1));
console.log(`\n${ok}/${results.length} OK`, byStage);
fs.writeFileSync(new URL('check-report.json', import.meta.url), JSON.stringify(results, null, 1));
process.exit(0);
