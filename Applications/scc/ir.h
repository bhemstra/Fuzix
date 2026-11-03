/*
 *	scc: the intermediate stream between scc (front end) and scc2
 *	(code generator).
 *
 *	Each record is an opcode byte followed by its operands. Words are
 *	little endian. An operand ("opd") is: kind, class, value (word),
 *	symbol (word).
 *
 *	The front end also writes the data and literal segment streams
 *	directly in object file format; scc2 adds the code and puts the
 *	object file together.
 */

#include <stdint.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef int16_t s16;

/*
 *	Tokens. Single character operators are their own character code.
 */
#define T_EOF		0
#define T_ID		1
#define T_NUM		2
#define T_STR		3
#define T_LINE		4	/* scc0 output only */
#define T_FILE		5	/* scc0 output only */
/* two or three character operators */
#define T_ARROW		128	/* -> */
#define T_INC		129	/* ++ */
#define T_DEC		130	/* -- */
#define T_SHL		131	/* << */
#define T_SHR		132	/* >> */
#define T_LE		133	/* <= */
#define T_GE		134	/* >= */
#define T_EQ		135	/* == */
#define T_NE		136	/* != */
#define T_ANDAND	137	/* && */
#define T_OROR		138	/* || */
#define T_ELLIPSIS	139	/* ... */
/* assignment operators: T_ASSIGN + operator index */
#define T_ADDEQ		140	/* += */
#define T_SUBEQ		141
#define T_MULEQ		142
#define T_DIVEQ		143
#define T_MODEQ		144
#define T_ANDEQ		145
#define T_OREQ		146
#define T_XOREQ		147
#define T_SHLEQ		148
#define T_SHREQ		149
/* keywords */
#define K_FIRST		160
#define K_AUTO		160
#define K_BREAK		161
#define K_CASE		162
#define K_CHAR		163
#define K_CONST		164
#define K_CONTINUE	165
#define K_DEFAULT	166
#define K_DO		167
#define K_DOUBLE	168
#define K_ELSE		169
#define K_ENUM		170
#define K_EXTERN	171
#define K_FLOAT		172
#define K_FOR		173
#define K_GOTO		174
#define K_IF		175
#define K_INT		176
#define K_LONG		177
#define K_REGISTER	178
#define K_RETURN	179
#define K_SHORT		180
#define K_SIGNED	181
#define K_SIZEOF	182
#define K_STATIC	183
#define K_STRUCT	184
#define K_SWITCH	185
#define K_TYPEDEF	186
#define K_UNION		187
#define K_UNSIGNED	188
#define K_VOID		189
#define K_VOLATILE	190
#define K_WHILE		191
#define K_LAST		191


/* scc0 names file record size */
#define NAMEREC		32

/* Operand kinds */
#define O_CON		1	/* constant v */
#define O_REG		2	/* value in HL */
#define O_GADR		3	/* address of symbol sym + v */
#define O_SADR		4	/* address in our segment sym at v */
#define O_LADR		5	/* address of frame slot v */
#define O_GVAR		6	/* lvalue: symbol sym + v */
#define O_SVAR		7	/* lvalue: our segment sym at v */
#define O_LVAR		8	/* lvalue: frame slot v */
#define O_IND		9	/* lvalue: address in HL */
#define O_CMP		10	/* result of a comparison: Z/C flags, see cc */

/* object segments */
#define SEG_CODE	1
#define SEG_DATA	2
#define SEG_BSS		3
#define SEG_LIT		7

/* run time helpers: the front end makes them object symbols 0-10 */
#define H_MUL		0
#define H_DIV		1
#define H_UDIV		2
#define H_MOD		3
#define H_UMOD		4
#define H_SHL		5
#define H_SHR		6
#define H_USHR		7
#define H_JPHL		8
#define H_SWITCH	9
#define H_REV		10

#define JP_Z		0xCA
#define JP_NZ		0xC2
#define JP_C		0xDA
#define JP_NC		0xD2

/* Operand classes: what the code generator needs to know of a type */
#define OC_WORD		0
#define OC_UCHAR	1
#define OC_SCHAR	2

#define I_TOHL		1	/* opd: load into HL */
#define I_TODE		2	/* opd: load into DE (simple operands) */
#define I_STORE		3	/* opd fixh: store HL (O_IND: address in DE) */
#define I_FAR		4	/* off: HL = IX + off */
#define I_SCALE		5	/* n: HL *= n, keeping DE */
#define I_OP		6	/* op uns swap */
#define I_CONST		7	/* op value uns: HL op= value */
#define I_JP		8	/* cond label: cond 0 = always */
#define I_LABEL		9	/* label */
#define I_CALLH		10	/* helper */
#define I_CALLS		11	/* symbol */
#define I_ADDSP		12	/* n: drop n bytes of arguments */
#define I_EXT		13	/* class: extend the char in L */
#define I_RAW		14	/* n bytes */
#define I_FBEGIN	15	/* symbol public: start of a function */
#define I_FEND		16	/* frame size */
#define I_WORD		17	/* value: a word in the code */
#define I_LABW		18	/* label: a label address in the code */
#define I_SYM		19	/* flags value name: one object symbol */
#define I_END		20	/* bss data literal sizes */
#define I_TEST		21	/* opd: set Z from the value (tobool) */
