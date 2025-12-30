#include "scr.h"
#include "ctype2.h"

#define EDITOR_ROWS    21
#define EDITOR_COLUMNS 50
#define TAB_SIZE       1

static inline bool has_selection(void) { return edit_state.code_edit.loc_selection.line >= 0; }
static inline void clear_selection(void) { edit_state.code_edit.loc_selection = (location_t){-1, -1}; }
static inline int  get_cursor_pos(void) { return min(edit_state.code_edit.loc_cursor.pos, max(0, editbuf_get_line(edit_state.code_edit.editbuf, edit_state.code_edit.loc_cursor.line, NULL))); }
static inline void update_cursor_pos(void) { edit_state.code_edit.loc_cursor.pos = get_cursor_pos(); }

void reset_state(void) {
    code_edit_t *state = &edit_state.code_edit;

    editbuf_reset(state->editbuf);
    state->filename[0]    = 0;
    state->loc_cursor     = (location_t){0, 0};
    state->loc_selection  = (location_t){-1, -1};
    state->scr_first_line = 0;
    state->scr_first_pos  = 0;
}

void update_selection_range(void) {
    code_edit_t *state = &edit_state.code_edit;

    if (loc_lt(state->loc_cursor, state->loc_selection)) {
        state->loc_selection_to   = state->loc_selection;
        state->loc_selection_from = state->loc_cursor;
    } else {
        state->loc_selection_to   = state->loc_cursor;
        state->loc_selection_from = state->loc_selection;
    }
}

static bool in_selection(location_t loc) {
    code_edit_t *state = &edit_state.code_edit;

    if (!has_selection())
        return false;

    update_selection_range();
    return (loc_lt(loc, state->loc_selection_to) && !loc_lt(loc, state->loc_selection_from));
}

static int get_leading_spaces(int line) {
    code_edit_t *state = &edit_state.code_edit;

    const uint8_t *p;
    int            line_len = editbuf_get_line(state->editbuf, line, &p);
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

static void delete_selection(void) {
    code_edit_t *state = &edit_state.code_edit;

    if (has_selection()) {
        update_selection_range();
        editbuf_delete_range(state->editbuf, state->loc_selection_from, state->loc_selection_to);
        state->loc_cursor = state->loc_selection_from;
    }
}

bool loc_dec(location_t *loc) {
    code_edit_t *state = &edit_state.code_edit;

    if (loc->pos > 0) {
        loc->pos--;
    } else if (loc->line > 0) {
        loc->line--;
        loc->pos = editbuf_get_line(state->editbuf, loc->line, NULL);
    } else {
        return false;
    }
    return true;
}

void loc_inc(location_t *loc) {
    code_edit_t *state = &edit_state.code_edit;

    int line_len = editbuf_get_line(state->editbuf, loc->line, NULL);
    if (loc->pos < line_len) {
        loc->pos++;
    } else if (loc->line + 1 < editbuf_get_line_count(state->editbuf)) {
        loc->line++;
        loc->pos = 0;
    }
}

static void forward_delete(void) {
    code_edit_t *state = &edit_state.code_edit;

    location_t loc_to = state->loc_cursor;
    loc_inc(&loc_to);
    editbuf_delete_range(state->editbuf, state->loc_cursor, loc_to);
}

static void backward_delete(void) {
    code_edit_t *state = &edit_state.code_edit;

    if (loc_dec(&state->loc_cursor))
        forward_delete();
}

static void insert_ch(uint8_t ch) {
    code_edit_t *state = &edit_state.code_edit;

    update_cursor_pos();
    if (editbuf_insert_ch(state->editbuf, state->loc_cursor, ch)) {
        state->loc_cursor.pos++;
    }
}

static int indent_line(int line) {
    code_edit_t *state = &edit_state.code_edit;

    int spaces = get_leading_spaces(line);

    spaces %= TAB_SIZE;
    int count = TAB_SIZE - spaces;

    for (int i = 0; i < count; i++)
        editbuf_insert_ch(state->editbuf, (location_t){line, 0}, ' ');

    return count;
}

static int unindent_line(int line) {
    code_edit_t *state = &edit_state.code_edit;

    int spaces = get_leading_spaces(line);
    int count  = (spaces % TAB_SIZE != 0) ? (spaces % TAB_SIZE) : TAB_SIZE;
    if (count > spaces)
        count = spaces;

    for (int i = 0; i < count; i++)
        editbuf_delete_ch(state->editbuf, (location_t){line, 0});

    return count;
}

static uint8_t colors[EDITOR_COLUMNS];
static int     colorize_idx;

static void put_color(unsigned color) {
    if (colorize_idx >= 0 && colorize_idx < EDITOR_COLUMNS)
        colors[colorize_idx] = color;
    colorize_idx++;
}

#define COLOR_VALUE    12
#define COLOR_RESERVED 14
#define COLOR_BUILTIN  11
#define COLOR_IDENT    6
#define COLOR_NORMAL   7
#define COLOR_COMMENT  13

typedef struct {
    const char *name;
    uint8_t     len;
    uint8_t     color;
} reserved_t;

#define ENTRY(a, color) \
    {a, sizeof(a) - 1, color}

static const reserved_t names[] = {
    // LUA reserved words
    ENTRY("and", COLOR_RESERVED),
    ENTRY("break", COLOR_RESERVED),
    ENTRY("do", COLOR_RESERVED),
    ENTRY("else", COLOR_RESERVED),
    ENTRY("elseif", COLOR_RESERVED),
    ENTRY("end", COLOR_RESERVED),
    ENTRY("false", COLOR_VALUE),
    ENTRY("for", COLOR_RESERVED),
    ENTRY("function", COLOR_RESERVED),
    ENTRY("goto", COLOR_RESERVED),
    ENTRY("if", COLOR_RESERVED),
    ENTRY("in", COLOR_RESERVED),
    ENTRY("local", COLOR_RESERVED),
    ENTRY("nil", COLOR_VALUE),
    ENTRY("not", COLOR_RESERVED),
    ENTRY("or", COLOR_RESERVED),
    ENTRY("repeat", COLOR_RESERVED),
    ENTRY("return", COLOR_RESERVED),
    ENTRY("then", COLOR_RESERVED),
    ENTRY("true", COLOR_VALUE),
    ENTRY("until", COLOR_RESERVED),
    ENTRY("while", COLOR_RESERVED),

    // GFX API functions
    ENTRY("camera", COLOR_BUILTIN),
    ENTRY("clip", COLOR_BUILTIN),
    ENTRY("cls", COLOR_BUILTIN),
    ENTRY("color", COLOR_BUILTIN),
    ENTRY("pal", COLOR_BUILTIN),
    ENTRY("palt", COLOR_BUILTIN),
    ENTRY("fillp", COLOR_BUILTIN),
    ENTRY("flip", COLOR_BUILTIN),
    ENTRY("line", COLOR_BUILTIN),
    ENTRY("rect", COLOR_BUILTIN),
    ENTRY("rectfill", COLOR_BUILTIN),
    ENTRY("rrect", COLOR_BUILTIN),
    ENTRY("rrectfill", COLOR_BUILTIN),
    ENTRY("oval", COLOR_BUILTIN),
    ENTRY("ovalfill", COLOR_BUILTIN),
    ENTRY("circ", COLOR_BUILTIN),
    ENTRY("circfill", COLOR_BUILTIN),
    ENTRY("pget", COLOR_BUILTIN),
    ENTRY("pset", COLOR_BUILTIN),
    ENTRY("print", COLOR_BUILTIN),
    ENTRY("printh", COLOR_BUILTIN),
    ENTRY("cursor", COLOR_BUILTIN),
    ENTRY("map", COLOR_BUILTIN),
    ENTRY("mget", COLOR_BUILTIN),
    ENTRY("mset", COLOR_BUILTIN),
    ENTRY("fget", COLOR_BUILTIN),
    ENTRY("fset", COLOR_BUILTIN),
    ENTRY("tline", COLOR_BUILTIN),
    ENTRY("spr", COLOR_BUILTIN),
    ENTRY("sspr", COLOR_BUILTIN),
    ENTRY("sget", COLOR_BUILTIN),
    ENTRY("sset", COLOR_BUILTIN),

    // Memory & data API function
    ENTRY("peek", COLOR_BUILTIN),
    ENTRY("poke", COLOR_BUILTIN),
    ENTRY("memset", COLOR_BUILTIN),
    ENTRY("memcpy", COLOR_BUILTIN),
    ENTRY("reload", COLOR_BUILTIN),
    ENTRY("cstore", COLOR_BUILTIN),
    ENTRY("scoresub", COLOR_BUILTIN),
    ENTRY("cartdata", COLOR_BUILTIN),
    ENTRY("dget", COLOR_BUILTIN),
    ENTRY("dset", COLOR_BUILTIN),

    // String
    ENTRY("sub", COLOR_BUILTIN),
    ENTRY("chr", COLOR_BUILTIN),
    ENTRY("ord", COLOR_BUILTIN),
    ENTRY("split", COLOR_BUILTIN),
    ENTRY("tostr", COLOR_BUILTIN),
    ENTRY("tonum", COLOR_BUILTIN),

    // Tables
    ENTRY("add", COLOR_BUILTIN),
    ENTRY("del", COLOR_BUILTIN),
    ENTRY("deli", COLOR_BUILTIN),
    ENTRY("all", COLOR_BUILTIN),
    ENTRY("foreach", COLOR_BUILTIN),
    ENTRY("pairs", COLOR_BUILTIN),

    ENTRY("setmetatable", COLOR_BUILTIN),
    ENTRY("getmetatable", COLOR_BUILTIN),
    ENTRY("rawset", COLOR_BUILTIN),
    ENTRY("rawget", COLOR_BUILTIN),
    ENTRY("rawequal", COLOR_BUILTIN),
    ENTRY("rawlen", COLOR_BUILTIN),

    // Audio API functions
    ENTRY("music", COLOR_BUILTIN),
    ENTRY("sfx", COLOR_BUILTIN),

    // System API functions
    ENTRY("run", COLOR_BUILTIN),
    ENTRY("stop", COLOR_BUILTIN),
    ENTRY("reset", COLOR_BUILTIN),
    ENTRY("yield", COLOR_BUILTIN),
    ENTRY("time", COLOR_BUILTIN),
    ENTRY("menuitem", COLOR_BUILTIN),
    ENTRY("stat", COLOR_BUILTIN),
    ENTRY("serial", COLOR_BUILTIN),
    ENTRY("extcmd", COLOR_BUILTIN),
    ENTRY("cocreate", COLOR_BUILTIN),
    ENTRY("coresume", COLOR_BUILTIN),
    ENTRY("costatus", COLOR_BUILTIN),

    // System commands
    ENTRY("load", COLOR_BUILTIN),

    // Input
    ENTRY("btn", COLOR_BUILTIN),
    ENTRY("btnp", COLOR_BUILTIN),

    // Math functions and operators
    ENTRY("cos", COLOR_BUILTIN),
    ENTRY("sin", COLOR_BUILTIN),
    ENTRY("atan2", COLOR_BUILTIN),
    ENTRY("sqrt", COLOR_BUILTIN),
    ENTRY("srand", COLOR_BUILTIN),
    ENTRY("rnd", COLOR_BUILTIN),
    ENTRY("max", COLOR_BUILTIN),
    ENTRY("min", COLOR_BUILTIN),
    ENTRY("mid", COLOR_BUILTIN),
    ENTRY("flr", COLOR_BUILTIN),
    ENTRY("ceil", COLOR_BUILTIN),
    ENTRY("sgn", COLOR_BUILTIN),
    ENTRY("abs", COLOR_BUILTIN),
    ENTRY("bnot", COLOR_BUILTIN),
    ENTRY("band", COLOR_BUILTIN),
    ENTRY("bor", COLOR_BUILTIN),
    ENTRY("bxor", COLOR_BUILTIN),
    ENTRY("shl", COLOR_BUILTIN),
    ENTRY("shr", COLOR_BUILTIN),
    ENTRY("lshr", COLOR_BUILTIN),
    ENTRY("rotl", COLOR_BUILTIN),
    ENTRY("rotr", COLOR_BUILTIN),
};

static unsigned get_name_color(const uint8_t *name, int len) {
    for (unsigned i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
        if (len == names[i].len && memcmp(names[i].name, name, len) == 0)
            return names[i].color;
    }

    return COLOR_IDENT;
}

static void colorize(const uint8_t *p, int len, int first_pos) {
    colorize_idx         = -first_pos;
    const uint8_t *p_end = p + len;

    while (p < p_end && colorize_idx < EDITOR_COLUMNS) {
        // Comment?
        if (p[0] == '-' && p[1] == '-') {
            while (colorize_idx < len && colorize_idx < EDITOR_COLUMNS)
                put_color(COLOR_COMMENT);

            // Done for this line
            return;
        }

        if (is_alpha(p[0]) || p[0] == '_') {
            const uint8_t *name = p;

            while (p < p_end && (is_alpha(p[0]) || is_decimal(p[0]) || p[0] == '_'))
                p++;
            int name_len = p - name;

            unsigned color = get_name_color(name, name_len);
            for (int i = 0; i < name_len; i++) {
                put_color(color);
            }

        } else if (is_decimal(p[0])) {
            const uint8_t *value = p;

            bool hexadecimal = false;
            if (p[0] == '0' && p[1] == 'x') {
                p += 2;
                hexadecimal = true;
            }

            while (p < p_end && (is_decimal(p[0]) || (hexadecimal && is_hexadecimal(p[0]))))
                p++;

            int value_len = p - value;
            for (int i = 0; i < value_len; i++) {
                put_color(COLOR_VALUE);
            }

        } else {
            put_color(COLOR_NORMAL);
            p++;
        }
    }
}

static void draw(void) {
    code_edit_t *state = &edit_state.code_edit;

    state->loc_cursor.line = clamp(state->loc_cursor.line, 0, editbuf_get_line_count(state->editbuf) - 1);
    state->loc_cursor.pos  = max(0, state->loc_cursor.pos);
    state->scr_first_line  = clamp(state->scr_first_line, max(0, state->loc_cursor.line - (EDITOR_ROWS - 1)), state->loc_cursor.line);
    state->scr_first_pos   = clamp(state->scr_first_pos, max(0, get_cursor_pos() - (EDITOR_COLUMNS - 1)), get_cursor_pos());

    scr_common(1);

    for (int row = 0; row < EDITOR_ROWS; row++) {
        int y = 8 + row * 7;

        location_t     loc = (location_t){state->scr_first_line + row, 0};
        const uint8_t *p;
        int            line_len = editbuf_get_line(state->editbuf, loc.line, &p);
        colorize(p, line_len, state->scr_first_pos);

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
#if 0
        unsigned key = (code & (KEY_MODIFIERS | KEY_CODE_MASK));

        switch (key) {
            case CH_UP: state->loc_cursor.line--; break;
            case CH_DOWN: state->loc_cursor.line++; break;
            case CH_LEFT: state->loc_cursor.pos--; break;
            case CH_RIGHT: state->loc_cursor.pos++; break;

            default: {
                uint8_t ch = code & 0xFF;

                if (ch >= ' ' && ch <= '~') {
                    if (editbuf_insert_ch(state->editbuf, edit_state.code_edit.loc_cursor, ch)) {
                        state->loc_cursor.pos++;
                    }
                }

                break;
            }
        }
#endif

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
                case CH_UP: state->loc_cursor.line--; break;
                case CH_DOWN: state->loc_cursor.line++; break;
                case CH_LEFT: {
                    update_cursor_pos();
                    loc_dec(&state->loc_cursor);
                    break;
                }
                case CH_RIGHT: {
                    update_cursor_pos();
                    loc_inc(&state->loc_cursor);
                    break;
                }
                case CH_HOME: {
                    if (key & KEY_MOD_CTRL) {
                        state->loc_cursor.line = 0;
                        state->loc_cursor.pos  = 0;
                    } else {
                        int leading_spaces    = get_leading_spaces(state->loc_cursor.line);
                        state->loc_cursor.pos = (state->loc_cursor.pos == leading_spaces) ? 0 : leading_spaces;
                    }
                    break;
                }
                case CH_END: {
                    if (key & KEY_MOD_CTRL)
                        state->loc_cursor.line = editbuf_get_line_count(state->editbuf) - 1;
                    state->loc_cursor.pos = editbuf_get_line(state->editbuf, state->loc_cursor.line, NULL);
                    break;
                }
                case CH_PAGEUP: state->loc_cursor.line -= (EDITOR_ROWS - 1); break;
                case CH_PAGEDOWN: state->loc_cursor.line += (EDITOR_ROWS - 1); break;
                default: check_other = true;
            }

            // Start a new selection?
            if (!check_other && !has_selection() && (key & KEY_MOD_SHIFT) != 0) {
                state->loc_selection = prev_loc_cursor;
            }

            bool keep_selection = false;

            if (check_other) {
                switch (ch) {
                    case CH_DELETE: {
                        update_cursor_pos();
                        if (has_selection()) {
                            delete_selection();
                        } else {
                            forward_delete();
                        }
                        break;
                    }
                    case CH_BACKSPACE: {
                        update_cursor_pos();
                        if (has_selection()) {
                            delete_selection();
                            break;
                        }
                        if (state->loc_cursor.line <= 0 && state->loc_cursor.pos <= 0)
                            break;

                        // Unindent?
                        if (state->loc_cursor.pos > 0 && state->loc_cursor.pos == get_leading_spaces(state->loc_cursor.line)) {
                            location_t loc_old = state->loc_cursor;
                            do {
                                loc_dec(&state->loc_cursor);
                            } while (state->loc_cursor.pos % TAB_SIZE != 0);
                            editbuf_delete_range(state->editbuf, state->loc_cursor, loc_old);
                            break;
                        }

                        backward_delete();
                        break;
                    }
                    case CH_ENTER: {
                        update_cursor_pos();
                        int leading_spaces = min(state->loc_cursor.pos, get_leading_spaces(state->loc_cursor.line));
                        if (editbuf_insert_ch(state->editbuf, state->loc_cursor, '\n')) {
                            state->loc_cursor.line++;
                            state->loc_cursor.pos = 0;

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
                        bool shift_pressed = (key & KEY_MOD_SHIFT) == 0;
                        if (has_selection()) {
                            int from_line = state->loc_selection_from.line;
                            int to_line   = state->loc_selection_to.line;
                            if (state->loc_selection_to.pos == 0)
                                to_line--;

                            for (int line = from_line; line <= to_line; line++) {
                                if (shift_pressed)
                                    indent_line(line);
                                else
                                    unindent_line(line);
                            }
                            keep_selection = true;

                        } else {
                            if (shift_pressed) {
                                int pos = state->loc_cursor.pos;
                                do {
                                    pos++;
                                } while (pos % TAB_SIZE != 0);

                                int count = pos - state->loc_cursor.pos;
                                for (int i = 0; i < count; i++)
                                    insert_ch(' ');

                            } else {
                                state->loc_cursor.pos -= unindent_line(state->loc_cursor.line);
                            }
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
