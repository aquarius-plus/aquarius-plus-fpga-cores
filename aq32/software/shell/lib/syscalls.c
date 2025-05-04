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

static uint8_t input_buffer[128];
static uint8_t input_buffer_rdidx;
static uint8_t input_buffer_wridx;
static uint8_t input_buffer_count;

static void input_buffer_push(uint8_t val) {
    if (input_buffer_count >= sizeof(input_buffer))
        return;

    input_buffer[input_buffer_wridx] = val;
    input_buffer_wridx++;
    if (input_buffer_wridx == sizeof(input_buffer))
        input_buffer_wridx = 0;
    input_buffer_count++;
}
static void input_buffer_push_str(const char *str) {
    while (*str)
        input_buffer_push(*(str++));
}
static int input_buffer_pop(void) {
    if (input_buffer_count == 0)
        return -1;

    uint8_t result = input_buffer[input_buffer_rdidx];
    input_buffer_rdidx++;
    if (input_buffer_rdidx == sizeof(input_buffer))
        input_buffer_rdidx = 0;
    input_buffer_count--;
    return result;
}

int _isatty(int fd) {
    return (fd == STDIN_FILENO || fd == STDOUT_FILENO || fd == STDERR_FILENO);
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
        return esp_set_errno(result);

    return FD_ESP_START + result;
}

static void process_keybuf(void) {
    while (1) {
        int key = REGS->KEYBUF;
        if (key < 0)
            return;

        if ((key & KEY_IS_SCANCODE))
            continue;

        switch (key & 0xFF) {
            case CH_UP: input_buffer_push_str("\033[A"); break;
            case CH_DOWN: input_buffer_push_str("\033[B"); break;
            case CH_RIGHT: input_buffer_push_str("\033[C"); break;
            case CH_LEFT: input_buffer_push_str("\033[D"); break;
            case CH_DELETE: input_buffer_push_str("\033[3~"); break;
            case CH_PAGEUP: input_buffer_push_str("\033[5~"); break;
            case CH_PAGEDOWN: input_buffer_push_str("\033[6~"); break;
            case CH_HOME: input_buffer_push_str("\033[H"); break;
            case CH_END: input_buffer_push_str("\033[F"); break;
            default:
                uint8_t ch = key & 0xFF;

                if (key & KEY_MOD_CTRL) {
                    uint8_t ch_upper = toupper(ch);

                    if (ch_upper >= '@' && ch_upper <= '_')
                        ch = ch_upper - '@';
                    else if (ch_upper == 0x7F)
                        ch = '\b';
                }
                input_buffer_push(ch);
                break;
        }
    }
}

ssize_t _read(int fd, void *buf, size_t count) {
    if (fd >= FD_ESP_START) {
        int result = esp_read(fd - FD_ESP_START, buf, count);
        if (result == ERR_EOF)
            result = 0;

        if (result < 0 && result != ERR_EOF)
            return esp_set_errno(result);

        return result;

    } else if (fd == STDIN_FILENO) {
        uint8_t *p = buf;

        while (count) {
            process_keybuf();
            int val = input_buffer_pop();
            if (val < 0) {
                // No data
                if (p > (uint8_t *)buf) {
                    // Return what we got so far
                    break;
                }
            } else {
                *(p++) = val;
                count--;
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
            return esp_set_errno(result);
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
            return esp_set_errno(result);

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
            return esp_set_errno(result);
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
        esp_set_errno(result);
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

int chdir(const char *path) {
    int result = esp_chdir(path);
    if (result < 0)
        return esp_set_errno(result);
    return 0;
}

int mkdir(const char *path, mode_t mode) {
    int result = esp_mkdir(path);
    if (result < 0)
        return esp_set_errno(result);
    return 0;
}

int rmdir(const char *path) {
    struct esp_stat st;
    int             result = esp_stat(path, &st);
    if (result < 0)
        return esp_set_errno(result);

    if ((st.attr & DE_ATTR_DIR) == 0) {
        errno = ENOTDIR;
        return -1;
    }

    result = esp_delete(path);
    if (result < 0)
        return esp_set_errno(result);
    return 0;
}

int _unlink(const char *path) {
    struct esp_stat st;
    int             result = esp_stat(path, &st);
    if (result < 0)
        return esp_set_errno(result);

    if ((st.attr & DE_ATTR_DIR) != 0) {
        errno = EISDIR;
        return -1;
    }

    result = esp_delete(path);
    if (result < 0)
        return esp_set_errno(result);
    return 0;
}
