/*
** $Id: lualib.h,v 1.43.1.1 2013/04/12 18:48:47 roberto Exp $
** Lua standard libraries
** See Copyright Notice in lua.h
*/

#ifndef lualib_h
#define lualib_h

#include "lua.h"

int luaopen_base(lua_State *L);

#define LUA_TABLIBNAME "table"
int luaopen_table(lua_State *L);

#define LUA_STRLIBNAME "string"
int luaopen_string(lua_State *L);

#define LUA_MATHLIBNAME "math"
int luaopen_math(lua_State *L);

#define LUA_LOADLIBNAME "package"
int luaopen_package(lua_State *L);

/* open all previous libraries */
void luaL_openlibs(lua_State *L);

#if !defined(lua_assert)
#define lua_assert(x) ((void)0)
#endif

#endif
