#define LUA_LIB
#include "lua_aqua8.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "state.h"
#include "func_gfx.h"

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
        } else if (memcmp(msg, "[string \"I\"]:0: ", 16) == 0) {
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

// Based on luaL_tolstring (lauxlib.c)
static int laq8_tostring(lua_State *L) {
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

static const luaL_Reg funcs[] = {
    {"cls", laq8_cls},
    {"print", laq8_print},
    {"tostring", laq8_tostring},
};

void mylib_register(lua_State *L) {
    lua_pushglobaltable(L);
    lua_pushglobaltable(L);
    lua_setfield(L, -2, "_G");
    luaL_setfuncs(L, funcs, 0);
}
