// test.mjs [image] : boot the LS-DOS hard disk image on the emulated Model II
// (Tools/m2web), answer the date and time, look at the disk, write files
// and check they are still there after booting again.
import { readFileSync } from 'fs';
import { Z80 } from '../m2web/z80.js';
import { Model2 } from '../m2web/m2.js';

const img = new Uint8Array(readFileSync(process.argv[2] ||
  new URL('../../Images/trs80m2/lsdos2-0.hdv', import.meta.url)));
let fails = 0;

// Boot, then type each line when LS-DOS waits for one; the screen after
function session(lines) {
  const m = new Model2(Z80, img);
  if (!m.bootHd()) throw new Error('no boot sector');
  let i = 0, idle = 0;
  for (let t = 0; t < 2000 && i <= lines.length; t++) {
    m.run(400000);
    const last = m.text().split('\n').filter(x => x.trim()).pop() || '';
    if (/(Ready|\?) *$/.test(last) && !m.keyq.length) {
      if (++idle < 3) continue;		// let it settle
      idle = 0;
      if (i === lines.length) break;
      for (const c of lines[i++] + '\r') m.key(c.charCodeAt(0));
    } else idle = 0;
  }
  return m.text();
}

function expect(screen, what, re) {
  const ok = re.test(screen);
  console.log((ok ? 'ok   ' : 'FAIL ') + what);
  if (!ok) { fails++; console.log(screen); }
}

let s = session(['11/04/26', '12:00:00', 'DEVICE', 'FREE']);
expect(s, 'boots to LS-DOS Ready', /LS-DOS Ready/);
expect(s, 'drive 0 is the hard disk', /:0 +\[LSDOS-HD\] .*Rigid.*Cyls=202, Fixed/);
expect(s, 'floppies are :1 and :2', /:1 .*8" Floppy #1[\s\S]*:2 .*8" Floppy #2/);
expect(s, 'FREE sees 6464K', /Free Space = +[\d.]+K\/ 6464\.00K/);

s = session(['11/04/26', '12:00:00',
  "DUMP TEST/CMD (START=X'3000',END=X'3FFF',TRA=X'402D')",
  'COPY TEST/CMD COPY/CMD', 'DIR /CMD']);
expect(s, 'DUMP and COPY write files', /COPY\/CMD[\s\S]*TEST\/CMD/);
s = session(['11/04/26', '12:00:00', 'DIR /CMD']);
expect(s, 'the files are there after booting again', /COPY\/CMD[\s\S]*TEST\/CMD/);
expect(s, 'BACKUP, FORMAT and the other utilities are there', /BACKUP\/CMD[\s\S]*FORMAT\/CMD/);
s = session(['11/04/26', '12:00:00', 'LIST COPY/CMD (HEX)']);
expect(s, 'LIST reads the copy back', /0000:00 = +05 06 54 45 53 54 20 20 +01 00 00 30/);
process.exit(fails ? 1 : 0);
