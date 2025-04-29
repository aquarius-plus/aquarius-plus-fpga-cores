#pragma once

#include "common.h"

extern volatile uint16_t *p_scr;
extern uint16_t           color;

static inline void scr_locate(int row, int column) {
    p_scr = TRAM + 80 * row + column;
}

static inline void scr_putchar(uint8_t ch) {
    *(p_scr++) = color | ch;
}

static inline void scr_puttext(const char *p) {
    while (*p)
        scr_putchar(*(p++));
}

static inline void scr_setcolor(uint8_t col) {
    color = col << 8;
}
