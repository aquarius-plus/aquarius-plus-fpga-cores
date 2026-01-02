#pragma once

#include "common.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

void lua_shutdown(void);
void lua_init(void);
void lua_run(const char *name, const void *buf, unsigned size);
