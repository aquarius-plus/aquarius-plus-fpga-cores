#include "screen.h"

volatile uint16_t *p_scr = TRAM;
uint16_t           color;

void scr_draw_border(int x, int y, int w, int h, uint8_t color, bool shadow, const char *title) {
    w -= 2;
    h -= 2;

    // Draw top border
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_putchar(16);
    if (title) {
        int title_w = strlen(title);
        int w2      = (w - (title_w + 2)) / 2;
        scr_fillchar(25, w2);

        scr_putchar(' ');
        scr_puttext(title);
        scr_putchar(' ');

        w2 = w - (title_w + 2) - w2;
        scr_fillchar(25, w2);

    } else {
        for (int i = 0; i < w; i++)
            scr_putchar(25);
    }
    scr_putchar(18);
    y++;

    // Draw sides
    for (int j = 0; j < h; j++) {
        scr_setcolor(COLOR_MENU);
        scr_locate(y, x);
        scr_putchar(26);

        scr_locate(y, x + 2 + w - 1);
        scr_putchar(26);

        if (shadow) {
            scr_setcolor(0);
            scr_putchar(' ');
            scr_putchar(' ');
        }

        y++;
    }

    // Draw bottom border
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_putchar(22);
    for (int i = 0; i < w; i++)
        scr_putchar(25);
    scr_putchar(24);

    if (shadow) {
        scr_setcolor(0);
        scr_putchar(' ');
        scr_putchar(' ');
    }
    y++;

    if (shadow) {
        scr_locate(y, x + 2);
        scr_fillchar(' ', w + 2);
    }
}
