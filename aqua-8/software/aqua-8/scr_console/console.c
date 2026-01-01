#include "console.h"
#include "state.h"
#include "draw/draw.h"
#include "readline.h"

static bool    cursor_visible = false;
static uint8_t saved_cursor[4 * 6];
static bool    booted = false;

static void console_hide_cursor(void) {
    if (!cursor_visible)
        return;
    cursor_visible = false;

    for (int j = 0; j < 6; j++) {
        for (int i = 0; i < 4; i++) {
            VRAM4BIT[(game_state.y + j) * 200 + (game_state.x + i)] = saved_cursor[j * 4 + i];
        }
    }
}
static void console_show_cursor(void) {
    if (cursor_visible)
        return;
    cursor_visible = true;

    for (int j = 0; j < 6; j++) {
        for (int i = 0; i < 4; i++) {
            volatile uint8_t *p     = &VRAM4BIT[(game_state.y + j) * 200 + (game_state.x + i)];
            saved_cursor[j * 4 + i] = *p;
            if (*p != game_state.color)
                *p = 8;
        }
    }
}

void console_putc(char ch) {
    console_hide_cursor();

    switch (ch) {
        case '\b': game_state.x -= 4; break;
        case '\t': game_state.x = (game_state.x + 16) & 15; break;
        case '\n': game_state.y += 7; break;
        case '\r': game_state.x = 0; break;
        default: {
            if (ch < ' ' || ch >= '~')
                return;

            rect_t r;
            r.x0 = game_state.x;
            r.y0 = game_state.y;
            r.x1 = r.x0 + 3;
            r.y1 = r.y0 + 6;
            fill_rect(&r, 0);

            draw_char_altfont(game_state.x, game_state.y, ch, game_state.color);
            game_state.x += 4;
            break;
        }
    }

    while (game_state.x < 0) {
        game_state.y -= 7;
        game_state.x += 200;
    }
    while (game_state.x >= 200) {
        game_state.y += 7;
        game_state.x -= 200;
    }
    if (game_state.y < 0) {
        game_state.y = 0;
    }
    while (game_state.y + 7 > 161) {
        game_state.y -= 7;

        // Scroll screen up
        const volatile uint32_t *ps = VRAM + (25 * 7);
        volatile uint32_t       *pd = VRAM;
        for (int i = 0; i < 25 * 154; i++) {
            *(pd++) = *(ps++);
        }

        // Clear bottom line
        for (int i = 0; i < 25 * 7; i++) {
            *(pd++) = 0;
        }
    }
    console_show_cursor();
}

void console_puts(const char *str) {
    while (*str) {
        console_putc(*(str++));
    }
}

uint8_t console_getc(void) {
    while (1) {
        int key = KEYBUF;
        if (key < 0)
            return 0;
        if (key & KEY_IS_SCANCODE)
            continue;

        uint8_t ch = key & 0xFF;
        if (ch == 3)
            ch = 27;

        if (key & KEY_MOD_CTRL) {
            uint8_t ch_upper = toupper(ch);
            if (ch_upper >= 'A' && ch_upper <= 'Z') //(ch_upper >= '@' && ch_upper <= '_')
                ch = ch_upper - '@';
            else if (ch_upper == 0x7F)
                ch = '\b';
        }
        return ch;
    }
}

static void startup_sequence(void) {
    VIDEO->PAGE = 0;

    int delay = 4;

    clear_screen(0);
    for (int i = 0; i < delay; i++) {
        frame30 = false;
        while (!frame30) {
        }
    }

    for (int x = 0; x < 200; x += 4) {
        for (int y = 0; y < 160; y += 2) {
            unsigned color = ((((y >> 2) + (x >> 2)) >> 1) & 7) + 6;
            draw_pixel(x, y, color);
        }
    }

    for (int i = 0; i < delay; i++) {
        frame30 = false;
        while (!frame30) {
        }
    }

    for (int x = 2; x < 200; x += 4) {
        for (int y = 1; y < 160; y += 2) {
            unsigned color = ((((y >> 2) + (x >> 2)) >> 1) & 7) + 6;
            draw_pixel(x, y, color);
        }
    }

    for (int i = 0; i < delay; i++) {
        frame30 = false;
        while (!frame30) {
        }
    }

    for (int x = 0; x < 200; x += 4) {
        for (int y = 0; y < 160; y += 2) {
            unsigned color = 0;
            draw_pixel(x, y, color);
        }
    }

    for (int i = 0; i < delay; i++) {
        frame30 = false;
        while (!frame30) {
        }
    }

    for (int x = 2; x < 200; x += 4) {
        for (int y = 1; y < 160; y += 2) {
            unsigned color = 0;
            draw_pixel(x, y, color);
        }
    }

    for (int i = 0; i < delay; i++) {
        frame30 = false;
        while (!frame30) {
        }
    }
}

static readline_ctx_t ctx;
static char           line[256];
static bool           readline_done = true;
static uint32_t       saved_vram[200 * 161 / 2 / sizeof(uint32_t)];

static void save_vram(void) {
    for (unsigned i = 0; i < sizeof(saved_vram) / sizeof(saved_vram[0]); i++) {
        saved_vram[i] = VRAM[i];
    }
}
static void restore_vram(void) {
    for (unsigned i = 0; i < sizeof(saved_vram) / sizeof(saved_vram[0]); i++) {
        VRAM[i] = saved_vram[i];
    }
}

void console_perform(void) {
    VIDEO->PAGE = 0;
    restore_vram();

    if (!booted) {
        booted = true;

        startup_sequence();
        clear_screen(0);

        draw_text("Aqua-8", 0, 7, 7, false);

        game_state.y = 21;

        game_state.color = 6;
        console_puts("Aqua-8 0.0.1\r\n");
        console_puts("(C) 2025 Frank van den Hoef\r\n");
        console_puts("\r\n");
        console_puts("Type ");
        game_state.color = 7;
        console_puts("help");
        game_state.color = 6;
        console_puts(" for help\r\n");
        console_puts("\r\n");
        game_state.color = 7;

        readline_init(&ctx, line, sizeof(line));
    }

    while (1) {
        if (readline_done) {
            game_state.x = 0;
            game_state.y = ((game_state.y + 6) / 7) * 7;
            console_putc('>');
            console_putc(' ');
        }
        readline_done = false;

        while (1) {
            uint8_t ch = console_getc();
            if (ch == 0)
                continue;

            int result = readline_process(&ctx, ch);
            if (result > 0) {
                console_puts("\r\n");
                readline_done = true;
                break;
            }
            if (result < 0) {
                edit_state.editing = true;
                save_vram();
                return;
            }
        }
    }
}
