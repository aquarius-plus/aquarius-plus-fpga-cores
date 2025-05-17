#include "editor.h"
#include "common.h"
#include "regs.h"
#include "menu.h"
#include "esp.h"
#include "editbuf.h"

#define CLIPBOARD_PATH "/.editor-clipboard"

#define EDITOR_ROWS    22
#define EDITOR_COLUMNS 78
#define TAB_SIZE       2

struct editor_state {
    struct editbuf *editbuf;
    char            filename[64];
    location_t      loc_cursor;
    location_t      loc_selection;
    int             scr_first_line;
    int             scr_first_pos;

    location_t loc_selection_from;
    location_t loc_selection_to;
};

struct editor_state state;

static int  load_file(const char *path);
static void save_file(const char *path);

static void reset_state(void) {
    editbuf_reset(state.editbuf);
    state.filename[0]    = 0;
    state.loc_cursor     = (location_t){0, 0};
    state.loc_selection  = (location_t){-1, -1};
    state.scr_first_line = 0;
    state.scr_first_pos  = 0;
}

static bool has_selection(void) {
    return state.loc_selection.line >= 0;
}

static void clear_selection(void) {
    state.loc_selection = (location_t){-1, -1};
}

static void update_selection_range(void) {
    if (loc_lt(state.loc_cursor, state.loc_selection)) {
        state.loc_selection_to   = state.loc_selection;
        state.loc_selection_from = state.loc_cursor;
    } else {
        state.loc_selection_to   = state.loc_cursor;
        state.loc_selection_from = state.loc_selection;
    }
}

static bool in_selection(location_t loc) {
    if (!has_selection())
        return false;

    update_selection_range();
    return (loc_lt(loc, state.loc_selection_to) && !loc_lt(loc, state.loc_selection_from));
}

static int get_cursor_pos(void) {
    return min(state.loc_cursor.pos, max(0, editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL)));
}

static void update_cursor_pos(void) {
    state.loc_cursor.pos = get_cursor_pos();
}

static bool check_modified(void) {
    if (!editbuf_get_modified(state.editbuf))
        return true;

    int result = dialog_confirm(NULL, "Save the changes made to the current document?");
    if (result < 0) {
        return false;
    }
    if (result > 0) {
        // Save document
        cmd_file_save();
        if (editbuf_get_modified(state.editbuf))
            return false;
    }
    return true;
}

void cmd_file_new(void) {
    if (check_modified())
        reset_state();
}

void cmd_file_open(void) {
    char tmp[256];
    if (dialog_open(tmp, sizeof(tmp))) {
        editor_redraw_screen();
        if (check_modified()) {
            scr_status_msg("Loading file...");
            load_file(tmp);
        }
    }
}

void cmd_file_save(void) {
    if (!state.filename[0]) {
        // File never saved, use 'save as' command instead.
        cmd_file_save_as();
        return;
    }
    if (!editbuf_get_modified(state.editbuf))
        return;

    save_file(state.filename);
}

void cmd_file_save_as(void) {
    char tmp[64];
    strcpy(tmp, state.filename);
    if (!dialog_save(tmp, sizeof(tmp)))
        return;

    bool do_save = true;

    struct esp_stat st;
    if (esp_stat(tmp, &st) == 0) {
        // File exists
        editor_redraw_screen();
        if (dialog_confirm(NULL, "Overwrite existing file?") <= 0)
            do_save = false;
    }

    if (do_save) {
        save_file(tmp);
    }
}

void cmd_file_exit(void) {
    if (check_modified()) {
        asm("j 0");
    }
}

static void render_editor(void) {
    for (int row = 0; row < EDITOR_ROWS; row++) {
        scr_locate(row + 2, 1);
        scr_setcolor(COLOR_EDITOR);

        location_t     loc = (location_t){state.scr_first_line + row, 0};
        const uint8_t *p;
        int            line_len = editbuf_get_line(state.editbuf, loc.line, &p);

        if (line_len > state.scr_first_pos)
            p += state.scr_first_pos;

        line_len = clamp(line_len - state.scr_first_pos, 0, EDITOR_COLUMNS);

        if (loc.line == state.loc_cursor.line) {
            int cpos = get_cursor_pos();

            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                loc.pos = state.scr_first_pos + i;
                scr_setcolor(
                    (i == cpos - state.scr_first_pos)
                        ? COLOR_CURSOR
                        : (in_selection(loc) ? COLOR_SELECTED : COLOR_EDITOR));

                if (i < line_len) {
                    scr_putchar(*(p++));
                } else {
                    if (i > line_len)
                        scr_setcolor(COLOR_EDITOR);
                    scr_putchar(' ');
                }
            }

        } else if (loc.line == state.loc_selection.line) {
            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                loc.pos = state.scr_first_pos + i;
                scr_setcolor(
                    (in_selection(loc) ? COLOR_SELECTED : COLOR_EDITOR));

                if (i < line_len) {
                    scr_putchar(*(p++));
                } else {
                    if (i > line_len)
                        scr_setcolor(COLOR_EDITOR);
                    scr_putchar(' ');
                }
            }

        } else {
            if (in_selection(loc))
                scr_setcolor(COLOR_SELECTED);

            scr_putbuf(p, line_len);
            int fill_sz = EDITOR_COLUMNS - line_len;
            if (fill_sz > 0) {
                scr_putchar(' ');
                fill_sz--;
            }

            scr_setcolor(COLOR_EDITOR);
            scr_fillchar(' ', fill_sz);
        }
    }
}

static int load_file(const char *path) {
    scr_status_msg("Loading file...");

    reset_state();
    if (!editbuf_load(state.editbuf, path)) {
        dialog_message("Error", "Error loading file!");
        return -1;
    }
    snprintf(state.filename, sizeof(state.filename), "%s", path);
    return 0;
}

static void save_file(const char *path) {
    scr_status_msg("Saving file...");

    if (!editbuf_save(state.editbuf, path)) {
        dialog_message("Error", "Error saving file!");
        return;
    }
    snprintf(state.filename, sizeof(state.filename), "%s", path);
}

static void save_range(const char *path, location_t from, location_t to) {
    FILE *f = fopen(path, "wt");
    if (f == NULL)
        return;

    int line = from.line;

    const uint8_t *p_line;
    int            line_len = editbuf_get_line(state.editbuf, line, &p_line);
    if (from.pos < line_len) {
        if (from.line == to.line) {
            fwrite(p_line + from.pos, to.pos - from.pos, 1, f);
            goto done;
        }
        fwrite(p_line + from.pos, line_len - from.pos, 1, f);
        fputc('\n', f);
    }

    for (line = from.line + 1; line < to.line; line++) {
        line_len = editbuf_get_line(state.editbuf, line, &p_line);
        if (line_len > 0)
            fwrite(p_line, line_len, 1, f);
        fputc('\n', f);
    }

    {
        line_len  = editbuf_get_line(state.editbuf, line, &p_line);
        int count = min(line_len, to.pos);
        if (count > 0)
            fwrite(p_line, count, 1, f);
    }

done:
    fclose(f);
}

static void insert_ch(uint8_t ch) {
    update_cursor_pos();
    if (editbuf_insert_ch(state.editbuf, state.loc_cursor, ch)) {
        state.loc_cursor.pos++;
    }
}

void cmd_edit_cut(void) {
    if (!has_selection())
        return;

    // Save range
    scr_status_msg("Writing to clipboard file...");
    update_selection_range();
    save_range(CLIPBOARD_PATH, state.loc_selection_from, state.loc_selection_to);

    // Delete range
}

void cmd_edit_copy(void) {
    if (!has_selection())
        return;

    scr_status_msg("Writing to clipboard file...");
    update_selection_range();
    save_range(CLIPBOARD_PATH, state.loc_selection_from, state.loc_selection_to);
}
void cmd_edit_paste(void) {
    clear_selection();

    // FILE *f = fopen(CLIPBOARD_PATH, "rt");
    // if (f == NULL)
    //     return;

    // int ch;

    // while ((ch = fgetc(f)) >= 0) {
    //     if (!is_cntrl(ch))
    //         insert_ch(ch);
    //     else if (ch == '\n') {
    //         if (editbuf_split_line(state.editbuf, state.loc_cursor)) {
    //             state.loc_cursor.line++;
    //             state.loc_cursor.pos = 0;
    //         }
    //     }
    // }
    // fclose(f);
}
void cmd_edit_select_all(void) {
    state.loc_selection.line = 0;
    state.loc_selection.pos  = 0;
    state.loc_cursor.line    = editbuf_get_line_count(state.editbuf);
}

static void render_editor_border(void) {
    char title[65];
    snprintf(title, sizeof(title), "%s%s", *state.filename ? state.filename : "Untitled", editbuf_get_modified(state.editbuf) ? "\x88" : "");
    scr_draw_border(1, 0, 80, 24, COLOR_EDITOR, BORDER_FLAG_NO_BOTTOM | BORDER_FLAG_NO_SHADOW | BORDER_FLAG_TITLE_INVERSE, title);
}

static void render_statusbar(void) {
    char tmp[64];

    tmp[0] = 0;

    snprintf(tmp, sizeof(tmp), "%d", editbuf_get_line_count(state.editbuf));

    // snprintf(tmp, sizeof(tmp), "%p", state.editbuf.p_buf);

    // uint8_t *p = getline_addr(state.loc_cursor.line);
    // snprintf(tmp, sizeof(tmp), "p[0]=%u p[1]=%u lines=%u cursor_line=%d scr_first_line=%d", p[0], p[1], state.num_lines, state.loc_cursor.line, state.scr_first_line);

    scr_status_msg(tmp);
    scr_setcolor(COLOR_STATUS2);
    scr_putchar(26);

    int line_len = editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL);
    int cpos     = min(line_len, state.loc_cursor.pos);

    snprintf(tmp, sizeof(tmp), " %05d:%03d ", state.loc_cursor.line + 1, cpos + 1);
    scr_puttext(tmp);
}

static void menu_redraw_screen(void) {
    render_editor_border();
    render_editor();
}

static int get_leading_spaces(void) {
    const uint8_t *p;
    int            line_len = editbuf_get_line(state.editbuf, state.loc_cursor.line, &p);
    if (line_len < 0)
        return 0;

    int leading_spaces = 0;
    for (int i = 0; i < line_len; i++) {
        if (p[i] != ' ')
            break;
        leading_spaces++;
    }
    return leading_spaces;
}

void editor_redraw_screen(void) {
    state.loc_cursor.line = clamp(state.loc_cursor.line, 0, editbuf_get_line_count(state.editbuf));
    state.loc_cursor.pos  = max(0, state.loc_cursor.pos);
    state.scr_first_line  = clamp(state.scr_first_line, max(0, state.loc_cursor.line - (EDITOR_ROWS - 1)), state.loc_cursor.line);
    state.scr_first_pos   = clamp(state.scr_first_pos, max(0, get_cursor_pos() - (EDITOR_COLUMNS - 1)), get_cursor_pos());

    menubar_render(menubar_menus, false, NULL);
    render_editor_border();
    render_editor();
    render_statusbar();
}

void editor(struct editbuf *eb) {
    state.editbuf = eb;

    reinit_video();
    reset_state();

    while (1) {
        editor_redraw_screen();

        int key;
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            if ((key & KEY_KEYDOWN) && (scancode == SCANCODE_LALT || scancode == SCANCODE_RALT)) {
                menubar_handle(menubar_menus, menu_redraw_screen);
            }

        } else {
            uint8_t ch = key & 0xFF;

            menu_handler_t handler = NULL;
            if ((key & (KEY_MOD_CTRL | KEY_MOD_ALT)) || is_cntrl(key)) {
                uint16_t shortcut = (key & (KEY_MOD_CTRL | KEY_MOD_SHIFT | KEY_MOD_ALT)) | toupper(ch);
                handler           = menubar_find_shortcut(menubar_menus, shortcut);
            }

            if (handler) {
                handler();
            } else {
                bool       check_other     = false;
                location_t prev_loc_cursor = state.loc_cursor;
                switch (ch) {
                    case CH_UP: state.loc_cursor.line--; break;
                    case CH_DOWN: state.loc_cursor.line++; break;
                    case CH_LEFT: {
                        update_cursor_pos();
                        state.loc_cursor.pos--;
                        if (state.loc_cursor.pos < 0 && state.loc_cursor.line > 0) {
                            state.loc_cursor.line--;
                            state.loc_cursor.pos = editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL);
                        }
                        break;
                    }
                    case CH_RIGHT: {
                        state.loc_cursor.pos++;
                        if (state.loc_cursor.pos > editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL)) {
                            state.loc_cursor.line++;
                            state.loc_cursor.pos = 0;
                        }
                        break;
                    }
                    case CH_HOME: {
                        if (key & KEY_MOD_CTRL) {
                            state.loc_cursor.line = 0;
                        }
                        state.loc_cursor.pos = 0;
                        break;
                    }
                    case CH_END: {
                        if (key & KEY_MOD_CTRL) {
                            state.loc_cursor.line = editbuf_get_line_count(state.editbuf);

                        } else {
                            state.loc_cursor.pos = editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL);
                        }
                        break;
                    }
                    case CH_PAGEUP: state.loc_cursor.line -= (EDITOR_ROWS - 1); break;
                    case CH_PAGEDOWN: state.loc_cursor.line += (EDITOR_ROWS - 1); break;
                    default: check_other = true;
                }

                // Start a new selection?
                if (!check_other && !has_selection() && (key & KEY_MOD_SHIFT) != 0) {
                    state.loc_selection = prev_loc_cursor;
                }

                if (check_other) {
                    switch (ch) {
                        case CH_DELETE: {
                            update_cursor_pos();
                            editbuf_delete_ch(state.editbuf, state.loc_cursor);
                            break;
                        }
                        case CH_BACKSPACE: {
                            update_cursor_pos();
                            if (state.loc_cursor.line <= 0 && state.loc_cursor.pos <= 0)
                                break;

                            if (state.loc_cursor.pos > 0) {
                                int leading_spaces = get_leading_spaces();
                                int count          = 1;

                                if (leading_spaces == state.loc_cursor.pos) {
                                    int pos = state.loc_cursor.pos;
                                    do {
                                        pos--;
                                    } while (pos % TAB_SIZE != 0);
                                    count = state.loc_cursor.pos - pos;
                                }

                                while (count > 0) {
                                    count--;
                                    state.loc_cursor.pos--;
                                    editbuf_delete_ch(state.editbuf, state.loc_cursor);
                                }
                            } else {
                                state.loc_cursor.line--;
                                state.loc_cursor.pos = editbuf_get_line(state.editbuf, state.loc_cursor.line, NULL);
                                editbuf_delete_ch(state.editbuf, state.loc_cursor);
                            }
                            break;
                        }
                        case CH_ENTER: {
                            update_cursor_pos();
                            int leading_spaces = min(state.loc_cursor.pos, get_leading_spaces());
                            if (editbuf_insert_ch(state.editbuf, state.loc_cursor, '\n')) {
                                state.loc_cursor.line++;
                                state.loc_cursor.pos = 0;

                                // Auto indent
                                while (leading_spaces > 0) {
                                    leading_spaces--;
                                    insert_ch(' ');
                                }
                            }
                            break;
                        }
                        case CH_TAB: {
                            update_cursor_pos();
                            int pos = state.loc_cursor.pos;
                            do {
                                pos++;
                            } while (pos % TAB_SIZE != 0);

                            int count = pos - state.loc_cursor.pos;
                            for (int i = 0; i < count; i++) {
                                insert_ch(' ');
                            }
                            break;
                        }
                        default: {
                            if ((key & (KEY_MOD_GUI | KEY_MOD_ALT | KEY_MOD_CTRL)) == 0 && !is_cntrl(ch))
                                insert_ch(ch);
                            break;
                        }
                    }
                }

                // Clear existing selection?
                if ((key & KEY_MOD_SHIFT) == 0) {
                    clear_selection();
                }
            }
        }
    }
}

void       editor_set_cursor(location_t loc) { state.loc_cursor = loc; }
location_t editor_get_cursor(void) { return state.loc_cursor; }
