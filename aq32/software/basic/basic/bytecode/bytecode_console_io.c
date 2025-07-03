#include "bytecode_internal.h"
#include "console.h"

static int print_filenr;

void bc_stmt_cls(void) {
    console_clear_screen();
}

void bc_stmt_color(void) {
    int color_border     = bc_stack_pop_long();
    int color_background = bc_stack_pop_long();
    int color_foreground = bc_stack_pop_long();

    if (color_border != INT32_MIN) {
        if (color_border < 0 || color_border > 15)
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_set_border_color(color_border);
    }

    if (color_background != INT32_MIN) {
        if (color_background < 0 || color_background > 15)
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_set_background_color(color_background);
    }

    if (color_foreground != INT32_MIN) {
        if (color_foreground < 0 || color_foreground > 15)
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_set_foreground_color(color_foreground);
    }
}

void bc_stmt_locate(void) {
    int cursor_on = bc_stack_pop_long();
    int column    = bc_stack_pop_long();
    int row       = bc_stack_pop_long();

    if (cursor_on != INT32_MIN) {
        if (cursor_on < 0 || cursor_on > 1)
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_show_cursor(cursor_on != 0);
    }

    if (column != INT32_MIN) {
        if (column < 1 || column > console_get_num_columns())
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_set_cursor_column(column - 1);
    }

    if (row != INT32_MIN) {
        if (row < 1 || row > console_get_num_rows())
            _basic_error(ERR_ILLEGAL_FUNC_CALL);
        console_set_cursor_row(row - 1);
    }
}

void bc_func_csrlin(void) {
    bc_stack_push_long(console_get_cursor_row() + 1);
}

void bc_func_pos(void) {
    bc_stack_push_long(console_get_cursor_column() + 1);
}

void bc_print_val(void) {
    stkval_t *val = bc_stack_pop();
    switch (val->type) {
        case VT_LONG: {
            char tmp[64];
            int  len = snprintf(tmp, sizeof(tmp), "%s%d ", val->val_long >= 0 ? " " : "", (int)val->val_long);

            if (print_filenr < 0) {
                console_puts(tmp);
            } else {
                file_io_write(print_filenr, tmp, len);
            }
            break;
        }
        case VT_SINGLE: {
            char tmp[64];
            int  len = snprintf(tmp, sizeof(tmp), "%s%.7g ", val->val_single >= 0 ? " " : "", (double)val->val_single);
            if (print_filenr < 0) {
                console_puts(tmp);
            } else {
                file_io_write(print_filenr, tmp, len);
            }
            break;
        }
        case VT_DOUBLE: {
            char tmp[64];
            int  len = snprintf(tmp, sizeof(tmp), "%s%.16lg ", val->val_double >= 0 ? " " : "", val->val_double);
            if (print_filenr < 0) {
                console_puts(tmp);
            } else {
                file_io_write(print_filenr, tmp, len);
            }
            break;
        }
        case VT_STR: {
            const uint8_t *p = val->val_str.p;
            if (print_filenr < 0) {
                const uint8_t *p_end = p + val->val_str.length;
                while (p < p_end)
                    console_putc(*(p++));
            } else {
                file_io_write(print_filenr, p, val->val_str.length);
            }
            bc_free_temp_val(val);
            break;
        }
    }
}

void bc_print_spc(void) {
    int val = bc_stack_pop_long();
    if (print_filenr < 0) {
        for (int i = 0; i < val; i++)
            console_putc(' ');
    } else {
        for (int i = 0; i < val; i++)
            file_io_write(print_filenr, " ", 1);
    }
}

void bc_print_tab(void) {
    int val = bc_stack_pop_long();
    if (val < 1)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);
    val -= 1;

    if (print_filenr < 0) {
        val %= console_get_num_columns();
        while (console_get_cursor_column() != val)
            console_putc(' ');
    } else {
        while (file_io_get_column(print_filenr) != (unsigned)val)
            file_io_write(print_filenr, " ", 1);
    }
}

void bc_print_next_field(void) {
    if (print_filenr < 0) {
        int w = console_get_num_columns();
        while (1) {
            console_putc(' ');
            int column = console_get_cursor_column();
            if (column % 14 == 0 && column + 14 < w)
                break;
        }
    } else {
        while (1) {
            file_io_write(print_filenr, " ", 1);
            int column = file_io_get_column(print_filenr);
            if (column % 14 == 0)
                break;
        }
    }
}

void bc_print_newline(void) {
    if (print_filenr < 0) {
        console_puts("\r\n");
    } else {
        file_io_write(print_filenr, "\n", 1);
    }
}

void bc_print_to_file(void) {
    print_filenr = bc_stack_pop_long();
}

void bc_print_to_screen(void) {
    print_filenr = -1;
}

void bc_stmt_width(void) {
    int val = bc_stack_pop_long();
    if (!console_set_width(val))
        _basic_error(ERR_ILLEGAL_FUNC_CALL);
    console_set_width(val);
}

void bc_stmt_input(void) { _basic_error(ERR_UNHANDLED); }

void bc_func_inkey_s(void) {
    uint8_t ch = console_getc();
    if (ch == 0) {
        bc_stack_push_temp_str(0);
    } else {
        stkval_t *stk     = bc_stack_push_temp_str(1);
        stk->val_str.p[0] = ch;
    }
}
