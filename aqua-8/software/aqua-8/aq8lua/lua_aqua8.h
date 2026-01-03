#pragma once

#include "common.h"
#include "z8lua/lua.h"
#include "z8lua/lauxlib.h"
#include "z8lua/lualib.h"

void lua_shutdown(void);
void lua_init(void);
void lua_run(const char *name, const void *buf, unsigned size);
