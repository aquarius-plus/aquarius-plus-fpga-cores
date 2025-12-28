#pragma once

#include "common.h"
#include "draw.h"

enum {
    MODE_CONSOLE = 0,
    MODE_CODE    = 1,
    MODE_SPRITE  = 2,
    MODE_MAP     = 3,
    MODE_SFX     = 4,
    MODE_MUSIC   = 5,
};

extern int mode;

void scr_common(unsigned bg_col);

void scr_code(void);
void scr_sprite(void);
void scr_map(void);
void scr_sfx(void);
void scr_music(void);
