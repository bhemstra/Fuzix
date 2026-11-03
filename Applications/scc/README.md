# scc - a small C compiler that runs on Fuzix

The Fuzix C compiler (fcc) is a cross compiler: its phases need more than
the 32K a process gets on the TRS-80 Model 4 and Model II. scc is a
compiler for a large subset of C that is small enough to run on the
machine itself. Its output links with the normal Fuzix C library.

```
cc -o hello hello.c
cc -c part1.c part2.c
cc -o prog part1.o part2.o -lcurses
```

## How it works

| Program        | Job                                                     |
|----------------|---------------------------------------------------------|
| `/usr/bin/cc`  | driver: runs the stages below in turn                   |
| `/usr/lib/scc0`| preprocessor and tokenizer: tokens and a names file     |
| `/usr/lib/scc1`| front end: declarations, types, expressions, statements |
| `/usr/lib/scc2`| code generator: Z80 code, writes the object file        |
| `/usr/bin/sld` | linker: object files and libraries to a Fuzix program   |

The stages pass temporary files (`x.o~t`, `x.o~n`, `x.o~1` to `x.o~3`)
so each one only needs part of the memory. Identifiers are numbered by
scc0, so the front end does not keep their text. The objects are in the
Fuzix (Bintools) object format and follow the Fuzix compiler ABI, so they
link with `libc.a`, `libcurses.a` and code compiled with fcc. sld links
`crt0.o`, `sccrt.o` (helpers for multiply, divide, shifts, switch), the
libraries and `libz80.a` (helpers the C library needs).

sld gives the same result as the Fuzix linker followed by `reloc`, but
reads the objects again for each pass so it fits in 32K.

## What is supported

- `char` (unsigned), `signed char`, `short`, `int`, `unsigned`, pointers,
  arrays (also several dimensions), `struct`, `union`, `enum`, `typedef`,
  function pointers, `const`/`volatile` (ignored)
- all statements, including `switch`, `goto` and labels
- all operators except those below, with constant folding
- initializers for globals and statics (also arrays and structs);
  scalar initializers for locals
- old style (K&R) function definitions
- the preprocessor: `#include`, `#define` with parameters, `#` and `##`,
  `#if`/`#elif` with `defined`, `#ifdef`, `#undef`, `__LINE__`, `__FILE__`

## Not supported

- `long`, `float` and `double` in expressions (they can be declared, so
  the system headers work, and `sizeof` knows them)
- passing, returning or assigning structs by value (use pointers)
- initializers for local arrays and structs, bit fields
- `-E` (there is no separate preprocessor output)

Limits: 4K of code per function, 256 labels per function, 64 locals in
scope, about a dozen system headers per source file.

## Tests

`tests/` holds test programs: each returns 0 when everything is right.
They were run with the Fuzix compiler kit Z80 emulator, and the compiler
was tested on the Model II simulator (`Tools/m2sim`) compiling and running
a program with `stdio`, `malloc` and structs.
