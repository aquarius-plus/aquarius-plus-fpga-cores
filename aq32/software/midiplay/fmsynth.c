#include "fmsynth.h"
#include "instrument_bank.h"

#define NUM_FM_CHANNELS 32

struct fm_channel {
    int8_t  midi_ch;
    int8_t  midi_note;
    uint8_t age;
    bool    is_4op;
};

struct midi_channel {
    uint8_t                  bank; // Controller 0
    const struct instrument *instrument;
    uint8_t                  volume; // Controller 7
    uint8_t                  pan;    // Controller 10
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

static struct midi_channel midi_channels[16];
static struct fm_channel   fm_channels[NUM_FM_CHANNELS];

static const uint16_t fnums[19] = {
    346, 367, 389, 412, 436, 462, 490, 519, 550, 582, 617, 654,
    692, 733, 777, 823, 872, 924, 979};

static int find_channel(bool is_4op) {
    int result = -1;
    int age    = -1;

    if (is_4op) {
        for (int ch = 0; ch < NUM_FM_CHANNELS; ch += 2) {
            if (fm_channels[ch].midi_ch < 0 && fm_channels[ch + 1].midi_ch < 0) {
                if (fm_channels[ch].age > age) {
                    age    = fm_channels[ch].age;
                    result = ch;
                }
            }
        }
    } else {
        for (int ch = 0; ch < NUM_FM_CHANNELS; ch++) {
            if (fm_channels[ch].midi_ch < 0) {
                if (fm_channels[ch].age > age) {
                    age    = fm_channels[ch].age;
                    result = ch;
                }
            }
        }
    }
    return result;
}

void fmsynth_reset(void) {
    for (int i = 0; i < NUM_FM_CHANNELS; i++)
        fm_channels[i].midi_ch = -1;

    FMSYNTH->ctrl = 0; // (1 << 7) | (1 << 6);

    for (int i = 0; i < 16; i++) {
        midi_channels[i].bank       = 0;
        midi_channels[i].instrument = instrument_bank;
        midi_channels[i].volume     = 100;
        midi_channels[i].pan        = 64;
    }
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

    // printf("ch%d: note %3d off\n", channel, note);

    bool is_4op = fm_channels[ch].is_4op;

    if (is_4op && (ch & 1) != 0)
        printf("Ieks!\n");

    uint32_t mask = is_4op ? ~(3 << ch) : ~(1 << ch);

    FMSYNTH->key_on &= mask;

    fm_channels[ch].midi_ch   = -1;
    fm_channels[ch].midi_note = -1;
    fm_channels[ch].age       = 0;
    fm_channels[ch].is_4op    = false;

    if (is_4op) {
        fm_channels[ch | 1].midi_ch   = -1;
        fm_channels[ch | 1].midi_note = -1;
        fm_channels[ch | 1].age       = 0;
        fm_channels[ch | 1].is_4op    = false;
    }

    for (int i = 0; i < NUM_FM_CHANNELS; i++) {
        if (fm_channels[i].midi_ch < 0 && fm_channels[i].age < 127)
            fm_channels[i].age++;
    }
}

static uint16_t calculate_block_fnum(uint8_t note) {
    int octave = (note / 12) - 1;
    if (octave < 0)
        return 0;
    if (octave > 7)
        octave = 7;

    int fnum_idx = note - (octave + 1) * 12;
    if (fnum_idx > 18)
        return 0;

    return octave << 10 | fnums[fnum_idx];
}

void fmsynth_note_on(uint8_t channel, uint8_t note, uint8_t velocity) {
    if (channel > 15 || note > 127)
        return;

    fmsynth_note_off(channel, note);
    if (velocity == 0)
        return;

    struct midi_channel     *midi_channel = &midi_channels[channel];
    const struct instrument *instrument   = midi_channel->instrument;

    int notenr = note;

    if (channel == 9) {
        // Percussion
        instrument = &instrument_bank[128 + note];
    }
    if (instrument->perc_note != 0)
        notenr = instrument->perc_note;

    // printf("ch%d: note %3d on, velocity=%u  instrument=%p\n", channel, note, velocity, instrument);

    if (instrument == NULL || instrument->flags == 4)
        return;

    bool is_4op      = instrument->flags == 1;
    bool is_pseudo_4 = instrument->flags == 3;

    int fmch = find_channel(is_4op || is_pseudo_4);
    if (fmch < 0) {
        printf("Out of channels!\n");
        return;
    }

    uint16_t blk_fnum0 = calculate_block_fnum(notenr + instrument->note_offset[0]);
    if (blk_fnum0 == 0)
        return;

    calculate_block_fnum(notenr);

    if (is_4op || is_pseudo_4) {
        uint16_t blk_fnum1 = calculate_block_fnum(notenr + instrument->note_offset[1]);
        if (blk_fnum1 == 0)
            return;

        if ((fmch & 1) != 0)
            printf("Ieks2!\n");

        fm_channels[fmch].midi_ch       = channel;
        fm_channels[fmch].midi_note     = note;
        fm_channels[fmch].is_4op        = true;
        fm_channels[fmch + 1].midi_ch   = channel;
        fm_channels[fmch + 1].midi_note = note;
        fm_channels[fmch + 1].is_4op    = true;

        if (is_4op)
            FMSYNTH->opmode |= 1 << (fmch / 2);
        else
            FMSYNTH->opmode &= ~(1 << (fmch / 2));

        for (int i = 0; i < 4; i++) {
            FMSYNTH->op_attr0[fmch * 2 + i] = instrument->op_attr0[i];
            FMSYNTH->op_attr1[fmch * 2 + i] = instrument->op_attr1[i];
        }

        FMSYNTH->ch_attr[fmch] =
            (1 << 21) |                     // CHB
            (1 << 20) |                     // CHA
            (instrument->fb_alg[0] << 16) | // FB/ALG
            blk_fnum0;                      // BLOCK/FNUM

        FMSYNTH->ch_attr[fmch + 1] =
            (1 << 21) |                     // CHB
            (1 << 20) |                     // CHA
            (instrument->fb_alg[1] << 16) | // FB/ALG
            blk_fnum1;                      // BLOCK/FNUM

        FMSYNTH->key_on |= (3 << fmch);

    } else {
        fm_channels[fmch].midi_ch   = channel;
        fm_channels[fmch].midi_note = note;
        fm_channels[fmch].is_4op    = false;

        FMSYNTH->opmode &= ~(1 << (fmch / 2));

        for (int i = 0; i < 2; i++) {
            FMSYNTH->op_attr0[fmch * 2 + i] = instrument->op_attr0[i];
            FMSYNTH->op_attr1[fmch * 2 + i] = instrument->op_attr1[i];
        }

        FMSYNTH->ch_attr[fmch] =
            (1 << 21) |                     // CHB
            (1 << 20) |                     // CHA
            (instrument->fb_alg[0] << 16) | // FB/ALG
            blk_fnum0;                      // BLOCK/FNUM

        FMSYNTH->key_on |= (1 << fmch);
    }
}

void fmsynth_aftertouch(uint8_t channel, uint8_t note, uint8_t pressure) {
    // printf("ch%d: aftertouch %3d pressure=%u\n", channel, note, pressure);
}

void fmsynth_controller(uint8_t channel, uint8_t controller, uint8_t value) {
    if (channel > 15 || controller > 127 || value > 127)
        return;

    switch (controller) {
        case 0: midi_channels[channel].bank = value; break;
        case 7:
            printf("ch%d: volume %u\n", channel, value);
            midi_channels[channel].volume = value;
            break;
        case 10:
            printf("ch%d: pan %u\n", channel, value);
            midi_channels[channel].pan = value;
            break;
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

    printf("ch%d: program change %u\n", channel, program);
    if (channel == 9)
        return;

    if (midi_channels[channel].bank == 0) {
        midi_channels[channel].instrument = &instrument_bank[program];
    } else {
        midi_channels[channel].instrument = NULL;
    }
}

void fmsynth_channel_pressure(uint8_t channel, uint8_t pressure) {
    // printf("ch%d: channel_pressure %u\n", channel, pressure);
}

void fmsynth_pitch_wheel(uint8_t channel, uint16_t pitch) {
    // printf("ch%d: pitch wheel %u\n", channel, pitch);
}
