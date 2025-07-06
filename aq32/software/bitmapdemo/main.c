#include "common.h"
#include "esp.h"
#include "csr.h"

#include "keen_data.h"

static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

int main(void) {
    memcpy((void *)VRAM4BPP, keen_data, keen_data_len);

    REGS->VCTRL = VCTRL_GFX_EN;

    while (1) {
        wait_frame();
        REGS->VSCRX = (REGS->VSCRX + 1) % 320;
        REGS->VSCRY = (REGS->VSCRY + 1) % 200;
    }
    return 0;
}
