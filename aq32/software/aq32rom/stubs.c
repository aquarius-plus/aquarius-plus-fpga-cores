#include "common.h"
#include "console.h"
#include <errno.h>
#include <sys/stat.h>

int _isatty(int fd) {
    return (fd == STDIN_FILENO || fd == STDOUT_FILENO || fd == STDERR_FILENO);
}

int _write(int fd, const void *buf, size_t size) {
    if (fd == STDOUT_FILENO) {
        const uint8_t *p   = buf;
        unsigned       len = size;
        while (len--) {
            uint8_t ch = *(p++);
            if (ch == '\n') {
                console_putc('\r');
            }
            console_putc(ch);
        }
    }
    return size;
}

int _close(int fd) {
    return 0;
}

noreturn void _exit(int status) {
    while (1);
}

int _kill(pid_t pid, int sig) {
    return 0;
}

ssize_t _read(int fd, void *buf, size_t count) {
    return 0;
}

int _getpid(void) {
    return 0;
}

off_t _lseek(int fd, off_t offset, int whence) {
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
