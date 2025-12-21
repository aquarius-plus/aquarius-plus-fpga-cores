/*
** $Id: lbaselib.c,v 1.276.1.1 2013/04/12 18:48:47 roberto Exp $
** Basic library
** See Copyright Notice in lua.h
*/

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define lbaselib_c
#define LUA_LIB

#include "lua.h"

#include "lauxlib.h"
#include "lualib.h"

static int luaB_print(lua_State *L) {
    int n = lua_gettop(L); /* number of arguments */
    int i;
    lua_getglobal(L, "tostring");
    for (i = 1; i <= n; i++) {
        const char *s;
        size_t      l;
        lua_pushvalue(L, -1); /* function to be called */
        lua_pushvalue(L, i);  /* value to print */
        lua_call(L, 1, 1);
        s = lua_tolstring(L, -1, &l); /* get result */
        if (s == NULL)
            return luaL_error(L, LUA_QL("tostring") " must return a string to " LUA_QL("print"));
        if (i > 1)
            luai_writestring("\t", 1);
        luai_writestring(s, l);
        lua_pop(L, 1); /* pop result */
    }
    luai_writeline();
    return 0;
}

#define SPACECHARS " \f\n\r\t\v"

static int luaB_tonumber(lua_State *L) {
    if (lua_isnoneornil(L, 2)) { /* standard conversion */
        int        isnum;
        lua_Number n = lua_tonumberx(L, 1, &isnum);
        if (isnum) {
            lua_pushnumber(L, n);
            return 1;
        } /* else not a number; must be something */
        luaL_checkany(L, 1);
    } else {
        size_t      l;
        const char *s    = luaL_checklstring(L, 1, &l);
        const char *e    = s + l; /* end point for 's' */
        int         base = luaL_checkint(L, 2);
        int         neg  = 0;
        luaL_argcheck(L, 2 <= base && base <= 36, 2, "base out of range");
        s += strspn(s, SPACECHARS); /* skip initial spaces */
        if (*s == '-') {
            s++;
            neg = 1;
        } /* handle signal */
        else if (*s == '+')
            s++;
        if (isalnum((unsigned char)*s)) {
            lua_Number n = 0;
            do {
                int digit = (isdigit((unsigned char)*s)) ? *s - '0'
                                                         : toupper((unsigned char)*s) - 'A' + 10;
                if (digit >= base)
                    break; /* invalid numeral; force a fail */
                n = n * (lua_Number)base + (lua_Number)digit;
                s++;
            } while (isalnum((unsigned char)*s));
            s += strspn(s, SPACECHARS); /* skip trailing spaces */
            if (s == e) {               /* no invalid trailing characters? */
                lua_pushnumber(L, (neg) ? -n : n);
                return 1;
            } /* else not a number */
        } /* else not a number */
    }
    lua_pushnil(L); /* not a number */
    return 1;
}

static int luaB_getmetatable(lua_State *L) {
    luaL_checkany(L, 1);
    if (!lua_getmetatable(L, 1)) {
        lua_pushnil(L);
        return 1; /* no metatable */
    }
    luaL_getmetafield(L, 1, "__metatable");
    return 1; /* returns either __metatable field (if present) or metatable */
}

static int luaB_setmetatable(lua_State *L) {
    int t = lua_type(L, 2);
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_argcheck(L, t == LUA_TNIL || t == LUA_TTABLE, 2, "nil or table expected");
    if (luaL_getmetafield(L, 1, "__metatable"))
        return luaL_error(L, "cannot change a protected metatable");
    lua_settop(L, 2);
    lua_setmetatable(L, 1);
    return 1;
}

static int luaB_rawequal(lua_State *L) {
    luaL_checkany(L, 1);
    luaL_checkany(L, 2);
    lua_pushboolean(L, lua_rawequal(L, 1, 2));
    return 1;
}

static int luaB_rawlen(lua_State *L) {
    int t = lua_type(L, 1);
    luaL_argcheck(L, t == LUA_TTABLE || t == LUA_TSTRING, 1, "table or string expected");
    lua_pushinteger(L, lua_rawlen(L, 1));
    return 1;
}

static int luaB_rawget(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checkany(L, 2);
    lua_settop(L, 2);
    lua_rawget(L, 1);
    return 1;
}

static int luaB_rawset(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checkany(L, 2);
    luaL_checkany(L, 3);
    lua_settop(L, 3);
    lua_rawset(L, 1);
    return 1;
}

static int luaB_type(lua_State *L) {
    luaL_checkany(L, 1);
    lua_pushstring(L, luaL_typename(L, 1));
    return 1;
}

static int pairsmeta(lua_State *L, const char *method, int iszero, lua_CFunction iter) {
    if (!luaL_getmetafield(L, 1, method)) { /* no metamethod? */
        luaL_checktype(L, 1, LUA_TTABLE);   /* argument must be a table */
        lua_pushcfunction(L, iter);         /* will return generator, */
        lua_pushvalue(L, 1);                /* state, */
        if (iszero)
            lua_pushinteger(L, 0); /* and initial value */
        else
            lua_pushnil(L);
    } else {
        lua_pushvalue(L, 1); /* argument 'self' to metamethod */
        lua_call(L, 1, 3);   /* get 3 values from metamethod */
    }
    return 3;
}

static int luaB_next(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 2); /* create a 2nd argument if there isn't one */
    if (lua_next(L, 1))
        return 2;
    else {
        lua_pushnil(L);
        return 1;
    }
}

static int luaB_pairs(lua_State *L) {
    return pairsmeta(L, "__pairs", 0, luaB_next);
}

static int ipairsaux(lua_State *L) {
    int i = luaL_checkint(L, 2);
    luaL_checktype(L, 1, LUA_TTABLE);
    i++; /* next value */
    lua_pushinteger(L, i);
    lua_rawgeti(L, 1, i);
    return (lua_isnil(L, -1)) ? 1 : 2;
}

static int luaB_ipairs(lua_State *L) {
    return pairsmeta(L, "__ipairs", 1, ipairsaux);
}

static int load_aux(lua_State *L, int status, int envidx) {
    if (status == LUA_OK) {
        if (envidx != 0) {                 /* 'env' parameter? */
            lua_pushvalue(L, envidx);      /* environment for loaded function */
            if (!lua_setupvalue(L, -2, 1)) /* set it as 1st upvalue */
                lua_pop(L, 1);             /* remove 'env' if not used by previous call */
        }
        return 1;
    } else { /* error (message is on top of the stack) */
        lua_pushnil(L);
        lua_insert(L, -2); /* put before error message */
        return 2;          /* return nil plus error message */
    }
}

/*
** {======================================================
** Generic Read function
** =======================================================
*/

/*
** reserved slot, above all arguments, to hold a copy of the returned
** string to avoid it being collected while parsed. 'load' has four
** optional arguments (chunk, source name, mode, and environment).
*/
#define RESERVEDSLOT 5

/*
** Reader for generic `load' function: `lua_load' uses the
** stack for internal stuff, so the reader cannot change the
** stack top. Instead, it keeps its resulting string in a
** reserved slot inside the stack.
*/
static const char *generic_reader(lua_State *L, void *ud, size_t *size) {
    (void)(ud); /* not used */
    luaL_checkstack(L, 2, "too many nested functions");
    lua_pushvalue(L, 1); /* get function */
    lua_call(L, 0, 1);   /* call it */
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1); /* pop result */
        *size = 0;
        return NULL;
    } else if (!lua_isstring(L, -1))
        luaL_error(L, "reader function must return a string");
    lua_replace(L, RESERVEDSLOT); /* save string in reserved slot */
    return lua_tolstring(L, RESERVEDSLOT, size);
}

static int luaB_load(lua_State *L) {
    int         status;
    size_t      l;
    const char *s    = lua_tolstring(L, 1, &l);
    const char *mode = luaL_optstring(L, 3, "bt");
    int         env  = (!lua_isnone(L, 4) ? 4 : 0); /* 'env' index or 0 if no 'env' */
    if (s != NULL) {                                /* loading a string? */
        const char *chunkname = luaL_optstring(L, 2, s);
        status                = luaL_loadbufferx(L, s, l, chunkname, mode);
    } else { /* loading from a reader function */
        const char *chunkname = luaL_optstring(L, 2, "=(load)");
        luaL_checktype(L, 1, LUA_TFUNCTION);
        lua_settop(L, RESERVEDSLOT); /* create reserved slot */
        status = lua_load(L, generic_reader, NULL, chunkname, mode);
    }
    return load_aux(L, status, env);
}

/* }====================================================== */

static int luaB_assert(lua_State *L) {
    if (!lua_toboolean(L, 1))
        return luaL_error(L, "%s", luaL_optstring(L, 2, "assertion failed!"));
    return lua_gettop(L);
}

static int luaB_select(lua_State *L) {
    int n = lua_gettop(L);
    if (lua_type(L, 1) == LUA_TSTRING && *lua_tostring(L, 1) == '#') {
        lua_pushinteger(L, n - 1);
        return 1;
    } else {
        int i = luaL_checkint(L, 1);
        if (i < 0)
            i = n + i;
        else if (i > n)
            i = n;
        luaL_argcheck(L, 1 <= i, 1, "index out of range");
        return n - i;
    }
}

static int luaB_tostring(lua_State *L) {
    luaL_checkany(L, 1);
    luaL_tolstring(L, 1, NULL);
    return 1;
}

//////////////////////////////////////////////////////////////////////////////
// Math functions and operators
//////////////////////////////////////////////////////////////////////////////
typedef lua_Unsigned b_uint;

#define LUA_NBITS 32
#define ALLONES   (~(((~(lua_Unsigned)0) << (LUA_NBITS - 1)) << 1))

// macro to trim extra bits
#define trim(x) ((x) & ALLONES)

static b_uint andaux(lua_State *L) {
    int    i, n = lua_gettop(L);
    b_uint r = ~(b_uint)0;
    for (i = 1; i <= n; i++)
        r &= luaL_checkunsigned(L, i);
    return trim(r);
}

static int b_not(lua_State *L) {
    b_uint r = ~luaL_checkunsigned(L, 1);
    lua_pushunsigned(L, trim(r));
    return 1;
}

static int b_and(lua_State *L) {
    b_uint r = andaux(L);
    lua_pushunsigned(L, r);
    return 1;
}

static int b_or(lua_State *L) {
    int    i, n = lua_gettop(L);
    b_uint r = 0;
    for (i = 1; i <= n; i++)
        r |= luaL_checkunsigned(L, i);
    lua_pushunsigned(L, trim(r));
    return 1;
}

static int b_xor(lua_State *L) {
    int    i, n = lua_gettop(L);
    b_uint r = 0;
    for (i = 1; i <= n; i++)
        r ^= luaL_checkunsigned(L, i);
    lua_pushunsigned(L, trim(r));
    return 1;
}

static int b_shift(lua_State *L, b_uint r, int i) {
    if (i < 0) { // shift right?
        i = -i;
        r = trim(r);
        if (i >= LUA_NBITS)
            r = 0;
        else
            r >>= i;
    } else { // shift left
        if (i >= LUA_NBITS)
            r = 0;
        else
            r <<= i;
        r = trim(r);
    }
    lua_pushunsigned(L, r);
    return 1;
}

static int b_lshift(lua_State *L) {
    return b_shift(L, luaL_checkunsigned(L, 1), luaL_checkint(L, 2));
}

static int b_rshift(lua_State *L) {
    return b_shift(L, luaL_checkunsigned(L, 1), -luaL_checkint(L, 2));
}

static int b_arshift(lua_State *L) {
    b_uint r = luaL_checkunsigned(L, 1);
    int    i = luaL_checkint(L, 2);
    if (i < 0 || !(r & ((b_uint)1 << (LUA_NBITS - 1))))
        return b_shift(L, r, -i);
    else { // arithmetic shift for 'negative' number
        if (i >= LUA_NBITS)
            r = ALLONES;
        else
            r = trim((r >> i) | ~(~(b_uint)0 >> i)); /* add signal bit */
        lua_pushunsigned(L, r);
        return 1;
    }
}

static int b_rot(lua_State *L, int i) {
    b_uint r = luaL_checkunsigned(L, 1);
    i &= (LUA_NBITS - 1); /* i = i % NBITS */
    r = trim(r);
    if (i != 0) /* avoid undefined shift of LUA_NBITS when i == 0 */
        r = (r << i) | (r >> (LUA_NBITS - i));
    lua_pushunsigned(L, trim(r));
    return 1;
}

static int b_lrot(lua_State *L) {
    return b_rot(L, luaL_checkint(L, 2));
}

static int b_rrot(lua_State *L) {
    return b_rot(L, -luaL_checkint(L, 2));
}

//////////////////////////////////////////////////////////////////////////////

static const luaL_Reg base_funcs[] = {
    {"assert", luaB_assert},
    {"getmetatable", luaB_getmetatable},
    {"ipairs", luaB_ipairs},
    {"load", luaB_load},
    {"next", luaB_next},
    {"pairs", luaB_pairs},
    {"print", luaB_print},
    {"rawequal", luaB_rawequal},
    {"rawlen", luaB_rawlen},
    {"rawget", luaB_rawget},
    {"rawset", luaB_rawset},
    {"select", luaB_select},
    {"setmetatable", luaB_setmetatable},
    {"tonum", luaB_tonumber},
    {"tostring", luaB_tostring},
    {"type", luaB_type},

    // Math functions and operators
    {"bnot", b_not},
    {"band", b_and},
    {"bor", b_or},
    {"bxor", b_xor},

    {"shl", b_lshift},
    {"shr", b_arshift},
    {"lshr", b_rshift},
    {"rotl", b_lrot},
    {"rotr", b_rrot},

    {NULL, NULL},
};

LUAMOD_API int luaopen_base(lua_State *L) {
    /* set global _G */
    lua_pushglobaltable(L);
    lua_pushglobaltable(L);
    lua_setfield(L, -2, "_G");
    /* open lib into global table */
    luaL_setfuncs(L, base_funcs, 0);
    lua_pushliteral(L, LUA_VERSION);
    lua_setfield(L, -2, "_VERSION"); /* set global _VERSION */
    return 1;
}
