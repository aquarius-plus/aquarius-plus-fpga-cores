#include <stdio.h>
#include <string.h>
#include "regs.h"

static volatile uint16_t *p_scr;
static uint16_t           color;
static const char        *filename = "/demos/Mandelbrot/run-me.bas";

static inline void scr_locate(int row, int column) {
    p_scr = TRAM + 80 * row + column;
}

static inline void scr_putchar(uint8_t ch) {
    *(p_scr++) = color | ch;
}

static inline void scr_puttext(const char *p) {
    while (*p)
        scr_putchar(*(p++));
}

static inline void scr_setcolor(uint8_t col) {
    color = col << 8;
}

int blaat = 0;

void render_screen(void) {
    {
        scr_locate(0, 0);
        scr_setcolor(0x07);
        scr_puttext("  File  Edit  View  Run  Help                                                   ");
    }

    {
        int filename_len = strlen(filename);

        scr_locate(1, 0);
        scr_setcolor(0x71);
        scr_putchar(16);

        int count = (78 - (filename_len + 2)) / 2;
        for (int i = 0; i < count; i++)
            scr_putchar(25);

        scr_setcolor(0x17);
        scr_putchar(' ');
        for (int i = 0; i < filename_len; i++)
            scr_putchar(filename[i]);
        scr_putchar(' ');

        scr_setcolor(0x71);
        count = 78 - count - (filename_len + 2);
        for (int i = 0; i < count; i++)
            scr_putchar(25);
        scr_putchar(18);
    }

    for (int j = 2; j <= 23; j++) {
        scr_locate(j, 0);
        scr_setcolor(0x71);
        scr_putchar(26);
        for (int i = 0; i < 78; i++)
            scr_putchar(' ');
        scr_putchar(26);
    }

    scr_locate(24, 0);
    scr_setcolor(0xF3);
    scr_puttext(" <Shift+F1=Help> <F5=Run>                                           ");
    scr_setcolor(0x03);
    scr_putchar(26);

    char tmp[32];
    snprintf(tmp, sizeof(tmp), " %05d:%03d ", blaat, 1);
    scr_puttext(tmp);
}

void editor(void) {

    // const char *file = "/demos/Mandelbrot/run-me.bas"

    while (1) {
        render_screen();
        blaat++;
    }
}
