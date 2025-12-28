#include "common.h"
#include "console.h"
#include <sys/stat.h>
#include <errno.h>

#include "lua.h"
#include "lauxlib.h"
#include "draw.h"
#include "trap.h"
#include "esp.h"
#include "scr.h"

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

    // uint16_t org1 = VIDEO->PALETTE[1];

    unsigned page = 1;
    VIDEO->PAGE   = page;

    while (1) {
        switch (mode) {
            case MODE_CODE: scr_code(); break;
            case MODE_SPRITE: scr_sprite(); break;
            case MODE_MAP: scr_map(); break;
            case MODE_SFX: scr_sfx(); break;
            case MODE_MUSIC: scr_music(); break;
        }

        handle_mouse();

        while (1) {
            int keybuf = KEYBUF;
            if (keybuf < 0)
                break;

            // last = keybuf;
        }

        frame30 = false;
        while (!frame30) {
        }
        page ^= 3;
        VIDEO->PAGE = page;
    }

    return 0;
}
