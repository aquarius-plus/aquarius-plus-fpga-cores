#include "dialog.h"
#include "screen.h"
#include "esp.h"

static void set_listing_color(int y, int x, int w, uint8_t col) {
    scr_setcolor(y == 6 ? COLOR_MENU_SEL : COLOR_MENU);

    scr_locate(y, x);
    while (w--)
        scr_putcolor(col);
}

static void draw_listing_line(int y, int x, int w, const struct esp_stat *st, const char *filename) {
    scr_setcolor(COLOR_MENU);

    scr_locate(y, x);
    if (!filename) {
        scr_fillchar(' ', w);
        return;
    }

    char tmp[32];
    if (st->date == 0 && st->time == 0) {
        scr_fillchar(' ', 16);
        w -= 16;
    } else {
        w -= snprintf(
            tmp, sizeof(tmp),
            " %02u-%02u-%02u %02u:%02u ",
            ((st->date >> 9) + 80) % 100,
            (st->date >> 5) & 15,
            st->date & 31,
            (st->time >> 11) & 31,
            (st->time >> 5) & 63);
        scr_puttext(tmp);
    }

    if (st->attr & DE_ATTR_DIR) {
        w -= snprintf(tmp, sizeof(tmp), "<DIR> ");
    } else {
        if (st->size < 1024) {
            w -= snprintf(tmp, sizeof(tmp), "%4lu  ", st->size);
        } else if (st->size < 1024 * 1024) {
            w -= snprintf(tmp, sizeof(tmp), "%4luK ", st->size >> 10);
        } else {
            w -= snprintf(tmp, sizeof(tmp), "%4luM ", st->size >> 20);
        }
    }
    scr_puttext(tmp);

    w--;

    const char *p = filename;
    while (w-- > 0) {
        char ch = *p;
        if (ch) {
            scr_putchar(ch);
            p++;
        } else {
            scr_putchar(' ');
        }
    }
    scr_putchar(' ');
}

static void draw_listing_page(int y, int x, int w, int rows, int page) {
    struct esp_stat st;
    char            tmp[256];

    int dd = esp_opendirext("", DE_FLAG_DOTDOT, page * rows);
    for (int i = 0; i < rows; i++) {
        if (dd >= 0) {
            int res = esp_readdir(dd, &st, tmp, sizeof(tmp));
            if (res < 0) {
                esp_closedir(dd);
                dd = -1;
            }
        }

        draw_listing_line(y, x, w, &st, dd >= 0 ? tmp : NULL);
        y++;
    }
    if (dd >= 0)
        esp_closedir(dd);
}

static int get_num_entries(void) {
    struct esp_stat st;
    char            tmp[16];
    int             result = 0;

    int dd = esp_opendirext("", DE_FLAG_DOTDOT, 0);
    if (dd >= 0) {
        while (1) {
            if (esp_readdir(dd, &st, tmp, sizeof(tmp)) < 0)
                break;
            result++;
        }
        esp_closedir(dd);
    }
    return result;
}

static void draw_current_dir(int y, int x, int w) {
    char tmp[256];
    getcwd((char *)tmp, sizeof(tmp));
    scr_locate(y, x);
    scr_setcolor(COLOR_MENU);
    scr_puttext(" Current dir: ");

    int path_len = strlen(tmp);
    if (path_len > w - 14) {
        scr_puttext("...");
        scr_puttext(tmp + path_len - (w - 3 - 14));
    } else {
        scr_puttext(tmp);
        scr_fillchar(' ', w - 14 - path_len);
    }
}

bool dialog_open(char *fn_buf, size_t fn_bufsize) {
    int w         = 80 - 12;
    int h         = 25 - 6;
    int x         = (80 - w) / 2;
    int y         = (25 - h) / 2;
    int rows      = h - 4;
    int selection = 0;
    int total     = get_num_entries();

    scr_setcolor(COLOR_STATUS);
    scr_locate(24, 1);
    scr_puttext("Enter=Select   Esc=Cancel   Up/Down/PgUp/PgDn=Change Selection");

    // Draw window border
    scr_draw_border(y, x, w, h, COLOR_MENU, 0, "Open");
    scr_draw_separator(y + 2, x, w, COLOR_MENU);
    x += 1;
    w -= 2;

    int old_selection = INT32_MIN;
    while (1) {
        if (selection >= total) {
            selection = total - 1;
        }
        if (selection < 0) {
            selection = 0;
        }

        if (old_selection != selection) {
            if (old_selection / rows != selection / rows) {
                draw_current_dir(y + 1, x, w);
                draw_listing_page(y + 3, x, w, rows, selection / rows);
            }

            if (old_selection >= 0)
                set_listing_color(y + 3 + old_selection % rows, x, w, COLOR_MENU);
            set_listing_color(y + 3 + selection % rows, x, w, COLOR_MENU_SEL);
            old_selection = selection;
        }

        int key;
        while ((key = REGS->KEYBUF) < 0);
        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Escape?
            if (((key & KEY_KEYDOWN) && scancode == 0x29))
                return false;

        } else {
            uint8_t ch = key & 0xFF;
            if (ch == CH_DOWN) {
                selection++;
            } else if (ch == CH_UP) {
                selection--;
            } else if (ch == CH_PAGEDOWN) {
                selection += rows;
            } else if (ch == CH_PAGEUP) {
                selection -= rows;
            } else if (ch == '\r') {
                int dd = esp_opendirext("", DE_FLAG_DOTDOT, selection);
                if (dd >= 0) {
                    struct esp_stat st;
                    int             res = esp_readdir(dd, &st, fn_buf, fn_bufsize);
                    esp_closedir(dd);

                    if (res == 0) {
                        if (st.attr & DE_ATTR_DIR) {
                            esp_chdir(fn_buf);
                            old_selection = INT32_MIN;
                            selection     = 0;
                            total         = get_num_entries();
                        } else {
                            return true;
                        }
                    }
                }
            }
        }
    }
}

int dialog_confirm(const char *text) {
    const char *choices_str = "<&Yes>  <&No>  <&Cancel>";

    int text_len    = strlen(text);
    int choices_len = strlen(choices_str);

    int w = max(text_len, choices_len) + 4;
    int h = 7;
    int x = (80 - w) / 2;
    int y = (25 - h) / 2;

    scr_draw_border(y, x, w, h, COLOR_MENU, 0, NULL);
    scr_setcolor(COLOR_MENU);
    scr_center_text(y + 1, x + 1, w - 2, "", false);
    scr_center_text(y + 2, x + 1, w - 2, text, false);
    scr_center_text(y + 3, x + 1, w - 2, "", false);
    scr_draw_separator(y + 4, x, w, COLOR_MENU);
    scr_center_text(y + 5, x + 1, w - 2, choices_str, true);

    while (1) {
        int key;
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Escape?
            if (((key & KEY_KEYDOWN) && scancode == 0x29))
                return -1;
        } else {
            uint8_t ch = key & 0xFF;
            switch (toupper(ch)) {
                case 'Y': return 1;
                case 'N': return 0;
                case 'C': return -1;
            }
        }
    }
}
