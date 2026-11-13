// QuickJS in flutter_js is built without BigInt. @noble/ciphers (AES-GCM, used
// by WTR-LAB and other plugins through `@libs/aes`) only needs BigInt to write
// 64-bit length blocks via DataView#setBigUint64, and those lengths always fit
// in a double. So a Number-backed BigInt plus 64-bit DataView accessors that
// split into two 32-bit words is enough. Real BigInt engines are left alone.
const g = globalThis;
if (typeof g.BigInt === 'undefined') {
  g.BigInt = value => {
    const n = Number(value);
    if (!Number.isFinite(n) || Math.floor(n) !== n) throw new RangeError('Cannot convert ' + value + ' to a BigInt');
    return n;
  };
}
const dv = DataView.prototype;
const TWO32 = 4294967296;
if (typeof dv.setBigUint64 !== 'function') {
  dv.setBigUint64 = function (offset, value, littleEndian) {
    const n = Number(value);
    const hi = Math.floor(n / TWO32) >>> 0;
    const lo = n % TWO32 >>> 0;
    this.setUint32(offset + (littleEndian ? 4 : 0), hi, littleEndian);
    this.setUint32(offset + (littleEndian ? 0 : 4), lo, littleEndian);
  };
  dv.setBigInt64 = dv.setBigUint64;
}
if (typeof dv.getBigUint64 !== 'function') {
  dv.getBigUint64 = function (offset, littleEndian) {
    const hi = this.getUint32(offset + (littleEndian ? 4 : 0), littleEndian);
    const lo = this.getUint32(offset + (littleEndian ? 0 : 4), littleEndian);
    return hi * TWO32 + lo;
  };
}
