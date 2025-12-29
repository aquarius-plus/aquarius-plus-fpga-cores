#include "scr.h"

int mode = MODE_SFX;

screen_t *scr_get_current(void) {
    switch (mode) {
        default:
        case MODE_CODE: return &scr_code;
        case MODE_SPRITE: return &scr_sprite;
        case MODE_MAP: return &scr_map;
        case MODE_SFX: return &scr_sfx;
        case MODE_MUSIC: return &scr_music;
    }
}

void scr_common(unsigned bg_col) {
    fill_rect(&(rect_t){0, 0, 199, 6}, 8);
    fill_rect(&(rect_t){0, 7, 199, 152}, bg_col);
    fill_rect(&(rect_t){0, 159 - 6, 199, 159}, 2);

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

void scr_mouse(int x, int y, int buttons, int clicked_buttons, int wheel) {
    if (buttons == clicked_buttons && clicked_buttons == 1) {
        int buttons_left = 200 - 5 * 8;
        if (y < 7 && x >= buttons_left && x < 200) {
            mode = MODE_CODE + (x - buttons_left) / 8;
            return;
        }
    }

    screen_t *scr = scr_get_current();
    if (scr->on_mouse) {
        scr->on_mouse(&(mouse_event_t){x, y, buttons, clicked_buttons, wheel});
    }
}

void scr_key(uint16_t key) {
    if (key == CH_F1) {
        mode = MODE_CODE;
    } else if (key == CH_F2) {
        mode = MODE_SPRITE;
    } else if (key == CH_F3) {
        mode = MODE_MAP;
    } else if (key == CH_F4) {
        mode = MODE_SFX;
    } else if (key == CH_F5) {
        mode = MODE_MUSIC;
    } else {

        screen_t *scr = scr_get_current();
        if (scr->on_key)
            scr->on_key(key);
    }
}
