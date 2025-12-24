#include "common.h"
#include "esp.h"

static const uint16_t palette[16] = {
    0x000,
    0x125,
    0x725,
    0x085,
    0xA53,
    0x554,
    0xCCC,
    0xFFE,
    0xF04,
    0xFA0,
    0xFF2,
    0x0E5,
    0x2AF,
    0x879,
    0xF7A,
    0xFCA
};

void reinit_video(void) {
#ifndef PCDEV
    for (int i = 0; i < 16; i++)
        PALETTE[i] = palette[i & 15];

    int fd = esp_open("esp:latin1b.chr", 0);
    if (fd >= 0) {
        esp_read(fd, (void *)CHRAM, 2048);
        esp_close(fd);
    }
#endif
}

void hexdump(const void *buf, int length) {
    int            idx = 0;
    const uint8_t *p   = (const uint8_t *)buf;

    while (length > 0) {
        int len = length;
        if (len > 16) {
            len = 16;
        }

        printf("%08x  ", idx);

        for (int i = 0; i < 16; i++) {
            if (i < len) {
                printf("%02x ", p[i]);
            } else {
                printf("   ");
            }
            if (i == 7) {
                printf(" ");
            }
        }
        printf(" |");

        for (int i = 0; i < len; i++) {
            printf("%c", (p[i] >= 32 && p[i] <= 126) ? p[i] : '.');
        }
        printf("|\n");

        idx += len;
        length -= len;
        p += len;
    }
}
