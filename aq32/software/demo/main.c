#include "common.h"

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

void main(void) {

    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    REGS->VCTRL = VCTRL_GFXMODE_TILE | VCTRL_TEXT_EN;

    for (int i = 0; i < 32000; i++)
        VRAM[i] = i & 0xFF;

    while (1) {
    }
}
