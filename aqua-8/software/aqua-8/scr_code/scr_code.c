#include "scr.h"
#include "ctype2.h"
#include "colorize.h"
#include "edit_ops.h"

static void draw(void) {
    scr_common(1);

    code_edit_t *state = &edit_state.code_edit;

    // Mouse handling
    {
        rect_t r = {0, 7, 199, 152};
        if (mouse_clicked(&r, 1, MOUSE_SPR_IBEAM)) {
            state->loc_cursor.line = state->scr_first_line + (edit_state.mouse_ev.y - r.y0) / 7;
            state->loc_cursor.pos  = state->scr_first_pos + (edit_state.mouse_ev.x - r.x0) / 4;
        }
        state->scr_first_line += -edit_state.mouse_ev.wheel;
    }

    state->loc_cursor.line = clamp(state->loc_cursor.line, 0, editbuf_get_line_count(state->editbuf) - 1);
    state->loc_cursor.pos  = max(0, state->loc_cursor.pos);
    state->scr_first_line  = clamp(state->scr_first_line, max(0, state->loc_cursor.line - (EDITOR_ROWS - 1)), state->loc_cursor.line);
    state->scr_first_pos   = clamp(state->scr_first_pos, max(0, get_cursor_pos() - (EDITOR_COLUMNS - 1)), get_cursor_pos());

    for (int row = 0; row < EDITOR_ROWS; row++) {
        int y = 8 + row * 7;

        location_t     loc = (location_t){state->scr_first_line + row, 0};
        const uint8_t *p;
        int            line_len = editbuf_get_line(state->editbuf, loc.line, &p);
        const uint8_t *colors   = colorize(p, line_len, state->scr_first_pos);

        if (line_len > state->scr_first_pos) {
            p += state->scr_first_pos;
        }

        line_len = clamp(line_len - state->scr_first_pos, 0, EDITOR_COLUMNS);

        int  x              = 0;
        bool is_cursor_line = loc.line == state->loc_cursor.line;

        if (is_cursor_line || loc.line == state->loc_selection.line) {
            int cpos = get_cursor_pos();

            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                loc.pos = state->scr_first_pos + i;

                if (is_cursor_line && i == cpos - state->scr_first_pos) {
                    // Cursor
                    rect_t r;
                    r.x0 = x;
                    r.y0 = y - 1;
                    r.x1 = x + 4;
                    r.y1 = y + 5;
                    fill_rect(&r, 8);

                } else if (in_selection(loc)) {
                    // Selected
                    rect_t r;
                    r.x0 = x;
                    r.y0 = y - 1;
                    r.x1 = x + 3;
                    r.y1 = y + 5;
                    fill_rect(&r, 10);
                }

                if (i >= line_len)
                    break;

                draw_char_altfont(x + 1, y, *(p++), colors[i]);
                x += 4;
            }

        } else {
            if (in_selection(loc)) {
                rect_t r;
                r.x0 = 0;
                r.y0 = y - 1;
                r.x1 = line_len * 4 + 3;
                r.y1 = y + 5;
                fill_rect(&r, 10);
            }

            for (int i = 0; i < line_len; i++) {
                draw_char_altfont(x + 1, y, *(p++), colors[i]);
                x += 4;
            }
        }
    }

    // Status bar
    {
        const uint8_t *p;
        int            line_len = editbuf_get_line(state->editbuf, state->loc_cursor.line, &p);
        int            cpos     = min(line_len, state->loc_cursor.pos);

        snprintf(
            edit_state.status_text, sizeof(edit_state.status_text),
            "Line %d/%d Col %d",
            state->loc_cursor.line + 1, editbuf_get_line_count(state->editbuf),
            cpos + 1);
    }
}

static void on_key(uint16_t key) {
    code_edit_t *state = &edit_state.code_edit;

    if ((key & KEY_IS_SCANCODE) == 0) {
        uint8_t ch = key & 0xFF;

        // menu_handler_t handler = NULL;
        // if ((key & (KEY_MOD_CTRL | KEY_MOD_ALT)) || is_cntrl(key)) {
        //     uint16_t shortcut = (key & (KEY_MOD_CTRL | KEY_MOD_SHIFT | KEY_MOD_ALT)) | toupper(ch);
        //     handler           = menubar_find_shortcut(menubar_menus, shortcut);
        // }

        // if (handler) {
        //     handler();
        // } else
        {
            bool       check_other     = false;
            location_t prev_loc_cursor = state->loc_cursor;
            switch (ch) {
                case CH_UP: op_cursor_up(); break;
                case CH_DOWN: op_cursor_down(); break;
                case CH_LEFT: op_cursor_left(); break;
                case CH_RIGHT: op_cursor_right(); break;
                case CH_HOME: op_cursor_home((key & KEY_MOD_CTRL) != 0); break;
                case CH_END: op_cursor_end((key & KEY_MOD_CTRL) != 0); break;
                case CH_PAGEUP: op_cursor_page_up(); break;
                case CH_PAGEDOWN: op_cursor_page_down(); break;
                default: check_other = true;
            }

            // Start a new selection?
            if (!check_other && !has_selection() && (key & KEY_MOD_SHIFT) != 0) {
                state->loc_selection = prev_loc_cursor;
            }

            bool keep_selection = false;

            if (check_other) {
                switch (ch) {
                    case CH_DELETE: op_delete(); break;
                    case CH_BACKSPACE: op_backspace(); break;
                    case CH_ENTER: op_enter(); break;
                    case CH_TAB: keep_selection |= op_tab((key & KEY_MOD_SHIFT) != 0); break;
                    default: {
                        if ((key & (KEY_MOD_GUI | KEY_MOD_ALT | KEY_MOD_CTRL)) == 0 && !is_cntrl(ch))
                            op_insert_ch(ch);
                        break;
                    }
                }
            }

            // Clear existing selection?
            if ((key & KEY_MOD_SHIFT) == 0 && !keep_selection) {
                clear_selection();
            }
        }
    }
}

static editbuf_t editbuf;
static uint8_t   code_buf[64 * 1024];

static void _init(void) {
    code_edit_t *state = &edit_state.code_edit;

    reset_state();

    editbuf_init(&editbuf, code_buf, sizeof(code_buf));
    if (editbuf_load(&editbuf, "/test.lua")) {
        edit_state.mode = MODE_CODE;
    }
    state->editbuf = &editbuf;
}

screen_t scr_code = {
    .init   = _init,
    .draw   = draw,
    .on_key = on_key,
};
