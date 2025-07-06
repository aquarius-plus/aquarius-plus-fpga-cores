#pragma once

#include <stdint.h>
#include <assert.h>

// KEYBUF
// | Bit | Description                  |
// | --: | ---------------------------- |
// |  31 | Empty(1)                     |
// |  14 | Scancode(1) / Character(0)   |
// |  13 | Scancode key up(0) / down(1) |
// |  12 | Repeated                     |
// |  11 | Modifier: Gui                |
// |  10 | Modifier: Alt                |
// |   9 | Modifier: Shift              |
// |   8 | Modifier: Ctrl               |
// | 7:0 | Character / Scancode         |

#define KEY_IS_SCANCODE (1 << 14)
#define KEY_KEYDOWN     (1 << 13)
#define KEY_IS_REPEATED (1 << 12)
#define KEY_MOD_GUI     (1 << 11)
#define KEY_MOD_ALT     (1 << 10)
#define KEY_MOD_SHIFT   (1 << 9)
#define KEY_MOD_CTRL    (1 << 8)

struct regs {
    volatile uint32_t ESP_CTRL;
    volatile uint32_t ESP_DATA;
    volatile uint32_t VCTRL;
    volatile uint32_t VSCRX;
    volatile uint32_t VSCRY;
    volatile uint32_t VLINE;
    volatile uint32_t VIRQLINE;
    volatile int32_t  KEYBUF;
};

struct pcm {
    volatile uint32_t status;
    volatile uint32_t fifo_ctrl;
    volatile uint32_t rate;
    volatile uint32_t data;
};

struct fmsynth {
    volatile uint32_t opmode;
    volatile uint32_t ctrl;
    volatile uint32_t key_on;
    volatile uint32_t _pad[29 + 32 + 32];
    volatile uint32_t ch_attr[32];
    volatile uint32_t op_attr0[64];
    volatile uint32_t op_attr1[64];
};

static_assert(sizeof(struct fmsynth) == 1024);

#define TEXT_COLUMNS 80
#define TEXT_ROWS    30

struct tram {
    uint16_t text[TEXT_COLUMNS * TEXT_ROWS];
    uint16_t init_val1;
    uint16_t text_color;
    uint16_t saved_color;
    uint16_t cursor_color;
    uint8_t  cursor_row;
    uint8_t  cursor_column;
    uint8_t  cursor_visible;
    uint8_t  cursor_enabled;
    uint16_t init_val2;
};

#define REGS     ((struct regs *)0x2000)
#define PCM      ((struct pcm *)0x2400)
#define FMSYNTH  ((struct fmsynth *)0x2800)
#define SPRATTR  ((volatile uint32_t *)0x03000)
#define SPRPOS   ((volatile uint32_t *)0x03100)
#define PALETTE  ((volatile uint16_t *)0x04000)
#define CHRAM    ((volatile uint8_t *)0x05000)
#define TRAM     ((struct tram *)0x06000)
#define VRAM     ((volatile uint8_t *)0x08000)
#define TILEMAP  ((volatile uint16_t *)(VRAM + 0x7000))
#define VRAM4BPP ((volatile uint8_t *)0x10000)

#define SPRATTR_TILEIDX_Pos 0
#define SPRATTR_TILEIDX_Msk (0x3FF << SPRATTR_TILEIDX_Pos)
#define SPRATTR_H16         (1 << 10)
#define SPRATTR_HFLIP       (1 << 11)
#define SPRATTR_VFLIP       (1 << 12)
#define SPRATTR_PALETTE_Pos 12
#define SPRATTR_PALETTE_Msk (3 << SPRATTR_PALETTE_Pos)
#define SPRATTR_PRIO        (1 << 15)

#define TILEMAP_TILEIDX_Pos 0
#define TILEMAP_TILEIDX_Msk (0x3FF << TILEMAP_TILEIDX_Pos)
#define TILEMAP_HFLIP       (1 << 11)
#define TILEMAP_VFLIP       (1 << 12)
#define TILEMAP_PALETTE_Pos 12
#define TILEMAP_PALETTE_Msk (3 << TILEMAP_PALETTE_Pos)
#define TILEMAP_PRIO        (1 << 15)

enum {
    ESPCMD_RESET       = 0x01, // Reset ESP
    ESPCMD_VERSION     = 0x02, // Get version string
    ESPCMD_GETDATETIME = 0x03, // Get current date/time
    ESPCMD_KEYMODE     = 0x08, // Set keyboard buffer mode
    ESPCMD_GETMOUSE    = 0x0C, // Get mouse state
    ESPCMD_GETGAMECTRL = 0x0E, // Get game controller state
    ESPCMD_GETMIDIDATA = 0x0F, // Get mouse state
    ESPCMD_OPEN        = 0x10, // Open / create file
    ESPCMD_CLOSE       = 0x11, // Close open file
    ESPCMD_READ        = 0x12, // Read from file
    ESPCMD_WRITE       = 0x13, // Write to file
    ESPCMD_SEEK        = 0x14, // Move read/write pointer
    ESPCMD_TELL        = 0x15, // Get current read/write
    ESPCMD_OPENDIR     = 0x16, // Open directory
    ESPCMD_CLOSEDIR    = 0x17, // Close open directory
    ESPCMD_READDIR     = 0x18, // Read from directory
    ESPCMD_DELETE      = 0x19, // Remove file or directory
    ESPCMD_RENAME      = 0x1A, // Rename / move file or directory
    ESPCMD_MKDIR       = 0x1B, // Create directory
    ESPCMD_CHDIR       = 0x1C, // Change directory
    ESPCMD_STAT        = 0x1D, // Get file status
    ESPCMD_GETCWD      = 0x1E, // Get current working directory
    ESPCMD_CLOSEALL    = 0x1F, // Close any open file/directory descriptor
    ESPCMD_OPENDIR83   = 0x20, // Open directory in 8.3 filename mode
    ESPCMD_READLINE    = 0x21, // Read line from file
    ESPCMD_OPENDIREXT  = 0x22, // Open directory with extended options
    ESPCMD_LSEEK       = 0x23, // Seek in file with offset and whence
    ESPCMD_LOADFPGA    = 0x40, // Load FPGA bitstream
};

enum {
    ERR_NOT_FOUND     = -1, // File / directory not found
    ERR_TOO_MANY_OPEN = -2, // Too many open files / directories
    ERR_PARAM         = -3, // Invalid parameter
    ERR_EOF           = -4, // End of file / directory
    ERR_EXISTS        = -5, // File already exists
    ERR_OTHER         = -6, // Other error
    ERR_NO_DISK       = -7, // No disk
    ERR_NOT_EMPTY     = -8, // Not empty
    ERR_WRITE_PROTECT = -9, // Write protected SD-card
};

enum {
    FO_RDONLY  = 0x00, // Open for reading only
    FO_WRONLY  = 0x01, // Open for writing only
    FO_RDWR    = 0x02, // Open for reading and writing
    FO_ACCMODE = 0x03, // Mask for above modes

    FO_APPEND = 0x04, // Append mode
    FO_CREATE = 0x08, // Create if non-existant
    FO_TRUNC  = 0x10, // Truncate to zero length
    FO_EXCL   = 0x20, // Error if already exists
};

#define VCTRL_TEXT_EN      (1 << 0)
#define VCTRL_TEXT_MODE80  (1 << 1)
#define VCTRL_TEXT_PRIO    (1 << 2)
#define VCTRL_GFX_EN       (1 << 3)
#define VCTRL_GFX_TILEMODE (1 << 4)
#define VCTRL_SPR_EN       (1 << 5)

#define MAX_ARGS 64
struct start_data {
    int   exit_status;
    int   argc;
    char *argv[MAX_ARGS];
};

#define STARTDATA ((struct start_data *)0x80000)
