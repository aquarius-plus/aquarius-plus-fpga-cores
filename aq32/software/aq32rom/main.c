#include "console.h"
#include "file_io.h"
#include <string.h>
#include <stdio.h>

// static const uint16_t palette[16] = {
//     0x111, 0xF11, 0x1F1, 0xFF1, 0x22E, 0xF1F, 0x3CC, 0xFFF,
//     0xCCC, 0x3BB, 0xC2C, 0x419, 0xFF7, 0x2D4, 0xB22, 0x333};

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

uint16_t   *p_scr;
uint16_t    color;
const char *filename = "Hello.bas";

static void puttext(const char *p) {
    while (*p)
        *(p_scr++) = color | *(p++);
}

void render_screen(void) {
    p_scr = (uint16_t *)TRAM;
    color = 0x0700;
    puttext("  File  Edit  View  Run  Help                                                   ");
    color = 0x7100;

    int filename_len = strlen(filename);

    *(p_scr++) = color | 16;
    int count  = (78 - (filename_len + 2)) / 2;
    for (int i = 0; i < count; i++)
        *(p_scr++) = color | 25;

    color      = 0x1700;
    *(p_scr++) = color | ' ';
    for (int i = 0; i < filename_len; i++) {
        *(p_scr++) = color | filename[i];
    }
    *(p_scr++) = color | ' ';

    color = 0x7100;
    count = 78 - count - (filename_len + 2);
    for (int i = 0; i < count; i++)
        *(p_scr++) = color | 25;
    *(p_scr++) = color | 18;

    for (int j = 0; j < 22; j++) {
        *(p_scr++) = color | 26;
        for (int i = 0; i < 78; i++)
            *(p_scr++) = color | ' ';
        *(p_scr++) = color | 26;
    }

    color = 0xF300;
    puttext(" <Shift+F1=Help> <F5=Run>                                           ");
    color      = 0x0300;
    *(p_scr++) = color | 26;

    char tmp[32];
    snprintf(tmp, sizeof(tmp), " %05d:%03d ", 123, 1);
    puttext(tmp);
}

void editor(void) {
    render_screen();

    color = 0x7100;
    p_scr = (uint16_t *)&TRAM[80 * 2 + 1];

    while (1) {
        unsigned ch = REGS->KEYBUF;
        if (ch != 0) {
            *(p_scr++) = color | ch;
        }
    }
}

// called from start.S
void main(void) {
    REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_REMAP_BORDER_CH | VCTRL_TEXT_EN;

    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    int fd = esp_open("esp:latin1b.chr", 0);
    if (fd >= 0) {
        esp_read(fd, (void *)CHRAM, 2048);
        esp_close(fd);
    }

#if 1
    console_init();

    printf("\nAquarius32 System V0.1\n\nSD:/>");
    printf("%lg", 50.123);
    fflush(stdout);

    while (1) {
        unsigned ch = REGS->KEYBUF;
        if (ch != 0) {
            console_putc(ch);
        }
    }
#else
    editor();
#endif
}
