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

int main(void) {
    // TRAM->init_val1 = 0;
    // TRAM->init_val2 = 0;
    // console_init();
    // console_puts("\r\n Pico-Aq V0.1\r\n\r\n");

    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i & 15];

    for (unsigned j = 0; j < 160; j++) {
        for (unsigned i = 0; i < 24; i++) {
            unsigned col = ((j / 40) * 4 + (i / 6)) & 0xF;

            uint32_t color =
                (col << 28) | (col << 24) |
                (col << 20) | (col << 16) |
                (col << 12) | (col << 8) |
                (col << 4) | (col << 0);

            VRAM[j * 24 + i] = color;
        }
    }

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
