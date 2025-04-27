#include "console.h"
#include "file_io.h"
#include <string.h>
#include <stdio.h>
#include "esp.h"

void editor(void);

// static const uint16_t palette[16] = {
//     0x111, 0xF11, 0x1F1, 0xFF1, 0x22E, 0xF1F, 0x3CC, 0xFFF,
//     0xCCC, 0x3BB, 0xC2C, 0x419, 0xFF7, 0x2D4, 0xB22, 0x333};

static const uint16_t palette[16] = {
    0x000, 0x00A, 0x0A0, 0x0AA, 0xA00, 0xA0A, 0xA50, 0xAAA,
    0x555, 0x55F, 0x5F5, 0x5FF, 0xF55, 0xF5F, 0xFF5, 0xFFF};

// called from start.S
void main(void) {
    REGS->VCTRL = VCTRL_80COLUMNS | VCTRL_REMAP_BORDER_CH | VCTRL_TEXT_EN;

    for (int i = 0; i < 64; i++)
        PALETTE[i] = palette[i & 15];

    FILE *f = fopen("esp:latin1b.chr", "rb");
    if (f) {
        fread((void *)CHRAM, 2048, 1, f);
        fclose(f);
    }

    {
        esp_cmd(ESPCMD_KEYMODE);
        esp_send_byte(7);
        int result = (int8_t)esp_get_byte();

        // printf("Keymode result=%d\n", result);
    }

#if 0
    console_init();

    printf("\nAquarius32 System V0.1\n\nSD:/>\n");
    fflush(stdout);

    // FILE *f = fopen("/demos/Mandelbrot/run-me.bas", "rt");
    // if (f != NULL) {
    //     char  *linebuf      = NULL;
    //     size_t linebuf_size = 0;
    //     int    line_size    = 0;
    //     while ((line_size = __getline(&linebuf, &linebuf_size, f)) > 0) {
    //         while (line_size > 0 && (linebuf[line_size - 1] == '\r' || linebuf[line_size - 1] == '\n'))
    //             line_size--;
    //         linebuf[line_size] = 0;
    //         if (line_size == 0)
    //             break;

    //         puts(linebuf);
    //     }
    //     fclose(f);
    // }

    // {
    //     esp_cmd(ESPCMD_KEYMODE);
    //     esp_send_byte(5);
    //     int result = (int8_t)esp_get_byte();

    //     printf("Keymode result=%d\n", result);
    // }

    while (1) {
        int ch = getchar();
        if (ch > 0) {
            console_putc(ch);
        }
    }
#else
    editor();
#endif
}
