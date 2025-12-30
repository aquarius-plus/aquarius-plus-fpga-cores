#include "scr.h"

static void draw(void) {
    scr_common(1);
    snprintf(edit_state.status_text, sizeof(edit_state.status_text), "Line 1/%d Col 1", editbuf_get_line_count(&edit_state.code_edit.editbuf));

    {
        rect_t r = {0, 7, 199, 152};
        if (mouse_clicked(&r, 1, MOUSE_SPR_IBEAM)) {
            edit_state.code_edit.cursor.pos  = (edit_state.mouse_ev.x - 1) / 4;
            edit_state.code_edit.cursor.line = (edit_state.mouse_ev.y - 7) / 7;
        }
    }

    // Draw cursor
    {
        rect_t r;
        r.x0 = edit_state.code_edit.cursor.pos * 4;
        r.y0 = 7 + edit_state.code_edit.cursor.line * 7;
        r.x1 = r.x0 + 4;
        r.y1 = r.y0 + 6;

        fill_rect(&r, 8);
    }

    int y    = 8;
    int line = 0;
    for (int j = 0; j < 21; j++) {
        const uint8_t *p;
        int            len = editbuf_get_line(&edit_state.code_edit.editbuf, line, &p);

        int x = 1;
        for (int i = 0; i < len; i++) {
            draw_char_altfont(x, y, p[i], 6);
            x += 4;
        }

        y += 7;
        line++;
    }

    // char bla[32];
    // snprintf(bla, sizeof(bla), "bla: %u", sec);
    // draw_text(bla, 50, 50, 7, false);
    // snprintf(bla, sizeof(bla), "last: %04x", last);
    // draw_text(bla, 50, 60, 7, false);

    // VRAM4BIT[0]++;
}

static void on_key(uint16_t code) {
    if ((code & KEY_IS_SCANCODE) == 0) {
        unsigned key = (code & (KEY_MODIFIERS | KEY_CODE_MASK));

        switch (key) {
            case CH_UP: edit_state.code_edit.cursor.line--; break;
            case CH_DOWN: edit_state.code_edit.cursor.line++; break;
            case CH_LEFT: edit_state.code_edit.cursor.pos--; break;
            case CH_RIGHT: edit_state.code_edit.cursor.pos++; break;

            default: {
                uint8_t ch = code & 0xFF;

                if (ch >= ' ' && ch <= '~') {
                    if (editbuf_insert_ch(&edit_state.code_edit.editbuf, edit_state.code_edit.cursor, ch)) {
                        edit_state.code_edit.cursor.pos++;
                    }
                }

                break;
            }
        }
    }
}

screen_t scr_code = {
    .draw   = draw,
    .on_key = on_key,
};
