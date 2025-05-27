#include "common.h"

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

int main(void) {
    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    REGS->VCTRL = VCTRL_GFX_EN;

    for (int i = 0; i < 32000; i++) {
        VRAM[i] = 0;
    }

    // for (int i = 0; i < 64000; i++) {
    //     VRAM4BPP[i] = keen_data[i];
    // }

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

    // VRAM[0]   = 0xFF;
    // VRAM[160] = 0xFF;

    // ((uint32_t *)VRAM4BPP)[0] = 0x01020304;
    // ((uint32_t *)VRAM4BPP)[1] = 0x05060708;

    // ((uint32_t *)VRAM)[40 * 0] = 0x78563412;
    // ((uint32_t *)VRAM)[40 * 1] = 0x00000010;
    // ((uint32_t *)VRAM)[40 * 2] = 0x00000002;
    // ((uint32_t *)VRAM)[40 * 3] = 0x00003000;
    // ((uint32_t *)VRAM)[40 * 4] = 0x00000400;
    // ((uint32_t *)VRAM)[40 * 5] = 0x00500000;
    // ((uint32_t *)VRAM)[40 * 6] = 0x00060000;
    // ((uint32_t *)VRAM)[40 * 7] = 0x70000000;
    // ((uint32_t *)VRAM)[40 * 8] = 0x08000000;

    // VRAM4BPP[320 * 1 + 0] = 1;
    // VRAM4BPP[320 * 2 + 1] = 2;
    // VRAM4BPP[320 * 3 + 2] = 3;
    // VRAM4BPP[320 * 4 + 3] = 4;
    // VRAM4BPP[320 * 5 + 4] = 5;
    // VRAM4BPP[320 * 6 + 5] = 6;
    // VRAM4BPP[320 * 7 + 6] = 7;
    // VRAM4BPP[320 * 8 + 7] = 8;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    // for (int i = 0; i < 8; i++)
    //     printf("%x\n", VRAM4BPP[i]);

    // printf("%08x\n", ((uint32_t *)VRAM4BPP)[0]);
    // printf("%08x\n", ((uint32_t *)VRAM4BPP)[1]);

    // ((uint32_t *)VRAM4BPP)[0] = 0x04030201;
    // ((uint32_t *)VRAM4BPP)[1] = 0x08070605;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    // for (int i = 0; i < 8; i++) {
    //     VRAM4BPP[i] = 15;
    // }
    // VRAM[160] = 0xF0;
    // VRAM[161] = 0xF0;
    // VRAM[162] = 0xF0;
    // VRAM[163] = 0xF0;

    // VRAM[0] = 0xF2;

    // VRAM4BPP[0]  = 15;
    // VRAM4BPP[3]  = 15;
    // VRAM4BPP[4]  = 15;
    // VRAM4BPP[6]  = 15;
    // VRAM4BPP[8]  = 15;
    // VRAM4BPP[10] = 15;
    // VRAM4BPP[12] = 15;
    // VRAM4BPP[14] = 15;

    // VRAM4BPP[320 + 1 + 0]  = 15;
    // VRAM4BPP[320 + 1 + 2]  = 15;
    // VRAM4BPP[320 + 1 + 4]  = 15;
    // VRAM4BPP[320 + 1 + 6]  = 15;
    // VRAM4BPP[320 + 1 + 8]  = 15;
    // VRAM4BPP[320 + 1 + 10] = 15;
    // VRAM4BPP[320 + 1 + 12] = 15;
    // VRAM4BPP[320 + 1 + 14] = 15;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    for (int j = 0; j < 200; j++)
        for (int i = 0; i < 320; i++)
            VRAM4BPP[j * 320 + i] = j ^ i;

    // REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_TEXT_EN;

    while (1) {
    }
    return 0;
}
