#include "scr.h"

int mode = MODE_CODE;

void scr_common(unsigned bg_col) {
    fill_rect(0, 0, 199, 6, 8);
    fill_rect(0, 7, 199, 152, bg_col);
    fill_rect(0, 159 - 6, 199, 159, 2);

    // Mode icons
    {
        int x = 200 - 5 * 8;
        draw_icon(x, 1, 0, mode == MODE_CODE ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 1, mode == MODE_SPRITE ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 2, mode == MODE_MAP ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 3, mode == MODE_SFX ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 4, mode == MODE_MUSIC ? 7 : 2);
    }

    const char *title = "";
    switch (mode) {
        case MODE_CODE: title = "Code editor"; break;
        case MODE_SPRITE: title = "Sprite editor"; break;
        case MODE_MAP: title = "Map editor"; break;
        case MODE_SFX: title = "Sound effects editor"; break;
        case MODE_MUSIC: title = "Music editor"; break;
    }
    draw_text(title, 1, 1, 15, true);
}
