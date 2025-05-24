#include "common.h"
#include "console.h"
#include "esp.h"
#include "readline.h"
#include <sys/stat.h>
#include <errno.h>

#define PATH_MAX 256

static const char *search_path = ".:/cores/aq32";

void skip_whitespace(char **p) {
    while (**p == ' ') (*p)++;
}

char *parse_param(char **p) {
    skip_whitespace(p);

    bool quoted = false;
    if (**p == '"') {
        quoted = true;
        (*p)++;
    }

    char *result = *p;

    while (**p) {
        if ((quoted && **p == '"') || (!quoted && **p == ' ')) {
            break;
        }
        (*p)++;
    }
    if (**p != 0) {
        *((*p)++) = 0;
    }
    return result;
}

static char *search_in_path(const char *name) {
    // Relative path, use search path
    const char *path_list = search_path; // getenv("PATH");
    if (path_list == NULL)
        return NULL;

    unsigned    name_len = strlen(name);
    const char *path     = path_list;
    char       *result   = NULL;

    while (1) {
        const char *delim    = strchr(path, ':');
        unsigned    path_len = (delim != NULL) ? (unsigned)(delim - path) : strlen(path);

        if (path_len != 0) {
            char *new_result = realloc(result, path_len + 1 + name_len + 1);
            if (new_result == NULL)
                break;
            result = new_result;

            strncpy(result, path, path_len);
            result[path_len] = 0;
            strcat(result, "/");
            strcat(result, name);

            struct esp_stat st;
            if (esp_stat(result, &st) == 0 && (st.attr & DE_ATTR_DIR) == 0) {
                return result;
            }
        }

        if (delim == NULL)
            break;
        path = delim + 1;
    }
    if (result)
        free(result);

    return NULL;
}

int cmd_cd(int argc, char **argv) {
    const char *path = "";
    if (argc == 2) {
        path = argv[1];
    } else if (argc > 2) {
        fprintf(stderr, "Too many arguments!\n");
        return 1;
    }

    if (chdir(path) < 0) {
        perror(path);
        return 1;
    }
    return 0;
}

int cmd_ls(int argc, char **argv) {
    const char *path = "";
    if (argc == 2) {
        path = argv[1];
    } else if (argc > 2) {
        fprintf(stderr, "Too many arguments!\n");
        return 1;
    }

    int dd = esp_opendir(path);
    if (dd < 0) {
        esp_set_errno(dd);
        perror(path);
        return 1;
    }

    char tmp[256];

    struct esp_stat st;
    while (1) {
        int res = esp_readdir(dd, &st, tmp, sizeof(tmp));
        if (res < 0)
            break;

        printf(
            "%02u-%02u-%02u %02u:%02u ",
            ((st.date >> 9) + 80) % 100,
            (st.date >> 5) & 15,
            st.date & 31,
            (st.time >> 11) & 31,
            (st.time >> 5) & 63);

        if (st.attr & DE_ATTR_DIR) {
            printf("<DIR> ");
        } else {
            if (st.size < 1024) {
                printf("%4lu  ", st.size);
            } else if (st.size < 1024 * 1024) {
                printf("%4luK ", st.size >> 10);
            } else {
                printf("%4luM ", st.size >> 20);
            }
        }
        printf("%s\n", tmp);
    }

    esp_closedir(dd);
    return 0;
}

int cmd_mkdir(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "missing operands\n");
        return 1;
    }

    int result = 0;
    for (int i = 1; i < argc; i++) {
        if (mkdir(argv[i], 0777) < 0) {
            perror(argv[i]);
            result = 1;
        }
    }
    return result;
}

int cmd_rmdir(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "missing operands\n");
        return 1;
    }

    int result = 0;
    for (int i = 1; i < argc; i++) {
        if (rmdir(argv[i]) < 0) {
            perror(argv[i]);
            result = 1;
        }
    }
    return result;
}

int cmd_rm(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "missing operands\n");
        return 1;
    }

    int result = 0;
    for (int i = 1; i < argc; i++) {
        if (unlink(argv[i]) < 0) {
            perror(argv[i]);
            result = 1;
        }
    }
    return result;
}

void load_executable(const char *path);

int execute(int argc, char **argv) {
    char path[256];
    snprintf(path, sizeof(path) - 5, argv[0]);
    int len = strlen(path);
    if (path[len - 5] != '.' ||
        tolower(path[len - 4]) != 'a' ||
        tolower(path[len - 3]) != 'q' ||
        path[len - 2] != '3' ||
        path[len - 1] != '2') {

        strcat(path, ".aq32");
    }

    char *filename      = path;
    char *search_result = NULL;
    if (strchr(filename, '/') == NULL) {
        // Search in path
        if ((search_result = search_in_path(filename)) == NULL) {
            fprintf(stdout, "%s: command not found\n", filename);
            return -1;
        }
        filename = search_result;
    }

    struct esp_stat st;
    int             result = esp_stat(filename, &st);
    if (result < 0) {
        esp_set_errno(result);
        perror(filename);
        goto done;
    }

    if ((st.attr & DE_ATTR_DIR) != 0) {
        errno = EISDIR;
        perror(filename);
        goto done;
    }
    load_executable(filename);
    return 0;

done:
    if (search_result)
        free(search_result);
    return 1;
}

// called from start.S
void main(void) {
    console_init();
    printf("\n Aquarius32 System V0.1\n\n");

    char prompt[PATH_MAX + 16];
    char line[128];

    while (1) {
        // Compose prompt
        getcwd(prompt, PATH_MAX);
        strcat(prompt, "> ");
        fputs(prompt, stdout);
        int result = readline(line, sizeof(line));
        if (result <= 0)
            continue;

        // Parse line
        char *p   = line;
        char *cmd = parse_param(&p);
        if (cmd[0] == 0)
            continue;

        char *cmd_argv[16];
        int   cmd_argc       = 0;
        cmd_argv[cmd_argc++] = cmd;

        while (1) {
            char *arg = parse_param(&p);
            if (arg[0] == 0)
                break;

            if (cmd_argc >= (int)(sizeof(cmd_argv) / sizeof(*cmd_argv)) - 1) {
                cmd_argc = -1;
                break;
            }

            cmd_argv[cmd_argc++] = arg;
        }
        if (cmd_argc < 0) {
            fprintf(stderr, "Parameter limit exceeded\n");
            continue;
        }
        cmd_argv[cmd_argc] = NULL;

        if (strcmp(cmd, "cd") == 0) {
            cmd_cd(cmd_argc, cmd_argv);
        } else if (strcmp(cmd, "ls") == 0 || strcmp(cmd, "dir") == 0) {
            cmd_ls(cmd_argc, cmd_argv);
        } else if (strcmp(cmd, "mkdir") == 0) {
            cmd_mkdir(cmd_argc, cmd_argv);
        } else if (strcmp(cmd, "rmdir") == 0) {
            cmd_rmdir(cmd_argc, cmd_argv);
        } else if (strcmp(cmd, "rm") == 0 || strcmp(cmd, "del") == 0) {
            cmd_rm(cmd_argc, cmd_argv);
        } else if (strcmp(cmd, "cp") == 0) {
        } else {
            execute(cmd_argc, cmd_argv);
        }
    }
}
