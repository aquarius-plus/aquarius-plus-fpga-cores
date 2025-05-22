#include "bytecode_internal.h"

void bc_push_var_int(void) {
    bc_stack_push_long((int16_t)read_u16(&bc_state.p_vars[bc_get_u16()]));
}

void bc_push_var_long(void) {
    bc_stack_push_long(read_u32(&bc_state.p_vars[bc_get_u16()]));
}

void bc_push_var_single(void) {
    uint32_t u32 = read_u32(&bc_state.p_vars[bc_get_u16()]);
    bc_stack_push_single(*(float *)&u32);
}

void bc_push_var_double(void) {
    uint64_t u64 = read_u64(&bc_state.p_vars[bc_get_u16()]);
    bc_stack_push_double(*(double *)&u64);
}

void bc_push_var_string(void) {
    uint8_t *p = &bc_state.p_vars[bc_get_u16()];
    uint8_t *p_str;
    memcpy(&p_str, p, sizeof(uint8_t *));

    value_t *stk        = bc_stack_push();
    stk->type           = VT_STR;
    stk->val_str.flags  = STR_FLAGS_TYPE_VAR;
    stk->val_str.p      = (p_str == NULL) ? NULL : p_str + 2;
    stk->val_str.length = (p_str == NULL) ? 0 : read_u16(p_str);
}

void bc_store_var_int(void) {
    value_t *val = bc_stack_pop();
    bc_to_long_round(val);
    if (val->val_long < INT16_MIN || val->val_long >= INT16_MAX)
        _basic_error(ERR_OVERFLOW);
    write_u16(&bc_state.p_vars[bc_get_u16()], val->val_long);
}

void bc_store_var_long(void) {
    value_t *val = bc_stack_pop();
    bc_to_long_round(val);
    write_u32(&bc_state.p_vars[bc_get_u16()], val->val_long);
}

void bc_store_var_single(void) {
    value_t *val = bc_stack_pop();
    bc_to_single(val);
    write_u32(&bc_state.p_vars[bc_get_u16()], val->val_long);
}

void bc_store_var_double(void) {
    value_t *val = bc_stack_pop();
    bc_to_double(val);
    write_u64(&bc_state.p_vars[bc_get_u16()], val->val_longlong);
}

void bc_store_var_string(void) {
    value_t *stk = bc_stack_pop_str();
    uint8_t *p   = &bc_state.p_vars[bc_get_u16()];

    uint8_t *p_str;
    memcpy(&p_str, p, sizeof(uint8_t *));

    p_str = realloc(p_str, 2 + stk->val_str.length);
    if (p_str == NULL)
        _basic_error(ERR_OUT_OF_MEM);
    memcpy(p, &p_str, sizeof(uint8_t *));

    write_u16(p_str, stk->val_str.length);
    memcpy(p_str + 2, stk->val_str.p, stk->val_str.length);

    bc_free_temp_val(stk);
}

void bc_push_array_int(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_push_array_long(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_push_array_single(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_push_array_double(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_push_array_string(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_store_array_int(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_store_array_long(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_store_array_single(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_store_array_double(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_store_array_string(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_dim_array_int(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_dim_array_long(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_dim_array_single(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_dim_array_double(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_dim_array_string(void) {
    _basic_error(ERR_UNHANDLED);
}

void bc_free_array(void) {
    _basic_error(ERR_UNHANDLED);
}
