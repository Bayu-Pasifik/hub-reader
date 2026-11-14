// Membuat animasi Lottie sederhana ke assets/lottie/*.json. Jalankan: node tool/gen_lottie.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'lottie');
mkdirSync(OUT, { recursive: true });

const k = (frames, linear = false) => ({
  a: 1,
  k: frames.map(([t, v], i) => {
    const e = { t, s: Array.isArray(v) ? v : [v] };
    if (i < frames.length - 1) {
      e.i = linear ? { x: [1], y: [1] } : { x: [0.4], y: [1] };
      e.o = linear ? { x: [0], y: [0] } : { x: [0.6], y: [0] };
    }
    return e;
  }),
});
const s = (v) => ({ a: 0, k: v });
const fill = (c, nm = 'Fill 1') => ({ nm, ty: 'fl', c: s(c), o: s(100), r: 1 });
const stroke = (c, w) => ({ ty: 'st', c: s(c), o: s(100), w: s(w), lc: 2, lj: 2 });
const ell = (sz, p = [0, 0]) => ({ ty: 'el', s: s(sz), p: s(p) });
const rect = (sz, r, p = [0, 0]) => ({ ty: 'rc', s: s(sz), p: s(p), r: s(r) });
const tr = (o = {}) => ({
  ty: 'tr', p: o.p ?? s([0, 0]), a: s([0, 0]), s: o.sc ?? s([100, 100]), r: s(0), o: s(100),
});
const group = (items, t) => ({ ty: 'gr', it: [...items, t ?? tr()] });
const layer = (shapes, pos, ind, extra = {}) => ({
  ddd: 0, ind, ty: 4, nm: `l${ind}`, sr: 1,
  ks: { o: s(100), r: s(0), p: s([...pos, 0]), a: s([0, 0, 0]), s: s([100, 100, 100]), ...extra },
  ao: 0, shapes, ip: 0, op: 120, st: 0, bm: 0,
});
const comp = (nm, layers, op = 60) => ({
  v: '5.7.0', fr: 30, ip: 0, op, w: 200, h: 200, nm, ddd: 0, assets: [], layers,
});

const BLUE = [0.38, 0.45, 0.95, 1];
const LIGHT = [0.38, 0.45, 0.95, 0.35];

const loading = () =>
  comp('loading', [0, 1, 2].map((i) => {
    const d = i * 6;
    const sc = k([[d, [60, 60, 100]], [d + 12, [130, 130, 100]], [d + 24, [60, 60, 100]], [60, [60, 60, 100]]]);
    return layer([group([ell([26, 26]), fill(BLUE)])], [60 + i * 40, 100], i + 1, { s: sc });
  }));

const empty = () => {
  const bob = k([[0, [0, 0]], [30, [0, -10]], [60, [0, 0]]]);
  const t = tr({ p: bob });
  const book = group([rect([84, 104], 10), fill(BLUE)], t);
  const l1 = group([rect([60, 8], 4, [0, -22]), fill([1, 1, 1, 0.9], 'Page')], tr({ p: bob }));
  const l2 = group([rect([44, 8], 4, [-8, -4]), fill([1, 1, 1, 0.65], 'Page')], tr({ p: bob }));
  const shadow = group([ell([80, 12]), fill(LIGHT)],
    tr({ sc: k([[0, [100, 100]], [30, [78, 78]], [60, [100, 100]]]) }));
  return comp('empty', [layer([l1, l2, book], [100, 90], 1), layer([shadow], [100, 160], 2)]);
};

const error = () => {
  const rot = k([[0, 0], [8, -8], [16, 8], [24, -6], [32, 0], [60, 0]]);
  const shapes = [
    group([ell([96, 96]), fill(LIGHT), stroke(BLUE, 6)]),
    group([rect([8, 34], 4, [0, -8]), fill(BLUE)]),
    group([ell([9, 9], [0, 22]), fill(BLUE)]),
  ];
  return comp('error', [layer(shapes, [100, 100], 1, { r: rot })]);
};

const path = (v, i, o, closed) => ({
  ty: 'sh', ks: s({ c: closed, v, i, o }),
});
const trim = (e) => ({ ty: 'tm', s: s(0), e, o: s(0), m: 1 });

// Hati meletup saat difavoritkan (sekali jalan, 24 frame).
const heart = () => {
  const v = [[0, 32], [-36, -4], [-18, -30], [0, -14], [18, -30], [36, -4]];
  const i = [[14, -10], [6, 14], [-12, 0], [-6, -8], [-12, 0], [0, -16]];
  const o = [[-14, -10], [0, -16], [12, 0], [6, -8], [12, 0], [-6, 14]];
  const pop = k([[0, [4, 4, 100]], [9, [125, 125, 100]], [15, [92, 92, 100]], [21, [100, 100, 100]]]);
  const ring = group([ell([150, 150]), stroke(BLUE, 5)], tr({
    sc: k([[2, [30, 30]], [20, [100, 100]]]),
  }));
  const ringLayer = layer([ring], [100, 100], 2, {
    o: k([[2, 0], [4, 70], [22, 0]]),
  });
  const heartLayer = layer([group([path(v, i, o, true), fill(BLUE)])], [100, 104], 1, { s: pop });
  return comp('heart', [heartLayer, ringLayer], 24);
};

// Pemeriksaan/sinkronisasi: busur berputar.
const sync = () => {
  const arc = group([ell([110, 110]), stroke(BLUE, 12), trim(s(70))]);
  const dot = group([ell([14, 14], [0, -55]), fill(BLUE)]);
  const rot = k([[0, 0], [60, 360]], true);
  return comp('sync', [layer([arc, dot], [100, 100], 1, { r: rot })]);
};

// Centang sukses: lingkaran membesar lalu centang tergambar.
const success = () => {
  const circ = group([ell([120, 120]), fill(LIGHT)], tr({
    sc: k([[0, [4, 4]], [14, [112, 112]], [22, [100, 100]]]),
  }));
  const check = group([
    path([[-24, 2], [-7, 19], [26, -16]], [[0, 0], [0, 0], [0, 0]], [[0, 0], [0, 0], [0, 0]], false),
    stroke(BLUE, 12),
    { ty: 'tm', s: s(0), e: k([[12, 0], [28, 100]]), o: s(0), m: 1 },
  ]);
  return comp('success', [layer([check, circ], [100, 100], 1)], 90);
};

// Kaca pembesar menyisir: dipakai untuk "tidak ada hasil".
const search = () => {
  const lens = group([ell([68, 68], [-10, -10]), stroke(BLUE, 10)]);
  const handle = group([rect([14, 44], 7, [0, 0]), fill(BLUE)], tr({ p: s([34, 34]) }));
  handle.it[handle.it.length - 1].r = s(-45);
  const move = k([[0, [100, 100, 0]], [15, [116, 96, 0]], [30, [100, 100, 0]], [45, [84, 104, 0]], [60, [100, 100, 0]]]);
  return comp('search', [layer([lens, handle], [100, 100], 1, { p: move })]);
};

for (const [n, f] of Object.entries({ loading, empty, error, heart, sync, success, search })) {
  writeFileSync(join(OUT, `${n}.json`), JSON.stringify(f()));
  console.log('ok', n);
}
