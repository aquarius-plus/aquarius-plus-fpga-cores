#include "common.h"
#include "esp.h"
#include "csr.h"

static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

int main(void) {
    FILE *f = fopen("/demos/tiledemo/data/tiledata.bin", "rb");
    if (!f) {
        perror("");
        exit(1);
    }
    fread((void *)VRAM, 0x4000, 1, f);
    memcpy((uint8_t *)VRAM + 0x7000, (uint8_t *)VRAM, 0x1000);

    uint16_t palette[16];
    fread(palette, sizeof(palette), 1, f);

    fclose(f);

    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i];

    REGS->VCTRL = /*VCTRL_TEXT_EN |*/ VCTRL_GFX_EN | VCTRL_GFX_TILEMODE;

    // REGS->VSCRY = 3;
    while (1) {
        wait_frame();
        REGS->VSCRX++;
    }

    return 0;
}
