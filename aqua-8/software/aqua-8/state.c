#include "state.h"
#include "esp.h"
#include "ctype2.h"

static const char *hexlut = "0123456789abcdef";

edit_state_t edit_state = {
    .editing = false,
    .mode    = MODE_CODE,

    .sfx_edit = {
        .sfx_idx    = 0,
        .octave     = 2,
        .volume     = 5,
        .waveform   = 0,
        .effect     = 0,
        .cursor_row = 1,
        .cursor_col = 1,
    },

    .spr_edit = {
        .color = 15,
    },
};

data_state_t data_state = {

    .sfx = {
        {
            .speed      = 16,
            .loop_start = 0,
            .loop_end   = 0,
            .notes      = {0xFFC0, 0xFFC1, 0xFFC2, 0xFFC3, 0xFFC4, 0xFFC5, 0xFFC6, 0xFFC7, 0xFFC8, 0xFFC9, 0xFFCA, 0xFFCB, 0xFFCC, 0xFFCD, 0xFFCE, 0xFFCF, 0xFFC9, 0x0FFF},
        },

    },

    .sprites = {
#include "game_sprites.inl"
    },
};

game_state_t game_state;

#include "scr_console/console.h"

enum {
    LOADMODE_NONE,
    LOADMODE_GFX,
    LOADMODE_GFF,
    LOADMODE_MAP,
    LOADMODE_SFX,
    LOADMODE_MUSIC,
    LOADMODE_LUA,
};

static unsigned get_nibble(char ch) {
    ch = to_lower(ch);
    if (ch >= '0' && ch <= '9')
        return ch - '0';
    if (ch >= 'a' && ch <= 'f')
        return ch - 'a' + 10;
    return 0;
}

int state_load_cart(const char *path) {
    char line[260];

    int fd = esp_open(path, FO_RDONLY);
    if (fd < 0)
        return fd;

    int len = esp_readline(fd, line, sizeof(line));
    if (len < 0 || strncmp(line, "aqua-8 cartridge", 16) != 0) {
        esp_close(fd);
        return -1;
    }

    editbuf_t *eb = edit_state.code_edit.editbuf;
    editbuf_reset(eb);
    memset(&data_state, 0, sizeof(data_state));

    uint8_t       *p_spr     = (uint8_t *)data_state.sprites;
    const uint8_t *p_spr_end = p_spr + sizeof(data_state.sprites);
    unsigned       sfx_idx   = 0;

    unsigned mode = LOADMODE_NONE;

    while (1) {
        int len = esp_readline(fd, line, sizeof(line));
        if (len < 0)
            break;

        unsigned old_mode = mode;

        if (strcmp(line, "__gfx__") == 0)
            mode = LOADMODE_GFX;
        else if (strcmp(line, "__gff__") == 0)
            mode = LOADMODE_GFF;
        else if (strcmp(line, "__map__") == 0)
            mode = LOADMODE_MAP;
        else if (strcmp(line, "__sfx__") == 0)
            mode = LOADMODE_SFX;
        else if (strcmp(line, "__music__") == 0)
            mode = LOADMODE_MUSIC;
        else if (strcmp(line, "__lua__") == 0)
            mode = LOADMODE_LUA;
        else {
            switch (mode) {
                case LOADMODE_GFX: {
                    if (len != 128)
                        break;

                    for (int i = 0; i < len; i += 2) {
                        if (p_spr >= p_spr_end)
                            break;

                        *(p_spr++) = get_nibble(line[i + 0]) | (get_nibble(line[i + 1]) << 4);
                    }
                    break;
                }
                case LOADMODE_GFF: {
                    break;
                }
                case LOADMODE_MAP: {
                    break;
                }
                case LOADMODE_SFX: {
                    if (len != 168 || sfx_idx >= 64)
                        break;
                    sfx_t      *sfx = &data_state.sfx[sfx_idx++];
                    const char *ps  = line;

                    uint8_t editor_mode = get_nibble(*(ps++)) << 4;
                    editor_mode |= get_nibble(*(ps++));
                    sfx->speed = get_nibble(*(ps++)) << 4;
                    sfx->speed |= get_nibble(*(ps++));
                    sfx->loop_start = get_nibble(*(ps++)) << 4;
                    sfx->loop_start |= get_nibble(*(ps++));
                    sfx->loop_end = get_nibble(*(ps++)) << 4;
                    sfx->loop_end |= get_nibble(*(ps++));

                    for (int i = 0; i < 32; i++) {
                        uint8_t pitch = get_nibble(*(ps++)) << 4;
                        pitch |= get_nibble(*(ps++));
                        uint8_t wf    = get_nibble(*(ps++));
                        uint8_t vol   = get_nibble(*(ps++));
                        uint8_t fx    = get_nibble(*(ps++));
                        sfx->notes[i] = ((fx & 7) << 12) | ((vol & 7) << 9) | ((wf & 7) << 6) | (pitch & 63);
                    }
                    break;
                }
                case LOADMODE_MUSIC: {
                    break;
                }
                case LOADMODE_LUA: {
                    break;
                }
            }
        }

        if (mode != old_mode) {
            console_printf("Changed mode to: %u\r\n", mode);
        }

        // console_putline(line);
    }

    esp_close(fd);

    return editbuf_get_size(eb);
}

static int esp_write_str(int fd, const char *str) {
    return esp_write(fd, str, strlen(str));
}

static int esp_write_hex_line(int fd, const void *buf, size_t len) {
    if (len > 128)
        return -1;

    char tmp[256 + 1];

    const uint8_t *ps = buf;
    char          *pd = tmp;
    for (unsigned i = 0; i < len; i++) {
        *(pd++) = hexlut[ps[0] & 0xF];
        *(pd++) = hexlut[(ps[0] >> 4) & 0xF];
        ps++;
    }
    *(pd++) = '\n';
    return esp_write(fd, tmp, pd - tmp);
}

int state_save_cart(const char *path) {
    int fd = esp_open(path, FO_WRONLY);
    if (fd < 0)
        return fd;

    esp_write_str(fd, "aqua-8 cartridge\n");
    esp_write_str(fd, "version 1\n");

    // Graphics
    {
        esp_write_str(fd, "__gfx__\n");
        for (int j = 0; j < 128; j++) {
            esp_write_hex_line(fd, &data_state.sprites[j * 16], 64);
        }

        esp_write_str(fd, "__gff__\n");
        esp_write_str(fd, "__map__\n");
    }

    // Sound
    {
        esp_write_str(fd, "__sfx__\n");
        for (int j = 0; j < 64; j++) {
            const sfx_t *sfx = &data_state.sfx[j];

            char  buf[168 + 2];
            char *pd = buf;

            uint8_t editor_mode = 0;

            *(pd++) = hexlut[editor_mode >> 4];
            *(pd++) = hexlut[editor_mode & 0xF];
            *(pd++) = hexlut[sfx->speed >> 4];
            *(pd++) = hexlut[sfx->speed & 0xF];
            *(pd++) = hexlut[sfx->loop_start >> 4];
            *(pd++) = hexlut[sfx->loop_start & 0xF];
            *(pd++) = hexlut[sfx->loop_end >> 4];
            *(pd++) = hexlut[sfx->loop_end & 0xF];

            for (int i = 0; i < 32; i++) {
                uint16_t note_code = sfx->notes[i];
                unsigned pitch     = note_code & 63;
                unsigned wf        = (note_code >> 6) & 7;
                unsigned vol       = (note_code >> 9) & 7;
                unsigned fx        = (note_code >> 12) & 7;

                *(pd++) = hexlut[pitch >> 4];
                *(pd++) = hexlut[pitch & 0xF];
                *(pd++) = hexlut[wf];
                *(pd++) = hexlut[vol];
                *(pd++) = hexlut[fx];
            }

            *(pd++) = '\n';
            esp_write(fd, buf, pd - buf);
        }

        esp_write_str(fd, "__music__\n");
    }

    // Source code
    {
        editbuf_t *eb = edit_state.code_edit.editbuf;
        esp_write_str(fd, "__lua__\n");
        unsigned size = (eb->p_split_start - eb->p_buf);
        if (size)
            esp_write(fd, eb->p_buf, size);
        size = (eb->p_buf_end - eb->p_split_end);
        if (size)
            esp_write(fd, eb->p_split_end, size);
        esp_write_str(fd, "\n");
    }

    esp_close(fd);

    return 0;
}
