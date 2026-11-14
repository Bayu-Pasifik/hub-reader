// Membuat animasi Lottie sederhana ke assets/lottie/*.json. Jalankan: node tool/gen_lottie.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'lottie');
mkdirSync(OUT, { recursive: true });

const k = (frames) => ({
  a: 1,
  k: frames.map(([t, v], i) => {
    const e = { t, s: Array.isArray(v) ? v : [v] };
    if (i < frames.length - 1) {
      e.i = { x: [0.4], y: [1] };
      e.o = { x: [0.6], y: [0] };
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
  ao: 0, shapes, ip: 0, op: 60, st: 0, bm: 0,
});
const comp = (nm, layers) => ({
  v: '5.7.0', fr: 30, ip: 0, op: 60, w: 200, h: 200, nm, ddd: 0, assets: [], layers,
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

for (const [n, f] of Object.entries({ loading, empty, error })) {
  writeFileSync(join(OUT, `${n}.json`), JSON.stringify(f()));
  console.log('ok', n);
}
