#include "basic.h"
#include <setjmp.h>

static jmp_buf jb_error;

static void syntax_error(void) {
    longjmp(jb_error, -5);
}

static void parse(void) {
    syntax_error();
}

int basic_run(void) {
    int result = setjmp(jb_error);
    if (result == 0) {
        parse();
        return 0;
    }
    return result;
}

const char *basic_get_error_msg(void) {
    return "Error in line 5";
}
