// TRS-80 Model II hardware for the browser emulator (a port of
// Tools/m2sim/m2sim.py): 32K fixed page 0, pages 1-15 at 0x8000 selected by
// port 0xFF, video RAM at 0xF800, keyboard, 30Hz real time clock NMI, WD1010
// hard disk (drive 0, 8 heads, 32 sectors of 512 bytes per track), and the
// keyboard interrupt through CTC channel 3 in IM 2 (LS-DOS uses it, Fuzix
// polls).

export const CPU_HZ = 4000000;

export class Model2 {
  constructor(Z80, hdimg) {
    this.page0 = new Uint8Array(0x8000);
    this.pages = [];
    for (let i = 0; i < 16; i++) this.pages.push(new Uint8Array(0x8000));
    this.video = new Uint8Array(0x800).fill(32);
    this.ff = 0;
    this.keyq = [];
    this.nmiLine = false;
    this.crtc = new Uint8Array(18);
    this.crtcReg = 0;
    this.ctc = [0, 1, 2, 3].map(() => ({ ctl: 0, tc: false }));
    this.ctcVec = 0;
    this.kbdIrq = false;
    this.hd = { sdh: 0, cyl: 0, sec: 0, status: 0x50, err: 0, buf: null, ptr: 0, wr: false, off: 0 };
    this.img = hdimg;
    this.dirty = false;
    const self = this;
    this.hal = {
      tStateCount: 0,
      readMemory(a) { return self.rd(a); },
      writeMemory(a, v) { self.wr(a, v); },
      contendMemory() {},
      readPort(a) { return self.inp(a & 0xFF); },
      writePort(a, v) { self.outp(a & 0xFF, v); },
      contendPort() {},
    };
    this.z = new Z80(this.hal);
    this.z.reset();
    this.tick = CPU_HZ / 30;
    this.nextNmi = this.tick;
  }

  rd(a) {
    if (a < 0x8000) return this.page0[a];
    if ((this.ff & 0x80) && a >= 0xF800) return this.video[a - 0xF800];
    const p = this.ff & 0x0F;
    return p ? this.pages[p][a - 0x8000] : 0xFF;
  }

  wr(a, v) {
    if (a < 0x8000) { this.page0[a] = v; return; }
    if ((this.ff & 0x80) && a >= 0xF800) { this.video[a - 0xF800] = v; return; }
    const p = this.ff & 0x0F;
    if (p) this.pages[p][a - 0x8000] = v;
  }

  // ---- WD1010
  hdOffset() {
    const h = this.hd;
    if (h.sec >= 32 || (h.sdh & 0x60) !== 0x20 || (h.sdh & 0x18)) return -1;
    return 256 + ((h.cyl * 8 + (h.sdh & 7)) * 32 + h.sec) * 512;
  }

  hdCmd(v) {
    const h = this.hd, c = v & 0xF0;
    h.err = 0;
    if (c === 0x10 || c === 0x70) {
      if (h.sdh & 0x18) { h.status = 0x51; h.err = 0x12; } else h.status = 0x50;
      return;
    }
    const off = this.hdOffset();
    if (off < 0 || off + 512 > this.img.length) { h.status = 0x51; h.err = 0x10; return; }
    h.ptr = 0;
    h.status = 0x58;
    if (c === 0x20) { h.buf = this.img.subarray(off, off + 512); h.wr = false; }
    else if (c === 0x30) { h.buf = new Uint8Array(512); h.wr = true; h.off = off; }
  }

  inp(p) {
    const h = this.hd;
    switch (p) {
      case 0xFF: return (this.keyq.length ? 0x80 : 0) | (this.ff & 0x20);
      case 0xFC: {
        const k = this.keyq.length ? this.keyq.shift() : 0;
        if (this.keyq.length) this.kbdIrq = true;	// the next one
        return k;
      }
      case 0xFE: this.nmiLine = false; return 0;
      case 0xF6: case 0xF7: return 0x04;
      case 0xE0: return 0x10;
      case 0xE4: return 0x80;		// no floppy: not ready
      case 0xC8:
        if (h.buf && !h.wr && h.ptr < 512) {
          const v = h.buf[h.ptr++];
          if (h.ptr === 512) h.status = 0x50;
          return v;
        }
        return 0;
      case 0xC9: return h.err;
      case 0xCF: return h.status;
      case 0xC0: return 0;
    }
    return 0xFF;
  }

  outp(p, v) {
    const h = this.hd;
    switch (p) {
      case 0xFF: this.ff = v; return;
      case 0xFC: this.crtcReg = v & 0x1F; return;
      case 0xFD: if (this.crtcReg < 18) this.crtc[this.crtcReg] = v; return;
      case 0xF0: case 0xF1: case 0xF2: case 0xF3: {
        const c = this.ctc[p - 0xF0];
        if (c.tc) c.tc = false;			// time constant
        else if (v & 1) { c.ctl = v; c.tc = !!(v & 4); }
        else if (p === 0xF0) this.ctcVec = v & 0xF8;
        return;
      }
      case 0xC8:
        if (h.wr) {
          h.buf[h.ptr++] = v;
          if (h.ptr === 512) {
            this.img.set(h.buf, h.off);
            h.wr = false;
            h.status = 0x50;
            this.dirty = true;
          }
        }
        return;
      case 0xCB: h.sec = v; return;
      case 0xCC: h.cyl = (h.cyl & 0xFF00) | v; return;
      case 0xCD: h.cyl = (h.cyl & 0xFF) | (v << 8); return;
      case 0xCE: h.sdh = v; return;
      case 0xCF: this.hdCmd(v); return;
    }
  }

  // The hard disk boot ROM: 512 byte sectors from cylinder 0 head 0,
  // starting at sector 1, into 0x0000 until one starts with the signature,
  // then jp (hl) just past it.
  bootHd() {
    const sig = '/* END BOOT */';
    let addr = 0;
    for (let s = 1; s < 20; s++) {
      const d = this.img.subarray(256 + s * 512, 256 + (s + 1) * 512);
      this.page0.set(d, addr);
      if (String.fromCharCode(...d.subarray(0, sig.length)) === sig) {
        const r = this.z.regs;
        this.ff = 0x80;
        r.pc = addr + sig.length;
        r.hl = addr + sig.length;
        r.sp = 0x2800;
        return true;
      }
      addr += 512;
    }
    return false;
  }

  // The real time clock NMI. IFF1 is saved in IFF2, which the Fuzix
  // handler looks at.
  nmi() {
    const r = this.z.regs;
    this.nmiLine = true;
    if (r.halted) { r.pc = (r.pc + 1) & 0xFFFF; r.halted = 0; }
    this.z.pushWord(r.pc);
    r.pc = 0x66;
    r.iff2 = r.iff1;
    r.iff1 = 0;
  }

  // A maskable interrupt in IM 2 with vector vec
  irq(vec) {
    const r = this.z.regs;
    if (r.halted) { r.pc = (r.pc + 1) & 0xFFFF; r.halted = 0; }
    this.z.pushWord(r.pc);
    const a = (r.i << 8) | vec;
    r.pc = this.rd(a) | (this.rd((a + 1) & 0xFFFF) << 8);
    r.iff1 = r.iff2 = 0;
  }

  // Run for n clock cycles
  run(n) {
    const h = this.hal, z = this.z;
    const end = h.tStateCount + n;
    while (h.tStateCount < end) {
      z.step();
      if (this.kbdIrq && (this.ctc[3].ctl & 0x80) && z.regs.iff1 && z.regs.im === 2) {
        this.kbdIrq = false;
        this.irq(this.ctcVec | 6);
      }
      if (h.tStateCount >= this.nextNmi) {
        this.nextNmi += this.tick;
        if ((this.ff & 0x20) && !this.nmiLine) this.nmi();
      }
    }
  }

  key(c) { this.keyq.push(c & 0xFF); this.kbdIrq = true; }

  cursor() {
    if ((this.crtc[10] & 0x60) === 0x20) return -1;	// cursor off
    const pos = ((this.crtc[14] << 8) | this.crtc[15]) - ((this.crtc[12] << 8) | this.crtc[13]);
    return pos & 0x7FF;
  }

  text() {
    const rows = [];
    for (let y = 0; y < 24; y++) {
      let s = '';
      for (let x = 0; x < 80; x++) {
        const c = this.video[y * 80 + x] & 0x7F;
        s += c >= 32 && c < 127 ? String.fromCharCode(c) : ' ';
      }
      rows.push(s.replace(/ +$/, ''));
    }
    return rows.join('\n');
  }
}
