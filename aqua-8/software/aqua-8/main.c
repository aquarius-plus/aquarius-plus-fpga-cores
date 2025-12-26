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

static const uint8_t font[760] = {
#include "font.inl"
};
static const uint8_t font2[760] = {
#include "altfont.inl"
};

void scr_pset(int x, int y, unsigned color) {
    REG_POSX16 = x;
    REG_POSY16 = y;
    REG_WR4BPP = color;

    // VRAM4BIT[y * 192 + x] = color;
}

void draw_char(int x, int y, uint8_t ch, unsigned color) {
    if (ch < 32 || ch > 127)
        return;
    ch -= 32;

    const uint8_t *p = &font[ch * 8];

    REG_COLOR  = color;
    REG_FLAGS  = 1;
    REG_POSX16 = x;
    REG_POSY16 = y;
    REG_WR1BPP = p[0];
    REG_WR1BPP = p[1];
    REG_WR1BPP = p[2];
    REG_WR1BPP = p[3];
    REG_WR1BPP = p[4];
    REG_WR1BPP = p[5];
}

void draw_char2(int x, int y, uint8_t ch, unsigned color) {
    if (ch < 32 || ch > 127)
        return;
    ch -= 32;

    const uint8_t *p = &font2[ch * 8];

    REG_COLOR  = color;
    REG_FLAGS  = 1;
    REG_POSX16 = x;
    REG_POSY16 = y;
    REG_WR1BPP = p[0];
    REG_WR1BPP = p[1];
    REG_WR1BPP = p[2];
    REG_WR1BPP = p[3];
    REG_WR1BPP = p[4];
    REG_WR1BPP = p[5];
}

void scr_print(const char *str, int x, int y, unsigned color) {
    while (*str) {
        draw_char(x, y, *str, color);
        x += 6;
        str++;
    }
}

static void wait_frame(void) {
    while ((csr_read_clear(mip, (1 << 16)) & (1 << 16)) == 0);
}

int main(void) {
    // TRAM->init_val1 = 0;
    // TRAM->init_val2 = 0;
    // console_init();
    // console_puts("\r\n AQUA-8 V0.1\r\n\r\n");

    unsigned cnt = 0;

    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i & 15];
    for (int i = 0; i < 16; i++)
        REMAPPING[i] = i;
    REG_REMAPT = 0x0;

    // for (unsigned j = 0; j < 160; j++) {
    //     for (unsigned i = 0; i < 24; i++) {
    //         unsigned col = 1; //((j / 40) * 4 + (i / 6)) & 0xF;

    //         uint32_t color =
    //             (col << 28) | (col << 24) |
    //             (col << 20) | (col << 16) |
    //             (col << 12) | (col << 8) |
    //             (col << 4) | (col << 0);

    //         VRAM[j * 24 + i] = color;
    //     }
    // }

    // *((uint32_t *)((uint8_t *)VRAM + 0)) = 0x00000007;

    // VRAM[0]      = 0x00000007;
    // VRAM[24]     = 0x00000070;
    // VRAM[24 * 2] = 0x00000700;
    // VRAM[24 * 3] = 0x00007000;
    // VRAM[24 * 4] = 0x00070000;
    // VRAM[24 * 5] = 0x00700000;
    // VRAM[24 * 6] = 0x07000000;
    // VRAM[24 * 7] = 0x70000000;

    // ((uint32_t *)VRAM4BIT)[0] = 0x0000007;

    // for (int ch = 32; ch < 127; ch++) {
    //     draw_char((ch & 31) * 6, (ch / 32) * 7, ch, 6);
    // }

    // for (int ch = 32; ch < 127; ch++) {
    //     draw_char2((ch & 31) * 5, 40 + (ch / 32) * 7, ch, 6);
    // }

    // // REG_FLAGS = 4;
    // scr_pset(0, 100, 0x77777777);
    // scr_pset(-1, 101, 0x77777777);
    // scr_pset(-2, 102, 0x77777777);
    // scr_pset(-3, 103, 0x77777777);
    // scr_pset(-4, 104, 0x77777777);
    // scr_pset(-5, 105, 0x77777777);
    // scr_pset(-6, 106, 0x77777777);
    // scr_pset(-7, 107, 0x77777777);
    // scr_pset(-8, 108, 0x77777777);

    // scr_pset(192 - 8, 108, 0x77777777);
    // scr_pset(192 - 7, 107, 0x77777777);
    // scr_pset(192 - 6, 106, 0x77777777);
    // scr_pset(192 - 5, 105, 0x77777777);
    // scr_pset(192 - 4, 104, 0x77777777);
    // scr_pset(192 - 3, 103, 0x77777777);
    // scr_pset(192 - 2, 102, 0x77777777);
    // scr_pset(192 - 1, 101, 0x77777777);
    // scr_pset(192 - 0, 100, 0x77777777);

    unsigned page = 0;
    REG_PAGE      = page;

    for (unsigned i = 0; i < 24 * 160; i++) {
        VRAM[i] = 0x11111111;
    }

    int x1   = 0;
    int x2   = 192;
    int y1   = 0;
    int y2   = 160;
    int xdir = 1;

    while (1) {
        PALETTE[1] = 0x080;

        REG_CLIPRECT = (y2 << 24) | (y1 << 16) | (x2 << 8) | (x1 << 0);

        for (unsigned i = 0; i < 24 * 160; i++) {
            VRAM[i] = 0x11111111;
        }

        for (int i = 0; i < 23; i++) {
            // char tmp[64];
            // snprintf(tmp, sizeof(tmp), "Hello world %6u %6u %6u", cnt, cnt, cnt);
            // scr_print(tmp, 0, i * 7, 7);
            // char tmp[64];
            // snprintf(tmp, sizeof(tmp), "Hello world %6u %6u %6u", cnt, cnt, cnt);
            scr_print("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 1, 1+i * 7, 7);
        }

        PALETTE[1] = 0x008;

        // cnt++;

        // Wait for vsync
        wait_frame();
        page ^= 3;
        REG_PAGE = page;

#if 0
        x1 += xdir;
        if (x1 <= 0)
            xdir = 1;
        else if (x1 >= 191)
            xdir = -1;
#endif
#if 0
        x2 += xdir;
        if (x2 <= 0)
            xdir = 1;
        else if (x2 >= 191)
            xdir = -1;
#endif
#if 0
        y1 += xdir;
        if (y1 <= 0)
            xdir = 1;
        else if (y1 >= 159)
            xdir = -1;
#endif
#if 0
        y2 += xdir;
        if (y2 <= 0)
            xdir = 1;
        else if (y2 >= 159)
            xdir = -1;
#endif
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
