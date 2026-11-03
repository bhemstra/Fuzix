/*
 *	scc2: code generator for scc
 */

#include "ir.h"

struct opd {
	u8 k;
	u8 cls;
	s16 v;
	u16 sym;
};

#define helper(h)	(h)

extern u16 codepos;

/* cg.c */
void gb(u8 b);
void gw(u16 w);
void glab(u16 l);
void setlabel(u16 l);
void gcallsym(u16 sym);
void gaddsp(s16 n);
void funcbegin(void);
void funcend(u16 frame);
void ext(u8 cls);
void far(s16 off);
void tohl(struct opd *o);
void tode(struct opd *o);
void store(struct opd *o, u8 fixh);
void scale(u16 n);
void emitop(u8 op, u8 uns, u8 swap);
void constop(u8 op, u16 v, u8 uns);

/* scc2.c */
void codeout(u8 *buf, u16 len);
void fatal(const char *m);
