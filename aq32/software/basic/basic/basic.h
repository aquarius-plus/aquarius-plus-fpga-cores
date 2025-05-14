#pragma once

#include "editor/editbuf.h"

enum {
    ERR_SYNTAX_ERROR         = 2,
    ERR_RETURN_WITHOUT_GOSUB = 3,
    ERR_ILLEGAL_FUNC_CALL    = 5,
    ERR_OVERFLOW             = 6,
    ERR_OUT_OF_MEM           = 7,
    ERR_LABEL_NOT_DEFINED    = 8,
    ERR_DIV_BY_ZERO          = 11,
    ERR_TYPE_MISMATCH        = 13,
    ERR_FORMULA_TOO_COMPLEX  = 16,
    ERR_FOR_WITHOUT_NEXT     = 26,
    ERR_WHILE_WITHOUT_WEND   = 29,
    ERR_DUPLICATE_LABEL      = 33,
    ERR_INTERNAL_ERROR       = 51,
    ERR_UNHANDLED            = 73,
};

int         basic_compile(struct editbuf *eb);
int         basic_run(void);
int         basic_get_error_line(void);
const char *basic_get_error_str(int err);

extern int err_line;

noreturn void _basic_error(int err);
