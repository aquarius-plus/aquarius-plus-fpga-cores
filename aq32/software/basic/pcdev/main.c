#include "basic.h"
#include "editor/editbuf.h"

struct editor_state {
    struct editbuf editbuf;

    char filename[64];
    int  cursor_line;
    int  cursor_pos;
    int  scr_first_line;
    int  scr_first_pos;
    bool modified;
};

struct editor_state state;

void reset_state(void) {
    memset(&state, 0, sizeof(state));
    editbuf_init(&state.editbuf);
}

static int load_file(const char *path) {
    FILE *f = fopen(path, "rt");
    if (!f)
        return -1;

    reset_state();
    snprintf(state.filename, sizeof(state.filename), "%s", path);

    int  line        = 0;
    bool do_truncate = false;

    size_t linebuf_size = MAX_BUFSZ;
    char  *linebuf      = malloc(linebuf_size);
    int    line_size    = 0;
    while ((line_size = getline(&linebuf, &linebuf_size, f)) >= 0) {
        // Strip of CR/LF
        while (line_size > 0 && (linebuf[line_size - 1] == '\r' || linebuf[line_size - 1] == '\n'))
            line_size--;
        linebuf[line_size] = 0;

        // Check line length
        if (!do_truncate && line_size > MAX_LINESZ) {
            // if (dialog_confirm("Error", "Line longer than 254 characters. Truncate long lines?") <= 0) {
            //     reset_state();
            //     break;
            // }
            do_truncate = true;
        }

        line_size = min(line_size, MAX_LINESZ);

        editbuf_insert_line(&state.editbuf, line, linebuf, line_size);
        line++;
    }

    fclose(f);
    free(linebuf);
    return 0;
}

int main(int argc, const char **argv) {
    const char *filename = NULL;

    if (argc == 2) {
        filename = argv[1];
    } else {
        filename = "../test/test.bas";
    }
    if (load_file(filename) < 0)
        return 1;

    printf("Loaded %s: %u lines\n", state.filename, editbuf_get_line_count(&state.editbuf));

    int result = basic_run(&state.editbuf);
    if (result != 0) {
        puts(basic_get_error_str(result));
        exit(1);
    } else {
        printf("Program finished.\n");
    }
    return 0;
}
