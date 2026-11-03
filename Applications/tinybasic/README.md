# Palo Alto Tiny BASIC for Fuzix

`tbasic` is an implementation of Palo Alto Tiny BASIC, the language
Li-Chen Wang published in Dr. Dobb's Journal in 1976 and put in the public
domain. TRS-80 Level I BASIC was derived from it. This version is written
from scratch in Z80 assembler and talks to the Fuzix kernel directly, so
the whole program is under 3K and almost all of the 32K process is left
for BASIC (`SIZE` shows about 28K free on the Model II).

```
tbasic            start it
tbasic game.bas   load a program and run it
```

## The language

- Numbers are 16 bit integers. Variables are the letters `A` to `Z`;
  `@(n)` is an array that uses the free memory.
- Lines start with a number. Several statements on a line are separated
  by `;`.
- Keywords may be shortened with a full stop: `P.` is `PRINT`, `G.` is
  `GOTO`, `GOS.` is `GOSUB`, `N.` is `NEXT`, `IN.` is `INPUT`. Typed at the
  prompt `L.`, `N.` and `R.` are `LIST`, `NEW` and `RUN`.

| Statement                    | Meaning                                    |
|------------------------------|--------------------------------------------|
| `LET A=1` or `A=1`           | assignment, also `A=1, B=2`                |
| `PRINT "A=", A, #3, B,`      | `,` between items, `#n` sets the width of numbers, a `,` at the end stays on the line |
| `INPUT A, 'NAME'N`           | the input may be an expression             |
| `IF A>B PRINT "X"`           | the rest of the line runs if true (`THEN` is allowed) |
| `GOTO 100`, `GOSUB 100`, `RETURN` | the line number may be an expression |
| `FOR I=1 TO 10 STEP 2` ... `NEXT I` |                                     |
| `REM`, `STOP`                |                                            |
| `LIST [n]`, `RUN`, `NEW`     |                                            |
| `SAVE "file"`, `LOAD "file"`, `BYE` | Fuzix additions                     |

Operators: `+ - * /` and the relations `= # > < >= <=` (`#` and `<>` are
not equal), which give 1 or 0. Functions: `RND(n)` (1 to n), `ABS(n)` and
`SIZE` (free memory).

Errors: `WHAT?` (not understood), `HOW?` (cannot be done, for instance
an overflow or a missing line) and `SORRY` (out of memory), followed by
the line with a `?` where it went wrong. Ctrl-C stops a running program
with `BREAK`.

```
10 PRINT "GUESS A NUMBER FROM 1 TO 100"
20 N=RND(100); T=0
30 INPUT 'YOUR GUESS'G; T=T+1
40 IF G<N PRINT "HIGHER"; GOTO 30
50 IF G>N PRINT "LOWER"; GOTO 30
60 PRINT "RIGHT IN ", T, " GUESSES"
```
