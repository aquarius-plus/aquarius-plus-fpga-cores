#include <stdio.h>

#include "lua.h"
#include "lauxlib.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

int luaopen_base(lua_State *L);

int main(int argc, const char **argv) {
    (void)argc;
    (void)argv;

    lua_State *L = luaL_newstate(); // Create a new Lua state
    luaL_requiref(L, "_G", luaopen_base, 1);

    luaL_loadstring(L, R"lua(
        function a()
            print("1")
        end

        function b()
            print("2")
        end
    )lua");

    int ret = lua_pcall(L, 0, LUA_MULTRET, 0);

    // lua_register()

    // lua_getglobal(L, "b");
    // lua_pcall(L, 0, 0, 0);

    // luaL_loadstring(L, "b()");
    // lua_pcall(L, 0, LUA_MULTRET, 0);
    // luaL_loadstring(L, "a()");
    // lua_pcall(L, 0, LUA_MULTRET, 0);

    // luaL_loadstring(
    //     L,
    //     "a=2^3;\n"
    //     "print(a)\n"
    //     "print(cls(1))\n"
    //     "print('Hello, World!')\n"
    //     // "?6\n"
    // );
    // int ret = lua_pcall(L, 0, LUA_MULTRET, 0);

    if (ret != LUA_OK) {
        const char *msg = (lua_type(L, -1) == LUA_TSTRING) ? lua_tostring(L, -1) : NULL;
        if (msg == NULL)
            msg = "(error object is not a string)";

        printf("Error: %s\n", msg);
        lua_pop(L, 1);
    }

    lua_close(L); // Close the Lua state

    return 0;
}
