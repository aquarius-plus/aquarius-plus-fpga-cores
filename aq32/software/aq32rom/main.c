#include "common.h"
#include "console.h"
#include "esp.h"

void editor(void);

// called from start.S
void main(void) {
#if 1
    editor();
#else
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
        int ch = REGS->KEYBUF;
        if (ch < 0)
            continue;
        printf("%04X\n", ch);
    }
    editor();
#endif
}
