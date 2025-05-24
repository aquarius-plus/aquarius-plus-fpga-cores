#include "readline.h"
#include "common.h"
#include "console.h"

struct readline_context {
    char    *buf;
    unsigned buf_size;
    unsigned len;
    unsigned idx;
};

static void insert_char(struct readline_context *ctx, char ch) {
    // Ensure buffer is large enough
    if (ctx->len >= ctx->buf_size - 1)
        return;

    for (unsigned i = ctx->len; i > ctx->idx; i--)
        ctx->buf[i] = ctx->buf[i - 1];
    ctx->buf[ctx->idx] = ch;
    ctx->len++;

    console_putc(ch);
    ctx->idx++;

    for (unsigned i = ctx->idx; i < ctx->len; i++)
        console_putc(ctx->buf[i]);
    for (int i = 0; i < (int)ctx->len - (int)ctx->idx; i++)
        console_putc('\b');
}

static void delete_char(struct readline_context *ctx) {
    ctx->len--;

    for (unsigned i = ctx->idx; i < ctx->len; i++) {
        char ch     = ctx->buf[i + 1];
        ctx->buf[i] = ch;
        console_putc(ch);
    }
    console_putc(' ');
    for (int i = 0; i < (int)ctx->len - (int)ctx->idx + 1; i++)
        console_putc('\b');
}

static void do_left(struct readline_context *ctx) {
    if (ctx->idx == 0)
        return;

    ctx->idx--;
    console_putc('\b');
}

static void do_right(struct readline_context *ctx) {
    if (ctx->idx >= ctx->len)
        return;

    console_putc(ctx->buf[ctx->idx++]);
}

int readline(char *buf, size_t buf_size) {
    struct readline_context ctx = {
        .buf      = buf,
        .buf_size = buf_size,
        .idx      = 0,
        .len      = 0,
    };

    while (1) {
        uint8_t ch = console_getc();
        if (ch == 0)
            continue;

        switch (ch) {
            case CH_ENTER: {
                console_putc('\r');
                console_putc('\n');
                ctx.buf[ctx.len] = 0;
                return ctx.len;
            }
            case CH_BACKSPACE: {
                if (ctx.idx > 0) {
                    do_left(&ctx);
                    delete_char(&ctx);
                }
                break;
            }
            case CH_DELETE: {
                if (ctx.idx < ctx.len)
                    delete_char(&ctx);
                break;
            }
            case CH_LEFT: {
                do_left(&ctx);
                break;
            }
            case CH_RIGHT: {
                do_right(&ctx);
                break;
            }
            case CH_HOME: {
                while (ctx.idx > 0)
                    do_left(&ctx);
                break;
            }
            case CH_END: {
                while (ctx.idx < ctx.len)
                    do_right(&ctx);
                break;
            }
            case 3: {
                console_puts("^C\r\n");
                return -1;
            }
            default:
                if (!is_cntrl(ch))
                    insert_char(&ctx, ch);
                break;
        }
    }
}
