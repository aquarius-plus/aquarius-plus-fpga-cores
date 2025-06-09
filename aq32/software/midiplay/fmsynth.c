#include "fmsynth.h"

#define NUM_FM_CHANNELS 32

#define NUM_FM_CHANNELS 32

struct fm_channel {
    int8_t  midi_ch;
    int8_t  midi_note;
    uint8_t age;
};

struct midi_channel {
    uint8_t program;
    uint8_t bank;   // Controller 0
    uint8_t volume; // Controller 7
    uint8_t pan;    // Controller 10
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

static struct midi_channel midi_channels[16];
static struct fm_channel   fm_channels[NUM_FM_CHANNELS];

static const uint16_t fnums[19] = {
    346, 367, 389, 412, 436, 462, 490, 519, 550, 582, 617, 654,
    692, 733, 777, 823, 872, 924, 979};

static const struct instrument strings = {
    .fb  = 4,
    .alg = 0,
    .op  = {
        {.a = 15, .d = 0, .s = 0, .r = 0, .ws = 0, .am = 0, .ksr = 0, .vib = 1, .sus = 1, .mult = 1, .ksl = 0, .tl = 23},
        {.a = 5, .d = 0, .s = 0, .r = 5, .ws = 0, .am = 1, .ksr = 0, .vib = 1, .sus = 1, .mult = 1, .ksl = 0, .tl = 14},
    },
};

static const struct instrument distorted_guitar = {
    .fb  = 6,
    .alg = 0,
    .op  = {
        {.a = 15, .d = 1, .s = 15, .r = 7, .ws = 0, .am = 0, .ksr = 0, .vib = 1, .sus = 0, .mult = 0, .ksl = 0, .tl = 13},
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

static const struct instrument test = {
    .fb  = 7,
    .alg = 1,
    .op  = {
        {.a = 15, .d = 0, .s = 15, .r = 7, .ws = 0, .am = 0, .ksr = 0, .vib = 0, .sus = 0, .mult = 1, .ksl = 0, .tl = 0},
        {.a = 15, .d = 0, .s = 15, .r = 7, .ws = 0, .am = 0, .ksr = 0, .vib = 0, .sus = 0, .mult = 1, .ksl = 0, .tl = 63},
        // {.a = 15, .d = 0, .s = 0, .r = 0, .ws = 0, .am = 0, .ksr = 0, .vib = 0, .sus = 0, .mult = 0, .ksl = 0, .tl = 63},
    },
};

static const struct instrument *cur_instrument = &strings;

static int find_channel(bool is_4op) {
    int result = -1;
    int age    = -1;

    for (int ch = 0; ch < NUM_FM_CHANNELS; ch++) {
        if (fm_channels[ch].midi_ch < 0) {
            if (fm_channels[ch].age > age) {
                age    = fm_channels[ch].age;
                result = ch;
            }
        }
    }
    return result;
}

void fmsynth_reset(void) {
    for (int i = 0; i < NUM_FM_CHANNELS; i++)
        fm_channels[i].midi_ch = -1;

    FMSYNTH->ctrl = 0; // (1 << 7) | (1 << 6);
}

void fmsynth_note_off(uint8_t channel, uint8_t note) {
    if (channel > 15 || note > 127)
        return;

    unsigned ch;
    for (ch = 0; ch < NUM_FM_CHANNELS; ch++)
        if (fm_channels[ch].midi_ch == channel && fm_channels[ch].midi_note == note)
            break;
    if (ch >= NUM_FM_CHANNELS)
        return;

    printf("ch%d: note %3d off\n", channel, note);

    FMSYNTH->key_on &= ~(1 << ch);
    fm_channels[ch].midi_ch = -1;
    fm_channels[ch].age     = 0;

    for (int i = 0; i < NUM_FM_CHANNELS; i++) {
        if (fm_channels[i].midi_ch < 0 && fm_channels[i].age < 127)
            fm_channels[i].age++;
    }
}

void fmsynth_note_on(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel > 15 || note > 127)
        return;

    fmsynth_note_off(channel, note);
    if (velocity == 0)
        return;

    printf("ch%d: note %3d on, velocity=%u\n", channel, note, velocity);

    int octave = (note / 12) - 1;
    if (octave < 0)
        return;
    if (octave > 7)
        octave = 7;

    int note_idx = note - (octave + 1) * 12;
    if (note_idx > 18)
        return;

    int fmch = find_channel(false);
    if (fmch < 0) {
        printf("Out of channels!\n");
        return;
    }

    fm_channels[fmch].midi_ch   = channel;
    fm_channels[fmch].midi_note = note;

    const struct instrument *instrument = cur_instrument;
    int                      ch         = fmch;

    for (int i = 0; i < 2; i++) {
        FMSYNTH->op_attr0[fmch * 2 + i] =
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
        FMSYNTH->op_attr1[fmch * 2 + i] = instrument->op[i].ws;
    }

    FMSYNTH->ch_attr[fmch] =
        (1 << 21) |                     // CHB
        (1 << 20) |                     // CHA
        (instrument->fb << 17) |        // FB
        ((instrument->alg & 1) << 16) | // CNT
        (octave << 10) |                // BLOCK
        fnums[note_idx];                // FNUM

    FMSYNTH->key_on |= (1 << ch);

    // FMSYNTH->ch_attr[0] |= (1 << 13);
}

void fmsynth_aftertouch(uint8_t channel, uint8_t note, uint8_t pressure) {
    // printf("ch%d: aftertouch %3d pressure=%u\n", channel, note, pressure);
}

void fmsynth_controller(uint8_t channel, uint8_t controller, uint8_t value) {
    if (channel > 15 || controller > 127 || value > 127)
        return;

    switch (controller) {
        case 0: midi_channels[channel].bank = value; break;
        case 7: midi_channels[channel].volume = value; break;
        case 10: midi_channels[channel].pan = value; break;
        case 120:   // All sound off
        case 123: { // All notes off
            for (int ch = 0; ch < NUM_FM_CHANNELS; ch++) {
                if (fm_channels[ch].midi_ch == channel) {
                    FMSYNTH->key_on &= ~(1 << ch);
                    fm_channels[ch].midi_ch = -1;
                }
            }
            break;
        }

        default:
            printf("ch%d: controller %u: %u\n", channel, controller, value);
            break;
    }
}

void fmsynth_program_change(uint8_t channel, uint8_t program) {
    if (channel > 15 || program > 127)
        return;

    // printf("ch%d: program change %u\n", channel, program);
    midi_channels[channel].program = program;

    switch (program) {
        case 0: cur_instrument = &strings; break;
        case 1: cur_instrument = &distorted_guitar; break;
        case 2: cur_instrument = &kick_b1; break;
        case 3: cur_instrument = &test; break;
    }
}

void fmsynth_channel_pressure(uint8_t channel, uint8_t pressure) {
    // printf("ch%d: channel_pressure %u\n", channel, pressure);
}

void fmsynth_pitch_wheel(uint8_t channel, uint16_t pitch) {
    // printf("ch%d: pitch wheel %u\n", channel, pitch);
}
