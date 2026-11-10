#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <setjmp.h>
#define rlimit kernel_rlimit
#define time_t kernel_time_t
typedef intptr_t arg_t;
typedef uintptr_t uarg_t, uaddr_t, uptr_t;
#define clock_t kernel_clock_t
typedef uint32_t clock_t;
typedef unsigned usize_t;
typedef int irqflags_t;
typedef uint16_t blkno_t;
#define staticfast static
#define min(a,b) ((a)<(b)?(a):(b))
#define TEST(c,msg) do {if(!(c)){puts(msg);return 1;}}while(0)
struct sigbits {uint16_t s_pending,s_held,s_ignored;};
struct p_tab {uint8_t p_status,p_flags,p_tty,p_nice,p_event;uint16_t p_pid,p_uid,p_pgrp,p_session,p_page,p_page2,p_timeout,p_priority,p_exitval; struct p_tab *p_pptr; struct sigbits p_sig[2]; unsigned p_time,p_utime,p_stime,p_cutime,p_cstime;};
typedef struct p_tab *ptptr;
struct cinode {uint16_t c_dev,c_num;struct {uint16_t i_mode,i_nlink,i_uid,i_gid;uint32_t i_size;uint16_t i_addr[20];} c_node;uint8_t c_refs,c_readers,c_writers,c_flags,c_super;};
struct s_queue {uint8_t *q_base,*q_head,*q_tail;int q_size,q_count,q_wakeup;};
typedef struct cinode *inoptr;
struct oft {inoptr o_inode;uint8_t o_access,o_refs;uint32_t o_ptr;};
struct rlimit {uint32_t rlim_cur,rlim_max;};
typedef struct u_data {arg_t u_argn,u_argn1,u_argn2;int u_error;bool u_sysio,u_ininterrupt,u_insys;uaddr_t u_syscall_sp,u_top,u_codebase,u_break;void *u_sp,*u_isp;uint16_t u_page,u_page2,u_euid,u_egid;uint8_t u_flags,u_name[8];int u_cursig;inoptr u_cwd,u_root;uint16_t u_block;unsigned u_nblock;uint8_t *u_dptr;uint8_t *u_base; unsigned u_count,u_done;uint32_t u_offset;uint16_t u_cloexec,u_mask;uint8_t u_files[16];ptptr u_ptab; int (*u_sigvec[32])(int);struct rlimit u_rlimit[9];} u_data;u_data udata;
struct p_tab ptab[16],*ptab_end=ptab+16;
struct oft of_tab[16];
struct cinode node;
#define NULLINODE ((inoptr)0)
/* DEFINE SELECT_BEGIN */
/* DEFINE SELECT_TEST */
/* DEFINE SELECT_END */
/* DEFINE SELECT_IN */
/* DEFINE SELECT_OUT */
/* DEFINE SELECT_EX */
/* DEFINE SIGWINCH */

#define NUM_DEV_TTY 1
#define CONFIG_LEVEL_2
#include "tty.h"
typedef uint8_t *queueptr_t;
#ifndef tty_input_queue
#define tty_input_queue(m) (&ttyinq[(uint8_t)(m)])
#endif
#define GETQ(p) (*(p))
struct tty ttydata[2];struct s_queue ttyinq[2];tcflag_t termios_mask[2];
static uint16_t tty_select;static int irqstate;
irqflags_t di(void){int previous=irqstate;irqstate=1;return previous;}void irqrestore(irqflags_t state){irqstate=state;}
int jobcontrol_ioctl(unsigned minor,struct tty *t,uarg_t op){return 0;}
int uput(const void *p,void *out,unsigned n){memcpy(out,p,n);return 0;}
int uget(const void *p,void *out,unsigned n){memcpy(out,p,n);return 0;}
int uputw(uint16_t value,void *p){*(uint16_t*)p=value;return 0;}
void clrq(struct s_queue *q){q->q_count=0;}
void tty_setup(uint_fast8_t minor,uint_fast8_t flags){}
void tty_selwake(unsigned minor,unsigned events){}
void tty_hangup(uint_fast8_t minor){}
void sgrpsig(unsigned group,unsigned sig){}
int tcsetpgrp(struct tty *t,char *data){return 0;}
ttyready_t tty_writeready(uint_fast8_t minor){return TTY_READY_NOW;}
static uint8_t bytes[8];
static void setup(void){ttyinq[1]=(struct s_queue){bytes,bytes,bytes,8,0,4};ttydata[1].termios.c_cc[VMIN]=1;}
static int poll_read(void){char events=SELECT_IN;if(tty_ioctl(1,SELECT_TEST,&events))return -1;return events;}

/* FUNCTION tty.c tty_output_ready optional */
/* FUNCTION tty.c tty_input_ready optional */
/* FUNCTION tty.c tty_ioctl 0 */

static int case_raw_input(void)
{
setup();bytes[0]='a';ttyinq[1].q_count=1;TEST(poll_read()==SELECT_IN&&ttyinq[1].q_count==1&&!irqstate,"report queued raw input without consuming it");
return 0;
}

static int case_raw_empty(void)
{
setup();TEST(!poll_read()&&!irqstate,"empty raw input is not ready");
return 0;
}

static int case_raw_minimum(void)
{
setup();ttydata[1].termios.c_cc[VMIN]=2;ttyinq[1].q_count=1;TEST(!poll_read(),"below VMIN");ttyinq[1].q_count=2;TEST(poll_read()==SELECT_IN,"VMIN satisfied");
return 0;
}

static int case_canonical_partial(void)
{
setup();ttydata[1].termios.c_lflag=ICANON;ttydata[1].termios.c_cc[VEOF]=4;bytes[0]='a';ttyinq[1].q_count=1;TEST(!poll_read(),"unfinished canonical line");
return 0;
}

static int case_canonical_line(void)
{
setup();ttydata[1].termios.c_lflag=ICANON;ttydata[1].termios.c_cc[VEOF]=4;bytes[0]='a';bytes[1]='\n';ttyinq[1].q_count=2;TEST(poll_read()==SELECT_IN&&ttyinq[1].q_count==2,"complete canonical line");
return 0;
}

static int case_canonical_eof(void)
{
setup();ttydata[1].termios.c_lflag=ICANON;ttydata[1].termios.c_cc[VEOF]=4;bytes[0]=4;ttyinq[1].q_count=1;TEST(poll_read()==SELECT_IN,"canonical EOF");
return 0;
}

static int case_wrapped_line(void)
{
setup();ttydata[1].termios.c_lflag=ICANON;ttydata[1].termios.c_cc[VEOF]=4;ttyinq[1].q_head=bytes+7;bytes[7]='a';bytes[0]='\n';ttyinq[1].q_count=2;TEST(poll_read()==SELECT_IN&&ttyinq[1].q_head==bytes+7&&!irqstate,"peek across queue wrap without consuming");
return 0;
}

static int case_immediate_empty(void)
{
setup();ttydata[1].termios.c_cc[VMIN]=0;TEST(poll_read()==SELECT_IN,"VMIN=VTIME=0 returns immediately");
return 0;
}

static int case_timed_empty(void)
{
setup();ttydata[1].termios.c_cc[VMIN]=0;ttydata[1].termios.c_cc[VTIME]=1;TEST(!poll_read(),"timed empty read is not ready");
return 0;
}

int main(int argc,char **case_argv)
{
if(argc!=2)return 2;
if(!strcmp(case_argv[1],"raw-input"))return case_raw_input();
if(!strcmp(case_argv[1],"raw-empty"))return case_raw_empty();
if(!strcmp(case_argv[1],"raw-minimum"))return case_raw_minimum();
if(!strcmp(case_argv[1],"canonical-partial"))return case_canonical_partial();
if(!strcmp(case_argv[1],"canonical-line"))return case_canonical_line();
if(!strcmp(case_argv[1],"canonical-eof"))return case_canonical_eof();
if(!strcmp(case_argv[1],"wrapped-line"))return case_wrapped_line();
if(!strcmp(case_argv[1],"immediate-empty"))return case_immediate_empty();
if(!strcmp(case_argv[1],"timed-empty"))return case_timed_empty();
return 2;
}
