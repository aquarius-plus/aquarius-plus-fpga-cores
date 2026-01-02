#pragma once

#include "common.h"
#include "lua-5.2.4/src/lua.h"
#include "lua-5.2.4/src/lauxlib.h"
#include "lua-5.2.4/src/lualib.h"

void lua_shutdown(void);
void lua_init(void);
void lua_run(const char *name, const void *buf, unsigned size);
