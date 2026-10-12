#!/usr/bin/env python3
"""Run focused host checks against actual kernel function bodies and constants."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

CASES = ['raw-input', 'raw-empty', 'raw-minimum', 'canonical-partial', 'canonical-line', 'canonical-eof', 'wrapped-line', 'immediate-empty', 'timed-empty']
VARIANTS = [('default', [])]


def function(text, name, variant):
    matches = list(re.finditer(r'(?m)^[\w *\t]+\b' + re.escape(name) +
                              r'\s*\([^;{}]*\)\s*\{', text))
    occurrence = int(variant) if variant.isdigit() else (1 if variant == 'inline' and len(matches) > 1 else 0)
    if variant == 'optional' and not matches: return ''
    match = matches[occurrence]
    masked = re.sub(r'/\*[\s\S]*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',
                    lambda m: ' ' * len(m.group()), text)
    depth = 0
    for position in range(text.index('{', match.start()), len(text)):
        if masked[position] == '{':
            depth += 1
        elif masked[position] == '}':
            depth -= 1
            if not depth:
                return text[match.start():position + 1] + '\n'
    raise ValueError('unterminated function: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kernel-dir', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--cc', default=os.environ.get('CC', 'cc'))
    args = parser.parse_args()
    kernel = args.kernel_dir.resolve()
    headers = '\n'.join((kernel/'include'/name).read_text() for name in ['kernel.h','tty.h','level2.h'])
    fixture = Path(__file__).with_name('check.c').read_text()
    def define(match):
        name = match.group(1)
        value = re.search(r'(?m)^#define\s+' + re.escape(name) + r'(?:\s|\()[^\n]*', headers)
        if value is None:
            raise ValueError('missing kernel constant: ' + name)
        return '#undef ' + name + '\n' + value.group()
    fixture = re.sub(r'/\* DEFINE (\w+) \*/', define, fixture)
    fixture = fixture.replace('/* NICE_FIELD */', re.search(r'(?:u?int8_t)\s+p_nice;', headers).group())
    masks = re.search(r'static const uint16_t stopper =[\s\S]*?static const uint16_t clear =[\s\S]*?;', (kernel/'process.c').read_text()).group()
    fixture = fixture.replace('/* SIGNAL_MASKS */', masks)
    failed = False
    with tempfile.TemporaryDirectory(prefix='fuzix-core-test-') as directory:
        directory = Path(directory)
        for label, flags in VARIANTS:
            def body(match):
                file, name, variant = match.groups()
                if variant == 'configured':
                    variant = 'external' if '-DCONFIG_BLKBUF_EXTERNAL' in flags else 'inline'
                return function((kernel/file).read_text(), name, variant)
            source = re.sub(r'/\* FUNCTION ([\w./-]+) (\w+) (\w+) \*/', body, fixture)
            if '/* TYPES */' in source:
                # Use real inode and select-map layouts to catch metadata overruns.
                types = []
                types.append(re.search(r'struct selmap \{[\s\S]*?\};', headers).group())
                for name in ['dinode','cinode']:
                    types.append(re.search(r'typedef struct ' + name + r' \{[\s\S]*?\}[^;]+;', headers).group())
                source = source.replace('/* TYPES */', '\n'.join(types))
                if 'c_select' in types[-1]:
                    source = '#define HAS_SELECT_STORAGE\n' + source
            cfile = directory/(label+'.c')
            binary = directory/label
            cfile.write_text(source)
            build = subprocess.run([args.cc,'-std=c99','-g','-Wall','-Wextra',
                                    '-Wno-unused-parameter','-Wno-unused-variable','-Wno-sign-compare',
                                    '-fsanitize=address,undefined',*flags,
                                    '-I'+str(kernel/'include'),str(cfile),'-o',str(binary)])
            if build.returncode:
                failed = True
                print('COMPILE FAIL ' + label, flush=True)
                continue
            for case in CASES:
                result = subprocess.run([str(binary),case],timeout=5,
                                        env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0'))
                passed = result.returncode == 0
                print(('PASS ' if passed else 'FAIL ') + label + ' ' + case,flush=True)
                failed |= not passed
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
