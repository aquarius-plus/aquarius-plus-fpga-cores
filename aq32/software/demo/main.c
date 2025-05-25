#include "common.h"

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

int main(void) {
    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    REGS->VCTRL = VCTRL_GFXMODE_BM4BPP;

    // printf("%X\n", REGS->VCTRL);

    // for (int i = 0; i < 10; i++) {
    //     for (int i = 0; i < 32768; i++) {
    //         VRAM[i] = i ^ (i >> 8);
    //     }

    //     for (int i = 0; i < 32768; i++) {
    //         uint8_t bla = i ^ (i >> 8);
    //         if (VRAM[i] != bla) {
    //             printf("Iek!\n");
    //             break;
    //         }
    //     }
    //     printf("Done.\n");
    // }

    for (int j = 0; j < 200; j++)
        for (int i = 0; i < 160; i++)
            VRAM[j * 160 + i] = j ^ i;

    // REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_TEXT_EN;

    while (1) {
    }
    return 0;
}
