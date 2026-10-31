#!/usr/bin/env python3
#
#	Minimal TRS-80 Model II simulator for debugging the Fuzix trs80m2 port
#
#	This is not a full emulator. It models just enough of the machine for
#	the Fuzix kernel: the memory paging and video RAM behind port 0xFF,
#	the keyboard, the real time clock NMI, the FD1791 floppy controller
#	driven by the Z80 DMA, a WD1010 style hard disk with 512 byte sectors
#	and the serial port A transmitter (for kernel debug output). The
#	behaviour follows the Model II Technical Reference Manual and the MAME
#	driver, so it cannot catch differences between that and real hardware
#	or other emulators.
#
#	The CPU is the "z80" Python package (pip install z80).
#
#	Example:
#	m2sim.py --floppy Images/trs80m2/bootds.imd --map Kernel/fuzix.map \
#		--mem 512 --keys 'bootdev=fda' --keys 'login:=root' \
#		--keys '#=ls /bin'
#

import argparse
import bisect
import re
import sys

import z80

CPU_HZ = 4_000_000
SLICE = 2000		# T states per run() call


def parse_args():
    ap = argparse.ArgumentParser(description=__doc__ or "TRS-80 Model II simulator")
    ap.add_argument('--floppy', help='ImageDisk (.imd) file for drive 0')
    ap.add_argument('--hdv', help='hard disk image (256 byte header, then 512 byte sectors, 8 heads)')
    ap.add_argument('--hd-spt', type=int, default=32,
                    help='512 byte sectors per track on the hard disk (default 32, as trs80gp)')
    ap.add_argument('--hd-secbase', type=int, default=0, choices=(0, 1),
                    help='first sector number on the hard disk tracks (default 0)')
    ap.add_argument('--hd-write', action='store_true',
                    help='write hard disk changes back to the image file')
    ap.add_argument('--kernel', help='load this fuzix.bin at 0x0100 instead of booting through the boot ROM path')
    ap.add_argument('--hd-boot', action='store_true',
                    help='boot from the hard disk the way the boot ROM does (reads from sector 1 into 0x0000)')
    ap.add_argument('--mem', type=int, default=512, choices=[64 + 32 * n for n in range(1, 15)],
                    help='total RAM in KiB (default 512)')
    ap.add_argument('--keys', action='append', default=[],
                    help="'text=input': when text appears on screen type input followed by Return. "
                         "May be given several times, the steps run in order")
    ap.add_argument('--seconds', type=float, default=120,
                    help='emulated seconds to run (default 120)')
    ap.add_argument('--hz', type=int, default=30, help='real time clock rate (default 30)')
    ap.add_argument('--map', help='fuzix.map, to name addresses and stop on kernel traps')
    ap.add_argument('--trace-disk', action='store_true', help='log every sector transferred')
    return ap.parse_args()


class Model2:
    def __init__(self, args):
        self.args = args
        self.npages = args.mem // 32		# pages 0..npages-1
        self.pages = [bytearray(b'\xff' * 0x8000) for _ in range(16)]
        for i in range(1, self.npages):
            self.pages[i] = bytearray(0x8000)
        self.video = bytearray(b' ' * 0x800)
        self.port_ff = 0x00
        self.m = z80.Z80Machine()
        self.mem = self.m.memory
        self.keyq = []
        self.nmi_line = False
        self.fdc = dict(track=0, sector=1, data=0, status=0)
        self.drvsel = 0xFF
        self.dma = dict(seq=[], addr=0, length=0, enabled=False)
        self.serial = bytearray()
        self.log = []
        self.disk = self.load_imd(args.floppy) if args.floppy else {}
        self.hdimg = bytearray(open(args.hdv, 'rb').read()) if args.hdv else None
        self.hd = dict(sdh=0, cyl=0, sec=0, status=0x50, err=0, buf=b'', ptr=0, wr=False, off=0)
        self.m.set_input_callback(self.inp)
        self.m.set_output_callback(self.outp)
        self.load_upper()

    # ---- disk images
    @staticmethod
    def load_imd(path):
        d = open(path, 'rb').read()
        i = d.index(b'\x1a') + 1
        secs = {}
        while i < len(d):
            mode, cyl, head, ns, sz = d[i:i + 5]
            i += 5
            smap = d[i:i + ns]
            i += ns
            ln = 128 << sz
            if head & 0xC0:
                raise SystemExit('IMD cylinder/head maps are not supported')
            for s in smap:
                t = d[i]
                i += 1
                if t in (1, 3, 5, 7):
                    secs[(cyl, head, s)] = bytearray(d[i:i + ln])
                    i += ln
                elif t in (2, 4, 6, 8):
                    secs[(cyl, head, s)] = bytearray([d[i]]) * ln
                    i += 1
        return secs

    # ---- memory paging: page 0 is fixed at 0000-7FFF, port 0xFF picks the
    # page at 8000-FFFF and bit 7 overlays video RAM at F800-FFFF
    def save_upper(self):
        p = self.port_ff & 0x0F
        if self.port_ff & 0x80:
            self.video[:] = self.mem[0xF800:0x10000]
            if 0 < p < self.npages:
                self.pages[p][0:0x7800] = self.mem[0x8000:0xF800]
        elif 0 < p < self.npages:
            self.pages[p][:] = self.mem[0x8000:0x10000]

    def load_upper(self):
        p = self.port_ff & 0x0F
        if 0 < p < self.npages:
            self.mem[0x8000:0x10000] = self.pages[p]
        else:
            self.mem[0x8000:0x10000] = b'\xff' * 0x8000
        if self.port_ff & 0x80:
            self.mem[0xF800:0x10000] = self.video

    def set_ff(self, v):
        self.save_upper()
        self.port_ff = v
        self.load_upper()

    def wr(self, a, v):
        if a >= 0x8000 and not (self.port_ff & 0x80 and a >= 0xF800):
            p = self.port_ff & 0x0F
            if p == 0 or p >= self.npages:
                return
        self.mem[a] = v

    def screen(self):
        v = bytes(self.mem[0xF800:0x10000]) if self.port_ff & 0x80 else bytes(self.video)
        rows = []
        for y in range(24):
            rows.append(''.join(chr(c & 0x7F) if 32 <= (c & 0x7F) < 127 else ' '
                                for c in v[y * 80:(y + 1) * 80]).rstrip())
        return '\n'.join(rows)

    # ---- Z80 DMA: just enough of the command parser for the sequences the
    # Fuzix floppy code and loader send
    def dma_write(self, v):
        s = self.dma['seq']
        s.append(v)
        if s[0] == 0x79:
            if len(s) == 5:
                self.dma['addr'] = s[1] | s[2] << 8
                self.dma['length'] = s[3] | s[4] << 8
                s.clear()
            return
        if s[0] == 0xC5:
            if len(s) == 2:
                s.clear()
            return
        if s[0] == 0xC3 or s[0] == 0x83:
            self.dma['enabled'] = False
        elif s[0] == 0x87:
            self.dma['enabled'] = True
        elif s[0] not in (0x14, 0x28, 0x8A, 0xCF, 0x05):
            self.log.append('DMA: unexpected byte %02X' % v)
        s.clear()

    # ---- FD1791. Data transfers complete instantly through the DMA.
    def fdc_cmd(self, v):
        drive = [i for i in range(4) if not (self.drvsel >> i) & 1]
        side = 0 if self.drvsel & 0x40 else 1
        mfm = bool(self.drvsel & 0x80)
        if (v & 0xF0) == 0xD0:
            self.fdc['status'] = 0
            return
        if not v & 0x80:		# type 1: restore, seek, step
            if v & 0xF0 == 0x00:
                self.fdc['track'] = 0
            elif v & 0xF0 == 0x10:
                self.fdc['track'] = self.fdc['data']
            self.fdc['status'] = 0x24 if self.fdc['track'] == 0 else 0x20
            return
        key = (self.fdc['track'], side, self.fdc['sector'])
        # Track 0 side 0 is single density, everything else double
        dd_track = key[0] > 0 or key[1] == 1
        if not drive or drive[0] != 0 or key not in self.disk or dd_track != mfm:
            self.fdc['status'] = 0x10
            self.log.append('FDC: record not found %s cmd %02X select %02X' % (key, v, self.drvsel))
            return
        if not self.dma['enabled']:
            self.fdc['status'] = 0x04
            self.log.append('FDC: lost data (DMA not enabled)')
            return
        sec = self.disk[key]
        if self.args.trace_disk:
            self.log.append('FDC %s cmd %02X -> %04X page %02X' % (key, v, self.dma['addr'], self.port_ff))
        if (v & 0xE0) == 0x80:
            for i, b in enumerate(sec):
                self.wr((self.dma['addr'] + i) & 0xFFFF, b)
        elif (v & 0xE0) == 0xA0:
            for i in range(len(sec)):
                sec[i] = self.mem[(self.dma['addr'] + i) & 0xFFFF]
        self.fdc['status'] = 0

    # ---- WD1010 hard disk, drive 0 only
    def hd_offset(self):
        hd = self.hd
        spt = self.args.hd_spt
        s = hd['sec'] - self.args.hd_secbase
        if s < 0 or s >= spt or (hd['sdh'] & 0x60) != 0x20 or (hd['sdh'] & 0x18):
            return None
        return 256 + ((hd['cyl'] * 8 + (hd['sdh'] & 7)) * spt + s) * 512

    def hd_cmd(self, v):
        hd = self.hd
        c = v & 0xF0
        hd['err'] = 0
        if c in (0x10, 0x70):		# restore, seek
            if hd['sdh'] & 0x18:
                hd['status'] = 0x51
                hd['err'] = 0x12
            else:
                hd['status'] = 0x50
            return
        off = self.hd_offset()
        if off is None or off + 512 > len(self.hdimg):
            hd['status'] = 0x51
            hd['err'] = 0x10
            if not hd['sdh'] & 0x18:
                self.log.append('HD: ID not found sdh %02X cyl %d sec %d' % (hd['sdh'], hd['cyl'], hd['sec']))
            return
        if self.args.trace_disk:
            self.log.append('HD cyl %d head %d sec %d cmd %02X' % (hd['cyl'], hd['sdh'] & 7, hd['sec'], v))
        hd['ptr'] = 0
        hd['status'] = 0x58
        if c == 0x20:
            hd['buf'] = bytearray(self.hdimg[off:off + 512])
            hd['wr'] = False
        elif c == 0x30:
            hd['buf'] = bytearray(512)
            hd['wr'] = True
            hd['off'] = off

    def hd_in(self, p):
        hd = self.hd
        if self.hdimg is None:
            return 0xFF
        if p == 0xC8:
            if hd['ptr'] < len(hd['buf']) and not hd['wr']:
                v = hd['buf'][hd['ptr']]
                hd['ptr'] += 1
                if hd['ptr'] == len(hd['buf']):
                    hd['status'] = 0x50
                return v
            return 0
        if p == 0xC9:
            return hd['err']
        if p == 0xCF:
            return hd['status']
        if p == 0xC0:
            return 0
        return 0xFF

    def hd_out(self, p, v):
        hd = self.hd
        if self.hdimg is None:
            return
        if p == 0xC8 and hd['wr']:
            hd['buf'][hd['ptr']] = v
            hd['ptr'] += 1
            if hd['ptr'] == 512:
                self.hdimg[hd['off']:hd['off'] + 512] = hd['buf']
                hd['wr'] = False
                hd['status'] = 0x50
        elif p == 0xCB:
            hd['sec'] = v
        elif p == 0xCC:
            hd['cyl'] = (hd['cyl'] & 0xFF00) | v
        elif p == 0xCD:
            hd['cyl'] = (hd['cyl'] & 0xFF) | v << 8
        elif p == 0xCE:
            hd['sdh'] = v
        elif p == 0xCF:
            self.hd_cmd(v)

    # ---- I/O ports
    def inp(self, port):
        p = port & 0xFF
        if p == 0xFF:
            return (0x80 if self.keyq else 0) | (self.port_ff & 0x20)
        if p == 0xFC:
            return self.keyq.pop(0) if self.keyq else 0
        if p == 0xFE:
            self.nmi_line = False
            return 0
        if p in (0xF6, 0xF7):
            return 0x04			# SIO: transmitter empty, nothing received
        if p == 0xE0:
            return 0x10			# PIO: printer not faulted
        if p == 0xE4:
            return self.fdc['status']
        if p == 0xE5:
            return self.fdc['track']
        if p == 0xE6:
            return self.fdc['sector']
        if p == 0xE7:
            return self.fdc['data']
        if 0xC0 <= p <= 0xCF:
            return self.hd_in(p)
        return 0xFF

    def outp(self, port, v):
        p = port & 0xFF
        if p == 0xFF:
            self.set_ff(v)
        elif p == 0xF4:
            self.serial.append(v)
        elif p == 0xF8:
            self.dma_write(v)
        elif p == 0xE4:
            self.fdc_cmd(v)
        elif p == 0xE5:
            self.fdc['track'] = v
        elif p == 0xE6:
            self.fdc['sector'] = v
        elif p == 0xE7:
            self.fdc['data'] = v
        elif p == 0xEF:
            self.drvsel = v
        elif 0xC0 <= p <= 0xCF:
            self.hd_out(p, v)

    # ---- start up
    def boot_rom(self):
        """Do what the boot ROM does: read the 26 single density sectors of
        cylinder 0 into 0x0E00, call 0x1404 and jump to 0x1004. A two
        instruction stub at 0x0000 stands in for the ROM code."""
        for s in range(26):
            key = (0, 0, s + 1)
            if key not in self.disk:
                raise SystemExit('floppy has no boot track')
            self.mem[0x0E00 + 128 * s:0x0E00 + 128 * (s + 1)] = self.disk[key]
        if bytes(self.mem[0x1000:0x1004]) != b'BOOT' or bytes(self.mem[0x1400:0x1404]) != b'DIAG':
            raise SystemExit('boot track lacks the BOOT/DIAG signatures')
        self.mem[0:6] = bytes([0xCD, 0x04, 0x14, 0xC3, 0x04, 0x10])
        self.set_ff(0x80)
        self.m.pc = 0x0000
        self.m.sp = 0x2000

    def boot_rom_hd(self):
        """Hard disk boot as in the boot ROM: read 512 byte sectors from
        cylinder 0 head 0 starting at sector 1 into 0x0000 until one starts
        with "/* END BOOT */", then jump just past it. At most 19 sectors."""
        sig = b'/* END BOOT */'
        if self.hdimg is None:
            raise SystemExit('--hd-boot needs --hdv')
        addr = 0
        for sector in range(1, 20):
            s = sector - self.args.hd_secbase
            if not 0 <= s < self.args.hd_spt:
                raise SystemExit('ROM: hard disk read error at sector %d' % sector)
            data = self.hdimg[256 + s * 512:256 + (s + 1) * 512]
            self.mem[addr:addr + 512] = data
            if bytes(data[:len(sig)]) == sig:
                self.set_ff(0x80)
                self.m.pc = addr + len(sig)
                self.m.hl = addr + len(sig)	# the ROM jumps with jp (hl)
                self.m.sp = 0x2800
                return
            addr += 512
        raise SystemExit('ROM: no /* END BOOT */ signature on the hard disk')

    def load_kernel(self, path):
        kern = open(path, 'rb').read()
        self.set_ff(0x01)
        low = kern[:0x7F00]
        self.mem[0x100:0x100 + len(low)] = low
        self.pages[1][0:len(kern) - 0x7F00] = kern[0x7F00:]
        self.load_upper()
        self.m.pc = 0x0100
        self.m.sp = 0xF7F0

    def nmi(self):
        """Deliver the RTC NMI. A real Z80 takes it between instructions,
        never between a DD/FD prefix and its opcode."""
        m = self.m
        if str(m.index_rp_kind).lower() != 'hl':
            return False
        self.nmi_line = True
        sp = (m.sp - 2) & 0xFFFF
        self.wr(sp, m.pc & 0xFF)
        self.wr((sp + 1) & 0xFFFF, m.pc >> 8)
        m.sp = sp
        m.pc = 0x66
        m.iff2 = m.iff1
        m.iff1 = 0
        m.halted = False
        return True


class Symbols:
    def __init__(self, path):
        self.syms = {}
        for line in open(path):
            mt = re.match(r'\s+([0-9A-F]{8})\s+(\S+)\s', line)
            if mt and not mt.group(2).startswith(('s__', 'l__')):
                self.syms[mt.group(2)] = int(mt.group(1), 16)
        self.addrs = sorted((v, k) for k, v in self.syms.items())
        self.keys = [a for a, _ in self.addrs]

    def name(self, a):
        i = bisect.bisect_right(self.keys, a) - 1
        if i < 0:
            return hex(a)
        return '%s+0x%x' % (self.addrs[i][1], a - self.addrs[i][0])


def main():
    args = parse_args()
    if not args.floppy and not args.kernel and not args.hd_boot:
        raise SystemExit('need --floppy, --hd-boot or --kernel')
    sim = Model2(args)
    m = sim.m
    syms = Symbols(args.map) if args.map else None
    stops = {}
    if syms:
        for k in ('null_handler', 'nmi_handler', 'trap_illegal', '_panic'):
            if k in syms.syms:
                stops[syms.syms[k]] = k
                m.set_breakpoint(syms.syms[k])

    if args.kernel:
        sim.load_kernel(args.kernel)
    elif args.hd_boot:
        sim.boot_rom_hd()
    else:
        sim.boot_rom()

    steps = []
    for k in args.keys:
        text, _, keys = k.partition('=')
        steps.append((text, keys))

    tick = CPU_HZ // args.hz
    limit = int(args.seconds * CPU_HZ)
    total = 0
    next_nmi = tick
    stopped = None
    while total < limit:
        m.ticks_to_stop = SLICE
        ev = m.run()
        total += SLICE - m.ticks_to_stop
        if ev & 1 and m.pc in stops:
            stopped = stops[m.pc]
            break
        if total >= next_nmi:
            if not (sim.port_ff & 0x20) or sim.nmi_line:
                next_nmi += tick
            elif sim.nmi():
                next_nmi += tick
        if steps and not sim.keyq:
            screen = sim.screen()
            text, keys = steps[0]
            if text in screen:
                sim.keyq.extend(keys.encode() + b'\r')
                sim.log.append('%.2fs typed %r' % (total / CPU_HZ, keys))
                steps.pop(0)

    print(sim.screen())
    print('---- %.2f emulated seconds, PC %s' % (total / CPU_HZ,
          syms.name(m.pc) if syms else hex(m.pc)))
    if stopped:
        print('---- stopped at %s, SP %04X, port FF %02X' % (stopped, m.sp, sim.port_ff))
        stack = [sim.mem[(m.sp + i) & 0xFFFF] | sim.mem[(m.sp + i + 1) & 0xFFFF] << 8
                 for i in range(0, 24, 2)]
        print('stack:', ' '.join(syms.name(x) for x in stack))
    if sim.log:
        print('---- log')
        print('\n'.join(sim.log[-40:]))
    if sim.serial:
        print('---- serial port A')
        print(sim.serial.decode('latin-1'))
    if args.hdv and args.hd_write:
        open(args.hdv, 'wb').write(sim.hdimg)
    return 1 if stopped else 0


if __name__ == '__main__':
    sys.exit(main())
