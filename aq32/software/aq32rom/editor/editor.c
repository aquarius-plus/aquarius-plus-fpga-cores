#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>
#include <ctype.h>
#include "regs.h"
#include "menu.h"
#include "screen.h"

static char    filename[64];
static uint8_t edit_buf[256 * 1024];
static int     cursor_line    = 0;
static int     cursor_pos     = 0; // Wanted position
static int     cursor_pos2    = 0; // Actual position due to line length
static int     scr_first_line = 0;
static int     scr_first_pos  = 0;
static int     num_lines      = 0;

#define EDITOR_ROWS    22
#define EDITOR_COLUMNS 78

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

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

static int getline_length(int line) {
    const uint8_t *p = getline_addr(line);
    if (p[0] == 0)
        return 0;
    return p[1];
}

static const struct menu_item menu_file_items[] = {
    {.title = "&New          Ctrl+N"},
    {.title = "&Open...      Ctrl+O"},
    {.title = "&Save         Ctrl+S"},
    {.title = "&Save As..."},
    {.title = "-"},
    {.title = "E&xit         Ctrl+Q"},
    {.title = NULL},
};

static const struct menu_item menu_edit_items[] = {
    {.title = "Cu&t     Ctrl+X"},
    {.title = "&Copy    Ctrl+C"},
    {.title = "&Paste   Ctrl+V"},
    {.title = "-"},
    {.title = "&Find    Ctrl+F"},
    {.title = NULL},
};

static const struct menu_item menu_view_items[] = {
    {.title = "&Output Screen   F4"},
    {.title = NULL},
};

static const struct menu_item menu_run_items[] = {
    {.title = "&Start   F5"},
    {.title = NULL},
};

static const struct menu_item menu_help_items[] = {
    {.title = "&Index"},
    {.title = "&Contents"},
    {.title = "&Topic      F1"},
    {.title = "-"},
    {.title = "&About..."},
    {.title = NULL},
};

static const struct menu menubar_menus[] = {
    {.title = "&File", .items = menu_file_items},
    {.title = "&Edit", .items = menu_edit_items},
    {.title = "&View", .items = menu_view_items},
    {.title = "&Run", .items = menu_run_items},
    {.title = "&Help", .items = menu_help_items},
    {.title = NULL},
};

static void render_title(void) {
    int filename_len = strlen(filename);

    scr_locate(1, 0);
    scr_setcolor(COLOR_EDITOR);
    scr_putchar(16);

    int count = (EDITOR_COLUMNS - (filename_len + 2)) / 2;
    for (int i = 0; i < count; i++)
        scr_putchar(25);

    scr_setcolor(COLOR_FILENAME);
    scr_putchar(' ');
    for (int i = 0; i < filename_len; i++)
        scr_putchar(filename[i]);
    scr_putchar(' ');

    scr_setcolor(COLOR_EDITOR);
    count = EDITOR_COLUMNS - count - (filename_len + 2);
    for (int i = 0; i < count; i++)
        scr_putchar(25);
    scr_putchar(18);
}

static void render_statusbar(void) {
    scr_locate(24, 0);
    scr_setcolor(COLOR_STATUS);
    // scr_puttext(" <Shift+F1=Help> <F5=Run>                                           ");
    scr_puttext("                                                                    ");
    scr_setcolor(COLOR_STATUS2);
    scr_putchar(26);

    char tmp[32];
    snprintf(tmp, sizeof(tmp), " %05d:%03d ", cursor_line + 1, cursor_pos2 + 1);
    scr_puttext(tmp);
}

static void render_editor(void) {
    const uint8_t *ps = getline_addr(scr_first_line);

    int line = 0;
    for (int j = 2; j < 2 + EDITOR_ROWS; j++) {
        int            pos     = 0;
        int            buf_len = *ps;
        const uint8_t *p_next  = ps + 1 + buf_len;

        ps++;
        int line_len = *(ps++);

        if (line_len > scr_first_pos) {
            ps += scr_first_pos;
        }
        line_len -= scr_first_pos;
        if (line_len < 0)
            line_len = 0;

        if (line_len > EDITOR_COLUMNS)
            line_len = EDITOR_COLUMNS;
        int fill_size = EDITOR_COLUMNS - line_len;

        scr_locate(j, 0);
        scr_setcolor(COLOR_EDITOR);
        scr_putchar(26);

        if (line == cursor_line - scr_first_line) {
            for (int i = 0; i < EDITOR_COLUMNS; i++) {
                scr_setcolor(pos == cursor_pos2 - scr_first_pos ? COLOR_CURSOR : COLOR_EDITOR);

                if (i < line_len)
                    scr_putchar(*(ps++));
                else
                    scr_putchar(' ');
                pos++;
            }

        } else {
            // scr_setcolor(COLOR_SELECTED);
            while (line_len--)
                scr_putchar(*(ps++));

            scr_setcolor(COLOR_EDITOR);
            while (fill_size--)
                scr_putchar(' ');
        }

        scr_setcolor(COLOR_EDITOR);
        scr_putchar(26);

        ps = p_next;
        line++;
    }

    scr_locate(24, 0);
    scr_setcolor(COLOR_STATUS);
    // scr_puttext(" <Shift+F1=Help> <F5=Run>                                           ");
    scr_puttext("                                                                    ");
    scr_setcolor(COLOR_STATUS2);
    scr_putchar(26);

    char tmp[32];
    snprintf(tmp, sizeof(tmp), " %05d:%03d ", cursor_line + 1, cursor_pos2 + 1);
    scr_puttext(tmp);
}

void load_file(const char *path) {
    snprintf(filename, sizeof(filename), "%s", path);

    uint8_t *pd = edit_buf;
    num_lines   = 0;

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
            if (line_size > MAX_LINESZ)
                line_size = MAX_LINESZ;

            *(pd++) = line_size + 1; // Buf length
            *(pd++) = line_size;     // Line length
            memcpy(pd, linebuf, line_size);
            pd += line_size;
            num_lines++;
        }

        // Buf length = 0: last line
        *(pd++) = 0;
        *(pd++) = 0;

        fclose(f);
        free(linebuf);
    }
}

static void resize_linebuffer(uint8_t *p, uint8_t new_size) {
    uint8_t cur_size = p[0];
    if (new_size == cur_size)
        return;

    uint8_t *p_next = p + 1 + p[0];
    uint8_t *p_end  = getline_addr(999999) + 2;
    memmove(p + 1 + new_size, p_next, p_end - p_next);
    p[0] = new_size;
}

static void insert_char(uint8_t ch) {
    uint8_t *p             = getline_addr(cursor_line);
    uint8_t  cur_line_size = p[0] == 0 ? 0 : p[1];

    if (cur_line_size >= MAX_LINESZ) {
        // Line full
        return;
    }

    // Enough room in buffer to increase line size?
    if (p[0] < 1 + cur_line_size + 1) {
        int new_size = 1 + cur_line_size + 16;
        if (new_size > MAX_BUFSZ)
            new_size = MAX_BUFSZ;

        resize_linebuffer(p, new_size);
    }

    uint8_t *p_cursor = p + 2 + cursor_pos2;
    memmove(p_cursor + 1, p_cursor, cur_line_size - cursor_pos2);
    *p_cursor = ch;
    p[1]++;
    cursor_pos = cursor_pos2 + 1;
}

static void delete_char(void) {
    uint8_t *p = getline_addr(cursor_line);
    if (p[0] == 0 || p[1] == 0)
        return;

    uint8_t cur_line_size = p[1];

    uint8_t *p_cursor = p + 2 + cursor_pos2;
    memmove(p_cursor, p_cursor + 1, cur_line_size - cursor_pos2 - 1);
    p[1]--;
}

// static void delete_line(void) {
//     uint8_t *p = getline_addr(cursor_line);
//     if (p[0] == 0)
//         return;

//     uint8_t *p_next = p + 1 + p[0];
//     uint8_t *p_end  = getline_addr(999999) + 2;
//     memmove(p, p_next, p_end - p_next);
// }

static void menu_redraw_screen(void) {
    render_title();
    render_editor();
}

void editor(void) {
    // load_file("/Bluetooth.cpp");
    load_file("/demos/Mandelbrot/run-me.bas");

    TRAM[2047] = 0;

    while (1) {
        render_menubar(menubar_menus, false, NULL);
        render_title();
        render_editor();
        render_statusbar();

        int key;
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            if ((key & KEY_KEYDOWN) && (scancode == 0xE2 || scancode == 0xE6)) {
                handle_menu(menubar_menus, menu_redraw_screen);
            }

            // Left alt pressed   -> 64E2
            // Left alt released  -> 40E2
            // Right alt pressed  -> 64E6
            // Right alt released -> 40E6

        } else {
            uint8_t ch = key & 0xFF;
            if (ch == CH_UP) {
                cursor_line--;
            } else if (ch == CH_DOWN) {
                cursor_line++;
            } else if (ch == CH_LEFT) {
                cursor_pos = cursor_pos2 - 1;
                if (cursor_pos < 0 && cursor_line > 0) {
                    cursor_line--;
                    cursor_pos = getline_length(cursor_line);
                }

            } else if (ch == CH_RIGHT) {
                cursor_pos = cursor_pos2 + 1;
                if (cursor_pos > getline_length(cursor_line)) {
                    cursor_line++;
                    cursor_pos = 0;
                }
            } else if (ch == CH_HOME) {
                cursor_pos = 0;
            } else if (ch == CH_END) {
                cursor_pos = getline_length(cursor_line);
            } else if (ch == CH_PAGEUP) {
                cursor_line -= (EDITOR_ROWS - 1);
            } else if (ch == CH_PAGEDOWN) {
                cursor_line += (EDITOR_ROWS - 1);
            } else if (ch == CH_DELETE) {
                delete_char();
            } else if (ch == CH_BACKSPACE) {
                if (cursor_pos2 > 0) {
                    cursor_pos2 = cursor_pos2 - 1;
                    cursor_pos  = cursor_pos2;
                    delete_char();
                }

            } else if (ch >= ' ' && ch < 127) {
                insert_char(ch);
            }
        }

        if (cursor_line < 0)
            cursor_line = 0;
        if (cursor_line > num_lines)
            cursor_line = num_lines;
        if (cursor_pos < 0)
            cursor_pos = 0;

        cursor_pos2 = cursor_pos;
        {
            int linelen = getline_length(cursor_line);
            if (cursor_pos2 > linelen)
                cursor_pos2 = linelen;
        }

        if (cursor_line < scr_first_line)
            scr_first_line = cursor_line;
        if (cursor_line > scr_first_line + (EDITOR_ROWS - 1))
            scr_first_line = cursor_line - (EDITOR_ROWS - 1);
        if (cursor_pos2 < scr_first_pos)
            scr_first_pos = cursor_pos2;
        if (cursor_pos2 > scr_first_pos + (EDITOR_COLUMNS - 1))
            scr_first_pos = cursor_pos2 - (EDITOR_COLUMNS - 1);
    }
}
