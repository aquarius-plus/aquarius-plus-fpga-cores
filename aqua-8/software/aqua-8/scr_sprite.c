#include "scr.h"

static void draw(void) {
    scr_common(5);

    int x, y;

    // draw_text("#0", 1, 8, 7, false);

    // Palette
    {
        x = 1;
        y = 8;

        draw_rect(x, y, x + 1 + 64, y + 1 + 16, 0);
        x += 1;
        y += 1;

        for (int i = 0; i < 16; i++) {
            int row = i / 8;
            int col = i % 8;

            fill_rect(
                x + col * 8, y + row * 8,
                x + col * 8 + 7, y + row * 8 + 7,
                i);
        }
    }

    // Sprite overview
    {
        x = 200 - 128 - 3;
        y = 8;
        draw_rect(x, y, x + 1 + 128, y + 1 + 128, 0);
        fill_rect(x + 1, y + 1, x + 128, y + 128, 0);
        x += 1;
        y += 1;

        for (int i = 0; i < 256; i++) {
            int row = i / 16;
            int col = i % 16;

            draw_game_sprite(i, x + col * 8, y + row * 8);
        }
    }

    // Sprite editor
    {
        x = 1;
        y = 27;
        draw_rect(x, y, x + 1 + 64, y + 1 + 64, 0);
    }

    // Commands
    {
        unsigned color     = 13;
        unsigned color_sel = 7;

        x = 5;
        y = 98;

        for (int i = 0; i < 6; i++) {
            draw_icon(x + i * 10, y, 16 + i, i == 0 ? color_sel : color);
        }

        y += 9;
        for (int i = 0; i < 6; i++) {
            draw_icon(x + i * 10, y, 32 + i, color);
        }
    }
}

screen_t scr_sprite = {
    .draw = draw,
};
