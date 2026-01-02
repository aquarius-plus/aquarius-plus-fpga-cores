#define LUA_LIB
#include "lua_aqua8.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "state.h"

static void mylib_register(lua_State *L);

static void print_lua_error(const char *type, lua_State *L) {
    printf("\fE%s\f6\n", type);

    if (!lua_isnil(L, -1)) {
        const char *msg = lua_tostring(L, -1);
        if (msg == NULL)
            msg = "(error object is not a string)";

        if (memcmp(msg, "[string \"C\"]:", 13) == 0) {
            msg += 13;
            printf("Line %s\n", msg);
        } else if (memcmp(msg, "[string \"I\"]:1: ", 16) == 0) {
            msg += 16;
            if (strncmp(msg, "syntax error", 12) != 0)
                printf("%s\n", msg);
        } else {
            printf("%s\n", msg);
        }

        lua_pop(L, 1);

        // force a complete garbage collection in case of errors
        lua_gc(L, LUA_GCCOLLECT, 0);
    }
}

void lua_shutdown(void) {
    if (game_state.L) {
        lua_close(game_state.L);
        game_state.L = NULL;
    }
}

void lua_init(void) {
    if (game_state.L) {
        return;
    }

    game_state.L = luaL_newstate();
    if (game_state.L == NULL) {
        printf("Error creating Lua state\n");
        return;
    }
    mylib_register(game_state.L);
}

void lua_run(const char *name, const void *buf, unsigned size) {
    if (!game_state.L) {
        return;
    }

    int result = luaL_loadbufferx(game_state.L, (const char *)buf, size, name, "text");
    if (result != LUA_OK) {
        print_lua_error("Syntax error", game_state.L);
        return;
    }

    result = lua_pcall(game_state.L, 0, LUA_MULTRET, 0);
    if (result != LUA_OK) {
        print_lua_error("Runtime error", game_state.L);
        return;
    }
}

static int my_print(lua_State *L) {
    // Get number of arguments
    int n = lua_gettop(L);

    lua_getglobal(L, "tostring");

    for (int i = 1; i <= n; i++) {
        const char *s;
        size_t      l;
        lua_pushvalue(L, -1); // function to be called
        lua_pushvalue(L, i);  // value to print
        lua_call(L, 1, 1);

        s = lua_tolstring(L, -1, &l); // get result
        if (s == NULL)
            return luaL_error(L, LUA_QL("tostring") " must return a string to " LUA_QL("print"));
        if (i > 1)
            luai_writestring("\t", 1);

        luai_writestring(s, l);
        lua_pop(L, 1); // pop result
    }

    luai_writeline();
    return 0;
}

// Based on luaL_tolstring (lauxlib.c)
static int my_tostring(lua_State *L) {
    luaL_checkany(L, 1);

    if (!luaL_callmeta(L, 1, "__tostring")) {
        switch (lua_type(L, 1)) {
            case LUA_TNUMBER:
            case LUA_TSTRING:
                lua_pushvalue(L, 1);
                break;
            case LUA_TBOOLEAN:
                lua_pushstring(L, (lua_toboolean(L, 1) ? "true" : "false"));
                break;
            case LUA_TNIL:
                lua_pushliteral(L, "[nil]");
                break;
            default:
                lua_pushfstring(L, "[%s]", luaL_typename(L, 1));
                break;
        }
    }
    lua_tolstring(L, -1, NULL);
    return 1;
}

int my_cls(lua_State *L) {
    int n = lua_gettop(L); /* number of arguments */

    int color_idx = 0;
    if (n > 0) {
        if (!lua_isnumber(L, 1)) {
            lua_pushstring(L, "incorrect argument");
            lua_error(L);
        }
        color_idx = 0; //(lua_tonumber(L, 1) >> 16) & 15;
    }

    printf("cls(%d)\n", color_idx);
    // printf("cls! n=%d\n", n);

    // // lua_pushnumber(L, 123 << 16);
    // lua_pushstring(L, "dinges");
    // lua_pushinteger(L, 123 << 16);
    return 0;
}

static const luaL_Reg funcs[] = {
    {"cls", my_cls},
    {"print", my_print},
    {"tostring", my_tostring},
};

void mylib_register(lua_State *L) {
    lua_pushglobaltable(L);
    lua_pushglobaltable(L);
    lua_setfield(L, -2, "_G");
    luaL_setfuncs(L, funcs, 0);
}

int my_number2str(char *s, int32_t n) {
    int len = sprintf(s, "%.4f", (double)n / 65536.0);

    // Trim trailing zeros
    char *s2 = s + len;
    while (s2[-1] == '0')
        s2--;
    if (s2[-1] == '.')
        s2--;
    *s2 = 0;

    return s2 - s;
}

int32_t my_str2number(const char *s, char **endp) {
    return (int32_t)(strtod(s, endp) * 65536.0);
}

int32_t my_nummul(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * (int64_t)b) >> 16LL);
}

int32_t my_numdiv(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a << 16LL) / (int64_t)b);
}

int32_t my_nummod(int32_t a, int32_t b) {
    return a - my_nummul(my_numdiv(a, b) & ~0xFFFF, b);
}

int32_t my_numpow(int32_t a, int32_t b) {
    double fa = (double)a / 65536.0;
    double fb = (double)b / 65536.0;
    return (int32_t)(pow(fa, fb) * 65536.0);
}
