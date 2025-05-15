#pragma once

#include "common.h"
#include "common/buffers.h"
#include "basic.h"
#include <math.h>

// Stack values
enum {
    VT_LONG,
    VT_SINGLE,
    VT_DOUBLE,
    VT_STR,
};

#define STR_FLAGS_TYPE_MSK   (3 << 0)
#define STR_FLAGS_TYPE_CONST (1 << 0)
#define STR_FLAGS_TYPE_VAR   (2 << 0)
#define STR_FLAGS_TYPE_TEMP  (3 << 0)

typedef struct {
    uint8_t type;
    union {
        int32_t val_long;
        int64_t val_longlong; // Only used to assign to val_double
        float   val_single;
        double  val_double;

        struct {
            uint8_t  flags;
            uint16_t length;
            uint8_t *p;
        } val_str;
    };
} value_t;

void bc_to_long_round(value_t *val);
void bc_to_single(value_t *val);
void bc_to_double(value_t *val);
void bc_promote_type(value_t *val, unsigned type);
void bc_promote_types(value_t *val_l, value_t *val_r);
void bc_promote_types_flt(value_t *val_l, value_t *val_r);

// Stack manipulation
#define STACK_DEPTH 64

extern const uint8_t *bc_p_buf;
extern const uint8_t *bc_p_cur;
extern value_t        bc_stack[STACK_DEPTH];
extern int            bc_stack_idx;

static inline value_t *bc_stack_push(void) {
    if (bc_stack_idx == 0)
        _basic_error(ERR_FORMULA_TOO_COMPLEX);
    return &bc_stack[--bc_stack_idx];
}
static inline value_t *bc_stack_pop(void) {
    if (bc_stack_idx >= STACK_DEPTH)
        _basic_error(ERR_INTERNAL_ERROR);
    return &bc_stack[bc_stack_idx++];
}
static inline value_t *bc_stack_pop_num(void) {
    if (bc_stack_idx >= STACK_DEPTH)
        _basic_error(ERR_INTERNAL_ERROR);
    value_t *stk = &bc_stack[bc_stack_idx++];
    if (stk->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);
    return stk;
}
static inline int32_t bc_stack_pop_long(void) {
    value_t *stk = bc_stack_pop_num();
    bc_to_long_round(stk);
    return stk->val_long;
}
static inline value_t *bc_stack_pop_str(void) {
    if (bc_stack_idx >= STACK_DEPTH)
        _basic_error(ERR_INTERNAL_ERROR);
    value_t *stk = &bc_stack[bc_stack_idx++];
    if (stk->type != VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);
    return stk;
}
static inline void bc_stack_push_bool(bool val) {
    value_t *stk  = bc_stack_push();
    stk->type     = VT_LONG;
    stk->val_long = val ? -1 : 0;
}
static inline void bc_stack_push_long(int32_t val) {
    value_t *stk  = bc_stack_push();
    stk->type     = VT_LONG;
    stk->val_long = val;
}
static inline void bc_stack_push_single(float val) {
    value_t *stk    = bc_stack_push();
    stk->type       = VT_SINGLE;
    stk->val_single = val;
}
static inline void bc_stack_push_double(double val) {
    value_t *stk    = bc_stack_push();
    stk->type       = VT_DOUBLE;
    stk->val_double = val;
}

value_t *bc_stack_push_temp_str(unsigned length);
void     bc_free_temp_val(value_t *val);

static inline uint8_t bc_get_u8(void) {
    return *(bc_p_cur++);
}
static inline uint16_t bc_get_u16(void) {
    uint16_t result = read_u16(bc_p_cur);
    bc_p_cur += 2;
    return result;
}
static inline uint32_t bc_get_u32(void) {
    uint32_t result = read_u32(bc_p_cur);
    bc_p_cur += 4;
    return result;
}
static inline uint64_t bc_get_u64(void) {
    uint64_t result = read_u32(bc_p_cur);
    bc_p_cur += 8;
    return result;
}

// Handlers
void bc_end(void);
void bc_line_tag(void);
void bc_dup(void);
void bc_data(void);
void bc_data_read(void);
void bc_data_restore(void);
void bc_push_const_int(void);
void bc_push_const_long(void);
void bc_push_const_single(void);
void bc_push_const_double(void);
void bc_push_const_string(void);
void bc_push_var_int(void);
void bc_push_var_long(void);
void bc_push_var_single(void);
void bc_push_var_double(void);
void bc_push_var_string(void);
void bc_store_var_int(void);
void bc_store_var_long(void);
void bc_store_var_single(void);
void bc_store_var_double(void);
void bc_store_var_string(void);
void bc_jmp(void);
void bc_jmp_nz(void);
void bc_jmp_z(void);
void bc_jsr(void);

// Statement tokens
void bc_stmt_clear(void);
void bc_stmt_dim(void);
void bc_stmt_erase(void);
void bc_stmt_inputs(void);
void bc_stmt_on(void);
void bc_stmt_option(void);
void bc_stmt_return(void);
void bc_stmt_timer(void);

// Math operators
void bc_op_pow(void);
void bc_op_mult(void);
void bc_op_div(void);
void bc_op_intdiv(void);
void bc_op_mod(void);
void bc_op_add(void);
void bc_op_sub(void);
void bc_op_eq(void);
void bc_op_ne(void);
void bc_op_lt(void);
void bc_op_le(void);
void bc_op_gt(void);
void bc_op_ge(void);
void bc_op_not(void);
void bc_op_and(void);
void bc_op_or(void);
void bc_op_xor(void);
void bc_op_eqv(void);
void bc_op_imp(void);
void bc_op_negate(void);
void bc_op_inc(void);
void bc_op_le_ge(void);

void bc_func_abs(void);
void bc_func_atn(void);
void bc_func_tan(void);
void bc_func_cos(void);
void bc_func_sin(void);
void bc_func_sqr(void);
void bc_func_exp(void);
void bc_func_fix(void);
void bc_func_sgn(void);
void bc_func_log(void);
void bc_func_int(void);
void bc_func_rnd(void);

void bc_stmt_randomize(void);

// Type conversion
void bc_func_cint(void);
void bc_func_clng(void);
void bc_func_csng(void);
void bc_func_cdbl(void);

// String handling
void bc_func_len(void);
void bc_func_left_s(void);
void bc_func_right_s(void);
void bc_func_mid_s(void);
void bc_func_asc(void);
void bc_func_instr(void);
void bc_func_val(void);
void bc_func_string_s(void);
void bc_func_space_s(void);
void bc_func_str_s(void);
void bc_func_chr_s(void);
void bc_func_hex_s(void);
void bc_func_oct_s(void);

// Console I/O
void bc_func_inkey_s(void);
void bc_func_csrlin(void);
void bc_func_pos(void);

void bc_stmt_cls(void);
void bc_stmt_color(void);
void bc_stmt_input(void);
void bc_stmt_locate(void);
void bc_stmt_width(void);

void bc_print_val(void);
void bc_print_spc(void);
void bc_print_tab(void);
void bc_print_newline(void);

// Error handling
void bc_func_erl(void);
void bc_func_err(void);

void bc_stmt_error(void);
void bc_stmt_resume(void);

// File I/O
void bc_func_mki_s(void);
void bc_func_mkl_s(void);
void bc_func_mks_s(void);
void bc_func_mkd_s(void);
void bc_func_cvi(void);
void bc_func_cvl(void);
void bc_func_cvs(void);
void bc_func_cvd(void);
