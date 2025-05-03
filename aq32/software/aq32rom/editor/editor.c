#include "common.h"
#include "regs.h"
#include "menu.h"
#include "screen.h"
#include "dialog.h"
#include "esp.h"
#include "editbuf.h"

#define EDITOR_ROWS    22
#define EDITOR_COLUMNS 78

struct editor_state {
    struct editbuf editbuf;

    char filename[64];
    int  cursor_line;
    int  cursor_pos;
    int  scr_first_line;
    int  scr_first_pos;
    bool modified;
};

struct editor_state state;

static void load_file(const char *path);
static void save_file(const char *path);
static void render_editor(void);

static void cmd_file_new(void);
static void cmd_file_open(void);
static void cmd_file_save(void);
static void cmd_file_save_as(void);
static void cmd_file_exit(void);

#pragma region Menus
static const struct menu_item menu_file_items[] = {
    {.title = "&New", .shortcut = KEY_MOD_CTRL | 'N', .status = "Removes currently loaded file from memory", .handler = cmd_file_new},
    {.title = "&Open...", .shortcut = KEY_MOD_CTRL | 'O', .status = "Loads new file into memory", .handler = cmd_file_open},
    {.title = "&Save", .shortcut = KEY_MOD_CTRL | 'S', .status = "Saves current file", .handler = cmd_file_save},
    {.title = "Save &As...", .shortcut = KEY_MOD_SHIFT | KEY_MOD_CTRL | 'S', .status = "Saves current file with specified name", .handler = cmd_file_save_as},
    {.title = "-"},
    {.title = "E&xit", .shortcut = KEY_MOD_CTRL | 'Q', .status = "Exits editor and returns to system", .handler = cmd_file_exit},
    {.title = NULL},
};

// static const struct menu_item menu_edit_items[] = {
//     {.title = "Cu&t", .shortcut = KEY_MOD_CTRL | 'X'},
//     {.title = "&Copy", .shortcut = KEY_MOD_CTRL | 'C'},
//     {.title = "&Paste", .shortcut = KEY_MOD_CTRL | 'V'},
//     {.title = "-"},
//     {.title = "&Find", .shortcut = KEY_MOD_CTRL | 'F'},
//     {.title = "&Replace", .shortcut = KEY_MOD_CTRL | 'H'},
//     {.title = "-"},
//     {.title = "&Select all", .shortcut = KEY_MOD_CTRL | 'A'},
//     {.title = "-"},
//     {.title = "Format document", .shortcut = KEY_MOD_SHIFT | KEY_MOD_ALT | 'F'},
//     {.title = "Format selection"},
//     {.title = "Trim trailing whitespace"},
//     {.title = NULL},
// };

// static const struct menu_item menu_view_items[] = {
//     {.title = "&Output Screen   F4"},
//     {.title = NULL},
// };

// static const struct menu_item menu_run_items[] = {
//     {.title = "&Start   F5"},
//     {.title = NULL},
// };

// static const struct menu_item menu_help_items[] = {
//     {.title = "&Index"},
//     {.title = "&Contents"},
//     {.title = "&Topic      F1"},
//     {.title = "-"},
//     {.title = "&About..."},
//     {.title = NULL},
// };

static const struct menu menubar_menus[] = {
    {.title = "&File", .items = menu_file_items},
    // {.title = "&Edit", .items = menu_edit_items},
    // {.title = "&View", .items = menu_view_items},
    // {.title = "&Run", .items = menu_run_items},
    // {.title = "&Help", .items = menu_help_items},
    {.title = NULL},
};
#pragma endregion

static void reset_state(void) {
    memset(&state, 0, sizeof(state));
    editbuf_init(&state.editbuf);
}

static int get_cursor_pos(void) {
    return min(state.cursor_pos, max(0, editbuf_get_line(&state.editbuf, state.cursor_line, NULL)));
}

static void update_cursor_pos(void) {
    state.cursor_pos = get_cursor_pos();
}

static bool check_modified(void) {
    if (!state.modified)
        return true;

    int result = dialog_confirm(NULL, "Save the changes made to the current document?");
    if (result < 0) {
        return false;
    }
    if (result > 0) {
        // Save document
        cmd_file_save();
        if (state.modified)
            return false;
    }
    return true;
}

static void cmd_file_new(void) {
    if (check_modified())
        reset_state();
}

static void cmd_file_open(void) {
    char tmp[256];
    if (dialog_open(tmp, sizeof(tmp))) {
        render_editor();
        if (check_modified()) {
            scr_status_msg("Loading file...");
            load_file(tmp);
        }
    }
}

static void cmd_file_save(void) {
    if (!state.filename[0]) {
        // File never saved, use 'save as' command instead.
        cmd_file_save_as();
        return;
    }
    if (!state.modified)
        return;

    save_file(state.filename);
}

static void cmd_file_save_as(void) {
    char tmp[64];
    strcpy(tmp, state.filename);
    if (!dialog_save(tmp, sizeof(tmp)))
        return;

    bool do_save = true;

    struct esp_stat st;
    if (esp_stat(tmp, &st) == 0) {
        // File exists
        render_editor();
        if (dialog_confirm(NULL, "Overwrite existing file?") <= 0)
            do_save = false;
    }

    if (do_save) {
        save_file(tmp);
    }
}

static void cmd_file_exit(void) {
}

static void render_editor(void) {
    for (int row = 0; row < EDITOR_ROWS; row++) {
        scr_locate(row + 2, 1);
        scr_setcolor(COLOR_EDITOR);

        int            line = state.scr_first_line + row;
        const uint8_t *p;
        int            line_len = editbuf_get_line(&state.editbuf, line, &p);

        if (line_len > state.scr_first_pos)
            p += state.scr_first_pos;

        line_len = clamp(line_len - state.scr_first_pos, 0, EDITOR_COLUMNS);

        if (line == state.cursor_line) {
            int cpos = get_cursor_pos();

            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                scr_setcolor(i == cpos - state.scr_first_pos ? COLOR_CURSOR : COLOR_EDITOR);

                if (i < line_len) {
                    scr_putchar(*(p++));
                } else {
                    scr_putchar(' ');
                }
            }

        } else {
            scr_putbuf(p, line_len);
            scr_setcolor(COLOR_EDITOR);
            scr_fillchar(' ', EDITOR_COLUMNS - line_len);
        }
    }
}

static void load_file(const char *path) {
    reset_state();
    snprintf(state.filename, sizeof(state.filename), "%s", path);

    int  line        = 0;
    bool do_truncate = false;

    FILE *f = fopen(path, "rt");
    if (f != NULL) {
        size_t linebuf_size = MAX_BUFSZ;
        char  *linebuf      = malloc(linebuf_size);
        int    line_size    = 0;
        while ((line_size = __getline(&linebuf, &linebuf_size, f)) >= 0) {
            // Strip of CR/LF
            while (line_size > 0 && (linebuf[line_size - 1] == '\r' || linebuf[line_size - 1] == '\n'))
                line_size--;
            linebuf[line_size] = 0;

            // Check line length
            if (!do_truncate && line_size > MAX_LINESZ) {
                if (dialog_confirm("Error", "Line longer than 254 characters. Truncate long lines?") <= 0) {
                    reset_state();
                    break;
                }
                do_truncate = true;
            }

            line_size = min(line_size, MAX_LINESZ);

            editbuf_insert_line(&state.editbuf, line, linebuf, line_size);
            line++;
        }

        fclose(f);
        free(linebuf);
    }
}

static void save_file(const char *path) {
    scr_status_msg("Saving file...");

    FILE *f = fopen(path, "wb");
    if (!f)
        return;

    int line_count = editbuf_get_line_count(&state.editbuf);
    for (int line = 0; line < line_count; line++) {
        const uint8_t *p;
        int            line_len = editbuf_get_line(&state.editbuf, line, &p);
        if (line_len < 0)
            break;

        if (line_len > 0)
            fwrite(p, line_len, 1, f);
        fputc('\n', f);
    }
    fclose(f);

    snprintf(state.filename, sizeof(state.filename), "%s", path);
    state.modified = false;
}

static void render_editor_border(void) {
    char title[65];
    snprintf(title, sizeof(title), "%s%s", *state.filename ? state.filename : "Untitled", state.modified ? "\x88" : "");
    scr_draw_border(1, 0, 80, 24, COLOR_EDITOR, BORDER_FLAG_NO_BOTTOM | BORDER_FLAG_NO_SHADOW | BORDER_FLAG_TITLE_INVERSE, title);
}

static void render_statusbar(void) {
    char tmp[64];

    // uint8_t *p = getline_addr(state.cursor_line);
    // snprintf(tmp, sizeof(tmp), "p[0]=%u p[1]=%u lines=%u cursor_line=%d scr_first_line=%d", p[0], p[1], state.num_lines, state.cursor_line, state.scr_first_line);

    scr_status_msg("");
    scr_setcolor(COLOR_STATUS2);
    scr_putchar(26);

    int line_len = editbuf_get_line(&state.editbuf, state.cursor_line, NULL);
    int cpos     = min(line_len, state.cursor_pos);

    snprintf(tmp, sizeof(tmp), " %05d:%03d ", state.cursor_line + 1, cpos + 1);
    scr_puttext(tmp);
}

static void menu_redraw_screen(void) {
    render_editor_border();
    render_editor();
}

void editor(void) {
    reset_state();

    while (1) {
        menubar_render(menubar_menus, false, NULL);
        render_editor_border();
        render_editor();
        render_statusbar();

        int key;
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            if ((key & KEY_KEYDOWN) && (scancode == SCANCODE_LALT || scancode == SCANCODE_RALT)) {
                menubar_handle(menubar_menus, menu_redraw_screen);
            }

        } else {
            uint8_t ch = key & 0xFF;
            switch (ch) {
                case CH_UP: state.cursor_line--; break;
                case CH_DOWN: state.cursor_line++; break;
                case CH_LEFT: {
                    update_cursor_pos();
                    state.cursor_pos--;
                    if (state.cursor_pos < 0 && state.cursor_line > 0) {
                        state.cursor_line--;
                        state.cursor_pos = editbuf_get_line(&state.editbuf, state.cursor_line, NULL);
                    }
                    break;
                }
                case CH_RIGHT: {
                    state.cursor_pos++;
                    if (state.cursor_pos > editbuf_get_line(&state.editbuf, state.cursor_line, NULL)) {
                        state.cursor_line++;
                        state.cursor_pos = 0;
                    }
                    break;
                }
                case CH_HOME: {
                    if (key & KEY_MOD_CTRL) {
                        state.cursor_line = 0;
                    }
                    state.cursor_pos = 0;
                    break;
                }
                case CH_END: {
                    if (key & KEY_MOD_CTRL) {
                        state.cursor_line = editbuf_get_line_count(&state.editbuf);

                    } else {
                        state.cursor_pos = editbuf_get_line(&state.editbuf, state.cursor_line, NULL);
                    }
                    break;
                }
                case CH_PAGEUP: state.cursor_line -= (EDITOR_ROWS - 1); break;
                case CH_PAGEDOWN: state.cursor_line += (EDITOR_ROWS - 1); break;
                case CH_DELETE: {
                    update_cursor_pos();
                    editbuf_delete_ch(&state.editbuf, state.cursor_line, state.cursor_pos);
                    break;
                }
                case CH_BACKSPACE: {
                    update_cursor_pos();
                    if (state.cursor_line <= 0 && state.cursor_pos <= 0)
                        break;

                    if (state.cursor_pos > 0) {
                        state.cursor_pos--;
                    } else {
                        state.cursor_line--;
                        state.cursor_pos = editbuf_get_line(&state.editbuf, state.cursor_line, NULL);
                    }

                    editbuf_delete_ch(&state.editbuf, state.cursor_line, state.cursor_pos);
                    state.modified = true;
                    break;
                }
                case CH_ENTER: {
                    update_cursor_pos();
                    editbuf_split_line(&state.editbuf, state.cursor_line, state.cursor_pos);
                    state.cursor_line++;
                    state.cursor_pos = 0;
                    state.modified   = true;
                    break;
                }
                case CH_TAB: {
                    break;
                }
                default: {
                    if (key & (KEY_MOD_CTRL | KEY_MOD_ALT)) {
                        uint16_t       shortcut = (key & (KEY_MOD_CTRL | KEY_MOD_SHIFT | KEY_MOD_ALT)) | toupper(ch);
                        menu_handler_t handler  = menubar_find_shortcut(menubar_menus, shortcut);
                        if (handler) {
                            handler();
                            break;
                        }
                    }

                    if ((ch >= ' ' && ch <= '~') || (ch >= 0xA0)) {
                        update_cursor_pos();
                        if (editbuf_insert_ch(&state.editbuf, state.cursor_line, state.cursor_pos, ch))
                            state.cursor_pos++;
                        state.modified = true;
                    }
                    break;
                }
            }
        }

        state.cursor_line    = clamp(state.cursor_line, 0, editbuf_get_line_count(&state.editbuf));
        state.cursor_pos     = max(0, state.cursor_pos);
        state.scr_first_line = clamp(state.scr_first_line, max(0, state.cursor_line - (EDITOR_ROWS - 1)), state.cursor_line);
        state.scr_first_pos  = clamp(state.scr_first_pos, max(0, get_cursor_pos() - (EDITOR_COLUMNS - 1)), get_cursor_pos());
    }
}
