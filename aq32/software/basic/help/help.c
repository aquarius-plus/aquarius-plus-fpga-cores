#include "help.h"
#include "screen.h"
#include "basic/common/buffers.h"

struct help_state {
    uint8_t *p_buf;
    uint8_t *p_buf_end;
};

static struct help_state state;

static void init(void) {
    buf_reinit();

    unsigned sz = 32768;
    state.p_buf = buf_malloc(sz);
    if (!state.p_buf)
        return;
    state.p_buf_end = state.p_buf + sz;
}

static void draw_screen(void) {
    scr_draw_border(0, 0, 80, 25, COLOR_HELP, BORDER_FLAG_NO_SHADOW | BORDER_FLAG_TITLE_INVERSE, "Help");

    for (int i = 1; i <= 23; i++) {
        scr_locate(i, 1);
        scr_setcolor(COLOR_HELP);
        scr_fillchar(' ', 78);
    }
}

void help(const char *topic) {
    init();
    draw_screen();

    while (1) {
        int key;
        while ((key = REGS->KEYBUF) < 0);

        if (key & KEY_IS_SCANCODE) {
            uint8_t scancode = key & 0xFF;
            // Escape?
            if (((key & KEY_KEYDOWN) && scancode == SCANCODE_ESC))
                return;
        } else {
            uint8_t ch = key & 0xFF;
            switch (toupper(ch)) {
                case CH_ENTER: return;
            }
        }
    }
}
