;
;	Palo Alto Tiny BASIC for Fuzix (Z80)
;
;	A new implementation of the language Li-Chen Wang published in
;	1976 (Dr. Dobb's Journal, public domain): 16 bit integers, the
;	variables A-Z, one array @(n), and
;
;	LIST [n]  RUN  NEW
;	LET  PRINT  INPUT  IF  GOTO  GOSUB  RETURN  FOR TO STEP  NEXT
;	REM  STOP
;	RND(n)  ABS(n)  SIZE
;	relations  >=  #  >  =  <=  <  (also <>), true is 1
;
;	Statements on a line are separated by ";". Keywords may be cut
;	short with a full stop: P. for PRINT, G. for GOTO, GOS. for GOSUB.
;	PRINT takes items separated by ",", #n sets the width of the
;	numbers that follow, a "," at the end leaves the line open.
;	Errors are WHAT? (cannot understand), HOW? (cannot do) and SORRY
;	(no memory), followed by the line with a ? where it went wrong.
;
;	For Fuzix there is also SAVE "file", LOAD "file" and BYE, Ctrl-C
;	stops a running program, IF allows a THEN and "tbasic file" loads
;	and runs a program.
;
;	It talks to the kernel directly instead of using the C library, so
;	it stays small. The program starts with its own Fuzix header and
;	relocates itself like crt0 does.
;
;	Register use: DE points into the program text being read, HL holds
;	values.
;

		.code

		.export __text

__text:
		.word 0x80A8		; Fuzix executable
		.byte 1			; 8080 family
		.byte 2			; Z80
		.byte 0			; relocatable
		.byte 0
		.word __data		; code size
		.word __data_size
		.word __bss_size
		.byte 18		; entry point
		.byte 0
		.byte 0
		.byte 0
		.word sigvec		; signal handler

;
;	Entry: DE is the (page aligned) load address. The relocation list
;	sits at the start of the BSS: each byte is a distance to the next
;	high byte to adjust, 255 skips 254 bytes, 0 ends it.
;
start:
		ld c,d
		ld hl,0
		add hl,de
		ld ix,__bss
		add ix,de
rel1:
		ld a,(ix+0)
		ld (ix+0),0
		inc ix
		or a
		jr z,rel3
		inc a
		jr z,rel2
		dec a
		ld e,a
		ld d,0
		add hl,de
		ld a,(hl)
		add a,c
		ld (hl),a
		jr rel1
rel2:
		ld de,254
		add hl,de
		jr rel1
rel3:
		ld (stkbase),sp
		ld hl,-768		; room for the stack (brk wants 512)
		add hl,sp
		ld (memtop),hl
		push hl
		ld a,30			; brk(memtop)
		call sys
		pop hl
		call setsig
		ld hl,1
		ld (seed),hl
		ld a,1
		ld (ofd),a
		ld hl,banner
		call pmsg
		call clrvar
		ld hl,__end
		ld (txtend),hl
		; tbasic file: load it and run it
		ld hl,(stkbase)
		ld a,(hl)
		dec a
		jp z,direct
		inc hl
		inc hl
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		inc hl
		inc hl
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		ld de,fname
		ld bc,31
		ldir
		ld hl,dorun
		push hl
		jp doload

;
;	System calls: A is the number, the arguments are on the stack as
;	for a C call. Calling the start of the program enters the kernel.
;	The result is in HL, carry set on error. BC is kept.
;
sys:
		call __text
		ret

;	SIGINT: note it, the interpreter looks between statements
sigvec:
		push af
		ld a,1
		ld (brkflg),a
		pop af
		ret

setsig:
		push de
		ld hl,sigvec
		push hl
		ld hl,2			; SIGINT
		push hl
		ld a,35			; signal
		call sys
		pop hl
		pop hl
		pop de
		ret

;
;	Output, buffered
;
outc:
		push hl
		push de
		ld (lastc),a
		ld hl,onum
		ld e,(hl)
		inc (hl)
		ld d,0
		ld hl,obuf
		add hl,de
		ld (hl),a
		cp 10
		jr z,outc1
		ld a,e
		cp 63
		jr c,outc2
outc1:
		call flush
outc2:
		pop de
		pop hl
		ret

flush:
		push bc
		push de
		push hl
		ld a,(onum)
		or a
		jr z,fl1
		ld l,a
		ld h,0
		push hl
		ld hl,obuf
		push hl
		ld a,(ofd)
		ld l,a
		ld h,0
		push hl
		ld a,8			; write
		call sys
		pop hl
		pop hl
		pop hl
		xor a
		ld (onum),a
fl1:
		pop hl
		pop de
		pop bc
		ret

crlf:
		ld a,10
		jr outc

;	Print the 0 terminated message at HL
pmsg:
		ld a,(hl)
		or a
		ret z
		call outc
		inc hl
		jr pmsg

;	Print text at DE up to the quote in C (or the end of the line)
prtstr:
		ld a,(de)
		inc de
		cp 13
		jr z,ps1
		cp c
		ret z
		call outc
		jr prtstr
ps1:
		dec de
		ret

;	Print HL as a signed number, right aligned in C characters
prtnum:
		push de
		ld e,c
		ld d,0
		bit 7,h
		jr z,pn1
		ld d,'-'
		call neghl
		dec e
pn1:
		ld c,0
pn2:
		ld b,16
		xor a
pn3:
		add hl,hl
		rla
		cp 10
		jr c,pn4
		sub 10
		inc l
pn4:
		djnz pn3
		add a,'0'
		push af
		inc c
		dec e
		ld a,h
		or l
		jr nz,pn2
pn5:
		bit 7,e
		jr nz,pn6
		ld a,e
		or a
		jr z,pn6
		ld a,' '
		call outc
		dec e
		jr pn5
pn6:
		ld a,d
		or a
		call nz,outc
pn7:
		pop af
		call outc
		dec c
		jr nz,pn7
		pop de
		ret

;
;	Input: read a line into the buffer at HL after printing the prompt
;	character in A. Returns DE at the start, the line ends in CR and is
;	in upper case outside quotes.
;
getln:
		push hl
		call outc
		call flush
		pop hl
		push hl
		ld bc,79
		push bc
		push hl
		ld bc,0
		push bc
		ld a,7			; read
		call sys
		pop bc
		pop bc
		pop bc
		pop de
		jr c,glerr
		ld a,h
		or l
		jp z,bye		; end of input
		add hl,de
		dec hl
		ld a,(hl)
		cp 10
		jr z,gl1
		inc hl
gl1:
		ld (hl),13
		push de
		ex de,hl
		call upcase
		pop de
		ret
glerr:
		ld a,(brkflg)
		or a
		jp z,bye
		jp qbreak

;	Upper case the CR terminated line at HL, not inside quotes
upcase:
		ld b,0
uc1:
		ld a,(hl)
		cp 13
		ret z
		ld c,a
		ld a,b
		or a
		jr z,uc2
		ld a,c
		cp b
		jr nz,uc4
		ld b,0
		jr uc4
uc2:
		ld a,c
		cp '"'
		jr z,uc3
		cp 0x27
		jr z,uc3
		cp 'a'
		jr c,uc4
		cp 'z'+1
		jr nc,uc4
		sub 32
		ld (hl),a
		jr uc4
uc3:
		ld b,a
uc4:
		inc hl
		jr uc1

;
;	Text scanning
;
skipsp:
		ld a,(de)
		cp ' '
		ret nz
		inc de
		jr skipsp

;	call tstc / .byte c: Z and DE past it if the next character is c
tstc:
		call skipsp
		ex (sp),hl
		cp (hl)
		inc hl
		ex (sp),hl
		ret nz
		inc de
		ret

;	Carry set if A is not a digit
isdig:
		cp '0'
		ret c
		cp '9'+1
		ccf
		ret

;	A number at DE into HL, carry set if there is none
getnum:
		call skipsp
		call isdig
		ret c
		ld hl,0
gn1:
		ld a,(de)
		call isdig
		jr c,gn2
		push hl
		ld bc,3277
		or a
		sbc hl,bc
		pop hl
		jp nc,qhow
		ld b,h
		ld c,l
		add hl,hl
		add hl,hl
		add hl,bc
		add hl,hl
		ld a,(de)
		sub '0'
		add a,l
		ld l,a
		jr nc,gn3
		inc h
gn3:
		bit 7,h
		jp nz,qhow
		inc de
		jr gn1
gn2:
		or a
		ret

;
;	Keyword tables: the characters with bit 7 set on the last one,
;	then the address. The table ends with 0 and the default address.
;	A full stop in the text ends a keyword early (P. is PRINT).
;	dispatch jumps to the address with DE past the keyword.
;
dispatch:
		call skipsp
dp1:
		push de
		ld c,0
dp2:
		ld a,(hl)
		or a
		jr z,dpdef
		ld a,(de)
		cp '.'
		jr z,dpdot
		ld b,a
		ld a,(hl)
		and 0x7F
		cp b
		jr nz,dpnext
		inc de
		inc c
		bit 7,(hl)
		inc hl
		jr z,dp2
		jr dpgo
dpdot:
		ld a,c
		or a
		jr z,dpnext
		inc de
dpd1:
		bit 7,(hl)
		inc hl
		jr z,dpd1
dpgo:
		pop bc
dpjp:
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		jp (hl)
dpnext:
		bit 7,(hl)
		inc hl
		jr z,dpnext
		inc hl
		inc hl
		pop de
		jr dp1
dpdef:
		inc hl
		pop de
		jr dpjp

;
;	Expressions
;
expr:
		call expr2
		push hl
		ld hl,reltab
		jp dispatch
relnone:
		pop hl
		ret

;	Common part of the relations: compare the left value (on the
;	stack under our return address) with the next expression
rel:
		pop iy
		call expr2
		pop bc
		push iy
		; Signed compare of BC with HL: carry if less, zero if equal
scmp:
		ld a,b
		xor 0x80
		ld b,a
		ld a,h
		xor 0x80
		ld h,a
		ld a,b
		cp h
		ret nz
		ld a,c
		cp l
		ret

relge:
		call rel
		jr c,false
		jr true
relne:
		call rel
		jr z,false
		jr true
relgt:
		call rel
		jr z,false
		jr c,false
		jr true
releq:
		call rel
		jr nz,false
		jr true
relle:
		call rel
		jr z,true
		jr c,true
		jr false
rellt:
		call rel
		jr c,true
false:
		ld hl,0
		ret
true:
		ld hl,1
		ret

;	+ and -
expr2:
		call skipsp
		cp '-'
		jr z,ex2neg
		cp '+'
		jr nz,ex2a
		inc de
ex2a:
		call expr3
ex2l:
		call skipsp
		cp '+'
		jr z,ex2add
		cp '-'
		ret nz
		inc de
		push hl
		call expr3
		pop bc
ex2sub:
		push de
		ld d,b
		ld e,c
		ex de,hl
		or a
		sbc hl,de
		jp pe,qhow
		pop de
		jr ex2l
ex2add:
		inc de
		push hl
		call expr3
		pop bc
		or a
		adc hl,bc
		jp pe,qhow
		jr ex2l
ex2neg:
		inc de
		call expr3
		ld bc,0
		jr ex2sub

;	* and /
expr3:
		call factor
ex3l:
		call skipsp
		cp '*'
		jr z,ex3mul
		cp '/'
		ret nz
		inc de
		push hl
		call factor
		pop bc
		call div
		jr ex3l
ex3mul:
		inc de
		push hl
		call factor
		pop bc
		call mul
		jr ex3l

factor:
		ld hl,fntab
		jp dispatch
fnone:
		call getvar
		jr c,fn1
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		ret
fn1:
		call getnum
		ret nc
parexp:
		call tstc
		.byte '('
		jp nz,qwhat
		call expr
		call tstc
		.byte ')'
		jp nz,qwhat
		ret

fabs:
		call parexp
abshl:
		bit 7,h
		ret z
neghl:
		xor a
		sub l
		ld l,a
		sbc a,a
		sub h
		ld h,a
		ret

absbc:
		bit 7,b
		ret z
		xor a
		sub c
		ld c,a
		sbc a,a
		sub b
		ld b,a
		ret

fsize:
		ld hl,(memtop)
		ld bc,(txtend)
		or a
		sbc hl,bc
		ret

;	RND(n): 1 to n
frnd:
		call parexp
		ld a,h
		or l
		jp z,qhow
		bit 7,h
		jp nz,qhow
		push de
		push hl
		; xorshift (7, 9, 8)
		ld hl,(seed)
		ld a,h
		rra
		ld a,l
		rra
		xor h
		ld h,a
		ld a,l
		rra
		ld a,h
		rra
		xor l
		ld l,a
		xor h
		ld h,a
		ld (seed),hl
		res 7,h
		ld b,h
		ld c,l
		pop de
		call udiv
		inc hl
		pop de
		ret

;	BC * HL, HOW? on overflow
mul:
		push de
		ld a,b
		xor h
		push af
		call absbc
		call abshl
		ex de,hl
		ld hl,0
		ld a,16
ml1:
		add hl,hl
		jp c,qhow
		ex de,hl
		add hl,hl
		ex de,hl
		jr nc,ml2
		add hl,bc
		jp c,qhow
ml2:
		dec a
		jr nz,ml1
		bit 7,h
		jp nz,qhow
		pop af
		call m,neghl
		pop de
		ret

;	BC / HL
div:
		ld a,h
		or l
		jp z,qhow
		push de
		ld a,b
		xor h
		push af
		call absbc
		call abshl
		ex de,hl
		call udiv
		ld h,b
		ld l,c
		pop af
		call m,neghl
		pop de
		ret

;	Unsigned BC / DE: quotient in BC, remainder in HL
udiv:
		ld hl,0
		ld a,16
ud1:
		sla c
		rl b
		adc hl,hl
		or a
		sbc hl,de
		jr nc,ud2
		add hl,de
		jr ud3
ud2:
		inc c
ud3:
		dec a
		jr nz,ud1
		ret

;
;	Variables: the address of the variable at DE in HL, carry set if
;	there is none. A-Z, or @(n) which counts down from the top of
;	memory.
;
getvar:
		call skipsp
		cp '@'
		jr z,gv1
		sub 'A'
		ret c
		cp 26
		ccf
		ret c
		inc de
		ld l,a
		ld h,0
		add hl,hl
		ld bc,vars
		add hl,bc
		or a
		ret
gv1:
		inc de
		call parexp
		bit 7,h
		jp nz,qhow
		inc hl
		add hl,hl
		ld b,h
		ld c,l
		ld hl,(memtop)
		or a
		sbc hl,bc
		jp c,qhow
		push hl
		ld bc,(txtend)
		or a
		sbc hl,bc
		pop hl
		jp c,qsorry
		or a
		ret

clrvar:
		ld hl,vars
		ld b,52
cv1:
		ld (hl),0
		inc hl
		djnz cv1
		ret

;
;	Program lines: line number (2 bytes), text, CR
;
;	Find line BC: HL is the line or where it would go, Z if found
findln:
		ld hl,__end
fd1:
		push de
		ld de,(txtend)
		or a
		sbc hl,de
		add hl,de
		pop de
		jr nc,fd3
		push hl
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		or a
		sbc hl,bc
		pop hl
		ret z
		jr nc,fd2
		call nextln
		jr fd1
fd2:
		or 1
		ret
fd3:
		or 1
		scf
		ret

nextln:
		inc hl
		inc hl
nl1:
		ld a,(hl)
		inc hl
		cp 13
		jr nz,nl1
		ret

;	Store the line at DE with number HL (empty text deletes it)
store:
		ld a,h
		or l
		jp z,qhow
		ld (lnum),hl
		call skipsp
		ld (instxt),de
		ld c,0
st1:
		ld a,(de)
		inc de
		inc c
		cp 13
		jr nz,st1
		ld a,c
		ld (inslen),a
		ld bc,(lnum)
		call findln
		push hl
		call z,delln
		pop hl
		ld a,(inslen)
		dec a
		ret z
		; Make room: move the rest of the program up
		ld (inspos),hl
		ld c,a
		inc c
		inc c
		inc c
		ld b,0
		ld hl,(txtend)
		push hl
		add hl,bc
		ex de,hl
		ld hl,(memtop)
		or a
		sbc hl,de
		jp c,qsorry
		jp z,qsorry
		ld (txtend),de
		pop hl
		ld bc,(inspos)
		or a
		sbc hl,bc
		jr z,st2
		ld b,h
		ld c,l
		ld hl,(inspos)
		add hl,bc
		dec hl
		dec de
		lddr
st2:
		ld hl,(inspos)
		ld bc,(lnum)
		ld (hl),c
		inc hl
		ld (hl),b
		inc hl
		ex de,hl
		ld hl,(instxt)
		ld a,(inslen)
		ld c,a
		ld b,0
		ldir
		ret

;	Delete the line at HL
delln:
		ld d,h
		ld e,l
		call nextln
		push hl
		ld hl,(txtend)
		pop bc
		or a
		sbc hl,bc
		ld a,h
		or l
		push bc
		ld b,h
		ld c,l
		pop hl
		jr z,dl1
		ldir
dl1:
		ld (txtend),de
		ret

;	List from the line at HL to the end
listfr:
		push de
		ld de,(txtend)
		or a
		sbc hl,de
		add hl,de
		pop de
		ret nc
		ld a,(brkflg)
		or a
		jp nz,qbreak
		push hl
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		ld c,0
		call prtnum
		ld a,' '
		call outc
		pop hl
		inc hl
		inc hl
ls1:
		ld a,(hl)
		inc hl
		cp 13
		jr z,ls2
		call outc
		jr ls1
ls2:
		call crlf
		jr listfr

;
;	Errors
;
qwhat:
		ld hl,mwhat
		jr qerr
qhow:
		ld hl,mhow
		jr qerr
qsorry:
		ld hl,msorry
		jr qerr
qbreak:
		xor a
		ld (brkflg),a
		call setsig
		ld hl,mbreak
qerr:
		ld a,1
		ld (ofd),a
		ld a,(lastc)
		cp 10
		call nz,crlf
		call pmsg
		call crlf
		ld hl,(curlin)
		ld a,h
		or l
		jr z,direct
		; the line, with a ? where it went wrong
		push hl
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		ld c,0
		call prtnum
		ld a,' '
		call outc
		pop hl
		inc hl
		inc hl
qe1:
		ld a,l
		cp e
		jr nz,qe2
		ld a,h
		cp d
		ld a,'?'
		call z,outc
qe2:
		ld a,(hl)
		cp 13
		jr z,qe3
		call outc
		inc hl
		jr qe1
qe3:
		call crlf

;
;	Direct mode: read lines, store numbered ones, run the others
;
direct:
		ld sp,(stkbase)
		ld hl,0
		ld (curlin),hl
		ld hl,gstk
		ld (gsp),hl
		ld hl,fstk
		ld (fsp),hl
dir1:
		ld hl,lbuf
		ld a,'>'
		call getln
		call getnum
		jr c,dir2
		call store
		jr dir1
dir2:
		cp 13			; an empty line
		jr z,dir1
		ld hl,0
		ld (curlin),hl
		; typed commands: LIST, NEW, RUN first (so R. is RUN)
		ld hl,cmdtab
		jp dispatch

;	Run statements from DE
runst:
		ld a,(brkflg)
		or a
		jp nz,qbreak
		ld hl,stmtab
		jp dispatch

;	End of a statement: ; or the end of the line
endst:
		call skipsp
		cp ';'
		jr nz,es1
		inc de
		jr runst
es1:
		cp 13
		jp nz,qwhat
runnxl:
		ld hl,(curlin)
		ld a,h
		or l
		jr z,direct
		call nextln

;	Run the line at HL (if it is not past the end)
runln:
		push de
		ld de,(txtend)
		or a
		sbc hl,de
		add hl,de
		pop de
		jr nc,direct
		ld (curlin),hl
		inc hl
		inc hl
		ex de,hl
		jr runst

;
;	Statements
;
list:
		call getnum
		jr nc,li1
		ld hl,0
li1:
		ld b,h
		ld c,l
		call findln
		call listfr
		jp direct

new:
		ld hl,__end
		ld (txtend),hl
		jp direct

dorun:
run:
		call clrvar
		ld hl,gstk
		ld (gsp),hl
		ld hl,fstk
		ld (fsp),hl
		ld hl,__end
		jr runln

stop:
		jp direct

rem:
		jr runnxl

goto:
		call expr
goto2:
		ld b,h
		ld c,l
		call findln
		jp nz,qhow
		jr runln

gosub:
		call expr
		push hl
		ld hl,(gsp)
		ld bc,gstk+64
		or a
		sbc hl,bc
		add hl,bc
		jp nc,qsorry
		ld bc,(curlin)
		ld (hl),c
		inc hl
		ld (hl),b
		inc hl
		ld (hl),e
		inc hl
		ld (hl),d
		inc hl
		ld (gsp),hl
		pop hl
		jr goto2

return:
		ld hl,(gsp)
		ld bc,gstk
		or a
		sbc hl,bc
		jp z,qhow
		add hl,bc
		dec hl
		ld d,(hl)
		dec hl
		ld e,(hl)
		dec hl
		ld b,(hl)
		dec hl
		ld c,(hl)
		ld (gsp),hl
		ld (curlin),bc
		jp endst

if:
		call expr
		ld a,h
		or l
		jr z,runnxl
		ld hl,thentab
		jp dispatch
ifthen:
		call skipsp
		call isdig
		jr nc,goto
		jp runst

;	LET var = expr [, var = expr]
let:
		call setvar
		call tstc
		.byte ','
		jr z,let
		jp endst

setvar:
		call getvar
		jp c,qwhat
		push hl
		call tstc
		.byte '='
		jp nz,qwhat
		call expr
		ld b,h
		ld c,l
		pop hl
		ld (hl),c
		inc hl
		ld (hl),b
		dec hl
		ret

print:
		ld a,6
		ld (pwidth),a
pr1:
		call skipsp
		cp ';'
		jr z,pr4
		cp 13
		jr z,pr4
		cp '#'
		jr z,pr5
		cp '"'
		jr z,pr6
		cp 0x27
		jr z,pr6
		call expr
		ld a,(pwidth)
		ld c,a
		call prtnum
pr2:
		call tstc
		.byte ','
		jr nz,pr4
		call skipsp
		cp ';'
		jp z,endst
		cp 13
		jp z,endst
		jr pr1
pr4:
		call crlf
		jp endst
pr5:
		inc de
		call expr
		ld a,l
		ld (pwidth),a
		jr pr2
pr6:
		inc de
		ld c,a
		call prtstr
		jr pr2

input:
		call skipsp
		cp '"'
		jr z,in2
		cp 0x27
		jr z,in2
		push de
		call getvar
		jp c,qwhat
		pop bc
		push hl
		push de
in1:
		ld a,(bc)
		call outc
		inc bc
		ld a,c
		cp e
		jr nz,in1
		ld a,b
		cp d
		jr nz,in1
		jr in3
in2:
		inc de
		ld c,a
		call prtstr
		call getvar
		jp c,qwhat
		push hl
		push de
in3:
		ld hl,ibuf
		ld a,':'
		call getln
		call expr
		pop de
		pop bc
		ld a,l
		ld (bc),a
		inc bc
		ld a,h
		ld (bc),a
		call tstc
		.byte ','
		jr z,input
		jp endst

;	FOR var = expr TO expr [STEP expr]
for:
		call setvar
		ld (fvar),hl
		ld hl,totab
		jp dispatch
for1:
		call expr
		ld (flim),hl
		ld hl,steptab
		jp dispatch
for2:
		call expr
		jr for3
for2d:
		ld hl,1
for3:
		ld (fstep),hl
		ld hl,(curlin)
		ld (fline),hl
		ld (ftext),de
		; Drop an older loop on the same variable
		ld hl,fstk
fp1:
		ld bc,(fsp)
		or a
		sbc hl,bc
		add hl,bc
		jr nc,fp3
		ld a,(fvar)
		cp (hl)
		jr nz,fp2
		inc hl
		ld a,(fvar+1)
		cp (hl)
		dec hl
		jr nz,fp2
		ld (fsp),hl
		jr fp3
fp2:
		ld bc,10
		add hl,bc
		jr fp1
fp3:
		ld de,(fsp)
		ld hl,fstk+80
		or a
		sbc hl,de
		jp z,qsorry
		ld hl,fvar
		ld bc,10
		ldir
		ld (fsp),de
		ld de,(ftext)
		jp endst

next:
		call getvar
		jp c,qwhat
		ld (fvar),hl
nx1:
		ld hl,(fsp)
		ld bc,fstk
		or a
		sbc hl,bc
		jp z,qhow
		add hl,bc
		ld bc,-10
		add hl,bc
		ld a,(fvar)
		cp (hl)
		jr nz,nx2
		inc hl
		ld a,(fvar+1)
		cp (hl)
		dec hl
		jr z,nx3
nx2:
		ld (fsp),hl
		jr nx1
nx3:
		push de
		push hl
		ld de,fvar
		ld bc,10
		ldir
		ld hl,(fvar)
		ld c,(hl)
		inc hl
		ld b,(hl)
		ld hl,(fstep)
		or a
		adc hl,bc
		jp pe,qhow
		ld b,h
		ld c,l
		ld hl,(fvar)
		ld (hl),c
		inc hl
		ld (hl),b
		ld hl,(flim)
		call scmp
		jr z,nx4
		sbc a,a
		ld b,a
		ld a,(fstep+1)
		rla
		sbc a,a
		xor b
		jr z,nx5
nx4:
		; go round again
		pop hl
		pop de
		ld hl,(fline)
		ld (curlin),hl
		ld de,(ftext)
		jp endst
nx5:
		; done: drop the loop
		pop hl
		ld (fsp),hl
		pop de
		jp endst

;
;	Files
;
getfn:
		call tstc
		.byte '"'
		jp nz,qwhat
		ld hl,fname
		ld b,30
gf1:
		ld a,(de)
		cp 13
		jr z,gf2
		inc de
		cp '"'
		jr z,gf2
		ld (hl),a
		inc hl
		djnz gf1
gf2:
		ld (hl),0
		ret

save:
		call getfn
		call flush
		push de
		ld hl,0x1A4		; 0644
		push hl
		ld hl,0x501		; O_WRONLY | O_CREAT | O_TRUNC
		push hl
		ld hl,fname
		push hl
		ld a,1			; open
		call sys
		pop bc
		pop bc
		pop bc
		jp c,qhow
		ld a,l
		ld (ofd),a
		ld hl,__end
		call listfr
		call flush
		call closefd
		pop de
		jp endst

closefd:
		ld a,(ofd)
		ld l,a
		ld h,0
		push hl
		ld a,2			; close
		call sys
		pop hl
		ld a,1
		ld (ofd),a
		ret

load:
		call getfn
		ld hl,direct
		push hl
doload:
		ld hl,0
		push hl
		ld hl,fname
		push hl
		ld a,1			; open
		call sys
		pop bc
		pop bc
		jp c,qhow
		ld a,l
		ld (ofd),a		; (only used for closing here)
		ld hl,__end
		ld (txtend),hl
lo1:
		ld hl,lbuf
		ld (inspos),hl
lo2:
		; read one character
		ld hl,1
		push hl
		ld hl,(inspos)
		push hl
		ld a,(ofd)
		ld l,a
		ld h,0
		push hl
		ld a,7			; read
		call sys
		pop bc
		pop bc
		pop bc
		jr c,lo4
		ld a,h
		or l
		jr z,lo4		; end of file
		ld hl,(inspos)
		ld a,(hl)
		cp 10
		jr z,lo3
		ld bc,lbuf+78
		or a
		sbc hl,bc
		jr nc,lo2		; too long: drop the rest
		add hl,bc
		inc hl
		ld (inspos),hl
		jr lo2
lo3:
		ld (hl),13
		ld hl,lbuf
		call upcase
		ld de,lbuf
		call getnum
		call nc,store
		jr lo1
lo4:
		call closefd
		ret

bye:
		call flush
		ld hl,0
		push hl
		xor a			; _exit
		call sys

;
;	Tables
;
cmdtab:
		.byte 'L','I','S','T'+0x80
		.word list
		.byte 'N','E','W'+0x80
		.word new
		.byte 'R','U','N'+0x80
		.word run
		.byte 0
		.word runst

;	In a program the statements come first (N. is NEXT)
stmtab:
		.byte 'N','E','X','T'+0x80
		.word next
		.byte 'L','E','T'+0x80
		.word let
		.byte 'I','F'+0x80
		.word if
		.byte 'G','O','T','O'+0x80
		.word goto
		.byte 'G','O','S','U','B'+0x80
		.word gosub
		.byte 'R','E','T','U','R','N'+0x80
		.word return
		.byte 'R','E','M'+0x80
		.word rem
		.byte 'F','O','R'+0x80
		.word for
		.byte 'I','N','P','U','T'+0x80
		.word input
		.byte 'P','R','I','N','T'+0x80
		.word print
		.byte 'S','T','O','P'+0x80
		.word stop
		.byte 'L','I','S','T'+0x80
		.word list
		.byte 'N','E','W'+0x80
		.word new
		.byte 'R','U','N'+0x80
		.word run
		.byte 'S','A','V','E'+0x80
		.word save
		.byte 'L','O','A','D'+0x80
		.word load
		.byte 'B','Y','E'+0x80
		.word bye
		.byte 0
		.word let

fntab:
		.byte 'R','N','D'+0x80
		.word frnd
		.byte 'A','B','S'+0x80
		.word fabs
		.byte 'S','I','Z','E'+0x80
		.word fsize
		.byte 0
		.word fnone

reltab:
		.byte '>','='+0x80
		.word relge
		.byte '#'+0x80
		.word relne
		.byte '>'+0x80
		.word relgt
		.byte '='+0x80
		.word releq
		.byte '<','='+0x80
		.word relle
		.byte '<','>'+0x80
		.word relne
		.byte '<'+0x80
		.word rellt
		.byte 0
		.word relnone

totab:
		.byte 'T','O'+0x80
		.word for1
		.byte 0
		.word qwhat

steptab:
		.byte 'S','T','E','P'+0x80
		.word for2
		.byte 0
		.word for2d

thentab:
		.byte 'T','H','E','N'+0x80
		.word ifthen
		.byte 0
		.word ifthen

banner:
		.byte 'T','I','N','Y',' ','B','A','S','I','C',10,0
mwhat:
		.byte 'W','H','A','T','?',0
mhow:
		.byte 'H','O','W','?',0
msorry:
		.byte 'S','O','R','R','Y',0
mbreak:
		.byte 'B','R','E','A','K',0

		.bss

stkbase:	.ds 2
memtop:		.ds 2
txtend:		.ds 2
curlin:		.ds 2
gsp:		.ds 2
fsp:		.ds 2
seed:		.ds 2
lnum:		.ds 2
inspos:		.ds 2
instxt:		.ds 2
inslen:		.ds 1
brkflg:		.ds 1
ofd:		.ds 1
onum:		.ds 1
lastc:		.ds 1
pwidth:		.ds 1
; a FOR frame being built or looked at: kept in this order
fvar:		.ds 2
flim:		.ds 2
fstep:		.ds 2
fline:		.ds 2
ftext:		.ds 2
vars:		.ds 52
gstk:		.ds 64
fstk:		.ds 80
fname:		.ds 32
obuf:		.ds 64
lbuf:		.ds 82
ibuf:		.ds 82
