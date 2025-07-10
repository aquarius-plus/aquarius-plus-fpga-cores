#include "common.h"
#include "esp.h"
#include "csr.h"

#include "keen_data.h"

static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

int main(void) {
    memcpy((void *)VRAM4BPP, keen_data, keen_data_len);

    GFX->CTRL = GFX_CTRL_GFX_EN;

    while (1) {
        wait_frame();
        GFX->SCRX1 = (GFX->SCRX1 + 1) % 320;
        GFX->SCRY1 = (GFX->SCRY1 + 1) % 200;
    }
    return 0;
}
