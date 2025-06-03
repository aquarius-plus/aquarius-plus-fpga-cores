#include "common.h"
#include "esp.h"

// static const uint16_t palette[16] = {
//     0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
//     0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

static uint8_t buf[256];

static uint8_t note_ch[128];
static uint8_t cur_ch;

static void note_off(uint8_t channel, uint8_t note) {
    printf("ch%d: note %3d off\n", channel, note);

    FMSYNTH->ch_attr[note_ch[note]] &= ~(1 << 13);
}

static const uint16_t fnums[12] = {
    346,
    367,
    389,
    412,
    436,
    462,
    490,
    519,
    550,
    582,
    617,
    654,
};

struct op_settings {
    uint8_t a, d, s, r;
    uint8_t ws;
    bool    am;
    bool    ksr;
    bool    vib;
    bool    sus;
    uint8_t mult;
    uint8_t ksl;
    uint8_t tl;
};

struct instrument {
    uint8_t            fb;
    uint8_t            alg;
    struct op_settings op[2];
};

static const struct instrument distorted_guitar = {
    .fb  = 6,
    .alg = 0,
    .op  = {
        {.a = 15, .d = 1, .s = 15, .r = 7, .ws = 0, .am = 0, .ksr = 0, .vib = 1, .sus = 0, .mult = 0, .ksl = 0, .tl = 8},
        {.a = 15, .d = 0, .s = 15, .r = 7, .ws = 6, .am = 0, .ksr = 0, .vib = 1, .sus = 0, .mult = 0, .ksl = 1, .tl = 0},
    },
};

static const struct instrument kick_b1 = {
    .fb  = 7,
    .alg = 0,
    .op  = {
        {.a = 15, .d = 11, .s = 5, .r = 8, .ws = 0, .am = 0, .ksr = 0, .vib = 0, .sus = 0, .mult = 2, .ksl = 0, .tl = 0},
        {.a = 15, .d = 7, .s = 15, .r = 15, .ws = 0, .am = 0, .ksr = 0, .vib = 0, .sus = 0, .mult = 0, .ksl = 0, .tl = 0},
    },
};

static const struct instrument strings = {
    .fb  = 4,
    .alg = 0,
    .op  = {
        {.a = 15, .d = 0, .s = 0, .r = 0, .ws = 0, .am = 0, .ksr = 0, .vib = 1, .sus = 1, .mult = 1, .ksl = 0, .tl = 23},
        {.a = 5, .d = 0, .s = 0, .r = 5, .ws = 0, .am = 1, .ksr = 0, .vib = 1, .sus = 1, .mult = 1, .ksl = 0, .tl = 14},
    },
};

static const struct instrument *cur_instrument = &strings;

static void play_ch_instrument(uint8_t ch, uint8_t block, uint16_t fnum, const struct instrument *instrument) {
    // Distorted guitar
    for (int i = 0; i < 2; i++) {
        FMSYNTH->op_attr0[ch * 2 + i] =
            (instrument->op[i].am ? (1 << 31) : 0) |  // AM
            (instrument->op[i].vib ? (1 << 30) : 0) | // VIB
            (instrument->op[i].sus ? (1 << 29) : 0) | // EGT
            (instrument->op[i].ksr ? (1 << 28) : 0) | // KSR
            (instrument->op[i].mult << 24) |          // MULT
            (instrument->op[i].ksl << 22) |           // KSL
            (instrument->op[i].tl << 16) |            // TL
            (instrument->op[i].a << 12) |             // AR
            (instrument->op[i].d << 8) |              // DR
            (instrument->op[i].s << 4) |              // SL
            instrument->op[i].r;                      // RR
        FMSYNTH->op_attr1[ch * 2 + i] = instrument->op[i].ws;
    }

    FMSYNTH->ch_attr[ch] =
        (1 << 21) |                     // CHB
        (1 << 20) |                     // CHA
        (instrument->fb << 17) |        // FB
        ((instrument->alg & 1) << 16) | // CNT
        (1 << 13) |                     // KON
        (block << 10) |                 // BLOCK
        fnum;                           // FNUM
}

static void note_on(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (velocity == 0) {
        note_off(channel, note);
        return;
    }
    printf("ch%d: note %3d on, velocity=%u\n", channel, note, velocity);

    int octave   = (note / 12) - 1;
    int note_idx = note % 12;

    if (octave < 0)
        return;

    note_ch[note] = cur_ch;
    play_ch_instrument(cur_ch, octave, fnums[note_idx], cur_instrument);

    // set_ch(cur_ch, octave, fnums[note_idx]);
    cur_ch = (cur_ch + 1) & 31;

    // FMSYNTH->ch_attr[0] |= (1 << 13);
}

static void aftertouch(uint8_t channel, uint8_t note, uint8_t pressure) {
    printf("ch%d: aftertouch %3d pressure=%u\n", channel, note, pressure);
}

static void controller(uint8_t channel, uint8_t controller, uint8_t value) {
    printf("ch%d: controller %u: %u\n", channel, controller, value);
}

static void program_change(uint8_t channel, uint8_t program) {
    printf("ch%d: program change %u\n", channel, program);

    switch (program) {
        case 0: cur_instrument = &strings; break;
        case 1: cur_instrument = &distorted_guitar; break;
        case 2: cur_instrument = &kick_b1; break;
    }
}

static void channel_pressure(uint8_t channel, uint8_t pressure) {
    printf("ch%d: channel_pressure %u\n", channel, pressure);
}

static void pitch_wheel(uint8_t channel, uint16_t pitch) {
    printf("ch%d: pitch wheel %u\n", channel, pitch);
}

void midi_test(void) {
    printf("MIDI test\n");

    while (1) {
        int count = esp_get_midi_data(buf, sizeof(buf));
        count /= 4;

        const uint8_t *p = buf;

        for (int i = 0; i < count; i++) {

            uint8_t channel = p[1] & 0xF;
            switch (p[1] >> 4) {
                case 0x8: note_off(channel, p[1]); break;
                case 0x9: note_on(channel, p[2], p[3]); break;
                case 0xA: aftertouch(channel, p[2], p[3]); break;
                case 0xB: controller(channel, p[2], p[3]); break;
                case 0xC: program_change(channel, p[2]); break;
                case 0xD: channel_pressure(channel, p[2]); break;
                case 0xE: pitch_wheel(channel, (p[3] << 7) | p[2]); break;
                default:
                    printf("%02x %02x %02x %02x\n", p[0], p[1], p[2], p[3]);
                    break;
            }

            p += 4;
        }
    }
}

int main(void) {
    midi_test();

    // for (int i = 0; i < 64; i++)
    //     PALETTE[i] = palette[i & 15];

    // REGS->VCTRL = VCTRL_GFX_EN;

    // for (int i = 0; i < 32000; i++) {
    //     VRAM[i] = 0;
    // }

    // for (int i = 0; i < 64000; i++) {
    //     VRAM4BPP[i] = keen_data[i];
    // }

    // printf("%X\n", REGS->VCTRL);

    // for (int i = 0; i < 10; i++) {
    //     for (int i = 0; i < 32768; i++) {
    //         VRAM[i] = i ^ (i >> 8);
    //     }

    //     for (int i = 0; i < 32768; i++) {
    //         uint8_t bla = i ^ (i >> 8);
    //         if (VRAM[i] != bla) {
    //             printf("Iek!\n");
    //             break;
    //         }
    //     }
    //     printf("Done.\n");
    // }

    // VRAM[0]   = 0xFF;
    // VRAM[160] = 0xFF;

    // ((uint32_t *)VRAM4BPP)[0] = 0x01020304;
    // ((uint32_t *)VRAM4BPP)[1] = 0x05060708;

    // ((uint32_t *)VRAM)[40 * 0] = 0x78563412;
    // ((uint32_t *)VRAM)[40 * 1] = 0x00000010;
    // ((uint32_t *)VRAM)[40 * 2] = 0x00000002;
    // ((uint32_t *)VRAM)[40 * 3] = 0x00003000;
    // ((uint32_t *)VRAM)[40 * 4] = 0x00000400;
    // ((uint32_t *)VRAM)[40 * 5] = 0x00500000;
    // ((uint32_t *)VRAM)[40 * 6] = 0x00060000;
    // ((uint32_t *)VRAM)[40 * 7] = 0x70000000;
    // ((uint32_t *)VRAM)[40 * 8] = 0x08000000;

    // VRAM4BPP[320 * 1 + 0] = 1;
    // VRAM4BPP[320 * 2 + 1] = 2;
    // VRAM4BPP[320 * 3 + 2] = 3;
    // VRAM4BPP[320 * 4 + 3] = 4;
    // VRAM4BPP[320 * 5 + 4] = 5;
    // VRAM4BPP[320 * 6 + 5] = 6;
    // VRAM4BPP[320 * 7 + 6] = 7;
    // VRAM4BPP[320 * 8 + 7] = 8;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    // for (int i = 0; i < 8; i++)
    //     printf("%x\n", VRAM4BPP[i]);

    // printf("%08x\n", ((uint32_t *)VRAM4BPP)[0]);
    // printf("%08x\n", ((uint32_t *)VRAM4BPP)[1]);

    // ((uint32_t *)VRAM4BPP)[0] = 0x04030201;
    // ((uint32_t *)VRAM4BPP)[1] = 0x08070605;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    // for (int i = 0; i < 8; i++) {
    //     VRAM4BPP[i] = 15;
    // }
    // VRAM[160] = 0xF0;
    // VRAM[161] = 0xF0;
    // VRAM[162] = 0xF0;
    // VRAM[163] = 0xF0;

    // VRAM[0] = 0xF2;

    // VRAM4BPP[0]  = 15;
    // VRAM4BPP[3]  = 15;
    // VRAM4BPP[4]  = 15;
    // VRAM4BPP[6]  = 15;
    // VRAM4BPP[8]  = 15;
    // VRAM4BPP[10] = 15;
    // VRAM4BPP[12] = 15;
    // VRAM4BPP[14] = 15;

    // VRAM4BPP[320 + 1 + 0]  = 15;
    // VRAM4BPP[320 + 1 + 2]  = 15;
    // VRAM4BPP[320 + 1 + 4]  = 15;
    // VRAM4BPP[320 + 1 + 6]  = 15;
    // VRAM4BPP[320 + 1 + 8]  = 15;
    // VRAM4BPP[320 + 1 + 10] = 15;
    // VRAM4BPP[320 + 1 + 12] = 15;
    // VRAM4BPP[320 + 1 + 14] = 15;

    // printf("%08x\n", ((uint32_t *)VRAM)[0]);

    // for (int j = 0; j < 200; j++)
    //     for (int i = 0; i < 320; i++)
    //         VRAM4BPP[j * 320 + i] = j ^ i;

    // REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_TEXT_EN;

    // while (1) {
    // }
    return 0;
}
