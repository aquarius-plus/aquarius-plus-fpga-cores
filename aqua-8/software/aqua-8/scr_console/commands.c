#include "commands.h"
#include "state.h"
#include "esp.h"
#include "console.h"

void cmd_help(const char *topic) {
    if (topic[0] == 0) {
        console_putline("\fCCOMMANDS\f6");
        console_putline("\f7load\f6 <filename>   Load a cartridge");
        console_putline("\f7save\f6 <filename>   Save a cartridge");
        console_putline("\f7run\f6 (or Ctrl-R)   Run");
        console_putline("\f7resume\f6            Resume halted program");
        console_putline("\f7reboot\f6            Reboot the system");
        console_putline("\f7ls\f6                List directory");
        console_putline("\f7cd\f6 <dirname>      Change directory");
        console_putline("\f7cd\f6 ..             Go up a directory");
        console_putline("\f7mkdir\f6 <dirname>   Create directory");
        console_putline("\f7help\f6 <topic>      Get help on topic");
        console_putline("");
        console_putline("\f7Help topics:");
        console_putline("\fCgfx data audio system math lua");
        console_putline("");
        console_putline("Press \f7ESC\f6 to toggle editor view");
    } else {
        console_puts("\fDTopic '\f6");
        console_puts(topic);
        console_putline("\fD' not found");
    }
}

static void print_cwd(void) {
    char tmp[64];
    esp_getcwd(tmp, sizeof(tmp));
    console_puts("\fCDirectory: ");
    console_putline(tmp);
}

void cmd_ls(const char *args) {
    (void)args;
    const char *path = "";
    int         dd   = esp_opendir(path);
    if (dd < 0) {
        console_putline("Error listing path");
        return;
    }

    game_state.color = 6;

    char fn[256];

    int lines_output = 1;
    print_cwd();

    struct esp_stat st;
    while (1) {
        int res = esp_readdir(dd, &st, fn, sizeof(fn));
        if (res < 0)
            break;

        console_printf("%02u-%02u-%02u %02u:%02u ", ((st.date >> 9) + 80) % 100, (st.date >> 5) & 15, st.date & 31, (st.time >> 11) & 31, (st.time >> 5) & 63);
        if (st.attr & DE_ATTR_DIR) {
            console_puts("<DIR> ");
        } else {
            if (st.size <= 99999) {
                console_printf("%5lu ", st.size);
            } else if (st.size < 1024 * 1024) {
                console_printf("%4luK ", st.size >> 10);
            } else {
                console_printf("%4luM ", st.size >> 20);
            }
        }

        if (st.attr & DE_ATTR_DIR) {
            console_puts("\fE");
        }
        console_putline(fn);

        lines_output++;
        if (lines_output >= 22) {
            lines_output = 0;
            console_puts("\fC--MORE--\f6");
            console_getc();
            int ch;
            while ((ch = console_getc()) <= 0);
            console_puts("\r        \r");
            if (ch == 27)
                break;
        }
    }
    esp_closedir(dd);
}

void cmd_cd(const char *path) {
    if (path[0] != 0) {
        if (esp_chdir(path) < 0) {
            console_putline("Directory not found");
            return;
        }
    }
    print_cwd();
}
