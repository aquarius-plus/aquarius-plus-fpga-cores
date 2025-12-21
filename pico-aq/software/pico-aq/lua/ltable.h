#pragma once

#include "lobject.h"

#define gnode(t, i) (&(t)->node[i])
#define gkey(n)     (&(n)->i_key.tvk)
#define gval(n)     (&(n)->i_val)
#define gnext(n)    ((n)->i_key.nk.next)

#define invalidateTMcache(t) ((t)->flags = 0)

/* returns the key, given the value of a table entry */
#define keyfromval(v) \
    (gkey(cast(Node *, cast(char *, (v)) - offsetof(Node, i_val))))

const TValue *luaH_getint(Table *t, int key);
void          luaH_setint(lua_State *L, Table *t, int key, TValue *value);
const TValue *luaH_getstr(Table *t, TString *key);
const TValue *luaH_get(Table *t, const TValue *key);
TValue       *luaH_newkey(lua_State *L, Table *t, const TValue *key);
TValue       *luaH_set(lua_State *L, Table *t, const TValue *key);
Table        *luaH_new(lua_State *L);
void          luaH_resize(lua_State *L, Table *t, int nasize, int nhsize);
void          luaH_resizearray(lua_State *L, Table *t, int nasize);
void          luaH_free(lua_State *L, Table *t);
int           luaH_next(lua_State *L, Table *t, StkId key);
int           luaH_getn(Table *t);

#if defined(LUA_DEBUG)
Node *luaH_mainposition(const Table *t, const TValue *key);
int   luaH_isdummy(Node *n);
#endif
