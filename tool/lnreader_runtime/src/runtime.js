// Runtime for running LNReader plugins (https://github.com/lnreader/lnreader-plugins)
// inside QuickJS (flutter_js) in hub_reader.
//
// The compiled plugins are ES5 CommonJS modules that `require` cheerio,
// htmlparser2, dayjs and a set of `@libs/*` helpers. LNReader (React Native)
// provides those through its own `require`; this file does the same, plus the
// web APIs that QuickJS does not have (fetch, URL, setTimeout, FormData, ...).
//
// Host contract (implemented in lib/novels/lnreader/js_engine.dart):
//   globalThis.__host(op, payload) -> string | ArrayBuffer | null   (sync, Dart)
//   Dart calls back into: __lnr.resolveFetch(id, metaJson), __lnr.rejectFetch(id, msg),
//   __lnr.fireTimer(id), __lnr.load(pluginId, code), __lnr.invoke(callId, pluginId, method, argsJson)

import './bigint-shim.js';
import 'core-js/actual/url';
import 'core-js/actual/url-search-params';
import 'core-js/actual/structured-clone';
import { load } from 'cheerio';
import { Parser } from 'htmlparser2';
import dayjs from 'dayjs';
import { gcm } from '@noble/ciphers/aes.js';

const g = globalThis;
const host = (op, payload) => g.__host(op, payload === undefined ? '' : payload);

// ------------------------------------------------------------------ console

const fmt = args =>
  args
    .map(a => {
      if (typeof a === 'string') return a;
      if (a instanceof Error) return a.stack || String(a);
      try {
        return JSON.stringify(a);
      } catch (_) {
        return String(a);
      }
    })
    .join(' ');
g.console = {
  log: (...a) => host('log', fmt(a)),
  info: (...a) => host('log', fmt(a)),
  debug: () => {},
  warn: (...a) => host('log', 'WARN ' + fmt(a)),
  error: (...a) => host('log', 'ERROR ' + fmt(a)),
  trace: () => {},
};

// ------------------------------------------------------------------- timers

let timerSeq = 0;
/** id -> { fn, args, interval (ms) | null } */
const timers = new Map();
const armTimer = (id, ms) => host('timer', JSON.stringify({ id, ms }));
g.setTimeout = (fn, ms, ...args) => {
  const id = ++timerSeq;
  timers.set(id, { fn, args, interval: null });
  armTimer(id, Math.max(0, Number(ms) || 0));
  return id;
};
g.clearTimeout = id => {
  if (timers.delete(id)) host('clearTimer', String(id));
};
g.setInterval = (fn, ms, ...args) => {
  const id = ++timerSeq;
  const interval = Math.max(1, Number(ms) || 0);
  timers.set(id, { fn, args, interval });
  armTimer(id, interval);
  return id;
};
g.clearInterval = g.clearTimeout;
g.queueMicrotask = fn => Promise.resolve().then(fn);

// ----------------------------------------------------------- base64 / text

// Own UTF-8 codec: libraries such as @noble/ciphers implement utf8ToBytes /
// bytesToUtf8 on top of the global TextEncoder/TextDecoder, so the polyfills
// below must not depend on them (that recursion crashes QuickJS).
const utf8ToBytes = str => {
  str = String(str);
  const out = [];
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i);
    if (c >= 0xd800 && c < 0xdc00 && i + 1 < str.length) {
      const d = str.charCodeAt(i + 1);
      if (d >= 0xdc00 && d < 0xe000) {
        c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00);
        i++;
      } else c = 0xfffd;
    } else if (c >= 0xd800 && c < 0xe000) c = 0xfffd;
    if (c < 0x80) out.push(c);
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
  }
  return new Uint8Array(out);
};
const bytesToUtf8 = bytes => {
  let out = '';
  let chunk = [];
  const push = cp => {
    if (cp > 0xffff) {
      cp -= 0x10000;
      chunk.push(0xd800 + (cp >> 10), 0xdc00 + (cp & 1023));
    } else chunk.push(cp);
    if (chunk.length > 8192) {
      out += String.fromCharCode.apply(null, chunk);
      chunk = [];
    }
  };
  for (let i = 0; i < bytes.length; ) {
    const b = bytes[i];
    let need = 0;
    let cp = 0;
    if (b < 0x80) {
      push(b);
      i++;
      continue;
    } else if (b >= 0xc2 && b < 0xe0) (need = 1), (cp = b & 31);
    else if (b >= 0xe0 && b < 0xf0) (need = 2), (cp = b & 15);
    else if (b >= 0xf0 && b < 0xf5) (need = 3), (cp = b & 7);
    else {
      push(0xfffd);
      i++;
      continue;
    }
    let j = 1;
    for (; j <= need; j++) {
      const n = bytes[i + j];
      if (n === undefined || (n & 0xc0) !== 0x80) break;
      cp = (cp << 6) | (n & 63);
    }
    if (j <= need) {
      push(0xfffd);
      i += j;
      continue;
    }
    push(cp);
    i += need + 1;
  }
  return out + String.fromCharCode.apply(null, chunk);
};

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
g.btoa = input => {
  const str = String(input);
  let out = '';
  for (let i = 0; i < str.length; i += 3) {
    const a = str.charCodeAt(i);
    const b = str.charCodeAt(i + 1);
    const c = str.charCodeAt(i + 2);
    if (a > 255 || b > 255 || c > 255) throw new Error('InvalidCharacterError');
    const n = (a << 16) | ((b || 0) << 8) | (c || 0);
    out +=
      B64[(n >> 18) & 63] +
      B64[(n >> 12) & 63] +
      (i + 1 < str.length ? B64[(n >> 6) & 63] : '=') +
      (i + 2 < str.length ? B64[n & 63] : '=');
  }
  return out;
};
g.atob = input => {
  const str = String(input).replace(/[\s=]+/g, '').replace(/-/g, '+').replace(/_/g, '/');
  let out = '';
  let buf = 0;
  let bits = 0;
  for (let i = 0; i < str.length; i++) {
    const v = B64.indexOf(str[i]);
    if (v < 0) throw new Error('InvalidCharacterError');
    buf = (buf << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out += String.fromCharCode((buf >> bits) & 255);
    }
  }
  return out;
};

const toBytes = input => {
  if (input instanceof Uint8Array) return input;
  if (input instanceof ArrayBuffer) return new Uint8Array(input);
  if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  return new Uint8Array(0);
};

class TextEncoderPolyfill {
  get encoding() {
    return 'utf-8';
  }
  encode(str = '') {
    return utf8ToBytes(str);
  }
}
class TextDecoderPolyfill {
  constructor(encoding = 'utf-8') {
    this.encoding = String(encoding || 'utf-8').toLowerCase();
  }
  decode(input) {
    const bytes = toBytes(input);
    if (this.encoding === 'utf-8' || this.encoding === 'utf8') return bytesToUtf8(bytes);
    // The host decodes other charsets (latin1, windows-1252, ...).
    return host('decode', JSON.stringify({ encoding: this.encoding, data: bytesToB64(bytes) })) || '';
  }
}
const bytesToB64 = bytes => {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return g.btoa(s);
};
if (typeof g.TextEncoder === 'undefined') g.TextEncoder = TextEncoderPolyfill;
if (typeof g.TextDecoder === 'undefined') g.TextDecoder = TextDecoderPolyfill;

// QuickJS is built without Intl. RanobeLib only reads
// `Intl.DateTimeFormat().resolvedOptions().timeZone` and falls back to its
// own default when it is missing, so a minimal shape is enough.
if (typeof g.Intl === 'undefined') {
  const pad = n => String(n).padStart(2, '0');
  function DateTimeFormat(locale) {
    if (!(this instanceof DateTimeFormat)) return new DateTimeFormat(locale);
    this._locale = locale || 'en-US';
  }
  DateTimeFormat.prototype.resolvedOptions = function () {
    return { locale: this._locale, calendar: 'gregory', numberingSystem: 'latn', timeZone: undefined };
  };
  DateTimeFormat.prototype.format = function (date) {
    const d = date === undefined ? new Date() : new Date(date);
    return `${pad(d.getMonth() + 1)}/${pad(d.getDate())}/${d.getFullYear()}`;
  };
  function NumberFormat(locale) {
    if (!(this instanceof NumberFormat)) return new NumberFormat(locale);
    this._locale = locale || 'en-US';
  }
  NumberFormat.prototype.resolvedOptions = function () {
    return { locale: this._locale, numberingSystem: 'latn' };
  };
  NumberFormat.prototype.format = n => String(n);
  g.Intl = { DateTimeFormat, NumberFormat };
}

// Minimal Buffer, enough for `Buffer.from(x).toString('base64')` style code.
if (typeof g.Buffer === 'undefined') {
  class MiniBuffer extends Uint8Array {
    static from(value, encoding) {
      if (typeof value === 'string') {
        if (encoding === 'base64') {
          const bin = g.atob(value);
          const out = new MiniBuffer(bin.length);
          for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
          return out;
        }
        if (encoding === 'hex') {
          const out = new MiniBuffer(value.length / 2);
          for (let i = 0; i < out.length; i++) out[i] = parseInt(value.substr(i * 2, 2), 16);
          return out;
        }
        const enc = utf8ToBytes(value);
        const out = new MiniBuffer(enc.length);
        out.set(enc);
        return out;
      }
      const src = Array.isArray(value) ? value : toBytes(value);
      const out = new MiniBuffer(src.length);
      out.set(src);
      return out;
    }
    static isBuffer(v) {
      return v instanceof MiniBuffer;
    }
    toString(encoding) {
      if (encoding === 'base64') return bytesToB64(this);
      if (encoding === 'hex') return Array.from(this, b => b.toString(16).padStart(2, '0')).join('');
      if (encoding === 'binary' || encoding === 'latin1') return String.fromCharCode.apply(null, this);
      return bytesToUtf8(this);
    }
  }
  g.Buffer = MiniBuffer;
}

// ------------------------------------------------------- Headers / FormData

class HeadersPolyfill {
  constructor(init) {
    this._map = new Map();
    if (!init) return;
    if (init instanceof HeadersPolyfill) init.forEach((v, k) => this.append(k, v));
    else if (Array.isArray(init)) init.forEach(([k, v]) => this.append(k, v));
    else Object.keys(init).forEach(k => init[k] != null && this.append(k, init[k]));
  }
  append(k, v) {
    const key = String(k).toLowerCase();
    const prev = this._map.get(key);
    this._map.set(key, prev ? prev + ', ' + v : String(v));
  }
  set(k, v) {
    this._map.set(String(k).toLowerCase(), String(v));
  }
  get(k) {
    const v = this._map.get(String(k).toLowerCase());
    return v === undefined ? null : v;
  }
  has(k) {
    return this._map.has(String(k).toLowerCase());
  }
  delete(k) {
    this._map.delete(String(k).toLowerCase());
  }
  forEach(cb, thisArg) {
    this._map.forEach((v, k) => cb.call(thisArg, v, k, this));
  }
  entries() {
    return this._map.entries();
  }
  keys() {
    return this._map.keys();
  }
  values() {
    return this._map.values();
  }
  [Symbol.iterator]() {
    return this._map.entries();
  }
  getSetCookie() {
    const v = this.get('set-cookie');
    return v ? v.split(/,(?=[^;]+=)/) : [];
  }
}
g.Headers = HeadersPolyfill;

class FormDataPolyfill {
  constructor() {
    this._entries = [];
  }
  append(k, v) {
    this._entries.push([String(k), v == null ? '' : String(v)]);
  }
  set(k, v) {
    this.delete(k);
    this.append(k, v);
  }
  get(k) {
    const e = this._entries.find(x => x[0] === k);
    return e ? e[1] : null;
  }
  getAll(k) {
    return this._entries.filter(x => x[0] === k).map(x => x[1]);
  }
  has(k) {
    return this._entries.some(x => x[0] === k);
  }
  delete(k) {
    this._entries = this._entries.filter(x => x[0] !== k);
  }
  forEach(cb, thisArg) {
    this._entries.forEach(([k, v]) => cb.call(thisArg, v, k, this));
  }
  entries() {
    return this._entries[Symbol.iterator]();
  }
  [Symbol.iterator]() {
    return this._entries[Symbol.iterator]();
  }
}
g.FormData = FormDataPolyfill;

// ---------------------------------------------------------- AbortController

class AbortSignalPolyfill {
  constructor() {
    this.aborted = false;
    this.reason = undefined;
    this.onabort = null;
    this._listeners = [];
  }
  addEventListener(type, fn) {
    if (type === 'abort') this._listeners.push(fn);
  }
  removeEventListener(type, fn) {
    this._listeners = this._listeners.filter(l => l !== fn);
  }
  throwIfAborted() {
    if (this.aborted) throw this.reason;
  }
  _abort(reason) {
    if (this.aborted) return;
    this.aborted = true;
    this.reason = reason || abortError();
    const ev = { type: 'abort', target: this };
    if (typeof this.onabort === 'function') this.onabort(ev);
    this._listeners.slice().forEach(l => l(ev));
  }
  static timeout(ms) {
    const c = new AbortControllerPolyfill();
    g.setTimeout(() => c.abort(), ms);
    return c.signal;
  }
}
class AbortControllerPolyfill {
  constructor() {
    this.signal = new AbortSignalPolyfill();
  }
  abort(reason) {
    this.signal._abort(reason);
  }
}
const abortError = () => {
  const e = new Error('The operation was aborted.');
  e.name = 'AbortError';
  return e;
};
g.AbortController = AbortControllerPolyfill;
g.AbortSignal = AbortSignalPolyfill;

// -------------------------------------------------------------------- fetch

let fetchSeq = 0;
const pendingFetch = new Map();

class ResponsePolyfill {
  constructor(meta) {
    this._id = meta.id;
    this.status = meta.status;
    this.statusText = meta.statusText || '';
    this.ok = meta.status >= 200 && meta.status < 300;
    this.url = meta.url;
    this.redirected = !!meta.redirected;
    this.type = 'basic';
    this.headers = new HeadersPolyfill(meta.headers || {});
    this.bodyUsed = false;
    this._text = undefined;
  }
  _readText() {
    if (this._text === undefined) this._text = host('body.text', String(this._id)) || '';
    return this._text;
  }
  text() {
    this.bodyUsed = true;
    return Promise.resolve(this._readText());
  }
  json() {
    this.bodyUsed = true;
    return this.text().then(t => JSON.parse(t));
  }
  arrayBuffer() {
    this.bodyUsed = true;
    const buf = host('body.bytes', String(this._id));
    return Promise.resolve(buf instanceof ArrayBuffer ? buf : new ArrayBuffer(0));
  }
  blob() {
    return this.arrayBuffer();
  }
  clone() {
    return this;
  }
}
g.Response = ResponsePolyfill;

const serializeBody = (body, headers) => {
  if (body == null) return { type: 'none' };
  if (body instanceof FormDataPolyfill) return { type: 'multipart', fields: body._entries };
  if (typeof URLSearchParams !== 'undefined' && body instanceof URLSearchParams) {
    if (!headers.has('content-type')) {
      headers.set('content-type', 'application/x-www-form-urlencoded;charset=UTF-8');
    }
    return { type: 'text', value: body.toString() };
  }
  if (typeof body === 'string') return { type: 'text', value: body };
  if (body instanceof ArrayBuffer || ArrayBuffer.isView(body)) {
    return { type: 'base64', value: bytesToB64(toBytes(body)) };
  }
  return { type: 'text', value: String(body) };
};

g.fetch = (input, init = {}) =>
  new Promise((resolve, reject) => {
    const url = typeof input === 'string' ? input : input && input.url ? input.url : String(input);
    const headers = new HeadersPolyfill(init.headers);
    const body = serializeBody(init.body, headers);
    const signal = init.signal;
    if (signal && signal.aborted) return reject(signal.reason || abortError());
    const id = ++fetchSeq;
    pendingFetch.set(id, { resolve, reject });
    if (signal) {
      signal.addEventListener('abort', () => {
        if (!pendingFetch.has(id)) return;
        pendingFetch.delete(id);
        host('abort', String(id));
        reject(signal.reason || abortError());
      });
    }
    const h = {};
    headers.forEach((v, k) => (h[k] = v));
    host(
      'fetch',
      JSON.stringify({
        id,
        url,
        method: (init.method || 'GET').toUpperCase(),
        headers: h,
        body,
        redirect: init.redirect || 'follow',
      }),
    );
  });

// ------------------------------------------------------------------ @libs/*

const NovelStatus = {
  Unknown: 'Unknown',
  Ongoing: 'Ongoing',
  Completed: 'Completed',
  Licensed: 'Licensed',
  PublishingFinished: 'Publishing Finished',
  Cancelled: 'Cancelled',
  OnHiatus: 'On Hiatus',
  STUB: 'STUB',
  Inactive: 'Inactive',
};
const defaultCover = 'https://github.com/LNReader/lnreader-plugins/blob/main/icons/src/coverNotAvailable.jpg?raw=true';
const FilterTypes = {
  TextInput: 'Text',
  Picker: 'Picker',
  CheckboxGroup: 'Checkbox',
  Switch: 'Switch',
  ExcludableCheckboxGroup: 'XCheckbox',
};

const DEFAULT_HEADERS = {
  'Connection': 'keep-alive',
  'Accept': '*/*',
  'Accept-Language': '*',
  'Sec-Fetch-Mode': 'cors',
  'Accept-Encoding': 'gzip, deflate',
  'Cache-Control': 'max-age=0',
};
const makeInit = init => {
  init = init || {};
  if (init.headers instanceof HeadersPolyfill) {
    for (const k of Object.keys(DEFAULT_HEADERS)) {
      if (!init.headers.has(k)) init.headers.set(k, DEFAULT_HEADERS[k]);
    }
    return init;
  }
  return Object.assign({}, init, { headers: Object.assign({}, DEFAULT_HEADERS, init.headers || {}) });
};
const fetchApi = (url, init) => g.fetch(url, makeInit(init));
const fetchText = (url, init, encoding) =>
  g
    .fetch(url, makeInit(init))
    .then(res => {
      if (!res.ok) return '';
      if (!encoding || /^utf-?8$/i.test(encoding)) return res.text();
      return res.arrayBuffer().then(buf => new TextDecoderPolyfill(encoding).decode(buf));
    })
    .catch(() => '');
const fetchFile = (url, init) =>
  g
    .fetch(url, makeInit(init))
    .then(res => (res.ok ? res.arrayBuffer().then(buf => bytesToB64(new Uint8Array(buf))) : ''))
    .catch(() => '');
const fetchProto = () => Promise.reject(new Error('fetchProto is not supported in hub_reader'));
const isUrlAbsolute = url => {
  if (!url) return false;
  if (url.indexOf('//') === 0) return true;
  if (url.indexOf('://') === -1) return false;
  if (url.indexOf('.') === -1) return false;
  if (url.indexOf('/') === -1) return false;
  if (url.indexOf(':') > url.indexOf('/')) return false;
  if (url.indexOf('://') < url.indexOf('.')) return true;
  return false;
};

const storageKey = (pluginId, kind, key) => pluginId + kind + (key || '');
class PluginStorage {
  constructor(pluginId) {
    this._id = pluginId;
  }
  set(key, value, expires) {
    const item = {
      created: new Date(),
      value,
      expires: expires instanceof Date ? expires.getTime() : expires,
    };
    host('storage.set', JSON.stringify({ key: storageKey(this._id, '_DB_', key), value: JSON.stringify(item) }));
  }
  get(key, raw) {
    const stored = host('storage.get', storageKey(this._id, '_DB_', key));
    if (!stored) return undefined;
    let item;
    try {
      item = JSON.parse(stored);
    } catch (_) {
      return undefined;
    }
    if (item.expires && Date.now() > item.expires) {
      this.delete(key);
      return undefined;
    }
    return raw ? item : item.value;
  }
  delete(key) {
    host('storage.delete', storageKey(this._id, '_DB_', key));
  }
  getAllKeys() {
    const prefix = storageKey(this._id, '_DB_', '');
    const keys = JSON.parse(host('storage.keys', prefix) || '[]');
    return keys.map(k => k.slice(prefix.length));
  }
  clearAll() {
    this.getAllKeys().forEach(k => this.delete(k));
  }
}
class WebStorage {
  constructor(pluginId, kind) {
    this._key = storageKey(pluginId, kind);
  }
  get() {
    const data = host('storage.get', this._key);
    return data ? JSON.parse(data) : undefined;
  }
}

const packages = {
  'htmlparser2': { Parser },
  'cheerio': { load },
  'dayjs': dayjs,
  'urlencode': {
    encode: s => encodeURIComponent(s),
    decode: s => decodeURIComponent(s),
  },
  '@libs/novelStatus': { NovelStatus },
  '@libs/fetch': { fetchApi, fetchText, fetchProto, fetchFile },
  '@libs/isAbsoluteUrl': { isUrlAbsolute },
  '@libs/filterInputs': { FilterTypes },
  '@libs/defaultCover': { defaultCover },
  '@libs/aes': { gcm },
  '@libs/utils': { utf8ToBytes, bytesToUtf8 },
  '@/types/constants': { NovelStatus, defaultCover },
};

// ------------------------------------------------------------ plugin loader

const plugins = new Map();

const describe = plugin => ({
  id: plugin.id,
  name: plugin.name,
  version: plugin.version,
  site: plugin.site,
  icon: plugin.icon,
  filters: plugin.filters || null,
  pluginSettings: plugin.pluginSettings || null,
  imageRequestInit: plugin.imageRequestInit || null,
  webStorageUtilized: !!plugin.webStorageUtilized,
  hasParsePage: typeof plugin.parsePage === 'function',
  hasResolveUrl: typeof plugin.resolveUrl === 'function',
  customCSS: plugin.customCSS || null,
});

const errorMessage = e => {
  if (e == null) return 'Unknown error';
  if (typeof e === 'string') return e;
  if (e.message) return (e.name && e.name !== 'Error' ? e.name + ': ' : '') + e.message;
  try {
    return JSON.stringify(e);
  } catch (_) {
    return String(e);
  }
};

g.__lnr = {
  version: 1,

  /** Load (or replace) a plugin. Returns its metadata as JSON. */
  load(key, code) {
    const req = name => {
      if (name === '@libs/storage') {
        return {
          storage: new PluginStorage(key),
          localStorage: new WebStorage(key, '_LocalStorage'),
          sessionStorage: new WebStorage(key, '_SessionStorage'),
        };
      }
      const pkg = packages[name];
      if (!pkg) throw new Error('Module not available in hub_reader: ' + name);
      return pkg;
    };
    // Same wrapper as LNReader's pluginManager.initPlugin.
    const plugin = Function('require', 'module', 'const exports = module.exports = {};\n' + code + '\n;return exports.default')(
      req,
      {},
    );
    if (!plugin || typeof plugin.popularNovels !== 'function') {
      throw new Error('Not an LNReader plugin');
    }
    plugins.set(key, plugin);
    return JSON.stringify(describe(plugin));
  },

  unload(key) {
    plugins.delete(key);
  },

  /** Call plugin[method](...args); the result is reported through host('done'). */
  invoke(callId, key, method, argsJson) {
    const done = (ok, value) => host('done', JSON.stringify(ok ? { id: callId, ok, value } : { id: callId, ok, error: value }));
    Promise.resolve()
      .then(() => {
        const plugin = plugins.get(key);
        if (!plugin) throw new Error('Plugin not loaded: ' + key);
        if (typeof plugin[method] !== 'function') throw new Error('Plugin has no method ' + method);
        return plugin[method].apply(plugin, JSON.parse(argsJson));
      })
      .then(
        value => done(true, value === undefined ? null : value),
        e => done(false, errorMessage(e)),
      );
  },

  resolveFetch(id, metaJson) {
    const p = pendingFetch.get(id);
    if (!p) return;
    pendingFetch.delete(id);
    const meta = JSON.parse(metaJson);
    meta.id = id;
    p.resolve(new ResponsePolyfill(meta));
  },

  rejectFetch(id, message) {
    const p = pendingFetch.get(id);
    if (!p) return;
    pendingFetch.delete(id);
    p.reject(new TypeError(message || 'Network request failed'));
  },

  fireTimer(id) {
    const t = timers.get(id);
    if (!t) return;
    if (t.interval == null) timers.delete(id);
    else armTimer(id, t.interval);
    try {
      if (typeof t.fn === 'function') t.fn(...t.args);
    } catch (e) {
      g.console.error('timer', e);
    }
  },
};
