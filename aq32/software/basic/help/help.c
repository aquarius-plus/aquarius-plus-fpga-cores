#include "help.h"
#include "screen.h"
#include "basic/common/buffers.h"

#define HELP_FILE "/cores/aq32/basic.hlp"

struct help_state {
    uint8_t *p_buf;
    uint8_t *p_buf_end;
};

static struct help_state state;

static bool init(void) {
    buf_reinit();

    unsigned sz = 32768;
    state.p_buf = buf_malloc(sz);
    if (!state.p_buf)
        return false;
    state.p_buf_end = state.p_buf + sz;

    return true;
}

static bool load_topic(const char *topic) {
    int topic_len = strlen(topic);

    FILE *f = fopen(HELP_FILE, "rb");
    if (!f)
        return false;

    unsigned buf_sz = state.p_buf_end - state.p_buf;
    uint8_t  hdr[4];
    uint16_t index_data_len;
    if (fread(hdr, sizeof(hdr), 1, f) != 1 || memcmp(hdr, "HELP", 4) != 0 ||
        fread(&index_data_len, sizeof(index_data_len), 1, f) != 1 || index_data_len > buf_sz ||
        fread(state.p_buf, index_data_len, 1, f) != 1)
        goto error;

    uint8_t *p           = state.p_buf;
    uint16_t num_entries = read_u16(p);
    p += 2;

    int offset = -1;

    for (unsigned i = 0; i < num_entries; i++) {
        uint8_t *p_next = p + 1 + p[0] + 4;
        if (p[0] == topic_len && strncasecmp((const char *)p + 1, topic, topic_len) == 0) {
            offset = read_u32(p + 1 + p[0]);
            break;
        }
        p = p_next;
    }
    if (offset < 0)
        goto error;

    fseek(f, offset, SEEK_CUR);

    uint16_t data_len;
    if (fread(&data_len, sizeof(data_len), 1, f) != 1 || data_len > buf_sz ||
        fread(state.p_buf, data_len, 1, f) != 1)
        goto error;

    fclose(f);
    return true;

error:
    fclose(f);
    return false;
}

static void draw_screen(void) {
    scr_draw_border(0, 0, 80, 25, COLOR_HELP, BORDER_FLAG_NO_SHADOW | BORDER_FLAG_TITLE_INVERSE, "Help");

    const uint8_t *p         = state.p_buf;
    unsigned       num_lines = read_u16(p);
    p += 2;
    int lines_remaining = num_lines;

    for (int i = 1; i <= 23; i++) {
        scr_locate(i, 1);
        scr_setcolor(COLOR_HELP);

        int line_len = 0;

        if (lines_remaining > 0) {
            int len = p[0];
            p++;
            const uint8_t *p_next = p + len;

            scr_setcolor(COLOR_HELP);
            bool bold   = false;
            bool escape = false;

            for (int i = 0; i < len; i++) {
                uint8_t val = *(p++);

                if (escape) {
                    escape = false;
                } else if (val == '\\') {
                    escape = true;
                    continue;
                } else if (val == '*') {
                    bold = !bold;
                    scr_setcolor(bold ? COLOR_HELP_BOLD : COLOR_HELP);
                    continue;
                } else if (val == '@') {
                    val = 136;
                }

                scr_putchar(val);
                line_len++;
            }

            p = p_next;
            lines_remaining--;
        }

        scr_fillchar(' ', 78 - line_len);
    }
}

void help(const char *topic) {
    if (!init() || !load_topic(topic))
        return;

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
