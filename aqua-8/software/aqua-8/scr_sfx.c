#include "scr.h"

typedef struct {
    uint8_t  speed;
    uint8_t  loop_start;
    uint8_t  loop_end;
    uint16_t notes[32];
} sfx_t;

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
    sfx_edit_t sfx_edit;
    sfx_t      sfx[64];
} state_t;

state_t state = {
    .sfx_edit = {
        .sfx_idx    = 0,
        .octave     = 2,
        .volume     = 5,
        .waveform   = 0,
        .effect     = 0,
        .cursor_row = 0,
        .cursor_col = 1,
    },

    .sfx = {
        {
            .speed      = 16,
            .loop_start = 0,
            .loop_end   = 0,
            .notes      = {0xFFC0, 0xFFC1, 0xFFC2, 0xFFC3, 0xFFC4, 0xFFC5, 0xFFC6, 0xFFC7, 0xFFC8, 0xFFC9, 0xFFCA, 0xFFCB, 0xFFCC, 0xFFCD, 0xFFCE, 0xFFCF, 0xFFC9, 0x0FFF},
        },
    },
};

// 01100000240452400528000280452b0450c005280450000529042240162d04500005307553c5252d000130052b0451f006260352b026260420c0052404500005230450c00521045230461f0450c0051c0421c025

// 01 Editor mode
// 10 Note duration
// 00 Loop start
// 00 Loop end
// 24045
// 24005
// 28000
// 28045
// 2b045
// 0c005
// 280450000529042240162d04500005307553c5252d000130052b0451f006260352b026260420c0052404500005230450c00521045230461f0450c0051c0421c025

static void draw_note(int x, int y, int row) {
    uint16_t note_code = state.sfx[state.sfx_edit.sfx_idx].notes[row];
    unsigned pitch     = note_code & 63;
    unsigned wf        = (note_code >> 6) & 7;
    unsigned vol       = (note_code >> 9) & 7;
    unsigned fx        = (note_code >> 12) & 7;

    static const char *note0 = "CCDDEFFGGAAB";
    static const char *note1 = " # #  # # # ";

    unsigned note   = pitch % 12;
    unsigned octave = pitch / 12;

    bool     is_current_row = row == state.sfx_edit.cursor_row;
    unsigned cursor_col     = state.sfx_edit.cursor_col;

    // fill_rect(x, y, x + 29, y + 6, 0);

    if (is_current_row) {
        // fill_rect(x + 1, y + 1, x + 28, y + 7, 1);

        fill_rect(x + 1, y + 1, x + 8, y + 7, cursor_col == 0 ? 3 : 1);
        fill_rect(x + 9, y + 1, x + 13, y + 7, cursor_col == 1 ? 3 : 1);
        fill_rect(x + 14, y + 1, x + 18, y + 7, cursor_col == 2 ? 3 : 1);
        fill_rect(x + 19, y + 1, x + 23, y + 7, cursor_col == 3 ? 3 : 1);
        fill_rect(x + 24, y + 1, x + 28, y + 7, cursor_col == 4 ? 3 : 1);

    } else {
        fill_rect(x + 1, y + 1, x + 28, y + 7, 0);
    }

    // fill_rect(x + 1, y + 1, x + 7, y + 7, 10);

    x += 2;
    draw_char_altfont(x, y + 2, vol == 0 ? '.' : note0[note], vol == 0 ? 1 : 7); // .CDEFGAB
    x += 4;
    draw_char_altfont(x, y + 2, vol == 0 ? '.' : note1[note], vol == 0 ? 1 : 7); // #
    x += 4;
    draw_char_altfont(x, y + 2, vol == 0 ? '.' : '0' + octave, vol == 0 ? 1 : 6); // 01234
    x += 5;
    draw_char_altfont(x, y + 2, vol == 0 ? '.' : '0' + wf, vol == 0 ? 1 : 14); // Waveform: 01234567
    x += 5;
    draw_char_altfont(x, y + 2, vol == 0 ? '.' : '0' + vol, vol == 0 ? 1 : 12); // Volume: 01234567
    x += 5;
    draw_char_altfont(x, y + 2, (vol == 0 || fx == 0) ? '.' : '0' + fx, vol == 0 ? 1 : 13); // Effect: 01234567
}

static void draw(void) {
    int x, y;
    scr_common(5);

    sfx_t *sfx = &state.sfx[state.sfx_edit.sfx_idx];

    // SFX
    int sfx_x = 2;
    int sfx_y = 9;
    {
        fill_rect(sfx_x, sfx_y, sfx_x + 42, sfx_y + 140, 1);
        draw_text("SFX", sfx_x + 16, sfx_y + 3, 7, true);

        y = sfx_y + 11;

        int nr = 0;
        for (int j = 0; j < 16; j++) {
            x = sfx_x + 2;
            for (int i = 0; i < 4; i++) {
                fill_rect(x, y, x + 8, y + 6, nr == state.sfx_edit.sfx_idx ? 7 : 13);
                draw_char_altfont(x + 1, y + 1, '0' + (nr / 10), 5);
                draw_char_altfont(x + 5, y + 1, '0' + (nr % 10), 5);

                x += 10;
                nr++;
            }
            y += 8;
        }
    }

    // Parameters
    char tmp[16];
    int  param_x = 59;
    int  param_y = 9;
    {
        // fill_rect(param_x, param_y, param_x + 121, param_y + 26, 1);

        // Speed
        x = param_x + 2;
        y = param_y + 2;
        draw_text("SPD", x, y, 6, true);
        x += 14;
        fill_rect(x - 1, y - 1, x + 11, y + 5, 0);
        snprintf(tmp, sizeof(tmp), "%03u", sfx->speed);
        draw_text(tmp, x, y, 6, true);

        // Loop
        x = param_x + 49;
        y = param_y + 2;
        draw_text(sfx->loop_start > 0 && sfx->loop_end == 0 ? "LEN" : "LOOP", x, y, 6, true);
        x += 18;
        fill_rect(x - 1, y - 1, x + 7, y + 5, 0);
        snprintf(tmp, sizeof(tmp), "%02u", sfx->loop_start);
        draw_text(tmp, x, y, 6, true);
        x += 11;
        fill_rect(x - 1, y - 1, x + 7, y + 5, 0);
        snprintf(tmp, sizeof(tmp), "%02u", sfx->loop_end);
        draw_text(tmp, x, y, 6, true);

        // Octave
        x = param_x + 2;
        y = param_y + 11;
        draw_text("OCT", x, y, 6, true);
        x += 13;
        for (int i = 0; i <= 4; i++) {
            fill_rect(x, y - 1, x + 4, y + 5, (state.sfx_edit.octave == i) ? 7 : 6);
            draw_char_altfont(x + 1, y, '0' + i, 5);
            x += 6;
        }

        // Volume
        x = param_x + 2;
        y = param_y + 20;
        draw_text("VOL", x, y, 6, true);
        x += 13;
        y -= 1;
        for (int i = 0; i <= 7; i++) {
            // Black
            if (i < 7)
                fill_rect(x, y, x + 1, y + (6 - i), state.sfx_edit.volume == i ? 13 : 0);

            // White
            if (i > 0)
                fill_rect(x, y + (7 - i), x + 1, y + 6, state.sfx_edit.volume == i ? 7 : 6);

            x += 3;
        }

        // Waveforms
        x = param_x + 49;
        y = param_y + 10;
        for (int i = 0; i < 8; i++) {
            fill_rect(x, y, x + 7, y + 5, i == state.sfx_edit.waveform ? i + 8 : 6);
            draw_icon(x, y, 48 + i, 7);
            x += 9;
        }

        // Effects
        x = param_x + 49;
        y = param_y + 20;
        for (int i = 0; i < 8; i++) {
            fill_rect(x, y, x + 7, y + 5, i == state.sfx_edit.effect ? 7 : 13);
            draw_icon(x, y, 64 + i, 5);
            x += 9;
        }
    }

    int notes_x = 59;
    int notes_y = 39;

    // Notes
    unsigned idx = 0;
    for (int row = 0; row < 4; row++) {
        x = notes_x + row * 32;
        y = notes_y;
        draw_rect(x, y, x + 29, y + 57, 0);
        for (int i = 0; i < 8; i++) {
            draw_note(x, y, idx++);
            y += 7;
        }
    }

    // x = 56;
    // y = 90;
    // fill_rect(x, y, x + 128, y + 64, 0);
}

static void on_mouse(int mx, int my, int buttons, int clicked_buttons, int wheel) {
    if (buttons == clicked_buttons && buttons == 1) {
        int x, y;
        // SFX
        {
            int sfx_x = 2;
            int sfx_y = 9;

            y = sfx_y + 11;

            int nr = 0;
            for (int j = 0; j < 16; j++) {
                x = sfx_x + 2;
                for (int i = 0; i < 4; i++) {
                    if (mx >= x && mx <= x + 8 && my >= y && my <= y + 6) {
                        state.sfx_edit.sfx_idx = nr;
                        return;
                    }
                    x += 10;
                    nr++;
                }
                y += 8;
            }
        }
    }
}

screen_t scr_sfx = {
    .draw     = draw,
    .on_mouse = on_mouse,
};
