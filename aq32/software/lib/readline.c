#include "readline.h"
#include "common.h"

#define BUF_SIZE (128)

enum {
    INP_ENTER = 256,
    INP_BACKSPACE,
    INP_LEFT,
    INP_RIGHT,
    INP_UP,
    INP_DOWN,
    INP_HOME,
    INP_END,
    INP_DELETE,
    INP_PGUP,
    INP_PGDN,
    INP_CTRL_C,
};

struct readline_context {
    unsigned buf_len;
    char    *buf;
    unsigned len;
    unsigned idx;
    bool     verbatim;
    uint8_t  escape_idx;
    uint8_t  escape_cmd[16];
};

static void do_left(struct readline_context *ctx);
static void do_right(struct readline_context *ctx);

static int input(struct readline_context *ctx) {
    while (1) {
        int ch = getchar();
        if (ch < 0 || ctx->verbatim) {
            // Translate end of file into CTRL-D
            if (ctx->verbatim && ch == EOF)
                ch = 'D' - '@';

            ctx->verbatim = false;
            return ch;
        }

        if (ctx->escape_idx) {
            if (ctx->escape_idx < sizeof(ctx->escape_cmd) - 1)
                ctx->escape_cmd[ctx->escape_idx++] = ch;

            if (ctx->escape_cmd[1] == '[') {
                // CSI: Control Sequence Introducer
                if (ctx->escape_idx > 2 && ch >= '@' && ch <= '~') {
                    ctx->escape_cmd[ctx->escape_idx] = 0;
                    unsigned len                     = ctx->escape_idx;
                    ctx->escape_idx                  = 0;

                    switch (ch) {
                        case 'A': return INP_UP;
                        case 'B': return INP_DOWN;
                        case 'C': return INP_RIGHT;
                        case 'D': return INP_LEFT;
                        case 'H': return INP_HOME;
                        case 'F': return INP_END;
                        case '~': {
                            if (len >= 4) {
                                switch (ctx->escape_cmd[len - 2]) {
                                    case '3': return INP_DELETE;
                                    case '5': return INP_PGUP;
                                    case '6': return INP_PGUP;
                                }
                            }
                            break;
                        }
                        default: break;
                    }
                }
            } else {
                ctx->escape_idx = 0;
            }
            continue;
        }

        if (ch == 3)
            return INP_CTRL_C;
        if (ch == '\n' || ch == '\r')
            return INP_ENTER;
        if (ch == '\b' || ch == 0x7F)
            return INP_BACKSPACE;
        if (ch == 'V' - '@') {
            ctx->verbatim = true;
            continue;
        }
        if (ch == 0x1B) {
            ctx->escape_cmd[ctx->escape_idx++] = ch;
            continue;
        }
        if (ch >= ' ')
            return ch;
    }
}

static inline bool is_ctrlch(char ch) {
    return ((ch > 0 && ch < ' ') || ch == 0x7F);
}

static int print_char(char ch) {
    // Echo the character to the user and add it to the buffer.
    if (is_ctrlch(ch)) {
        // Control character
        putchar('^');
        if (ch == 0x7F) {
            putchar('?');
        } else {
            putchar(ch + '@');
        }
        return 2;
    }

    putchar(ch);
    return 1;
}

static void insert_char(struct readline_context *ctx, char ch) {
    // Ensure buffer is large enough
    if (ctx->len >= ctx->buf_len - 1) {
        char *new_buf = realloc(ctx->buf, ctx->buf_len + BUF_SIZE);
        if (!new_buf)
            return;

        ctx->buf     = new_buf;
        ctx->buf_len = ctx->buf_len + BUF_SIZE;
    }

    for (unsigned i = ctx->len; i > ctx->idx; i--)
        ctx->buf[i] = ctx->buf[i - 1];
    ctx->buf[ctx->idx] = ch;
    ctx->len++;

    print_char(ch);
    ctx->idx++;

    int cnt = 0;
    for (unsigned i = ctx->idx; i < ctx->len; i++) {
        char ch = ctx->buf[i];
        cnt += print_char(ch);
    }
    for (int i = 0; i < cnt; i++)
        putchar('\b');
}

static void delete_char(struct readline_context *ctx) {
    int curlen = 0;
    for (unsigned i = ctx->idx; i < ctx->len; i++) {
        curlen += is_ctrlch(ctx->buf[i]) ? 2 : 1;
    }

    ctx->len--;

    int newlen = 0;
    for (unsigned i = ctx->idx; i < ctx->len; i++) {
        char ch     = ctx->buf[i + 1];
        ctx->buf[i] = ch;
        newlen += print_char(ch);
    }

    int diff = curlen - newlen;
    for (int i = 0; i < diff; i++)
        putchar(' ');
    for (int i = 0; i < newlen + diff; i++)
        putchar('\b');
}

static void do_backspace(struct readline_context *ctx) {
    if (ctx->idx > 0) {
        do_left(ctx);
        delete_char(ctx);
    }
}

static void do_delete(struct readline_context *ctx) {
    if (ctx->idx < ctx->len) {
        delete_char(ctx);
    }
}

static void do_left(struct readline_context *ctx) {
    if (ctx->idx == 0)
        return;

    ctx->idx--;
    if (is_ctrlch(ctx->buf[ctx->idx]))
        putchar('\b');
    putchar('\b');
}

static void do_right(struct readline_context *ctx) {
    if (ctx->idx >= ctx->len)
        return;

    print_char(ctx->buf[ctx->idx++]);
}

char *readline(void) {
    struct readline_context ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.buf_len = BUF_SIZE;
    if ((ctx.buf = malloc(BUF_SIZE)) == NULL)
        return NULL;

    char *result = NULL;

    while (1) {
        fflush(stdout);
        int ch = input(&ctx);

        // Enter?
        if (ch == INP_ENTER || ch == EOF) {
            putchar('\r');
            putchar('\n');
            fflush(stdout);
            ctx.buf[ctx.len] = 0;

            if (ch == EOF && ctx.len == 0) {
                free(ctx.buf);
            } else {
                result = ctx.buf;
            }
            break;
        }

        if (ch == INP_BACKSPACE) {
            do_backspace(&ctx);
            continue;
        }
        if (ch == INP_DELETE) {
            do_delete(&ctx);
            continue;
        }
        if (ch == INP_LEFT) {
            do_left(&ctx);
            continue;
        }
        if (ch == INP_HOME) {
            while (ctx.idx > 0)
                do_left(&ctx);
            continue;
        }
        if (ch == INP_RIGHT) {
            do_right(&ctx);
            continue;
        }
        if (ch == INP_END) {
            while (ctx.idx < ctx.len)
                do_right(&ctx);
            continue;
        }
        if (ch == INP_CTRL_C) {
            print_char(3);
            putchar('\r');
            putchar('\n');
            ctx.buf[0] = 0;
            result     = ctx.buf;
            break;
        }

        // Skip nul-character
        if (ch <= 0 || ch > 255)
            continue;

        insert_char(&ctx, ch);
    }

    fflush(stdout);
    return result;
}
