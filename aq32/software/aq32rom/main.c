#include "lib.h"
#include "console.h"
#include "file_io.h"

static const uint16_t palette[16] = {
    0x111, 0xF11, 0x1F1, 0xFF1, 0x22E, 0xF1F, 0x3CC, 0xFFF,
    0xCCC, 0x3BB, 0xC2C, 0x419, 0xFF7, 0x2D4, 0xB22, 0x333};

// called from start.S
void main(void) {
    REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_REMAP_BORDER_CH | VCTRL_TEXT_EN;

    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    int fd = esp_open("esp:default.chr", 0);
    if (fd >= 0) {
        esp_read(fd, CHRAM, 2048);
        esp_close(fd);
    }

    console_init();

    printf("Aquarius32\n\nSD:/>");

    while (1) {
        unsigned ch = REGS->KEYBUF;
        if (ch != 0) {
            console_putc(ch);
        }
    }
}
