#include "console.h"

void console_init(void) {}
bool console_set_width(int width) {
    if (width != 40 && width != 80)
        return false;
    return true;
}
void console_clear_screen(void) {}
void console_show_cursor(bool) {}
int  console_get_cursor_row(void) { return 0; }
int  console_get_cursor_column(void) { return 0; }
int  console_get_num_columns(void) { return 80; }
int  console_get_num_rows(void) { return 25; }

void console_set_cursor_row(int) {}
void console_set_cursor_column(int) {}
void console_set_foreground_color(int) {}
void console_set_background_color(int) {}
void console_set_border_color(int) {}

void console_putc(char ch) {
    putchar(ch);
}

void console_puts(const char *s) {
    while (*s)
        putchar(*(s++));
}
