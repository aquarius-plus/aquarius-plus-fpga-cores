#include "state.h"

state_t state = {
    .mode = MODE_SFX,

    .sfx_edit = {
        .sfx_idx    = 0,
        .octave     = 2,
        .volume     = 5,
        .waveform   = 0,
        .effect     = 0,
        .cursor_row = 1,
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
