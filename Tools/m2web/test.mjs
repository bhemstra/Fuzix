import { readFileSync } from 'fs';
import { Z80 } from './z80.js';
import { Model2, CPU_HZ } from './m2.js';
const img = new Uint8Array(readFileSync(process.argv[2] || "../../Images/trs80m2/hard2-0.hdv"));
const m = new Model2(Z80, img);
if (!m.bootHd()) throw new Error('no boot');
const steps = [['new date:', ''], ['new time:', ''], ['login:', 'root'], ['Welcome to FUZIX', 'ls /bin | wc -l'], ['    1', 'tbasic'], ['TINY BASIC', 'PRINT SIZE']];
const t0 = Date.now();
for (let sec = 0; sec < 40; sec++) {
  m.run(CPU_HZ);
  if (steps.length && !m.keyq.length && m.text().includes(steps[0][0])) {
    for (const ch of steps[0][1] + '\r') m.key(ch.charCodeAt(0));
    steps.shift();
  }
}
console.log(m.text());
console.log('emulated 40 s in', (Date.now() - t0) / 1000, 's');
