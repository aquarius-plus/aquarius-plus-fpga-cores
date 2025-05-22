#include "bytecode_internal.h"

void bc_func_mki_s(void) {
    int32_t val = bc_stack_pop_long();
    if (val < INT16_MIN || val > INT16_MAX)
        _basic_error(ERR_OVERFLOW);

    int16_t   val16 = val;
    stkval_t *stk   = bc_stack_push_temp_str(2);
    memcpy(stk->val_str.p, &val16, 2);
}

void bc_func_mkl_s(void) {
    int32_t   val = bc_stack_pop_long();
    stkval_t *stk = bc_stack_push_temp_str(4);
    memcpy(stk->val_str.p, &val, 4);
}

void bc_func_mks_s(void) {
    stkval_t *stk = bc_stack_pop_num();
    bc_to_single(stk);
    float val = stk->val_single;

    stk = bc_stack_push_temp_str(4);
    memcpy(stk->val_str.p, &val, 4);
}

void bc_func_mkd_s(void) {
    stkval_t *stk = bc_stack_pop_num();
    bc_to_double(stk);
    double val = stk->val_double;

    stk = bc_stack_push_temp_str(8);
    memcpy(stk->val_str.p, &val, 8);
}

void bc_func_cvi(void) {
    stkval_t stk = *bc_stack_pop_str();
    if (stk.val_str.length < 2)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);

    int16_t val;
    memcpy(&val, stk.val_str.p, 2);
    bc_free_temp_val(&stk);
    bc_stack_push_long(val);
}

void bc_func_cvl(void) {
    stkval_t stk = *bc_stack_pop_str();
    if (stk.val_str.length < 4)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);

    int32_t val;
    memcpy(&val, stk.val_str.p, 4);
    bc_free_temp_val(&stk);
    bc_stack_push_long(val);
}

void bc_func_cvs(void) {
    stkval_t stk = *bc_stack_pop_str();
    if (stk.val_str.length < 4)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);

    float val;
    memcpy(&val, stk.val_str.p, 4);
    bc_free_temp_val(&stk);
    bc_stack_push_single(val);
}

void bc_func_cvd(void) {
    stkval_t stk = *bc_stack_pop_str();
    if (stk.val_str.length < 8)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);

    double val;
    memcpy(&val, stk.val_str.p, 8);
    bc_free_temp_val(&stk);
    bc_stack_push_double(val);
}
