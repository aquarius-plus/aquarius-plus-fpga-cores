#include "myfuncs.h"

#include <stdio.h>

int my_cls(lua_State *L) {
    int n = lua_gettop(L); /* number of arguments */

    int color_idx = 0;
    if (n > 0) {
        if (!lua_isnumber(L, 1)) {
            lua_pushstring(L, "incorrect argument");
            lua_error(L);
        }
        color_idx = (lua_tonumber(L, 1) >> 16) & 15;
    }

    printf("cls(%d)\n", color_idx);
    // printf("cls! n=%d\n", n);

    // // lua_pushnumber(L, 123 << 16);
    // lua_pushstring(L, "dinges");
    // lua_pushinteger(L, 123 << 16);
    return 0;
}
