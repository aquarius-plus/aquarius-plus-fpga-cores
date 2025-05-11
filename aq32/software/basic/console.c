#include "console.h"

#define DEF_FGCOL    (0)
#define DEF_BGCOL    (3)
#define CURSOR_COLOR (0x80)

struct terminal_data {
    uint16_t *buffer;
    int       rows, columns;
    int       cursor_row, cursor_col;
    uint8_t   saved_color;
    uint8_t   fg_col;
    uint8_t   bg_col;
    uint8_t   text_color;
};

static struct terminal_data terminal;

static void memmove16(uint16_t *dst, const uint16_t *src, unsigned count) {
    uint16_t       *d = dst;
    const uint16_t *s = src;
    if (d < s) {
        while (count--) {
            *(d++) = *(s++);
        }
    } else {
        s += (count - 1);
        d += (count - 1);
        while (count--) {
            *(d--) = *(s--);
        }
    }
}

static void memset16(uint16_t *dst, uint16_t val, unsigned count) {
    while (count--)
        *(dst++) = val;
}

static void clear_display(void) {
    // erase entire display
    memset16(
        terminal.buffer,
        (terminal.text_color << 8) | ' ',
        terminal.columns * terminal.rows);
}

static void hide_cursor(struct terminal_data *td) {
    if (terminal.buffer == NULL ||
        terminal.cursor_row < 0 || terminal.cursor_row >= terminal.rows ||
        terminal.cursor_col < 0 || terminal.cursor_col >= terminal.columns)
        return;

    uint16_t *p = &terminal.buffer[terminal.cursor_row * terminal.columns + terminal.cursor_col];
    *p          = (*p & 0xFF) | (terminal.saved_color << 8);
}

static void show_cursor(struct terminal_data *td) {
    if (terminal.buffer == NULL ||
        terminal.cursor_row < 0 || terminal.cursor_row >= terminal.rows ||
        terminal.cursor_col < 0 || terminal.cursor_col >= terminal.columns)
        return;

    uint16_t *p          = &terminal.buffer[terminal.cursor_row * terminal.columns + terminal.cursor_col];
    terminal.saved_color = *p >> 8;
    *p                   = (*p & 0xFF) | (CURSOR_COLOR << 8);
}

static inline int imin(int a, int b) { return a < b ? a : b; }
static inline int imax(int a, int b) { return a > b ? a : b; }

static inline void cursor_set(struct terminal_data *td, int col, int row) {
    terminal.cursor_col = imax(0, imin(col, terminal.columns - 1));
    terminal.cursor_row = imax(0, imin(row, terminal.rows - 1));
}

static void terminal_process(struct terminal_data *td, char ch) {
    if (terminal.buffer == NULL || terminal.columns == 0 || terminal.rows == 0) {
        return;
    }

    if (ch == '\t') {
        // Horizontal TAB
        terminal.cursor_col = (terminal.cursor_col + 8) & ~7;

    } else if (ch == '\n') {
        // Newline
        terminal.cursor_row++;

    } else if (ch == '\r') {
        // Carriage return
        terminal.cursor_col = 0;

    } else {
        terminal.buffer[terminal.cursor_row * terminal.columns + terminal.cursor_col] = (terminal.text_color << 8) | ch;
        terminal.cursor_col++;
    }

    if (terminal.cursor_row < 0) {
        terminal.cursor_row = 0;
    }
    if (terminal.cursor_col < 0) {
        terminal.cursor_col = 0;
    }

    if (terminal.cursor_col >= terminal.columns) {
        terminal.cursor_col = 0;
        terminal.cursor_row++;
    }

    if (terminal.cursor_row >= terminal.rows) {
        memmove16(terminal.buffer, terminal.buffer + terminal.columns, terminal.columns * (terminal.rows - 1));
        memset16(terminal.buffer + terminal.columns * (terminal.rows - 1), (terminal.text_color << 8) | ' ', terminal.columns);
        terminal.cursor_row = terminal.rows - 1;
    }
}

void console_init(void) {
    terminal.buffer     = (uint16_t *)TRAM;
    terminal.rows       = 25;
    terminal.columns    = 80;
    terminal.text_color = (DEF_FGCOL << 4) | DEF_BGCOL;
    terminal.fg_col     = DEF_FGCOL;
    terminal.bg_col     = DEF_BGCOL;

    reinit_video();
    hide_cursor(&terminal);
    clear_display();
    show_cursor(&terminal);
}

void console_putc(char ch) {
    hide_cursor(&terminal);
    terminal_process(&terminal, ch);
    show_cursor(&terminal);
}
