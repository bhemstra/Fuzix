#
#	Build the SDCC helper library with exactly the same compiler and
#	options as the kernel so the calling conventions match.
#
CSRCS = _divschar.c _divsint.c _divslong.c _divuchar.c _divuint.c \
	_divulong.c _modschar.c _modsint.c _modslong.c _moduchar.c \
	_moduint.c _modulong.c _mulint.c _mullong.c _mulschar.c \
	_muluchar.c _memset.c _strcmp.c _memcmp.c _strncmp.c _strncpy.c \
	_strchr.c
ASRCS = crtenter.s sdcc_call.s string.s

OBJS = $(CSRCS:.c=.rel) $(ASRCS:.s=.rel)

# Generic C versions only: the inline asm in some of these files is
# written for the register based convention
RTOPTS = -c --std-sdcc99 -m$(CPU) --stack-auto --opt-code-size \
	 -D_SDCC_NO_ASM_LIB_FUNCS $(SDCCCALL)

all: sdccrt.lib

sdccrt.lib: $(OBJS)
	rm -f $@
	sdar rcs $@ $(OBJS)

$(CSRCS:.c=.rel): %.rel: %.c
	$(CROSS_CC) $(RTOPTS) $<

$(ASRCS:.s=.rel): %.rel: %.s
	$(CROSS_AS) $(ASOPTS) $<

clean:
	rm -f *.rel *.asm *.lst *.sym *.lib
