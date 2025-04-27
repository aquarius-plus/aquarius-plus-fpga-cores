#include "common.h"
#include "console.h"
#include <errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/timeb.h>
#include <sys/time.h>
#include "esp.h"

#define FD_ESP_START 10
#define XFER_MAX     0xF000

int _isatty(int fd) {
    return (fd == STDIN_FILENO || fd == STDOUT_FILENO || fd == STDERR_FILENO);
}

static int set_errno(int esp_err) {
    switch (esp_err) {
        case ERR_NOT_FOUND: errno = ENOENT; break;     // File / directory not found
        case ERR_TOO_MANY_OPEN: errno = ENFILE; break; // Too many open files / directories
        case ERR_PARAM: errno = EINVAL; break;         // Invalid parameter
        case ERR_EXISTS: errno = EEXIST; break;        // File already exists
        case ERR_OTHER: errno = EIO; break;            // Other error
        case ERR_NO_DISK: errno = ENODEV; break;       // No disk
        case ERR_NOT_EMPTY: errno = ENOTEMPTY; break;  // Not empty
        case ERR_WRITE_PROTECT: errno = EROFS; break;  // Write protected SD-card
        case ERR_EOF:                                  // End of file / directory
        default: errno = EIO; break;
    }
    return -1;
}

int _open(const char *path, int flags) {
    uint8_t esp_flags = 0;

    switch (flags & O_ACCMODE) {
        case O_RDONLY: esp_flags = 0; break;
        case O_WRONLY: esp_flags = 1; break;
        case O_RDWR: esp_flags = 2; break;
    }
    if (flags & O_APPEND)
        esp_flags |= 0x4;
    if (flags & O_CREAT)
        esp_flags |= 0x8;
    if (flags & O_TRUNC)
        esp_flags |= 0x10;
    if (flags & O_EXCL)
        esp_flags |= 0x20;

    esp_cmd(ESPCMD_OPEN);
    esp_send_byte(esp_flags);
    esp_send_bytes(path, strlen(path) + 1);
    int result = (int8_t)esp_get_byte();
    if (result < 0) {
        return set_errno(result);
    }
    return FD_ESP_START + result;
}

ssize_t _read(int fd, void *buf, size_t count) {
    uint8_t *p = buf;

    if (fd >= FD_ESP_START) {
        unsigned remaining = count;

        while (remaining > 0) {
            uint16_t length;
            if (remaining > XFER_MAX) {
                length = XFER_MAX;
            } else {
                length = remaining;
            }

            esp_cmd(ESPCMD_READ);
            esp_send_byte(fd - FD_ESP_START);
            esp_send_byte(length & 0xFF);
            esp_send_byte(length >> 8);
            int result = (int8_t)esp_get_byte();
            if (result < 0) {
                if (result == ERR_EOF)
                    break;
                return set_errno(result);
            }

            uint16_t rx_len = esp_get_byte();
            rx_len |= esp_get_byte() << 8;
            while (rx_len--)
                *(p++) = esp_get_byte();

            if (length != rx_len)
                break;
            remaining -= length;
        }

    } else if (fd == STDIN_FILENO) {
        while (count) {
            unsigned ch = REGS->KEYBUF;
            if (ch == 0) {
                // No data
                if (p > (uint8_t *)buf) {
                    // Return what we got so far
                    break;
                }
            } else {
                *(p++) = ch;
                count--;
            }
        }

    } else {
        errno = EINVAL;
        return -1;
    }
    return p - (uint8_t *)buf;
}

int _write(int fd, const void *buf, size_t count) {
    const uint8_t *p = buf;

    if (fd >= FD_ESP_START) {
        unsigned remaining = count;

        while (remaining > 0) {
            uint16_t length;
            if (remaining > XFER_MAX) {
                length = XFER_MAX;
            } else {
                length = remaining;
            }

            esp_cmd(ESPCMD_WRITE);
            esp_send_byte(fd - FD_ESP_START);
            esp_send_byte(length & 0xFF);
            esp_send_byte(length >> 8);
            uint16_t tx_len = length;
            while (tx_len--)
                esp_send_byte(*(p++));

            int result = (int8_t)esp_get_byte();
            if (result < 0)
                return set_errno(result);

            uint16_t written = esp_get_byte();
            if (length != written)
                break;
            remaining -= length;
        }

    } else if (fd == STDOUT_FILENO || fd == STDERR_FILENO) {
        while (count--) {
            uint8_t ch = *(p++);
            if (ch == '\n') {
                console_putc('\r');
            }
            console_putc(ch);
        }

    } else {
        errno = EINVAL;
        return -1;
    }

    return p - (uint8_t *)buf;
}

off_t _lseek(int fd, off_t offset, int whence) {
    if (whence < 0 || whence > 2) {
        errno = EINVAL;
        return -1;
    }

    if (fd >= FD_ESP_START) {
        esp_cmd(ESPCMD_LSEEK);
        esp_send_byte(fd - FD_ESP_START);
        esp_send_byte(offset & 0xFF);
        esp_send_byte(offset >> 8);
        esp_send_byte(offset >> 8);
        esp_send_byte(offset >> 8);
        esp_send_byte(whence);

        int32_t result = (int8_t)esp_get_byte();
        if (result < 0)
            return set_errno(result);

        esp_get_bytes(&result, sizeof(result));
        return result;

    } else {
        errno = ESPIPE;
        return -1;
    }
    return 0;
}

int _close(int fd) {
    if (fd >= FD_ESP_START) {
        esp_cmd(ESPCMD_CLOSE);
        esp_send_byte(fd - FD_ESP_START);
        int result = (int8_t)esp_get_byte();
        if (result < 0)
            return set_errno(result);
        return 0;
    }

    errno = EINVAL;
    return -1;
}

noreturn void _exit(int status) {
    while (1);
}

int _kill(pid_t pid, int sig) {
    return 0;
}

int _getpid(void) {
    return 0;
}

int _fstat(int fd, struct stat *st) {
    errno = ENOENT;
    return -1;
}

void *_sbrk(intptr_t incr) {
    extern char  _end;
    static char *heap_end;

    if (heap_end == NULL)
        heap_end = &_end;

    char *prev_heap_end = heap_end;
    heap_end += incr;

    return prev_heap_end;
}

int _lstat(const char *path, struct stat *st) {
    errno = ENOENT;
    return -1;
}

int _ftime(struct timeb *tp) {
    errno = EIO;
    return -1;
}

int _unlink(const char *name) {
    esp_cmd(ESPCMD_DELETE);
    esp_send_bytes(name, strlen(name) + 1);

    int result = (int8_t)esp_get_byte();
    if (result < 0)
        return set_errno(result);

    return 0;
}

int _access(const char *file, int mode) {
    errno = ENOENT;
    return -1;
}

int _faccessat(int dirfd, const char *file, int mode, int flags) {
    errno = ENOENT;
    return -1;
}

int _fstatat(int dirfd, const char *file, struct stat *st, int flags) {
    errno = ENOENT;
    return -1;
}

int _gettimeofday(struct timeval *tp, void *tzp) {
    errno = EIO;
    return -1;
}

int _link(const char *old_name, const char *new_name) {
    errno = ENOENT;
    return -1;
}

int _openat(int dirfd, const char *name, int flags, int mode) {
    errno = ENOENT;
    return -1;
}

int _stat(const char *file, struct stat *st) {
    errno = ENOENT;
    return -1;
}
