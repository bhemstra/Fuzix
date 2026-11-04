#include <kernel.h>
#include <kdata.h>
#include <printf.h>

extern uint8_t *bsrc;
extern uint8_t *bdest;
extern uint16_t blen;
extern void do_blkzero(void);
extern void do_blkcopyk(void);
extern void do_blkcopyul(void);
extern void do_blkcopyuh(void);

/*
 *	Must live in CODE2
 */

void blktok(void *kaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    bsrc = buf->__bf_data + off;
    bdest = kaddr;
    blen = len;
    do_blkcopyk();
}

void blkfromk(void *kaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    bsrc = kaddr;
    bdest = buf->__bf_data + off;
    blen = len;
    do_blkcopyk();
}

/* FIXME: work out a nice way to share the logic */
void blktou(void *uaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    uint16_t split;
    bdest = uaddr;
    blen = len;
    /* If it's all below 16K or all over 32K then use the 0x4000 window */
    if ((uint16_t)uaddr + len < 0x4000 || (uint16_t)uaddr >= 0x8000) {
        bsrc = buf->__bf_data + off;
        do_blkcopyul();
        return;
    }
    /* If it's all below 0x8000 then use the 0x8000 window */
    if ((uint16_t)uaddr + len <= 0x8000) {
        bsrc = buf->__bf_data + off + 0x4000;
        do_blkcopyuh();
        return;
    }
    /* Split case */
    split = 0x8000 - (uint16_t)uaddr;
    blen = split;
    bsrc = buf->__bf_data + off + 0x4000;
    do_blkcopyuh();
    blen = len - split;
    bdest += split;
    bsrc = buf->__bf_data + off + split;
    do_blkcopyul();
}

void blkfromu(void *uaddr, struct blkbuf *buf, uint16_t off, uint16_t len)
{
    uint16_t split;
    bsrc = uaddr;
    bdest = buf->__bf_data + off;
    blen = len;
    /* If it's all below 16K or all over 32K then use the 0x4000 window */
    if ((uint16_t)uaddr + len < 0x4000 || (uint16_t)uaddr >= 0x8000) {
        do_blkcopyul();
        return;
    }
    /* If it's all below 0x8000 then use the 0x8000 window */
    if ((uint16_t)uaddr + len <= 0x8000) {
        bdest += 0x4000;
        do_blkcopyuh();
        return;
    }
    /* Split case */
    split = 0x8000 - (uint16_t)uaddr;
    blen = split;
    bdest += 0x4000;
    do_blkcopyuh();
    blen = len - split;
    bdest += split- 0x4000;
    bsrc += split;
    do_blkcopyul();
}

static uint8_t scratchbuf[64];

/* Worst case is needing to copy over about 64 bytes */
void *blkptr(struct blkbuf *buf, uint16_t offset, uint16_t len)
{
    if (len > 64)
        panic("blkptr");
    bsrc = buf->__bf_data + offset;
    bdest = scratchbuf;
    blen = sizeof(scratchbuf);
    do_blkcopyk();
    return scratchbuf;
}

void blkzero(struct blkbuf *buf)
{
    bsrc = buf->__bf_data;
    do_blkzero();
}

/*
 *	Scratch buffers for syscall arguments - until we can rework
 *	execve and realloc to avoid this need
 *
 *	The buffers must be valid in both kernel and buffer mappings.
 */

extern uint8_t workbuf[2][BLKSIZE];
static uint8_t tfree = 3;

void tmpfree(void *p)
{
  if (p == workbuf[0]) {
      tfree |= 1;
      return;
  }
  if (p == workbuf[1]) {
      tfree |= 2;
      return;
  }
  panic("tmpfree");
}

void *tmpbuf(void)
{
   if (tfree & 1) {
       tfree &= ~1;
       return workbuf[0];
   }
   if (tfree & 2) {
       tfree &= ~2;
       return workbuf[1];
   }
   panic("tmpbuf");
}
