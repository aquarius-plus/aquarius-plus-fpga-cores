#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

int luaopen_base(lua_State *L);

int main(int argc, const char **argv) {
    (void)argc;
    (void)argv;

    lua_State *L = luaL_newstate(); // Create a new Lua state

    luaL_requiref(L, "_G", luaopen_base, 1);

    // luaL_openlibs(L); // Load Lua libraries

    luaL_loadstring(L, "print('Hello, World!')");
    lua_pcall(L, 0, LUA_MULTRET, 0);

    lua_close(L); // Close the Lua state

    return 0;
}
