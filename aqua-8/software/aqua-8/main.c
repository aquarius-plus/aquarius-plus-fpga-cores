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

// void draw_mouse_cursor(int x, int y) {
//     int spr = 0;
//     if (y < 7 && x >= 200 - 5 * 8) {
//         spr = 1;
//     } else if (y >= 7 && y < 160 - 7 && state.mode == MODE_CODE)
//         spr = 2;

//     int sx = x;
//     int sy = y;
//     switch (spr) {
//         case 0: // Pointer
//             sx -= 1;
//             sy -= 1;
//             break;
//         case 1: // Hand
//             sx -= 3;
//             sy -= 1;
//             break;
//         case 2: // I-beam
//             sx -= 1;
//             sy -= 4;
//             break;
//         default: break;
//     }

//     draw_sprite(spr, sx, sy);
// }

static void handle_mouse(void) {
    static uint8_t prev_buttons = 0;

    esp_cmd(ESPCMD_GETMOUSE);
    uint8_t result = esp_get_byte();
    if (result == 0) {
        uint16_t x = esp_get_byte();
        x |= esp_get_byte() << 8;
        uint8_t y       = esp_get_byte();
        uint8_t buttons = esp_get_byte();
        int8_t  wheel   = esp_get_byte();

        if (x > 240)
            x = 240;

        // char bla[32];
        // snprintf(bla, sizeof(bla), "%u %u %u %d", x, y, buttons, wheel);
        // draw_text(bla, 50, 70, 7, false);

        edit_state.mouse_spr = MOUSE_SPR_POINTER;

        uint8_t clicked_buttons = ~prev_buttons & buttons;
        prev_buttons            = buttons;

        edit_state.mouse_ev.x               = x;
        edit_state.mouse_ev.y               = y;
        edit_state.mouse_ev.buttons         = buttons;
        edit_state.mouse_ev.clicked_buttons = clicked_buttons;
        edit_state.mouse_ev.wheel           = wheel;
    }
}

uint16_t lastKeys[16];

static void draw_mouse_cursor(void) {
    int sx = edit_state.mouse_ev.x;
    int sy = edit_state.mouse_ev.y;
    switch (edit_state.mouse_spr) {
        case MOUSE_SPR_POINTER:
            sx -= 1;
            sy -= 1;
            break;
        case MOUSE_SPR_HAND:
            sx -= 3;
            sy -= 1;
            break;
        case MOUSE_SPR_IBEAM:
            sx -= 1;
            sy -= 4;
            break;
        case MOUSE_SPR_CROSSHAIR:
            sx -= 3;
            sy -= 3;
            break;
        default: break;
    }
    draw_sprite(edit_state.mouse_spr, sx, sy);
}

static void handle_keybuf(void) {
    while (1) {
        int keybuf = KEYBUF;
        if (keybuf < 0)
            break;

        for (int i = 0; i < 15; i++) {
            lastKeys[i] = lastKeys[i + 1];
        }
        lastKeys[15]         = keybuf;
        edit_state.modifiers = keybuf & KEY_MODIFIERS;
        scr_key(keybuf);

        // last = keybuf;
    }
}

uint8_t code_buf[64 * 1024];

int main(void) {
    esp_closeall();

    palette_init();
    remap_reset();

    __irq_enable();
    csr_write(mie, (1 << VBLANK_IRQn));

    editbuf_init(&edit_state.code_edit.editbuf, code_buf, sizeof(code_buf));

    if (editbuf_load(&edit_state.code_edit.editbuf, "/sdk/cb/projects/tetris/tetris.cb")) {
        edit_state.mode = MODE_CODE;
    }

    // uint16_t org1 = VIDEO->PALETTE[1];

    unsigned page = 1;
    VIDEO->PAGE   = page;

    while (1) {
        // VIDEO->PALETTE[5] = 0xFFF;
        handle_mouse();
        handle_keybuf();

        edit_state.status_text[0] = 0;
        scr_get_current()->draw();
        scr_draw_status();
        draw_mouse_cursor();
        edit_state.mouse_ev.clicked_buttons = 0;
        edit_state.mouse_ev.wheel           = 0;

#if 0
        for (int i = 0; i < 16; i++) {
            char buf[16];
            snprintf(buf, sizeof(buf), "%04X\n", lastKeys[i]);
            draw_text(buf, 10, 10 + i * 8, 7, true);
        }
#endif

        palette_init();

        frame30 = false;
        while (!frame30) {
        }
        page ^= 3;
        VIDEO->PAGE = page;
    }

    return 0;
}
