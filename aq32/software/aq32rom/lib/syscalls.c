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

    int result = esp_open(path, esp_flags);
    if (result < 0)
        return set_errno(result);

    return FD_ESP_START + result;
}

ssize_t _read(int fd, void *buf, size_t count) {
    if (fd >= FD_ESP_START) {
        int result = esp_read(fd - FD_ESP_START, buf, count);
        if (result == ERR_EOF)
            result = 0;

        if (result < 0 && result != ERR_EOF)
            return set_errno(result);

        return result;

    } else if (fd == STDIN_FILENO) {
        uint8_t *p = buf;

        while (count) {
            int ch = REGS->KEYBUF;
            if (ch < 0) {
                // No data
                if (p > (uint8_t *)buf) {
                    // Return what we got so far
                    break;
                }
            } else {
                if ((ch & KEY_IS_SCANCODE) == 0) {
                    *(p++) = ch & 0xFF;
                    count--;
                }
            }
        }
        return p - (uint8_t *)buf;

    } else {
        errno = EINVAL;
        return -1;
    }
}

int _write(int fd, const void *buf, size_t count) {
    if (fd >= FD_ESP_START) {
        int result = esp_write(fd - FD_ESP_START, buf, count);
        if (result < 0)
            return set_errno(result);
        return result;

    } else if (fd == STDOUT_FILENO || fd == STDERR_FILENO) {
        const uint8_t *p = buf;
        while (count--) {
            uint8_t ch = *(p++);
            if (ch == '\n') {
                console_putc('\r');
            }
            console_putc(ch);
        }
        return p - (uint8_t *)buf;

    } else {
        errno = EINVAL;
        return -1;
    }
}

off_t _lseek(int fd, off_t offset, int whence) {
    if (whence < 0 || whence > 2) {
        errno = EINVAL;
        return -1;
    }

    if (fd >= FD_ESP_START) {
        int result = esp_lseek(fd - FD_ESP_START, offset, whence);
        if (result < 0)
            return set_errno(result);

        return result;

    } else {
        errno = ESPIPE;
        return -1;
    }
    return 0;
}

int _close(int fd) {
    if (fd >= FD_ESP_START) {
        int result = esp_close(fd - FD_ESP_START);
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
    int result = esp_delete(name);
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

char *getcwd(char *buf, size_t size) {
    esp_cmd(ESPCMD_GETCWD);
    int result = (int8_t)esp_get_byte();
    if (result < 0) {
        set_errno(result);
        return NULL;
    }

    char *p  = buf;
    char *p2 = buf + size - 1;
    while (1) {
        uint8_t ch = esp_get_byte();
        if (p < p2) {
            *(p++) = ch;
            if (ch == 0)
                break;
        } else {
            buf = NULL;
        }
    }
    return buf;
}
