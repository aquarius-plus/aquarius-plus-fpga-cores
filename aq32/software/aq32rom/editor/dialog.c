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

struct file_list_ctx {
    int    y;
    int    x;
    int    w;
    int    rows;
    int    old_selection;
    int    selection;
    int    total;
    char  *fn_buf;
    size_t fn_bufsize;

    struct esp_stat st;
};

void file_list_reset(struct file_list_ctx *ctx) {
    ctx->old_selection = INT32_MIN;
    ctx->selection     = 0;
    ctx->total         = -1;
}

void file_list_init(struct file_list_ctx *ctx, int y, int x, int w, int rows, char *fn_buf, size_t fn_bufsize) {
    ctx->y          = y;
    ctx->x          = x;
    ctx->w          = w;
    ctx->rows       = rows;
    ctx->fn_buf     = fn_buf;
    ctx->fn_bufsize = fn_bufsize;
    file_list_reset(ctx);
}

void file_list_draw(struct file_list_ctx *ctx, bool show_selection) {
    if (ctx->total < 0)
        ctx->total = get_num_entries();

    ctx->selection = clamp(ctx->selection, 0, ctx->total - 1);

    if (ctx->old_selection != ctx->selection) {
        if (ctx->old_selection / ctx->rows != ctx->selection / ctx->rows) {
            draw_listing_page(ctx->y, ctx->x, ctx->w, ctx->rows, ctx->selection / ctx->rows);
        }

        if (ctx->old_selection >= 0)
            set_listing_color(ctx->y + ctx->old_selection % ctx->rows, ctx->x, ctx->w, COLOR_MENU);
        ctx->old_selection = ctx->selection;
    }
    set_listing_color(ctx->y + ctx->selection % ctx->rows, ctx->x, ctx->w, show_selection ? COLOR_MENU_SEL : COLOR_MENU);
}

int file_list_handle(struct file_list_ctx *ctx) {
    while (1) {
        file_list_draw(ctx, true);

        int key;
        while ((key = REGS->KEYBUF) < 0);
        if (key & KEY_IS_SCANCODE) {
            return key;

        } else {
            uint8_t ch = key & 0xFF;
            switch (ch) {
                case CH_DOWN: ctx->selection++; break;
                case CH_UP: ctx->selection--; break;
                case CH_PAGEDOWN: ctx->selection += ctx->rows; break;
                case CH_PAGEUP: ctx->selection -= ctx->rows; break;
                case '\r': {
                    int dd = esp_opendirext("", DE_FLAG_DOTDOT, ctx->selection);
                    if (dd >= 0) {
                        int res = esp_readdir(dd, &ctx->st, ctx->fn_buf, ctx->fn_bufsize);
                        esp_closedir(dd);
                        if (res == 0)
                            return key;
                    }
                    break;
                }
                default: return key;
            }
        }
    }
}

bool dialog_open(char *fn_buf, size_t fn_bufsize) {
    struct file_list_ctx flctx;

    int w = 80 - 12;
    int h = 25 - 6;
    int x = (80 - w) / 2;
    int y = (25 - h) / 2;

    scr_draw_border(y, x, w, h, COLOR_MENU, 0, "Open");
    scr_draw_separator(y + 2, x, w, COLOR_MENU);
    scr_status_msg("Enter=Select   Esc=Cancel   Up/Down/PgUp/PgDn=Change Selection");

    draw_current_dir(y + 1, x + 1, w - 2);
    file_list_init(&flctx, y + 3, x + 1, w - 2, h - 4, fn_buf, fn_bufsize);

    while (1) {
        int key = file_list_handle(&flctx);
        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Escape?
            if (((key & KEY_KEYDOWN) && scancode == 0x29))
                return false;
        } else {
            uint8_t ch = key & 0xFF;
            if (ch == '\r') {
                if (flctx.st.attr & DE_ATTR_DIR) {
                    esp_chdir(fn_buf);
                    draw_current_dir(y + 1, x + 1, w - 2);
                    file_list_reset(&flctx);
                } else {
                    return true;
                }
            }
        }
    }
    return false;
}

struct edit_field_ctx {
    int    y;
    int    x;
    int    w;
    char  *buf;
    size_t buf_len;
    int    cursor_pos;
    int    first_pos;
};

void edit_field_init(struct edit_field_ctx *ctx, int y, int x, int w, char *buf, size_t buf_len) {
    ctx->y          = y;
    ctx->x          = x;
    ctx->w          = w;
    ctx->buf        = buf;
    ctx->buf_len    = buf_len;
    ctx->cursor_pos = strlen(buf);
    ctx->first_pos  = 0;
}

void edit_field_draw(struct edit_field_ctx *ctx, bool show_cursor) {
    scr_locate(ctx->y, ctx->x);
    scr_setcolor(COLOR_FIELD);
    scr_puttext_filled(ctx->w, ctx->buf, false, false);
}

int edit_field_handle(struct edit_field_ctx *ctx) {
    while (1) {
        edit_field_draw(ctx, true);

        int key;
        while ((key = REGS->KEYBUF) < 0);
        if (key & KEY_IS_SCANCODE) {
            return key;

        } else {
            uint8_t ch = key & 0xFF;
            switch (ch) {
                case CH_LEFT: ctx->cursor_pos--; break;
                case CH_RIGHT: ctx->cursor_pos++; break;
                case CH_HOME: ctx->cursor_pos = 0; break;
                case CH_END: ctx->cursor_pos = strlen(ctx->buf); break;
                case '\t':
                case '\r': return key;
                default: {
                    break;
                }
            }
        }
    }
}

bool dialog_save(char *fn_buf, size_t fn_bufsize) {
    struct file_list_ctx  flctx;
    struct edit_field_ctx efctx;

    int w = 80 - 12;
    int h = 25 - 6;
    int x = (80 - w) / 2;
    int y = (25 - h) / 2;

    scr_draw_border(y, x, w, h, COLOR_MENU, 0, "Save");
    scr_draw_separator(y + 2, x, w, COLOR_MENU);
    scr_draw_separator(y + h - 3, x, w, COLOR_MENU);
    scr_status_msg("Enter=Select   Esc=Cancel   Up/Down/PgUp/PgDn/Tab=Change Selection");

    draw_current_dir(y + 1, x + 1, w - 2);
    scr_locate(y + h - 2, x + 1);
    scr_puttext(" Filename: ");

    char tmp[256];
    file_list_init(&flctx, y + 3, x + 1, w - 2, h - 6, tmp, sizeof(tmp));
    file_list_draw(&flctx, false);

    edit_field_init(&efctx, y + h - 2, x + 12, w - 14, fn_buf, fn_bufsize);
    edit_field_draw(&efctx, false);

    scr_setcolor(COLOR_MENU);
    scr_putchar(' ');

    int cur_field = 1;

    while (1) {
        int key;
        if (cur_field == 0) {
            key = file_list_handle(&flctx);
        } else if (cur_field == 1) {
            key = edit_field_handle(&efctx);
        }

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Escape?
            if (((key & KEY_KEYDOWN) && scancode == 0x29))
                return false;
        } else {
            uint8_t ch = key & 0xFF;
            if (ch == '\r') {
                if (cur_field == 0) {
                    if (flctx.st.attr & DE_ATTR_DIR) {
                        esp_chdir(tmp);
                        draw_current_dir(y + 1, x + 1, w - 2);
                        file_list_reset(&flctx);
                    } else {
                        snprintf(fn_buf, fn_bufsize, "%s", tmp);
                        file_list_draw(&flctx, false);
                        cur_field = 1;
                    }

                } else if (cur_field == 1) {
                }

            } else if (ch == '\t') {
                if (cur_field == 0) {
                    file_list_draw(&flctx, false);
                    cur_field = 1;
                } else if (cur_field == 1) {
                    edit_field_draw(&efctx, false);
                    cur_field = 0;
                }
            }
        }
    }
    return false;
}

int dialog_confirm(const char *text) {
    const char *choices_str = "<&Yes>  <&No>  <&Cancel>";

    scr_status_msg("Y=Yes   N=No   C/Esc=Cancel");

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
