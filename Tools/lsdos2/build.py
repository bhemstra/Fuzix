#!/usr/bin/env python3
#
#	build.py [--lsdos DIR] [--zmac ZMAC] [--out IMAGE]
#
#	Build a TRS-80 Model II hard disk image that boots LS-DOS 6.3.1
#	from the hard disk boot ROM, from Michel Bernard's (GmEsoft) LS-DOS
#	6.3.1 Level N sources for the Model II, assembled with George
#	Phillips' zmac. Both are fetched into work/ when not given.
#
#	The sources are copied into work/src with Unix line ends and a few
#	changes (EDITS below): the hard disk driver HDDVR2/ASM in lowcore,
#	drive 0 the hard disk, floppies as :1 and :2, and some spellings
#	zmac does not take. Then:
#
#	BOOT/SYS (lowcore), SYS0-SYS13, SYS6-8 built from the library
#	commands like BLDLIBS/CMD does, the utilities, the hard disk loader
#	HDBOOT2/ASM, and mklsdos.py puts it all on the disk.
#
import argparse, os, re, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOP = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)

LSDOS_URL = 'https://github.com/GmEsoft/TRS80_M2_LSDOS631N'
ZMAC_URL = 'https://github.com/gp48k/zmac'

# (file, old, new[, 'all']): every old text must be there
EDITS = [
	# zmac: no COM (comment record) pseudo-op
	('copycom.asm', "\tCOM\t'<(C) 1982-4,6,90 MISOSYS>'", "; COM '<(C) 1982-4,6,90 MISOSYS>'"),
	('copycom.asm', "\tCOM\t'<*(C) 1986,LSI>'", "; COM '<*(C) 1986,LSI>'"),
	# a colon for a semicolon
	('sys3.asm', "\tELSE\t\t\t:<--> Before", "\tELSE\t\t\t;<--> Before"),
	# NUL is an operator in zmac (and the symbol is not used)
	('svcequ.asm', "NUL\tEQU\t0\t", ";NUL\tEQU\t0\t"),
	# the build switches
	('buildver.asm', "@DOSVER", "@HD\tEQU\t-1\t\t; Drive 0 is the hard disk\n"
		"HDDIR\tEQU\t1\t\t; its directory cylinder\n@DOSVER"),
	# drive 0 the hard disk, physical floppy 0 and 1 as :1 and :2
	('lowcore.asm', """	IF	@MOD2
	JP	FDCDVR		;Floppy drive 0
	DB	22H,0C1H,0,76,29,3-1<5+10-1,38	;3=grans/trk; 10=sects/gran

	JP	FDCDVR		;Floppy drive 1
	DB	62H,42H,76,76,29,3-1<5+10-1,38

	RET
	DW	FDCDVR		;Floppy drive #2
	DB	62H,44H,76,76,29,3-1<5+10-1,38
""", """	IF	@MOD2
	 IF	@HD
	JP	HDDVR		;Hard disk (fixed): 202 cylinders of 4 heads
	DB	0CH,10H,0,201,4-1<5+32-1,8-1<5+16-1,HDDIR
	JP	FDCDVR		;Floppy drive 0 as :1
	DB	62H,41H,76,76,29,3-1<5+10-1,38
	 ELSE
	JP	FDCDVR		;Floppy drive 0
	DB	22H,0C1H,0,76,29,3-1<5+10-1,38	;3=grans/trk; 10=sects/gran
	 ENDIF

	JP	FDCDVR		;Floppy drive 1
	DB	62H,42H,76,76,29,3-1<5+10-1,38

	 IFEQ	@HD,0
	RET
	DW	FDCDVR		;Floppy drive #2
	DB	62H,44H,76,76,29,3-1<5+10-1,38
	 ENDIF
"""),
	('lowcore.asm', "*GET\tFDCDVR2\t\t\t;Floppy disk driver (Model II)\n\tENDIF",
		"*GET\tFDCDVR2\t\t\t;Floppy disk driver (Model II)\n\t IF\t@HD\n"
		"*GET\tHDDVR2\t\t\t;Hard disk driver (Model II)\n\t ENDIF\n\tENDIF"),
	('lowcore.asm', "\tIF\t1\t\t;Model 2 garbage ", "\tIFEQ\t@HD,0\t\t;Model 2 garbage "),
	# SYSINIT sets up DCT 0 from what the floppy boot sector found
	('sysinit4.asm', "\tLD\tA,(BOOTST$)\t;Get boot step rate\n",
		"\tIFEQ\t@HD,0\t\t;Not for the hard disk\n\tLD\tA,(BOOTST$)\t;Get boot step rate\n"),
	('sysinit4.asm', "\tLD\t(DCT$+5),A\t;  track position of head\n",
		"\tLD\t(DCT$+5),A\t;  track position of head\n\tENDIF\n"),
	('sysinit4.asm', "\tIF\t@MOD2\n\tLD\tA,(DIRCYL$)\n",
		"\tIF\t@MOD2\n\tIFEQ\t@HD,0\t\t;Not for the hard disk\n\tLD\tA,(DIRCYL$)\n"),
	('sysinit4.asm', "\tLD\t(0476H),A\t;Store MAXCYL in DCT0\n\tENDIF\n",
		"\tLD\t(0476H),A\t;Store MAXCYL in DCT0\n\tENDIF\n\tENDIF\n"),
	# LIST is a pseudo-op in zmac
	('libcmds/lblist.asm', "\tCALL\tLIST\n", "\tCALL\tLISTF\n"),
	('libcmds/lblist.asm', "\nLIST\tCALL\tRESKFL", "\nLISTF\tCALL\tRESKFL"),
	# LORG (load origin) is PHASE in zmac
	('utils/format.asm', "\tORG\t4300H\t\t; Execute at ROM boot\n\tLORG\tCORE$\t\t;   but load here\n",
		"\tORG\tCORE$\t\t; Load here\n\tPHASE\t4300H\t\t;   but execute at ROM boot\n"),
	('utils/format.asm', "\tORG\tCORE$+256\n\tLORG\tCORE$+256\n", "\tDEPHASE\n\tORG\tCORE$+256\n"),
	('utils/backup.asm', "\tORG\tBACKUP\t\t; Set for MIRROR exec\nMIRBU\tEQU\tCORE$\n\tLORG\tMIRBU\t\t; Load origin\n",
		"MIRBU\tEQU\tCORE$\n\tORG\tMIRBU\t\t; Load origin\n\tPHASE\tBACKUP\t\t; Set for MIRROR exec\n"),
	('utils/backup.asm', "\tORG\tBACKUP\n;\nCLSBU\tEQU\tCORE$+MIRSIZ\n\tLORG\tCLSBU\n",
		"\tDEPHASE\nCLSBU\tEQU\tCORE$+MIRSIZ\n\tORG\tCLSBU\n\tPHASE\tBACKUP\n"),
	('utils/backup3.asm', "\tORG\t$<-8+1<+8\n;\nHITBUF\tDS\t256", "\tDS\t$<-8+1<+8-$\n;\nHITBUF\tDS\t256"),
	('utils/backup3.asm', "\tORG\tCORE$+MIRSIZ+CLSSIZ\n\tLORG\t$\t\t; No offset here\n",
		"\tDEPHASE\n\tORG\tCORE$+MIRSIZ+CLSSIZ\n"),
	('utils/diskcopy.asm', "\tDC\t11,-18", "\tDC\t11,0EEH"),
	('utils/memdisk.asm', "(IX+0FFH)", "(IX-1)", 'all'),
	('utils/com.asm', "CLDATA$\tDB\t0", "\tDB\t0"),
]

NOTICE = '''LS-DOS 6.3.1 for the TRS-80 Model II, booting from hard disk.

Roy Soltoff holds the copyright to the software and documentation in
the list below; notices that name other authors are outdated. Roy
grants free permission to everyone to download and use this software
and documentation and to redistribute it to others, provided this
notice is retained. All other rights are reserved.

(The list: the MISOSYS software on Tim Mann's web page, LS-DOS 6.3.1
among it.)

Copyright 1982-1984, 1986, 1990 by MISOSYS, Inc.
Typed in (and enhanced) by Pete Cervasio. Changes are copyright
1997-98 Peter W. Cervasio. Permission to do whatever you want with my
changes is granted, as long as my copyright notice is left intact.

Model II build, level N: Michel Bernard (GmEsoft),
https://github.com/GmEsoft/TRS80_M2_LSDOS631N

Hard disk driver, loader and disk layout: Tools/lsdos2 in
https://github.com/bhemstra/Fuzix
'''

LIBCMDS = ('lbmemory lbdir lbcopy lblib lbremove lbrename lbdevice lbroute '
	'lblink lbreset lbset lblist lbdo lbload lbfree lbdate lbdebug lbattrib '
	'lbpurge lbdump lbcreate lbauto lbbuild lbsystem lbsysgen lbforms '
	'lbsetcom lbsetki lbspool').split()

UTILS = [('backup', 'BACKUP/CMD'), ('format', 'FORMAT/CMD'),
	('diskcopy', 'DISKCOPY/CMD'), ('patch', 'PATCH/CMD'),
	('repair', 'REPAIR/CMD'), ('log', 'LOG/CMD'), ('comm', 'COMM/CMD'),
	('dateconv', 'DATECONV/CMD'), ('help', 'HELP/CMD'),
	('memdisk', 'MEMDISK/DCT'), ('com', 'COM/DVR'), ('click', 'CLICK/FLT'),
	('forms', 'FORMS/FLT'), ('ksm', 'KSM/FLT')]


def run(*cmd, **kw):
	subprocess.run(cmd, check=True, **kw)


def fetch(args, work):
	if not args.lsdos:
		args.lsdos = os.path.join(work, 'TRS80_M2_LSDOS631N')
		if not os.path.isdir(args.lsdos):
			run('git', 'clone', '-q', '--depth', '1', LSDOS_URL, args.lsdos)
	if not args.zmac:
		d = os.path.join(work, 'zmac')
		args.zmac = os.path.join(d, 'src', 'zmac')
		if not os.path.isfile(args.zmac):
			if not os.path.isdir(d):
				run('git', 'clone', '-q', '--depth', '1', ZMAC_URL, d)
			run('make', '-s', '-C', os.path.join(d, 'src'), 'zmac')


def prepare(srcdir, dst):
	"""Copy the sources with LF line ends, apply EDITS, add ours. zmac
	looks for *GET NAME as NAME.asm, so each file also gets an upper
	case name."""
	if os.path.isdir(dst):
		shutil.rmtree(dst)
	for root, _, files in os.walk(srcdir):
		rel = os.path.relpath(root, srcdir)
		if rel not in ('.', 'libcmds', 'utils'):
			continue
		os.makedirs(os.path.join(dst, rel), exist_ok=True)
		for f in files:
			if f.lower().endswith('.asm'):
				t = open(os.path.join(root, f), 'rb').read().replace(b'\r\n', b'\n').replace(b'\r', b'\n')
				open(os.path.join(dst, rel, f.lower()), 'wb').write(t)
	for f in ('hddvr2.asm', 'hdboot2.asm'):
		shutil.copy(os.path.join(HERE, f), dst)
	for path, old, new, *all in EDITS:
		p = os.path.join(dst, path)
		s = open(p).read()
		if old not in s:
			sys.exit('%s: text to change not found:\n%s' % (path, old))
		open(p, 'w').write(s.replace(old, new, -1 if all else 1))
	# Each directory sees all the top level sources, by both names
	for rel in ('.', 'libcmds', 'utils'):
		d = os.path.join(dst, rel)
		for f in sorted(os.listdir(dst)):
			if not f.endswith('.asm'):
				continue
			if rel != '.' and not os.path.exists(os.path.join(d, f)):
				os.symlink(os.path.join('..', f), os.path.join(d, f))
		for f in sorted(os.listdir(d)):
			if f.endswith('.asm') and f == f.lower():
				u = f[:-4].upper() + '.asm'
				if not os.path.exists(os.path.join(d, u)):
					os.symlink(f, os.path.join(d, u))


def mkequ(lst, out):
	"""The equates of a listing's symbol table, as XREF (EQU) makes them"""
	t = open(lst, errors='replace').read().split('Symbol Table:')[1]
	with open(out, 'w') as o:
		for line in t.splitlines():
			m = re.match(r'^(\S+)\s+=?\s*([0-9A-Fa-f]+)\s+(-?\d+)\s*$', line)
			if m and m.group(1)[0] not in '?$':
				o.write('%s\tEQU\t%s\n' % (m.group(1), m.group(3)))
		o.write('\tEND\n')


def assemble(zmac, d, name, equs):
	"""Assemble d/name.asm into d/out/name.cmd (and .cim, .lst). The
	.EQU files go next to it; symbols the module defines itself are
	dropped from them (MRAS allows those, zmac does not)."""
	out = os.path.join(d, 'out')
	os.makedirs(out, exist_ok=True)
	eq = {e: open(e).read().splitlines() for e in equs}
	for _ in range(10):
		for e, lines in eq.items():
			open(os.path.join(d, os.path.basename(e)), 'w').write('\n'.join(lines) + '\n')
		r = subprocess.run([zmac, '--mras', '-o', 'out/%s.cmd' % name, '-o', 'out/%s.cim' % name,
			'-o', 'out/%s.lst' % name, name + '.asm'], cwd=d, capture_output=True, text=True)
		if r.returncode == 0:
			return os.path.join(out, name)
		err = (r.stdout + r.stderr).splitlines()
		dropped = False
		for i, l in enumerate(err[:-1]):
			if 'Mult. def.' not in l or not err[i + 1].strip():
				continue
			sym = err[i + 1].split()[0]
			where = l.split('(')[0]
			# Defined in an .EQU file again: drop it from that one,
			# defined in the module: drop it from all of them
			for e in eq:
				if where.endswith('.EQU') and os.path.basename(e) != where:
					continue
				n = len(eq[e])
				eq[e] = [x for x in eq[e] if x.split('\t')[0] != sym]
				dropped |= len(eq[e]) != n
		if not dropped:
			sys.exit('%s/%s.asm:\n%s' % (d, name, '\n'.join(err[:20])))
	sys.exit(name + ': too many duplicate symbols')


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument('--lsdos', help='TRS80_M2_LSDOS631N checkout')
	ap.add_argument('--zmac', help='zmac binary')
	ap.add_argument('--out', default=os.path.join(TOP, 'Images', 'trs80m2', 'lsdos2-0.hdv'))
	args = ap.parse_args()
	work = os.path.join(HERE, 'work')
	os.makedirs(work, exist_ok=True)
	fetch(args, work)
	src = os.path.join(work, 'src')
	prepare(os.path.join(args.lsdos, 'LSDOS631N_M2', 'lsdos631'), src)
	z = os.path.abspath(args.zmac)
	equ = lambda n: os.path.join(work, n + '.EQU')

	lowcore = assemble(z, src, 'lowcore', [])
	mkequ(lowcore + '.lst', equ('LOWCORE'))
	sysres = assemble(z, src, 'sysres', [equ('LOWCORE')])
	mkequ(sysres + '.lst', equ('SYSRES'))
	eqs = [equ('LOWCORE'), equ('SYSRES')]
	files = [('SYS0/SYS', sysres + '.cmd')]
	for n in (1, 2, 3, 4, 5):
		files.append(('SYS%d/SYS' % n, assemble(z, src, 'sys%d' % n, eqs) + '.cmd'))
	mkequ(os.path.join(src, 'out', 'sys5.lst'), equ('SYS5'))
	eqs.append(equ('SYS5'))
	for n in (9, 10, 11, 12, 13):
		files.append(('SYS%d/SYS' % n, assemble(z, src, 'sys%d' % n, eqs) + '.cmd'))
	boot = assemble(z, src, 'hdboot2', [equ('LOWCORE')])

	lib = os.path.join(src, 'libcmds')
	for n in LIBCMDS:
		assemble(z, lib, n, eqs)
	import mklib
	other = os.path.join(args.lsdos, 'LSDOS631N_M2', 'lsdos631', 'other')
	for n in (6, 7, 8):
		f = os.path.join(src, 'out', 'sys%d.sys' % n)
		mklib.build(f, os.path.join(other, 'l631lib%d.dat' % n), os.path.join(lib, 'out'))
		files.append(('SYS%d/SYS' % n, f))
	ut = os.path.join(src, 'utils')
	for n, fname in UTILS:
		files.append((fname, assemble(z, ut, n, eqs) + '.cmd'))

	# The permission to redistribute LS-DOS asks for its notice to go along
	notice = os.path.join(work, 'notice.txt')
	open(notice, 'wb').write(NOTICE.replace('\n', '\r').encode())
	files.append(('NOTICE/TXT', notice))

	import mklsdos
	os.makedirs(os.path.dirname(args.out), exist_ok=True)
	mklsdos.build(args.out, os.path.join(TOP, 'Kernel', 'platform', 'platform-trs80m2', 'xtrsheader'),
		lowcore + '.cim', sysres + '.cmd', boot + '.cim', files)
	print('wrote', args.out)


main()
