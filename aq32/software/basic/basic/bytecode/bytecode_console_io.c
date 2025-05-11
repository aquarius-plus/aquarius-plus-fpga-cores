#include "bytecode_internal.h"
#include "console.h"

void bc_stmt_cls(void) { _basic_error(ERR_UNHANDLED); }
void bc_stmt_color(void) { _basic_error(ERR_UNHANDLED); }
void bc_stmt_input(void) { _basic_error(ERR_UNHANDLED); }
void bc_stmt_locate(void) { _basic_error(ERR_UNHANDLED); }
void bc_stmt_width(void) { _basic_error(ERR_UNHANDLED); }
void bc_func_csrlin(void) { _basic_error(ERR_UNHANDLED); }
void bc_func_pos(void) { _basic_error(ERR_UNHANDLED); }
void bc_func_inkey_s(void) { _basic_error(ERR_UNHANDLED); }

void bc_print_val(void) {
    value_t *val = bc_stack_pop();
    switch (val->type) {
        case VT_LONG: printf("%s%d ", val->val_long >= 0 ? " " : "", (int)val->val_long); break;
        case VT_SINGLE: printf("%s%.7g ", val->val_single >= 0 ? " " : "", (double)val->val_single); break;
        case VT_DOUBLE: printf("%s%.16lg ", val->val_double >= 0 ? " " : "", val->val_double); break;
        case VT_STR: {
            printf("%.*s", val->val_str.length, val->val_str.p);
            // free_temp_val(&val);
            break;
        }
    }
}
void bc_print_spc(void) {
    value_t *val = bc_stack_pop();
    bc_to_long_round(val);

    for (int i = 0; i < val->val_long; i++)
        putchar(' ');
}
void bc_print_tab(void) {
    value_t *val = bc_stack_pop();
    bc_to_long_round(val);

    // Fixme
    for (int i = 0; i < val->val_long; i++)
        putchar(' ');
}
void bc_print_newline(void) {
    putchar('\n');
}
