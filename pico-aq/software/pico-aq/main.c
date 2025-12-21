#include "common.h"
#include "console.h"
#include <sys/stat.h>
#include <errno.h>

#include "lua.h"
#include "lauxlib.h"

void load_executable(const char *path);

int luaopen_base(lua_State *L);

int main(void) {
    TRAM->init_val1 = 0;
    TRAM->init_val2 = 0;
    console_init();
    console_puts("\r\n Pico-Aq V0.1\r\n\r\n");

    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_requiref(L, "_G", luaopen_base, 1);

    luaL_loadstring(
        L,
        "a=2^3;\n"
        "print(a)\n"
        "print('Hello, World!')\n");
    lua_pcall(L, 0, LUA_MULTRET, 0);

    lua_close(L); // Close the Lua state


    while (1);

    // load_executable("/cores/aq32/shell.aq32");
    return 0;
}
