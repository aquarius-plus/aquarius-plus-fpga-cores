#pragma once

#include "lobject.h"

#define sizeCclosure(n) (cast(int, sizeof(CClosure)) + cast(int, sizeof(TValue) * ((n) - 1)))

#define sizeLclosure(n) (cast(int, sizeof(LClosure)) + cast(int, sizeof(TValue *) * ((n) - 1)))

Proto      *luaF_newproto(lua_State *L);
Closure    *luaF_newCclosure(lua_State *L, int nelems);
Closure    *luaF_newLclosure(lua_State *L, int nelems);
UpVal      *luaF_newupval(lua_State *L);
UpVal      *luaF_findupval(lua_State *L, StkId level);
void        luaF_close(lua_State *L, StkId level);
void        luaF_freeproto(lua_State *L, Proto *f);
void        luaF_freeupval(lua_State *L, UpVal *uv);
const char *luaF_getlocalname(const Proto *func, int local_number, int pc);
