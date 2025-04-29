#include "dialog.h"
#include "screen.h"
#include "esp.h"

void dialog_open(void) {
    int w = 80 - 12;
    int h = 25 - 6;
    int x = (80 - w) / 2;
    int y = (25 - h) / 2;

    // Draw window border
    scr_draw_border(x, y, w, h, COLOR_MENU, true, "Open");
    y++;
    x++;
    w -= 2;

    // Draw current directory
    char cwd[256];
    getcwd((char *)cwd, sizeof(cwd));
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_puttext(" Current dir: ");

    int path_len = strlen(cwd);
    if (path_len > w - 14) {
        scr_puttext("...");
        scr_puttext(cwd + path_len - (w - 3 - 14));
    } else {
        scr_puttext(cwd);
        scr_fillchar(' ', w - 14 - path_len);
    }
    y++;

    // Draw separator
    scr_locate(y, x - 1);
    scr_putchar(19);
    for (int i = 0; i < w; i++)
        scr_putchar(25);
    scr_putchar(21);

    int key;
    while (1) {
        while ((key = REGS->KEYBUF) < 0);
        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            if (((key & KEY_KEYDOWN) && scancode == 0x29))
                return;
        }
    }
}
