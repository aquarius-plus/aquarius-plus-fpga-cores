#include "common.h"
#include "console.h"
#include <sys/stat.h>
#include <errno.h>

#include "lua.h"
#include "lauxlib.h"

void load_executable(const char *path);

int luaopen_base(lua_State *L);

static const uint16_t palette[16] = {
    0x000,
    0x125,
    0x725,
    0x085,
    0xA53,
    0x554,
    0xCCC,
    0xFFE,
    0xF04,
    0xFA0,
    0xFF2,
    0x0E5,
    0x2AF,
    0x879,
    0xF7A,
    0xFCA};

static const uint8_t font[1016] = {
#include "font.inl"
};

void scr_pset(int x, int y, unsigned color) {
    VRAM4BIT[y * 192 + x] = color;
}

void draw_char(int x, int y, uint8_t ch, unsigned color) {
    if (ch < 32 || ch > 127)
        return;
    ch -= 32;

    const uint8_t *p = &font[ch * 8];

    for (int j = 0; j < 6; j++) {
        for (int i = 0; i < 5; i++) {
            if (*p & (1 << i))
                scr_pset(x + i, y + j, color);
        }
        p++;
    }
}

void scr_print(const char *str, int x, int y, unsigned color) {
    while (*str) {
        draw_char(x, y, *str, color);
        x += 6;
        str++;
    }
}

int main(void) {
    // TRAM->init_val1 = 0;
    // TRAM->init_val2 = 0;
    // console_init();
    // console_puts("\r\n AQUA-8 V0.1\r\n\r\n");

    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i & 15];

    for (unsigned j = 0; j < 160; j++) {
        for (unsigned i = 0; i < 24; i++) {
            unsigned col = 1; //((j / 40) * 4 + (i / 6)) & 0xF;

            uint32_t color =
                (col << 28) | (col << 24) |
                (col << 20) | (col << 16) |
                (col << 12) | (col << 8) |
                (col << 4) | (col << 0);

            VRAM[j * 24 + i] = color;
        }
    }

    // *((uint32_t *)((uint8_t *)VRAM + 0)) = 0x00000007;

    VRAM_OFFSET = 0;

    // VRAM[0]      = 0x00000007;
    // VRAM[24]     = 0x00000070;
    // VRAM[24 * 2] = 0x00000700;
    // VRAM[24 * 3] = 0x00007000;
    // VRAM[24 * 4] = 0x00070000;
    // VRAM[24 * 5] = 0x00700000;
    // VRAM[24 * 6] = 0x07000000;
    // VRAM[24 * 7] = 0x70000000;

    // ((uint32_t *)VRAM4BIT)[0] = 0x0000007;

    for (int ch = 32; ch < 127; ch++) {
        draw_char((ch & 31) * 6, (ch / 32) * 7, ch, 6);
    }

    // for (int j = 0; j < 20; j++)
    //     draw_str(8, j * 7, "lua_State *L = luaL_newstate();", 6);

#if 0
    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_requiref(L, "_G", luaopen_base, 1);

    luaL_loadstring(
        L,
        "a=2^3;\n"
        "print(a)\n"
        "print('Hello, World!')\n");
    lua_pcall(L, 0, LUA_MULTRET, 0);

    lua_close(L); // Close the Lua state
#endif

    while (1);

    // load_executable("/cores/aq32/shell.aq32");
    return 0;
}
