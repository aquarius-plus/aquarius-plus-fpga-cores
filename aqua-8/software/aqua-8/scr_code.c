#include "scr.h"

void scr_code(void) {
    scr_common(1);

    // char bla[32];
    // snprintf(bla, sizeof(bla), "bla: %u", sec);
    // draw_text(bla, 50, 50, 7, false);
    // snprintf(bla, sizeof(bla), "last: %04x", last);
    // draw_text(bla, 50, 60, 7, false);

    draw_text("Line 1/1 Col 1", 1, 154, 14, true);

    // VRAM4BIT[0]++;
}
