#!/usr/bin/env python3
#
#	mklib.py out.sys desc.dat cmddir
#
#	Build a system library overlay (SYS6/SYS, SYS7/SYS, SYS8/SYS) from
#	the assembled library command /CMD files, like BLDLIBS/CMD by Pete
#	Cervasio does with its L631LIBn/DAT description files.
#
import sys, os


def build(out, dat, cmddir):
	lines = [l.split()[0] for l in open(dat, errors='replace').read().replace('\r', '\n').split('\n') if l.strip()]
	outname = lines[0]
	ninputs = int(lines[2])
	i = 3
	inputs, entries = [], []		# entries: [isam, tra, file index]
	for f in range(ninputs):
		name = lines[i].split(':')[0].split('/')[0].lower()
		n = int(lines[i + 1])
		i += 2
		inputs.append(os.path.join(cmddir, name + '.cmd'))
		for _ in range(n):
			entries.append([int(lines[i], 16) & 0xFF, int(lines[i + 1], 16), f])
			i += 2
	o = bytearray()
	o += b'\x05\x06' + ('sys' + outname[3] + '  ').encode()
	o += b'\x1f\x17(C) 1982-4,6,90 MISOSYS'
	dirpos = len(o)
	o += bytes(8 * len(entries))
	o += b'\x0a\x01\x00'
	o += b'\x04\x01\x00'
	starts = []
	for path in inputs:
		starts.append(len(o))
		d = open(path, 'rb').read()
		j = 0
		while True:
			t, n = d[j], d[j + 1]
			if t in (0x05, 0x1F):
				j += 2 + n
			elif t == 0x01:
				size = n - 2
				if size < 1:
					size += 256
				o += d[j:j + 4 + size]
				j += 4 + size
			elif t == 0x07:
				o += d[j:j + 2 + n]
				j += 2 + n
			elif t == 0x02:
				o += b'\x04\x01\x00'
				break
			else:
				sys.exit('%s: block type %02X' % (path, t))
	o += b'\x02\x02\x00\x00'
	for k, (isam, tra, f) in enumerate(entries):
		p = starts[f]
		o[dirpos + 8 * k:dirpos + 8 * k + 8] = bytes([0x08, 0x06, isam,
			tra & 0xFF, tra >> 8, (p >> 8) & 0xFF, p >> 16, p & 0xFF])
	open(out, 'wb').write(o)


if __name__ == '__main__':
	build(*sys.argv[1:4])
