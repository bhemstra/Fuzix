;
;        zx128 vt primitives
;

        ; exported symbols
        .export _plot_char
        .export _scroll_down
        .export _scroll_up
        .export _cursor_on
        .export _cursor_off
	.export _cursor_disable
        .export _clear_lines
        .export _clear_across
        .export _do_beep
	.export _curattr

	; Build the video library as the only driver

#define ZXVID_ONLY
#define SCREENBASE	0x40
#define VIDEO_MAP
#define VIDEO_UNMAP
#define BANKED_Z80

	.commondata
	.export _vtborder
_vtborder:
	.byte	0

	.overlay1		; TODO where to land this ?

#include "../../dev/zx/video.S"
