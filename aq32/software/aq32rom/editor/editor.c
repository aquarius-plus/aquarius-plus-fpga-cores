#include "common.h"
#include "regs.h"
#include "menu.h"
#include "screen.h"
#include "dialog.h"
#include "esp.h"

#define EDITOR_ROWS    22
#define EDITOR_COLUMNS 78

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

uint8_t edit_buf[256 * 1024];

struct editor_state {
    char filename[64];
    int  cursor_line;
    int  cursor_pos;  // Wanted position
    int  cursor_pos2; // Actual position due to line length
    int  scr_first_line;
    int  scr_first_pos;
    int  num_lines;
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
    edit_buf[0] = 0;
    edit_buf[1] = 0;
}

static bool check_modified(void) {
    if (!state.modified)
        return true;

    int result = dialog_confirm("Save the changes made to the current document?");
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
        if (dialog_confirm("Overwrite existing file?") <= 0)
            do_save = false;
    }

    if (do_save) {
        save_file(tmp);
    }
}

static void cmd_file_exit(void) {
}

static uint8_t *getline_addr(int line) {
    if (line < 0)
        line = 0;

    uint8_t *p = edit_buf;
    while (line--) {
        int buf_len = *p;
        if (buf_len == 0)
            break;
        p += 1 + buf_len;
    }
    return p;
}

static void update_num_lines(void) {
    int cnt = 0;

    uint8_t *p = edit_buf;
    while (p[0]) {
        cnt++;
        p += 1 + p[0];
    }
    state.num_lines = cnt;
}

static uint8_t *get_end_of_edit_buf(void) {
    uint8_t *p = edit_buf;
    while (p[0]) {
        p += 1 + p[0];
    }
    return p;
}

static int getline_length(int line) {
    const uint8_t *p = getline_addr(line);
    if (p[0] == 0)
        return 0;
    return p[1];
}

static void render_editor(void) {
    const uint8_t *ps = getline_addr(state.scr_first_line);

    for (int line = 0; line < EDITOR_ROWS; line++) {
        int            buf_len  = *ps;
        const uint8_t *p_next   = ps;
        int            line_len = 0;

        if (buf_len > 0) {
            p_next = ps + 1 + buf_len;
            ps++;
            line_len = *(ps++);
        }

        if (line_len > state.scr_first_pos)
            ps += state.scr_first_pos;

        line_len = clamp(line_len - state.scr_first_pos, 0, EDITOR_COLUMNS);

        int fill_size = EDITOR_COLUMNS - line_len;

        scr_locate(line + 2, 1);
        scr_setcolor(COLOR_EDITOR);

        if (line == state.cursor_line - state.scr_first_line) {
            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                scr_setcolor(i == state.cursor_pos2 - state.scr_first_pos ? COLOR_CURSOR : COLOR_EDITOR);

                if (i < line_len) {
                    scr_putchar(*(ps++));
                } else {
                    scr_putchar(' ');
                }
            }

        } else {
            // scr_setcolor(COLOR_SELECTED);
            while (line_len--)
                scr_putchar(*(ps++));

            scr_setcolor(COLOR_EDITOR);
            scr_fillchar(' ', fill_size);
        }

        ps = p_next;
    }
}

static void load_file(const char *path) {
    reset_state();
    snprintf(state.filename, sizeof(state.filename), "%s", path);

    uint8_t *pd = edit_buf;

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

            // Limit line to 254 characters
            line_size = min(line_size, MAX_LINESZ);

            *(pd++) = line_size + 1; // Buf length
            *(pd++) = line_size;     // Line length
            memcpy(pd, linebuf, line_size);
            pd += line_size;
            state.num_lines++;
        }

        // Buf length = 0: last line
        *(pd++) = 0;
        *(pd++) = 0;

        fclose(f);
        free(linebuf);
    }
}

static void save_file(const char *path) {
    scr_status_msg("Saving file...");

    FILE *f = fopen(path, "wb");
    if (!f)
        return;

    uint8_t *p = edit_buf;
    while (1) {
        if (p[0] == 0)
            break;

        fwrite(p + 2, p[1], 1, f);
        fputc('\n', f);
        p += 1 + p[0];
    }
    fclose(f);

    snprintf(state.filename, sizeof(state.filename), "%s", path);
    state.modified = false;
}

static void resize_linebuffer(uint8_t *p, uint8_t new_size) {
    uint8_t cur_size = p[0];
    if (new_size == cur_size)
        return;

    uint8_t *p_next = p + 1 + p[0];
    uint8_t *p_end  = get_end_of_edit_buf() + 2;
    memmove(p + 1 + new_size, p_next, p_end - p_next);
    p[0] = new_size;
}

static void insert_char(uint8_t ch) {
    uint8_t *p             = getline_addr(state.cursor_line);
    uint8_t  cur_line_size = p[0] == 0 ? 0 : p[1];

    if (cur_line_size >= MAX_LINESZ) {
        // Line full
        return;
    }

    // Enough room in buffer to increase line size?
    if (p[0] < 1 + cur_line_size + 1) {
        resize_linebuffer(p, min(1 + cur_line_size + 15, MAX_BUFSZ));
    }

    uint8_t *p_cursor = p + 2 + state.cursor_pos2;
    memmove(p_cursor + 1, p_cursor, cur_line_size - state.cursor_pos2);
    *p_cursor = ch;
    p[1]++;
    state.cursor_pos = state.cursor_pos2 + 1;

    state.modified = true;
}

static void delete_char(void) {
    uint8_t *p = getline_addr(state.cursor_line);
    if (p[0] == 0)
        return;

    if (state.cursor_pos2 > p[1])
        state.cursor_pos2 = p[1];

    uint8_t *p_cursor = p + 2 + state.cursor_pos2;

    uint8_t cur_line_size = p[1];
    if (state.cursor_pos2 >= cur_line_size) {
        // Merge with next line
        uint8_t *pn        = p + 1 + p[0];
        uint8_t  pn_bufsz  = pn[0];
        uint8_t  pn_linesz = pn[1];
        if (pn_bufsz == 0 || p[1] + pn_linesz > MAX_LINESZ)
            return;

        uint8_t *eoeb = get_end_of_edit_buf();
        uint8_t *pnn  = pn + 1 + pn_bufsz;

        memmove(p_cursor, pn + 2, pn_linesz);
        p[1] += pn_linesz;

        unsigned new_bufsize = p[0] + 1 + pn_bufsz;
        if (new_bufsize > MAX_BUFSZ) {
            memmove(p + 1 + p[1] + 1, pnn, eoeb + 2 - pnn);
            new_bufsize = p[1] + 1;
        }
        p[0] = new_bufsize;

        return;

    } else {
        // Delete within line
        memmove(p_cursor, p_cursor + 1, cur_line_size - state.cursor_pos2 - 1);
        p[1]--;
    }

    state.modified = true;
}

// static void delete_line(void) {
//     uint8_t *p = getline_addr(cursor_line);
//     if (p[0] == 0)
//         return;

//     uint8_t *p_next = p + 1 + p[0];
//     uint8_t *p_end  = getline_addr(999999) + 2;
//     memmove(p, p_next, p_end - p_next);
// }

static void render_editor_border(void) {
    char title[65];
    snprintf(title, sizeof(title), "%s%s", *state.filename ? state.filename : "Untitled", state.modified ? "\x88" : "");
    scr_draw_border(1, 0, 80, 24, COLOR_EDITOR, BORDER_FLAG_NO_BOTTOM | BORDER_FLAG_NO_SHADOW | BORDER_FLAG_TITLE_INVERSE, title);
}

static void render_statusbar(void) {
    scr_status_msg("");
    scr_setcolor(COLOR_STATUS2);
    scr_putchar(26);

    char tmp[32];
    snprintf(tmp, sizeof(tmp), " %05d:%03d ", state.cursor_line + 1, state.cursor_pos2 + 1);
    scr_puttext(tmp);
}

static void menu_redraw_screen(void) {
    render_editor_border();
    render_editor();
}

void editor(void) {
    reset_state();

    while (1) {
        update_num_lines();
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
                    state.cursor_pos = state.cursor_pos2 - 1;
                    if (state.cursor_pos < 0 && state.cursor_line > 0) {
                        state.cursor_line--;
                        state.cursor_pos = getline_length(state.cursor_line);
                    }
                    break;
                }
                case CH_RIGHT: {
                    state.cursor_pos = state.cursor_pos2 + 1;
                    if (state.cursor_pos > getline_length(state.cursor_line)) {
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
                        state.cursor_line = state.num_lines;

                    } else {
                        state.cursor_pos = getline_length(state.cursor_line);
                    }
                    break;
                }
                case CH_PAGEUP: state.cursor_line -= (EDITOR_ROWS - 1); break;
                case CH_PAGEDOWN: state.cursor_line += (EDITOR_ROWS - 1); break;
                case CH_DELETE: delete_char(); break;
                case CH_BACKSPACE: {
                    if (state.cursor_pos2 > 0) {
                        state.cursor_pos2 = state.cursor_pos2 - 1;
                        state.cursor_pos  = state.cursor_pos2;
                        delete_char();
                    } else if (state.cursor_line > 0) {
                        state.cursor_line--;
                        state.cursor_pos2 = getline_length(state.cursor_line);
                        state.cursor_pos  = state.cursor_pos2;
                        delete_char();
                    }
                    break;
                }
                case CH_ENTER: {
                    split_line();
                    state.cursor_line++;
                    state.cursor_pos2 = 0;
                    state.cursor_pos  = state.cursor_pos2;
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
                        insert_char(ch);
                    }
                    break;
                }
            }
        }

        state.cursor_line    = clamp(state.cursor_line, 0, state.num_lines);
        state.cursor_pos     = max(0, state.cursor_pos);
        state.cursor_pos2    = min(state.cursor_pos, getline_length(state.cursor_line));
        state.scr_first_line = clamp(state.scr_first_line, max(0, state.cursor_line - (EDITOR_ROWS - 1)), state.cursor_line);
        state.scr_first_pos  = clamp(state.scr_first_pos, max(0, state.cursor_pos2 - (EDITOR_COLUMNS - 1)), state.cursor_pos2);
    }
}
