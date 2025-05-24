#include "console.h"

#define DEF_FGCOL    (0)
#define DEF_BGCOL    (3)
#define CURSOR_COLOR (0x80)

static int      num_rows, num_columns;
static int      cursor_row, cursor_column;
static uint16_t saved_color;
static uint16_t text_color;
static bool     cursor_visible;
static bool     cursor_enabled;

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

static void hide_cursor(void) {
    if (cursor_visible) {
        uint16_t *p_cursor = (uint16_t *)&TRAM[cursor_row * num_columns + cursor_column];
        *p_cursor          = saved_color | (*p_cursor & 0xFF);
        cursor_visible     = false;
    }
}

static void show_cursor(void) {
    if (cursor_enabled && !cursor_visible) {
        uint16_t *p_cursor = (uint16_t *)&TRAM[cursor_row * num_columns + cursor_column];
        uint16_t  val      = *p_cursor;
        saved_color        = val & 0xFF00;
        *p_cursor          = (CURSOR_COLOR << 8) | (val & 0xFF);
        cursor_visible     = true;
    }
}

void _clear_screen(void) {
    cursor_row    = 0;
    cursor_column = 0;
    memset16((uint16_t *)TRAM, text_color | ' ', num_columns * num_rows);
}

void console_init(void) {
    num_rows       = 25;
    num_columns    = 80;
    text_color     = (DEF_FGCOL << 12) | (DEF_BGCOL << 8);
    cursor_visible = false;
    cursor_enabled = true;

    reinit_video();
    _clear_screen();
    show_cursor();
}

bool console_set_width(int width) {
    if (width != 40 && width != 80)
        return false;
    return true;
}

void console_clear_screen(void) {
    hide_cursor();
    _clear_screen();
    show_cursor();
}

void console_show_cursor(bool en) {
    hide_cursor();
    cursor_enabled = en;
    show_cursor();
}

void console_set_cursor_row(int val) {
    if (val < 0)
        val = 0;
    if (val > num_rows - 1)
        val = num_rows - 1;

    hide_cursor();
    cursor_row = val;
    show_cursor();
}
int console_get_cursor_row(void) { return cursor_row; }
int console_get_num_rows(void) { return num_rows; }

void console_set_cursor_column(int val) {
    if (val < 0)
        val = 0;
    if (val > num_columns - 1)
        val = num_columns - 1;

    hide_cursor();
    cursor_column = val;
    show_cursor();
}
int console_get_num_columns(void) { return num_columns; }
int console_get_cursor_column(void) { return cursor_column; }

void console_set_foreground_color(int val) {
    text_color = ((val & 0xF) << 12) | (text_color & 0x0F00);
}
void console_set_background_color(int val) {
    text_color = (text_color & 0xF000) | ((val & 0xF) << 8);
}
void console_set_border_color(int val) {
    TRAM[2047] = ((val & 0xF) << 12) | ((val & 0xF) << 8) | ' ';
}

static void _putc(char ch) {
    if (ch == '\b') {
        if (cursor_column > 0) {
            cursor_column--;
        } else {
            if (cursor_row > 0) {
                cursor_column = num_columns - 1;
                cursor_row--;
            }
        }

    } else if (ch == '\t') {
        // Horizontal TAB
        cursor_column = (cursor_column + 8) & ~7;

    } else if (ch == '\n') {
        // Newline
        cursor_row++;

    } else if (ch == '\r') {
        // Carriage return
        cursor_column = 0;

    } else {
        // Regular character
        TRAM[cursor_row * num_columns + cursor_column] = text_color | ch;
        cursor_column++;
    }

    if (cursor_column >= num_columns) {
        cursor_column = 0;
        cursor_row++;
    }
    if (cursor_row >= num_rows) {
        memmove16((uint16_t *)TRAM, (uint16_t *)TRAM + num_columns, num_columns * (num_rows - 1));
        memset16((uint16_t *)TRAM + num_columns * (num_rows - 1), text_color | ' ', num_columns);
        cursor_row = num_rows - 1;
    }
}

void console_putc(char ch) {
    hide_cursor();
    _putc(ch);
    show_cursor();
}

void console_puts(const char *s) {
    hide_cursor();
    while (*s)
        _putc(*(s++));
    show_cursor();
}

static uint8_t kb_buf[64];
static uint8_t kb_wridx;
static uint8_t kb_rdidx;
static uint8_t kb_cnt;

static void _process_keybuf(void) {
    while (1) {
        int key = REGS->KEYBUF;
        if (key < 0)
            return;
        _console_handle_key(key);
        if ((key & KEY_IS_SCANCODE))
            continue;
    }
}

uint8_t console_getc(void) {
    _process_keybuf();

    if (kb_cnt == 0)
        return 0;

    uint8_t ch = kb_buf[kb_rdidx++];
    if (kb_rdidx == sizeof(kb_buf))
        kb_rdidx = 0;
    kb_cnt--;

    return ch;
}

void console_flush_input(void) {
    kb_wridx = 0;
    kb_rdidx = 0;
    kb_cnt   = 0;
}

static void _dummy() {}
void        console_ctrl_c_pressed(void) __attribute__((weak, alias("_dummy")));

void _console_handle_key(int key) {
    if (key < 0)
        return;
    if (key & KEY_IS_SCANCODE)
        return;

    uint8_t ch = key & 0xFF;
    if (key & KEY_MOD_CTRL) {
        uint8_t ch_upper = toupper(ch);
        if (ch_upper >= '@' && ch_upper <= '_')
            ch = ch_upper - '@';
        else if (ch_upper == 0x7F)
            ch = '\b';
    }

    if (ch == 3)
        console_ctrl_c_pressed();

    if (kb_cnt < sizeof(kb_buf) && ch > 0) {
        kb_buf[kb_wridx++] = ch;
        if (kb_wridx == sizeof(kb_buf))
            kb_wridx = 0;
        kb_cnt++;
    }
}
