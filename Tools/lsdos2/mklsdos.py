#!/usr/bin/env python3
#
#	mklsdos.py out.hdv header lowcore.cim sys0.cmd hdboot2.cim \
#		[NAME/EXT=file ...]
#
#	(build.py calls build() with the same arguments.)
#
#	Build a TRS-80 Model II hard disk image (.hdv) that boots LS-DOS
#	6.3.1 from the hard disk boot ROM.
#
#	The drive: 101 cylinders, 8 heads, 32 sectors of 512 bytes. LS-DOS
#	(see HDDVR2/ASM) sees 202 cylinders of 4 heads x 32 sectors of 256
#	bytes, each the first half of a physical sector; 8 granules of 16
#	sectors per cylinder. Cylinder 0 is the boot area (BOOT/SYS),
#	cylinder 1 the directory.
#
#	Files named SYSn/SYS go to their fixed system directory slots,
#	other files after them.
#
import sys, time

PCYL, HEADS, SPT, PSEC = 101, 8, 32, 512
LCYL = 2 * PCYL				# LS-DOS cylinders
LSPC = 128				# LS-DOS sectors per cylinder
GPC, SPG = 8, 16			# granules per cylinder, sectors per granule
DIRCYL = 1
DIRSECS = 32				# directory record sectors (2-33)


def poff(cyl, head, sec):
	return 256 + ((cyl * HEADS + head) * SPT + sec) * PSEC


def loff(cyl, sec):
	"""File offset of LS-DOS sector sec of LS-DOS cylinder cyl"""
	return poff(cyl >> 1, (cyl & 1) * 4 + (sec >> 5), sec & 31)


def namehash(name11):
	a = 0
	for c in name11:
		a ^= c
		a = ((a << 1) | (a >> 7)) & 0xFF
	return a or 1


def pwhash(pw):
	"""SYS2 HASHPSWD, step by step"""
	pw = (pw.upper() + ' ' * 8)[:8].encode()
	hl = 0xFFFF
	for c in reversed(pw):
		d, e = c, hl >> 8
		l = hl & 0xFF
		a = l & 7
		a = ((a >> 3) | (a << 5)) & 0xFF	# RRCA x3
		a ^= l
		hl = (a << 4) & 0xFFFF			# L = A, H = 0, HL << 4
		a ^= hl >> 8				# XOR H
		a ^= d
		d = a
		a = hl & 0xFF				# LD A,L
		hl = (hl << 1) & 0xFFFF
		a ^= hl >> 8
		a ^= e
		e = a
		hl = (d << 8) | e
	return hl


def cmdblocks(data):
	"""Load blocks and entry point of a /CMD file"""
	i, blocks, entry = 0, [], None
	while i < len(data):
		t, n = data[i], data[i + 1]
		if t == 1:
			if n < 3:
				n += 256
			blocks.append((data[i + 2] | data[i + 3] << 8, data[i + 4:i + 2 + n]))
			i += 2 + n
		elif t == 2:
			entry = data[i + 2] | data[i + 3] << 8
			break
		else:
			i += 2 + (n or 256)
	return blocks, entry


def name11(fname):
	n, _, e = fname.upper().partition('/')
	return (n.ljust(8)[:8] + e.ljust(3)[:3]).encode()


SYSDEC = {'BOOT/SYS': 0x00, 'DIR/SYS': 0x01}
for n in range(6):
	SYSDEC['SYS%d/SYS' % n] = 2 + n
for n in range(6, 14):
	SYSDEC['SYS%d/SYS' % n] = 0x20 + n - 6


def build(out, header, cimf, sys0f, bootf, files):
	img = bytearray(open(header, 'rb').read(256).ljust(256, b'\0'))
	img += bytes(PCYL * HEADS * SPT * PSEC)

	# Boot area: the loader, memory 0000-23FF and the video memory
	mem = bytearray(0x2400)
	cim = open(cimf, 'rb').read()
	mem[0x200:0x200 + len(cim)] = cim[:0x2400 - 0x200]
	video = bytearray(b' ' * 0x800)
	blocks, entry = cmdblocks(open(sys0f, 'rb').read())
	assert entry == 0x1E00, 'SYS0 entry %04X' % entry
	for a, d in blocks:
		if a + len(d) <= 0x2400:
			mem[a:a + len(d)] = d
		elif a >= 0xF800:
			video[a - 0xF800:a - 0xF800 + len(d)] = d
		else:
			sys.exit('SYS0 block at %04X does not fit' % a)
	boot = open(bootf, 'rb').read()
	assert len(boot) <= 512
	img[poff(0, 0, 8):poff(0, 0, 8) + len(boot)] = boot
	img[poff(0, 0, 9):poff(0, 0, 9) + len(mem)] = mem
	img[poff(0, 0, 27):poff(0, 0, 27) + len(video)] = video
	img[poff(0, 0, 1) + 2] = DIRCYL		# where @RDSSC looks

	# Directory
	gat = bytearray(256)
	for c in range(0xCB):
		gat[c] = 0x00 if c < LCYL else 0xFF
	gat[0] = gat[DIRCYL] = 0xFF
	hit = bytearray(256)
	dirsec = [bytearray(256) for _ in range(DIRSECS)]
	blank = pwhash('')
	assert blank == 0x4296, hex(blank)

	def entry(dec, name, attr, ern, eof, extents, owner=0x71F4, user=0):
		e = bytearray(32)
		e[0] = attr
		e[3] = eof
		e[5:16] = name11(name)
		e[16:18] = owner.to_bytes(2, 'little')
		e[18:20] = user.to_bytes(2, 'little')
		e[20:22] = ern.to_bytes(2, 'little')
		ext = b''.join(bytes(x) for x in extents)
		e[22:30] = ext.ljust(8, b'\xff')
		e[30:32] = b'\xff\xff'
		dirsec[dec & 0x1F][dec & 0xE0:(dec & 0xE0) + 32] = e
		hit[dec] = namehash(name11(name))

	entry(0x00, 'BOOT/SYS', 0x5E, LSPC, 0, [(0, GPC - 1)])
	entry(0x01, 'DIR/SYS', 0x5D, DIRSECS + 2, 0, [(DIRCYL, GPC - 1)],
		user=blank)

	nextg = [2 * GPC]			# next free granule (cylinder 2)
	userdec = [d for d in range(256)
		if (d & 0x1F) < DIRSECS and d not in SYSDEC.values()]

	def store(name, data, dec, attr, owner):
		nsec = (len(data) + 255) // 256
		ngran = max(1, (nsec + SPG - 1) // SPG)
		g = nextg[0]
		nextg[0] += ngran
		assert nextg[0] <= LCYL * GPC, 'disk full'
		extents, left, gg = [], ngran, g
		while left:
			n = min(left, 32)
			extents.append((gg // GPC, (gg % GPC) << 5 | (n - 1)))
			gg += n
			left -= n
		assert len(extents) <= 4, name + ' too big'
		for i in range(ngran * SPG):
			gr = g + i // SPG
			c, s = gr // GPC, (gr % GPC) * SPG + i % SPG
			gat[c] |= 1 << (gr % GPC)
			o = loff(c, s)
			img[o:o + 256] = data[i * 256:(i + 1) * 256].ljust(256, b'\0')
		entry(dec, name, attr, nsec, len(data) & 0xFF, extents, owner, 0)

	for name, path in files:
		name = name.upper()
		data = open(path, 'rb').read()
		if name in SYSDEC:
			store(name, data, SYSDEC[name], 0x5E, 0x71F4)
		else:
			store(name, data, userdec.pop(0), 0x10, blank)

	gat[0xCC] = LCYL - 1 - 0x22		# cylinders beyond 35
	gat[0xCD] = 0x08 | (GPC - 1)		# system disk, new dates
	gat[0xCE:0xD0] = pwhash('PASSWORD').to_bytes(2, 'little')
	gat[0xD0:0xD8] = b'LSDOS-HD'
	gat[0xD8:0xE0] = time.strftime('%m/%d/%y').encode()
	gat[0xE0] = 0x0D			# no AUTO command
	gat[0xF5:0xF9] = b'\x03631'
	gat[0xF9:0x100] = bytes([0x0C, 0x10, 0, LCYL - 1, 0x7F, 0xEF, DIRCYL])

	o = loff(DIRCYL, 0)
	img[o:o + 256] = gat
	o = loff(DIRCYL, 1)
	img[o:o + 256] = hit
	for i, d in enumerate(dirsec):
		o = loff(DIRCYL, 2 + i)
		img[o:o + 256] = d
	open(out, 'wb').write(img)


if __name__ == '__main__':
	build(*sys.argv[1:6], [a.split('=', 1) for a in sys.argv[6:]])
