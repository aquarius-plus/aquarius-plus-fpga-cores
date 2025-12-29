#pragma once

#include "common.h"
#include "draw.h"
#include "state.h"

typedef struct {
    void (*draw)(void);
    void (*on_key)(uint16_t code);
} screen_t;

screen_t *scr_get_current(void);

void scr_common(unsigned bg_col);
void scr_key(uint16_t code);

static inline bool mouse_clicked(const rect_t *r, uint8_t button, uint8_t spr) {
    if (rect_contains(r, state.mouse_ev.x, state.mouse_ev.y)) {
        state.mouse_spr = spr;

        if (state.mouse_ev.clicked_buttons == button && state.mouse_ev.buttons == state.mouse_ev.clicked_buttons)
            return true;
    }
    return false;
}

static inline bool mouse_hover(const rect_t *r, uint8_t spr) {
    if (rect_contains(r, state.mouse_ev.x, state.mouse_ev.y)) {
        state.mouse_spr = spr;
        return true;
    }
    return false;
}

static inline bool mouse_lclick(const rect_t *r) { return mouse_clicked(r, 1, MOUSE_SPR_HAND); }
static inline bool mouse_rclick(const rect_t *r) { return mouse_clicked(r, 2, MOUSE_SPR_HAND); }

extern screen_t scr_code;
extern screen_t scr_sprite;
extern screen_t scr_map;
extern screen_t scr_sfx;
extern screen_t scr_music;
