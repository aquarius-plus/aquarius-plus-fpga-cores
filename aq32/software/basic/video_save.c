#include "video_save.h"
#include "common.h"

static uint16_t saved_tram[2048];
static uint8_t  saved_chram[2048];
static uint16_t saved_palette[64];
static uint32_t saved_reg_vctrl;

void save_video(void) {
    for (int i = 0; i < 2048; i++)
        saved_tram[i] = TRAM[i];
    for (int i = 0; i < 2048; i++)
        saved_chram[i] = CHRAM[i];
    for (int i = 0; i < 64; i++)
        saved_palette[i] = PALETTE[i];
    saved_reg_vctrl = REGS->VCTRL;
}

void restore_video(void) {
    for (int i = 0; i < 2048; i++)
        TRAM[i] = saved_tram[i];
    for (int i = 0; i < 2048; i++)
        CHRAM[i] = saved_chram[i];
    for (int i = 0; i < 64; i++)
        PALETTE[i] = saved_palette[i];
    REGS->VCTRL = saved_reg_vctrl;
}
