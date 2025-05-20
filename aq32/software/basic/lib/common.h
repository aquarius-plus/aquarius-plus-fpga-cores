#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdalign.h>
#include <stdnoreturn.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

#include "regs.h"

#define COLOR_MENU              0x07
#define COLOR_MENU_SEL          0x70
#define COLOR_MENU_ACCEL        0xF7
#define COLOR_MENU_INACTIVE     0x87
#define COLOR_MENU_SHORTCUT     0x87
#define COLOR_MENU_SHORTCUT_SEL 0x80
#define COLOR_EDITOR            0x71
#define COLOR_FILENAME          0x17
#define COLOR_CURSOR            0x06
#define COLOR_SELECTED          0x17
#define COLOR_STATUS            0xF3
#define COLOR_STATUS2           0x03
#define COLOR_FIELD             0xF8

#define COLOR_HELP      0x70
#define COLOR_HELP_BOLD 0xF0
#define COLOR_HELP_LINK 0x90

#define CH_TAB         '\t'
#define CH_ENTER       '\r'
#define CH_BACKSPACE   '\b'
#define CH_F1          0x80
#define CH_F2          0x81
#define CH_F3          0x82
#define CH_F4          0x83
#define CH_F5          0x84
#define CH_F6          0x85
#define CH_F7          0x86
#define CH_F8          0x87
#define CH_F9          0x90
#define CH_F10         0x91
#define CH_F11         0x92
#define CH_F12         0x93
#define CH_PRINTSCREEN 0x88
#define CH_PAUSE       0x89
#define CH_INSERT      0x9D
#define CH_HOME        0x9B
#define CH_PAGEUP      0x8A
#define CH_DELETE      0x7F
#define CH_END         0x9A
#define CH_PAGEDOWN    0x8B
#define CH_RIGHT       0x8E
#define CH_LEFT        0x9E
#define CH_DOWN        0x9F
#define CH_UP          0x8F

#define SCANCODE_LALT 0xE2
#define SCANCODE_RALT 0xE6
#define SCANCODE_ESC  0x29

static inline int min(int a, int b) { return a < b ? a : b; }
static inline int max(int a, int b) { return a > b ? a : b; }
static inline int clamp(int val, int _min, int _max) {
    if (val < _min)
        return _min;
    if (val > _max)
        return _max;
    return val;
}

void reinit_video(void);

void hexdump(const void *buf, int length);

static inline uint16_t read_u16(const uint8_t *p) {
    return p[0] | (p[1] << 8);
}
static inline uint32_t read_u32(const uint8_t *p) {
    return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);
}
static inline uint64_t read_u64(const uint8_t *p) {
    return (
        (uint64_t)p[0] |
        ((uint64_t)p[1] << 8) |
        ((uint64_t)p[2] << 16) |
        ((uint64_t)p[3] << 24) |
        ((uint64_t)p[4] << 32) |
        ((uint64_t)p[5] << 40) |
        ((uint64_t)p[6] << 48) |
        ((uint64_t)p[7] << 56));
}
static inline void write_u16(uint8_t *p, uint16_t val) {
    p[0] = val & 0xFF;
    p[1] = (val >> 8) & 0xFF;
}
static inline void write_u32(uint8_t *p, uint32_t val) {
    p[0] = val & 0xFF;
    p[1] = (val >> 8) & 0xFF;
    p[2] = (val >> 16) & 0xFF;
    p[3] = (val >> 24) & 0xFF;
}
static inline void write_u64(uint8_t *p, uint64_t val) {
    p[0] = val & 0xFF;
    p[1] = (val >> 8) & 0xFF;
    p[2] = (val >> 16) & 0xFF;
    p[3] = (val >> 24) & 0xFF;
    p[4] = (val >> 32) & 0xFF;
    p[5] = (val >> 40) & 0xFF;
    p[6] = (val >> 48) & 0xFF;
    p[7] = (val >> 56) & 0xFF;
}

static inline bool is_decimal(uint8_t ch) { return (ch >= '0' && ch <= '9'); }
static inline bool is_upper(uint8_t ch) { return (ch >= 'A' && ch <= 'Z'); }
static inline bool is_lower(uint8_t ch) { return (ch >= 'a' && ch <= 'z'); }
static inline bool is_alpha(uint8_t ch) { return is_upper(ch) || is_lower(ch); }
static inline char to_upper(char ch) { return is_lower(ch) ? (ch - 'a' + 'A') : ch; }
static inline char to_lower(char ch) { return is_upper(ch) ? (ch - 'A' + 'a') : ch; }
static inline bool is_typechar(char ch) { return (ch == '%' || ch == '&' || ch == '!' || ch == '#' || ch == '$'); }
static inline bool is_cntrl(uint8_t ch) { return (ch < 32 || (ch >= 127 && ch < 160)); }
