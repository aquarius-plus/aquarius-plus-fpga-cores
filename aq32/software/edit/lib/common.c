#include "common.h"

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

void reinit_video(void) {
    REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_REMAP_BORDER_CH | VCTRL_TEXT_EN;
    TRAM[2047]  = 0;

    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    FILE *f = fopen("esp:latin1b.chr", "rb");
    if (f) {
        fread((void *)CHRAM, 2048, 1, f);
        fclose(f);
    }
}
