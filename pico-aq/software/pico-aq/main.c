#include "common.h"
#include "console.h"
#include <sys/stat.h>
#include <errno.h>

void load_executable(const char *path);

int main(void) {
    TRAM->init_val1 = 0;
    TRAM->init_val2 = 0;
    console_init();
    console_puts("\r\n Pico-Aq V0.1\r\n\r\n");

    while (1);

    // load_executable("/cores/aq32/shell.aq32");
    return 0;
}
