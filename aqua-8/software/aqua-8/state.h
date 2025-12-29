#pragma once

#include "common.h"

enum {
    MODE_CODE = 0,
    MODE_SPRITE,
    MODE_MAP,
    MODE_SFX,
    MODE_MUSIC,
    MODE_CONSOLE,
};

#define MOUSE_SPR_POINTER   0
#define MOUSE_SPR_HAND      1
#define MOUSE_SPR_IBEAM     2
#define MOUSE_SPR_CROSSHAIR 3

typedef struct {
    uint8_t x;
    uint8_t y;
    uint8_t buttons;
    uint8_t clicked_buttons;
    int8_t  wheel;
} mouse_event_t;

typedef struct {
    uint8_t  speed;
    uint8_t  loop_start;
    uint8_t  loop_end;
    uint16_t notes[32];
} sfx_t;

enum {
    TOOL_PIXEL,
    TOOL_LINE,
    TOOL_FILL,
    TOOL_SELECT,
    TOOL_ROTATE,
    TOOL_COLORPICK,
    TOOL_CIRCLE,
    TOOL_RECT,
    TOOL_STAMP,
    TOOL_HFLIP,
    TOOL_VFLIP,
    TOOL_DELETE,
};

typedef struct {
    uint8_t spr_idx;
    uint8_t color;
    uint8_t tool;
} sprite_edit_t;

typedef struct {
    uint8_t sfx_idx;
    uint8_t octave;
    uint8_t volume;
    uint8_t waveform;
    uint8_t effect;
    uint8_t cursor_row;
    uint8_t cursor_col;
} sfx_edit_t;

typedef struct {
    uint8_t       mode;
    mouse_event_t mouse_ev;
    uint8_t       mouse_spr;
    char          status_text[40];
    uint16_t      modifiers;

    sprite_edit_t spr_edit;
    uint32_t      sprites[16 * 16 * 8];
    sfx_edit_t    sfx_edit;
    sfx_t         sfx[64];
} state_t;

extern state_t state;
