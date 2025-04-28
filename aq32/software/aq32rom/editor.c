#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "regs.h"

static volatile uint16_t *p_scr;
static uint16_t           color;
static char               filename[64];
static uint8_t            edit_buf[256 * 1024];
static int                cursor_line    = 0;
static int                cursor_pos     = 0; // Wanted position
static int                cursor_pos2    = 0; // Actual position due to line length
static int                scr_first_line = 0;
static int                scr_first_pos  = 0;
static int                num_lines      = 0;

#define COLOR_MENU     0x07
#define COLOR_EDITOR   0x71
#define COLOR_FILENAME 0x17
#define COLOR_CURSOR   0x06
#define COLOR_SELECTED 0x17
#define COLOR_STATUS   0xF3
#define COLOR_STATUS2  0x03

#define EDITOR_ROWS    22
#define EDITOR_COLUMNS 78

#define CH_BACKSPACE   '\b'
#define CH_F1          0x80
#define CH_F2          0x81
#define CH_F3          0x82
#define CH_F4          0x83
#define CH_F5          0x84
#define CH_F6          0x85
#define CH_F7          0x86
#define CH_F8          0x87
#define CH_F9          0x90
#define CH_F10         0x91
#define CH_F11         0x92
#define CH_F12         0x93
#define CH_PRINTSCREEN 0x88
#define CH_PAUSE       0x89
#define CH_INSERT      0x9D
#define CH_HOME        0x9B
#define CH_PAGEUP      0x8A
#define CH_DELETE      0x7F
#define CH_END         0x9A
#define CH_PAGEDOWN    0x8B
#define CH_RIGHT       0x8E
#define CH_LEFT        0x9E
#define CH_DOWN        0x9F
#define CH_UP          0x8F

#define MAX_BUFSZ  255
#define MAX_LINESZ (MAX_BUFSZ - 1)

static inline void scr_locate(int row, int column) {
    p_scr = TRAM + 80 * row + column;
}

static inline void scr_putchar(uint8_t ch) {
    *(p_scr++) = color | ch;
}

static inline void scr_puttext(const char *p) {
    while (*p)
        scr_putchar(*(p++));
}

static inline void scr_setcolor(uint8_t col) {
    color = col << 8;
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

static int getline_length(int line) {
    const uint8_t *p = getline_addr(line);
    if (p[0] == 0)
        return 0;
    return p[1];
}

static void render_screen(void) {
    {
        scr_locate(0, 0);
        scr_setcolor(COLOR_MENU);
        scr_puttext("  File  Edit  View  Run  Help                                                   ");
    }

    {
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

void editor(void) {
    // load_file("/Bluetooth.cpp");
    load_file("/demos/Mandelbrot/run-me.bas");

    while (1) {
        render_screen();

        int ch = getchar();
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
