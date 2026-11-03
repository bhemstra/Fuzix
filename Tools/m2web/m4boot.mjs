// m4boot.mjs [image] : check the Model 4 hard disk boot sector
//
// Does what the Model 4P boot ROM (or the FreHD auto boot ROM) does: read
// cylinder 0 head 0 sector 1 of the hard disk into 0x4300 and jump to it,
// then runs the boot sector against a WD1010 with 256 byte sectors until
// it jumps to the kernel. Checks the kernel was loaded and "hda2" is in
// the command line slot.
import { readFileSync } from 'fs';
import { Z80 } from './z80.js';

const img = new Uint8Array(readFileSync(process.argv[2] ||
  new URL('../../Images/trs80/hard4p-0.hdv', import.meta.url)));
const kern = new Uint8Array(readFileSync(process.argv[3] ||
  new URL('../../Kernel/fuzix.bin', import.meta.url)));
const mem = new Uint8Array(65536);
const hd = { sdh: 0, cyl: 0, sec: 0, status: 0x50, buf: null, ptr: 0, reads: 0 };
const SPT = 32, HEADS = 8;

function hdcmd(v) {
  if ((v & 0xF0) !== 0x20) { hd.status = 0x50; return; }
  const head = hd.sdh & 7;
  if ((hd.sdh & 0x18) || hd.sec >= SPT) { hd.status = 0x51; return; }
  const off = 256 + ((hd.cyl * HEADS + head) * SPT + hd.sec) * 256;
  hd.buf = img.subarray(off, off + 256);
  hd.ptr = 0;
  hd.status = 0x58;
  hd.reads++;
}

const hal = {
  tStateCount: 0,
  readMemory: a => mem[a],
  writeMemory: (a, v) => { mem[a] = v; },
  contendMemory() {}, contendPort() {},
  readPort(a) {
    switch (a & 0xFF) {
      case 0xCF: return hd.status;
      case 0xC8: {
        const v = hd.buf ? hd.buf[hd.ptr++] : 0;
        if (hd.ptr === 256) hd.status = 0x50;
        return v;
      }
    }
    return 0xFF;
  },
  writePort(a, v) {
    switch (a & 0xFF) {
      case 0xCB: hd.sec = v; break;
      case 0xCC: hd.cyl = (hd.cyl & 0xFF00) | v; break;
      case 0xCD: hd.cyl = (hd.cyl & 0xFF) | (v << 8); break;
      case 0xCE: hd.sdh = v; break;
      case 0xCF: hdcmd(v); break;
    }
  },
};

// The ROM part: sector 1 of cylinder 0 to 0x4300
mem.set(img.subarray(256 + 256, 256 + 512), 0x4300);
const z = new Z80(hal);
z.reset();
z.regs.pc = 0x4300;
z.regs.sp = 0x4200;
let steps = 0;
while (z.regs.pc !== 0x0100 && steps < 5000000) { z.step(); steps++; }
if (z.regs.pc !== 0x0100) {
  console.log('FAIL: did not reach 0x0100, pc', z.regs.pc.toString(16), 'screen',
    String.fromCharCode(...mem.subarray(0xF800, 0xF850)).trim());
  process.exit(1);
}
let bad = 0;
for (let i = 0; i < kern.length; i++)
  if (i < 2 || i >= 16 ? mem[0x100 + i] !== kern[i] : false) bad++;
const cmd = String.fromCharCode(...mem.subarray(0x102, 0x106));
console.log('reached the kernel after', hd.reads, 'sector reads;',
  bad ? bad + ' kernel bytes differ' : 'kernel loaded intact',
  '; command line', JSON.stringify(cmd));
process.exit(bad || cmd !== 'hda2' ? 1 : 0);
