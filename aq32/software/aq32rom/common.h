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

#include "regs.h"

#define COLOR_MENU       0x07
#define COLOR_MENU_ACCEL 0xF7
#define COLOR_MENU_SEL   0x70
#define COLOR_EDITOR     0x71
#define COLOR_FILENAME   0x17
#define COLOR_CURSOR     0x06
#define COLOR_SELECTED   0x17
#define COLOR_STATUS     0xF3
#define COLOR_STATUS2    0x03

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
