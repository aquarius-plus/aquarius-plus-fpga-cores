#include <stdio.h>

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int main(int argc, const char **argv) {
    (void)argc;
    (void)argv;

    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_openlibs(L);               // Load Lua libraries

    luaL_loadstring(L, "print('Hello, World!')");
    lua_pcall(L, 0, LUA_MULTRET, 0);

    lua_close(L); // Close the Lua state

    return 0;
}
