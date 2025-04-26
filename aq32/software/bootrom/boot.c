#include "regs.h"
#include "esp.h"
#include <stddef.h>

static size_t strlen(const char *s) {
    size_t result = 0;
    while (*s) {
        s++;
        result++;
    }
    return result;
}

static int esp_open(const char *path, uint8_t flags) {
    esp_cmd(ESPCMD_OPEN);
    esp_send_byte(flags);
    esp_send_bytes(path, strlen(path) + 1);
    return (int8_t)esp_get_byte();
}

static int esp_read(int fd, void *buf, uint16_t length) {
    esp_cmd(ESPCMD_READ);
    esp_send_byte(fd);
    esp_send_byte(length & 0xFF);
    esp_send_byte(length >> 8);
    int result = (int8_t)esp_get_byte();
    if (result < 0)
        return result;

    result = esp_get_byte();
    result |= esp_get_byte() << 8;
    esp_get_bytes(buf, result);
    return result;
}

static int esp_close(int fd) {
    esp_cmd(ESPCMD_CLOSE);
    esp_send_byte(fd);
    return (int8_t)esp_get_byte();
}

// called from start.S
void boot(void) {
    esp_cmd(ESPCMD_RESET);
    int fd = esp_open("aq32.rom", FO_RDONLY);
    if (fd >= 0) {
        uint8_t *addr = (uint8_t *)0x80000;
        while (1) {
            int count = esp_read(fd, addr, 0x8000);
            if (count <= 0)
                break;
            addr += count;
        }
        esp_close(fd);
        ((void (*)())0x80000)();
    }
    while (1);
}
