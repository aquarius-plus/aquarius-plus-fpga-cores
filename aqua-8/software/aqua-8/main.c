#include "common.h"
#include "console.h"
#include <sys/stat.h>
#include <errno.h>

#include "lua.h"
#include "lauxlib.h"
#include "draw.h"
#include "trap.h"
#include "esp.h"

int luaopen_base(lua_State *L);

volatile bool frame30 = false;

void vblank_handler(void) {
    static unsigned frame = 0;
    frame++;

    // if (frame & 1)
    {
        frame30 = true;
    }
}

void trap_handler(struct trap_regs *regs) {
    unsigned mip = csr_read_clear(mip, -1UL);
    if (mip & (1 << VBLANK_IRQn)) {
        vblank_handler();
    }
}

enum {
    MODE_CONSOLE = 0,
    MODE_CODE    = 1,
    MODE_SPRITE  = 2,
    MODE_MAP     = 3,
    MODE_SFX     = 4,
    MODE_MUSIC   = 5,
};

static int      mode = MODE_CODE;
static unsigned sec  = 0;
static uint16_t last = 0;

void screen_code(void) {
    fill_rect(0, 7, 199, 152, 1);

    char bla[32];
    snprintf(bla, sizeof(bla), "bla: %u", sec);
    draw_text(bla, 50, 50, 7, false);
    snprintf(bla, sizeof(bla), "last: %04x", last);
    draw_text(bla, 50, 60, 7, false);

    draw_text("Line 1/1 Col 1", 1, 154, 14, true);

    // VRAM4BIT[0]++;
}

void screen_sprite(void) {
    fill_rect(0, 7, 199, 152, 5);

    int x, y;

    // draw_text("#0", 1, 8, 7, false);

    // Palette
    {
        x = 1;
        y = 8;

        draw_rect(x, y, x + 1 + 64, y + 1 + 16, 0);
        x += 1;
        y += 1;

        for (int i = 0; i < 16; i++) {
            int row = i / 8;
            int col = i % 8;

            fill_rect(
                x + col * 8, y + row * 8,
                x + col * 8 + 7, y + row * 8 + 7,
                i);
        }
    }

    // Sprite overview
    {
        x = 200 - 128 - 3;
        y = 8;
        draw_rect(x, y, x + 1 + 128, y + 1 + 128, 0);
        fill_rect(x + 1, y + 1, x + 128, y + 128, 0);
        x += 1;
        y += 1;

        for (int i = 0; i < 256; i++) {
            int row = i / 16;
            int col = i % 16;

            draw_game_sprite(i, x + col * 8, y + row * 8);
        }
    }

    // Sprite editor
    {
        x = 1;
        y = 27;
        draw_rect(x, y, x + 1 + 64, y + 1 + 64, 0);
    }

    // Commands
    {
        x = 5;
        y = 98;

        for (int i = 0; i < 6; i++) {
            draw_icon(x + i * 10, y, 16 + i, i == 0 ? 7 : 13);
        }

        y += 9;
        for (int i = 0; i < 6; i++) {
            draw_icon(x + i * 10, y, 32 + i, 13);
        }
    }
}

void screen(void) {
    fill_rect(0, 0, 199, 6, 8);
    fill_rect(0, 159 - 6, 199, 159, 2);

    // Mode icons
    {
        int x = 200 - 5 * 8;
        draw_icon(x, 1, 0, mode == MODE_CODE ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 1, mode == MODE_SPRITE ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 2, mode == MODE_MAP ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 3, mode == MODE_SFX ? 7 : 2);
        x += 8;
        draw_icon(x, 1, 4, mode == MODE_MUSIC ? 7 : 2);
    }

    const char *title = "";
    switch (mode) {
        case MODE_CODE: title = "Code editor"; break;
        case MODE_SPRITE: title = "Sprite editor"; break;
        case MODE_MAP: title = "Map editor"; break;
        case MODE_SFX: title = "SFX editor"; break;
        case MODE_MUSIC: title = "Music editor"; break;
    }
    draw_text(title, 1, 1, 15, true);

    switch (mode) {
        case MODE_CODE: title = "Code editor"; break;
        case MODE_SPRITE: title = "Sprite editor"; break;
        case MODE_MAP: title = "Map editor"; break;
        case MODE_SFX: title = "SFX editor"; break;
        case MODE_MUSIC: title = "Music editor"; break;
    }

    switch (mode) {
        case MODE_CODE: screen_code(); break;
        case MODE_SPRITE: screen_sprite(); break;
        case MODE_MAP: break;
        case MODE_SFX: break;
        case MODE_MUSIC: break;
    }

    // // draw_hline(10, 10, 100, 7);
    // // draw_vline(10, 10, 100, 7);
    // // draw_hline(10, 109, 100, 7);
    // // draw_vline(109, 10, 100, 7);

    // for (int i = 0; i < 16; i++) {
    //     fill_rect(i * 8, 30, i * 8 + 7, 37, i);
    // }
}

void draw_mouse_cursor(int x, int y) {
    int spr = 0;
    if (y < 7 && x >= 200 - 5 * 8) {
        spr = 1;
    } else if (y >= 7 && y < 160 - 7 && mode == MODE_CODE)
        spr = 2;

    int sx = x;
    int sy = y;
    switch (spr) {
        case 0: // Pointer
            sx -= 1;
            sy -= 1;
            break;
        case 1: // Hand
            sx -= 3;
            sy -= 1;
            break;
        case 2: // I-beam
            sx -= 1;
            sy -= 4;
            break;
        default: break;
    }

    draw_sprite(spr, sx, sy);
}

void on_click(int x, int y, int buttons) {
    int buttons_left = 200 - 5 * 8;

    if (y < 7 && x >= buttons_left && x < 200) {
        mode = MODE_CODE + (x - buttons_left) / 8;
    }
}

void handle_mouse(void) {
    static uint8_t prev_buttons = 0;

    esp_cmd(ESPCMD_GETMOUSE);
    uint8_t result = esp_get_byte();
    if (result == 0) {
        uint16_t x = esp_get_byte();
        x |= esp_get_byte() << 8;
        uint8_t y       = esp_get_byte();
        uint8_t buttons = esp_get_byte();
        int8_t  wheel   = esp_get_byte();

        // char bla[32];
        // snprintf(bla, sizeof(bla), "%u %u %u %d", x, y, buttons, wheel);
        // draw_text(bla, 50, 70, 7, false);

        uint8_t pressed_buttons = ~prev_buttons & buttons;
        prev_buttons            = buttons;

        if (pressed_buttons)
            on_click(x, y, buttons);

        draw_mouse_cursor(x, y);
    }
}

int main(void) {
    esp_closeall();

    palette_init();
    remap_reset();

    __irq_enable();
    csr_write(mie, (1 << VBLANK_IRQn));

    unsigned t = 0;

    screen();

    // uint16_t org1 = VIDEO->PALETTE[1];

    unsigned page = 1;
    VIDEO->PAGE   = page;

    while (1) {
        frame30 = false;
        while (!frame30) {
        }
        page ^= 3;
        VIDEO->PAGE = page;

        screen();
        handle_mouse();

        if (++t % 30 == 0)
            sec++;

        while (1) {
            int keybuf = KEYBUF;
            if (keybuf < 0)
                break;

            last = keybuf;
        }
    }

    return 0;
}
