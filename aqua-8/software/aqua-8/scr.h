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

typedef struct {
    // void (*mouse_move)(void);
    // void (*key_up)(void);
    // void (*key_down)(void);
    void (*draw)(void);
    void (*on_mouse)(int x, int y, int buttons, int clicked_buttons, int wheel);

    void (*on_char)(uint8_t ch);
} screen_t;

screen_t *scr_get_current(void);

extern int mode;

void scr_common(unsigned bg_col);
void scr_mouse(int x, int y, int buttons, int clicked_buttons, int wheel);

extern screen_t scr_code;
extern screen_t scr_sprite;
extern screen_t scr_map;
extern screen_t scr_sfx;
extern screen_t scr_music;
