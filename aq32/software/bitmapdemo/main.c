#include "common.h"
#include "esp.h"
#include "csr.h"
#include "console.h"

#include "keen_data.h"

static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

// #define WRAP

int main(void) {
    memcpy((void *)VRAM4BPP, keen_data, keen_data_len);

    console_set_width(40);
    console_show_cursor(false);
    console_set_background_color(0);
    console_set_foreground_color(9);
    console_clear_screen();

    GFX->CTRL =
        GFX_CTRL_TEXT_PRIO | GFX_CTRL_TEXT_EN |
        GFX_CTRL_GFX_EN
#ifdef WRAP
        | GFX_CTRL_BM_WRAP
#endif
        ;

    while (1) {
        wait_frame();
#ifdef WRAP
        GFX->SCRX1 = (GFX->SCRX1 + 1) % 320;
        GFX->SCRY1 = (GFX->SCRY1 + 1) % 200;
#else
        GFX->SCRX1++;
        GFX->SCRY1++;
#endif
        console_set_cursor_row(0);
        console_set_cursor_column(0);
        printf("%3u %3u", GFX->SCRX1, GFX->SCRY1);
    }

    return 0;
}
