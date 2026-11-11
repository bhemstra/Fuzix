; 2014-12-31 William R Sowerbutts
; DS1302 support for the N8 - same as the N8VEM Mark 4
; Need to be careful as bit 2 is owned by the SD card driver hence
; use of _rtc_shadow

        .z180

        ; exported symbols
        .export _ds1302_set_ce
        .export _ds1302_set_clk
        .export _ds1302_set_data
        .export _ds1302_set_driven
        .export _ds1302_get_data
; N8_RTC          = 0x88

	.code

#define PIN_CE          0xEF10
#define PIN_DATA_HIZ    0xDF20
#define PIN_CLK         0xBF40
#define PIN_DATA_OUT    0x7F80
#define PIN_DATA_IN     0x01
#define PIN_OTHER	0x00


#include "../../dev/ds1302_commonu.s"
