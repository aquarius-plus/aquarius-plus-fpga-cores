#include "scr.h"

static void draw(void) {
    scr_common(1);
    snprintf(state.status_text, sizeof(state.status_text), "Line 1/1 Col 1");

    // char bla[32];
    // snprintf(bla, sizeof(bla), "bla: %u", sec);
    // draw_text(bla, 50, 50, 7, false);
    // snprintf(bla, sizeof(bla), "last: %04x", last);
    // draw_text(bla, 50, 60, 7, false);

    // VRAM4BIT[0]++;
}

screen_t scr_code = {
    .draw = draw,
};
