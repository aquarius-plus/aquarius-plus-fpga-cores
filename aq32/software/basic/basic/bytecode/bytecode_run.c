#include "bytecode.h"
#include "../common/buffers.h"
#include "../basic.h"
#include <math.h>

typedef void (*bc_handler_t)(void);

enum {
    VT_LONG,
    VT_FLOAT,
    VT_DOUBLE,
    VT_STR,
    VT_VAR,
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
        float   val_float;
        double  val_double;

        struct {
            uint8_t  flags;
            uint16_t length;
            uint8_t *p;
        } val_str;
    };
} value_t;

#define STACK_DEPTH 64

static const uint8_t *p_buf;
static const uint8_t *p_cur;

static value_t stack[STACK_DEPTH];
static int     stack_idx;

static inline value_t *stack_push(void) {
    if (stack_idx == 0)
        _basic_error(ERR_FORMULA_TOO_COMPLEX);
    return &stack[--stack_idx];
}
static inline value_t *stack_pop(void) {
    if (stack_idx >= STACK_DEPTH)
        _basic_error(ERR_INTERNAL_ERROR);
    return &stack[stack_idx++];
}
static inline void stack_push_bool(bool val) {
    value_t *stk  = stack_push();
    stk->type     = VT_LONG;
    stk->val_long = val ? -1 : 0;
}
static inline void stack_push_long(int32_t val) {
    value_t *stk  = stack_push();
    stk->type     = VT_LONG;
    stk->val_long = val;
}
static inline void stack_push_float(float val) {
    value_t *stk   = stack_push();
    stk->type      = VT_FLOAT;
    stk->val_float = val;
}
static inline void stack_push_double(double val) {
    value_t *stk    = stack_push();
    stk->type       = VT_DOUBLE;
    stk->val_double = val;
}

static inline uint8_t bc_get_u8(void) {
    return *(p_cur++);
}
static inline uint16_t bc_get_u16(void) {
    uint16_t result = read_u16(p_cur);
    p_cur += 2;
    return result;
}
static inline uint32_t bc_get_u32(void) {
    uint32_t result = read_u32(p_cur);
    p_cur += 4;
    return result;
}
static inline uint64_t bc_get_u64(void) {
    uint64_t result = read_u32(p_cur);
    p_cur += 8;
    return result;
}

static void to_long_round(value_t *val) {
    if (val->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    if (val->type == VT_FLOAT) {
        val->type     = VT_LONG;
        val->val_long = (int32_t)roundf(val->val_float);
    } else if (val->type == VT_DOUBLE) {
        val->type     = VT_LONG;
        val->val_long = (int32_t)round(val->val_double);
    }
}
static void to_float(value_t *val) {
    if (val->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    if (val->type == VT_LONG) {
        val->type      = VT_FLOAT;
        val->val_float = val->val_long;
    } else if (val->type == VT_DOUBLE) {
        val->type      = VT_FLOAT;
        val->val_float = (float)val->val_double;
    }
}
static void to_double(value_t *val) {
    if (val->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    if (val->type == VT_LONG) {
        val->type       = VT_FLOAT;
        val->val_double = val->val_long;
    } else if (val->type == VT_FLOAT) {
        val->type       = VT_FLOAT;
        val->val_double = val->val_float;
    }
}
static void promote_type(value_t *val, unsigned type) {
    if (val->type >= type)
        return;

    if (val->type == VT_LONG) {
        if (type == VT_FLOAT) {
            val->val_float = val->val_long;
        } else if (type == VT_DOUBLE) {
            val->val_double = val->val_long;
        }
    } else if (val->type == VT_FLOAT) {
        val->val_double = val->val_float;
    }
    val->type = type;
}
static void promote_types(value_t *val_l, value_t *val_r) {
    if (val_l->type == VT_STR || val_r->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    if (val_r->type < val_l->type) {
        promote_type(val_r, val_l->type);
    } else if (val_l->type < val_r->type) {
        promote_type(val_l, val_r->type);
    }
}
static void promote_types_flt(value_t *val_l, value_t *val_r) {
    if (val_l->type == VT_STR || val_r->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    int type = val_l->type > val_r->type ? val_l->type : val_r->type;
    if (type < VT_FLOAT)
        type = VT_FLOAT;

    if (val_l->type < type)
        promote_type(val_l, type);
    if (val_r->type < type)
        promote_type(val_r, type);
}

static void bc_end(void) {
    _basic_error(0);
}
static void bc_line_tag(void) {
    err_line = p_cur[0] | (p_cur[1] << 8);
    p_cur += 2;
}
static void bc_dup(void) {
    if (stack_idx >= STACK_DEPTH)
        _basic_error(ERR_INTERNAL_ERROR);
    value_t *stk_from = &stack[stack_idx];
    value_t *stk_to   = stack_push();
    *stk_to           = *stk_from;
}
static void bc_op_inc(void) {
    value_t *val = stack_pop();
    if (val->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    switch (val->type) {
        case VT_LONG: stack_push_long(val->val_long + 1); break;
        case VT_FLOAT: stack_push_float(val->val_float + 1.0f); break;
        case VT_DOUBLE: stack_push_double(val->val_double + 1.0); break;
    }
}
static void bc_op_le_ge(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    bool is_neg = false;

    value_t *val_step = stack_pop();
    if (val_step->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);
    switch (val_step->type) {
        case VT_LONG: is_neg = val_step->val_long < 0; break;
        case VT_FLOAT: is_neg = val_step->val_float < 0.0f; break;
        case VT_DOUBLE: is_neg = val_step->val_double < 0.0; break;
    }

    if (is_neg) {
        switch (val_l->type) {
            case VT_LONG: stack_push_bool(val_l->val_long >= val_r->val_long); break;
            case VT_FLOAT: stack_push_bool(val_l->val_float >= val_r->val_float); break;
            case VT_DOUBLE: stack_push_bool(val_l->val_double >= val_r->val_double); break;
        }
    } else {
        switch (val_l->type) {
            case VT_LONG: stack_push_bool(val_l->val_long <= val_r->val_long); break;
            case VT_FLOAT: stack_push_bool(val_l->val_float <= val_r->val_float); break;
            case VT_DOUBLE: stack_push_bool(val_l->val_double <= val_r->val_double); break;
        }
    }
}
static void bc_data_start(void) { _basic_error(ERR_UNHANDLED); }
static void bc_data_end(void) { _basic_error(ERR_UNHANDLED); }
static void bc_data_read(void) { _basic_error(ERR_UNHANDLED); }
static void bc_data_restore(void) { _basic_error(ERR_UNHANDLED); }
static void bc_push_const_int(void) {
    stack_push_long((int16_t)bc_get_u16());
}
static void bc_push_const_long(void) {
    stack_push_long(bc_get_u32());
}
static void bc_push_const_single(void) {
    uint32_t u32 = bc_get_u32();
    stack_push_float(*(float *)&u32);
}
static void bc_push_const_double(void) {
    uint64_t u64 = bc_get_u64();
    stack_push_double(*(double *)&u64);
}
static void bc_push_const_string(void) {
    value_t *stk        = stack_push();
    stk->type           = VT_STR;
    stk->val_str.flags  = STR_FLAGS_TYPE_CONST;
    stk->val_str.p      = (uint8_t *)(p_cur + 1);
    stk->val_str.length = p_cur[0];
    p_cur += 1 + p_cur[0];
}
static void bc_push_var_int(void) {
    stack_push_long((int16_t)read_u16(&buf_variables[bc_get_u16()]));
}
static void bc_push_var_long(void) {
    stack_push_long(read_u32(&buf_variables[bc_get_u16()]));
}
static void bc_push_var_single(void) {
    uint32_t u32 = read_u32(&buf_variables[bc_get_u16()]);
    stack_push_float(*(float *)&u32);
}
static void bc_push_var_double(void) {
    uint64_t u64 = read_u64(&buf_variables[bc_get_u16()]);
    stack_push_double(*(double *)&u64);
}
static void bc_push_var_string(void) { _basic_error(ERR_UNHANDLED); }
static void bc_store_var_int(void) {
    value_t *val = stack_pop();
    to_long_round(val);
    if (val->val_long < INT16_MIN || val->val_long >= INT16_MAX)
        _basic_error(ERR_OVERFLOW);
    write_u16(&buf_variables[bc_get_u16()], val->val_long);
}
static void bc_store_var_long(void) {
    value_t *val = stack_pop();
    to_long_round(val);
    write_u32(&buf_variables[bc_get_u16()], val->val_long);
}
static void bc_store_var_single(void) {
    value_t *val = stack_pop();
    to_float(val);
    write_u32(&buf_variables[bc_get_u16()], val->val_long);
}
static void bc_store_var_double(void) {
    value_t *val = stack_pop();
    to_double(val);
    write_u64(&buf_variables[bc_get_u16()], val->val_longlong);
}
static void bc_store_var_string(void) { _basic_error(ERR_UNHANDLED); }
static void bc_jmp(void) {
    p_cur = p_buf + bc_get_u16();
}
static void bc_jmp_nz(void) {
    value_t *val = stack_pop();
    to_long_round(val);

    uint16_t offset = bc_get_u16();
    if (val->val_long != 0)
        p_cur = p_buf + offset;
}
static void bc_jmp_z(void) {
    value_t *val = stack_pop();
    to_long_round(val);

    uint16_t offset = bc_get_u16();
    if (val->val_long == 0)
        p_cur = p_buf + offset;
}
static void bc_jsr(void) { _basic_error(ERR_UNHANDLED); }
static void bc_print_val(void) {
    value_t *val = stack_pop();
    switch (val->type) {
        case VT_LONG: printf("%s%d ", val->val_long >= 0 ? " " : "", (int)val->val_long); break;
        case VT_FLOAT: printf("%s%.7g ", val->val_float >= 0 ? " " : "", (double)val->val_float); break;
        case VT_DOUBLE: printf("%s%.16lg ", val->val_double >= 0 ? " " : "", val->val_double); break;
        case VT_STR: {
            printf("%.*s", val->val_str.length, val->val_str.p);
            // free_temp_val(&val);
            break;
        }
    }
}
static void bc_print_spc(void) {
    value_t *val = stack_pop();
    to_long_round(val);

    for (int i = 0; i < val->val_long; i++)
        putchar(' ');
}
static void bc_print_tab(void) {
    value_t *val = stack_pop();
    to_long_round(val);

    // Fixme
    for (int i = 0; i < val->val_long; i++)
        putchar(' ');
}
static void bc_print_newline(void) {
    putchar('\n');
}
static void bc_op_pow(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types_flt(val_l, val_r);
    switch (val_l->type) {
        case VT_FLOAT: stack_push_float(powf(val_l->val_float, val_r->val_float)); break;
        case VT_DOUBLE: stack_push_double(pow(val_l->val_double, val_r->val_double)); break;
    }
}
static void bc_op_mult(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_long(val_l->val_long * val_r->val_long); break;
        case VT_FLOAT: stack_push_float(val_l->val_float * val_r->val_float); break;
        case VT_DOUBLE: stack_push_double(val_l->val_double * val_r->val_double); break;
    }
}
static void bc_op_div(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types_flt(val_l, val_r);
    switch (val_l->type) {
        case VT_FLOAT: stack_push_float(val_l->val_float / val_r->val_float); break;
        case VT_DOUBLE: stack_push_double(val_l->val_double / val_r->val_double); break;
    }
}
static void bc_op_intdiv(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    to_long_round(val_l);
    to_long_round(val_r);
    if (val_r->val_long == 0)
        _basic_error(ERR_DIV_BY_ZERO);

    stack_push_long(val_l->val_long / val_r->val_long);
}
static void bc_op_mod(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    to_long_round(val_l);
    to_long_round(val_r);
    if (val_r->val_long == 0)
        _basic_error(ERR_DIV_BY_ZERO);

    stack_push_long(val_l->val_long % val_r->val_long);
}
static void bc_op_add(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_long(val_l->val_long + val_r->val_long); break;
        case VT_FLOAT: stack_push_float(val_l->val_float + val_r->val_float); break;
        case VT_DOUBLE: stack_push_double(val_l->val_double + val_r->val_double); break;
    }
}
static void bc_op_sub(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_long(val_l->val_long - val_r->val_long); break;
        case VT_FLOAT: stack_push_float(val_l->val_float - val_r->val_float); break;
        case VT_DOUBLE: stack_push_double(val_l->val_double - val_r->val_double); break;
    }
}
static void bc_op_eq(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long == val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float == val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double == val_r->val_double); break;
    }
}
static void bc_op_ne(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long != val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float != val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double != val_r->val_double); break;
    }
}
static void bc_op_lt(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long < val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float < val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double < val_r->val_double); break;
    }
}
static void bc_op_le(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long <= val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float <= val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double <= val_r->val_double); break;
    }
}
static void bc_op_gt(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long > val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float > val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double > val_r->val_double); break;
    }
}
static void bc_op_ge(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    promote_types(val_l, val_r);

    switch (val_l->type) {
        case VT_LONG: stack_push_bool(val_l->val_long >= val_r->val_long); break;
        case VT_FLOAT: stack_push_bool(val_l->val_float >= val_r->val_float); break;
        case VT_DOUBLE: stack_push_bool(val_l->val_double >= val_r->val_double); break;
    }
}
static void bc_op_not(void) {
    value_t *val = stack_pop();
    to_long_round(val);
    stack_push_long(-(val->val_long + 1));
}
static void bc_op_and(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    to_long_round(val_l);
    to_long_round(val_r);
    stack_push_long(val_l->val_long & val_r->val_long);
}
static void bc_op_or(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    to_long_round(val_l);
    to_long_round(val_r);
    stack_push_long(val_l->val_long | val_r->val_long);
}
static void bc_op_xor(void) {
    value_t *val_r = stack_pop();
    value_t *val_l = stack_pop();
    to_long_round(val_l);
    to_long_round(val_r);
    stack_push_long(val_l->val_long ^ val_r->val_long);
}
static void bc_op_eqv(void) { _basic_error(ERR_UNHANDLED); }
static void bc_op_imp(void) { _basic_error(ERR_UNHANDLED); }
static void bc_op_negate(void) {
    value_t *val = stack_pop();
    if (val->type == VT_STR)
        _basic_error(ERR_TYPE_MISMATCH);

    switch (val->type) {
        case VT_LONG: stack_push_long(-val->val_long); break;
        case VT_FLOAT: stack_push_float(-val->val_float); break;
        case VT_DOUBLE: stack_push_double(-val->val_double); break;
    }
}
static void bc_stmt_clear(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_cls(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_color(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_dim(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_erase(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_error(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_input(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_inputs(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_locate(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_on(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_option(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_randomize(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_resume(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_return(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_swap(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_timer(void) { _basic_error(ERR_UNHANDLED); }
static void bc_stmt_width(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_abs(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_asc(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_atn(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cdbl(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_chr_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cint(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_clng(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cos(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_csng(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_csrlin(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cvd(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cvi(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cvl(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_cvs(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_erl(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_err(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_exp(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_fix(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_hex_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_inkey_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_instr(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_int(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_left_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_len(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_log(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_mid_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_mkd_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_mki_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_mkl_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_mks_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_oct_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_pos(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_right_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_rnd(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_sgn(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_sin(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_space_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_sqr(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_string_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_str_s(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_tan(void) { _basic_error(ERR_UNHANDLED); }
static void bc_func_val(void) { _basic_error(ERR_UNHANDLED); }

static bc_handler_t bc_handlers[] = {
    [BC_END]      = bc_end,
    [BC_LINE_TAG] = bc_line_tag,

    [BC_DUP]          = bc_dup,
    [BC_OP_INC]       = bc_op_inc,
    [BC_OP_LE_GE]     = bc_op_le_ge, // Used in for loop with step, takes 3 params: step/var/end
    [BC_DATA_START]   = bc_data_start,
    [BC_DATA_END]     = bc_data_end,
    [BC_DATA_READ]    = bc_data_read,
    [BC_DATA_RESTORE] = bc_data_restore,

    [BC_PUSH_CONST_INT]    = bc_push_const_int,
    [BC_PUSH_CONST_LONG]   = bc_push_const_long,
    [BC_PUSH_CONST_SINGLE] = bc_push_const_single,
    [BC_PUSH_CONST_DOUBLE] = bc_push_const_double,
    [BC_PUSH_CONST_STRING] = bc_push_const_string,

    [BC_PUSH_VAR_INT]    = bc_push_var_int,
    [BC_PUSH_VAR_LONG]   = bc_push_var_long,
    [BC_PUSH_VAR_SINGLE] = bc_push_var_single,
    [BC_PUSH_VAR_DOUBLE] = bc_push_var_double,
    [BC_PUSH_VAR_STRING] = bc_push_var_string,

    [BC_STORE_VAR_INT]    = bc_store_var_int,
    [BC_STORE_VAR_LONG]   = bc_store_var_long,
    [BC_STORE_VAR_SINGLE] = bc_store_var_single,
    [BC_STORE_VAR_DOUBLE] = bc_store_var_double,
    [BC_STORE_VAR_STRING] = bc_store_var_string,

    [BC_JMP]    = bc_jmp,
    [BC_JMP_NZ] = bc_jmp_nz,
    [BC_JMP_Z]  = bc_jmp_z,
    [BC_JSR]    = bc_jsr,

    [BC_PRINT_VAL]     = bc_print_val,
    [BC_PRINT_SPC]     = bc_print_spc,
    [BC_PRINT_TAB]     = bc_print_tab,
    [BC_PRINT_NEWLINE] = bc_print_newline,

    // Keep in same order as operator tokens (tokenizer.h)
    [BC_OP_POW]    = bc_op_pow,    // TOK_POW
    [BC_OP_MULT]   = bc_op_mult,   // TOK_MULT
    [BC_OP_DIV]    = bc_op_div,    // TOK_DIV
    [BC_OP_INTDIV] = bc_op_intdiv, // TOK_INTDIV
    [BC_OP_MOD]    = bc_op_mod,    // TOK_MOD
    [BC_OP_ADD]    = bc_op_add,    // TOK_PLUS
    [BC_OP_SUB]    = bc_op_sub,    // TOK_MINUS
    [BC_OP_EQ]     = bc_op_eq,     // TOK_EQ
    [BC_OP_NE]     = bc_op_ne,     // TOK_NE
    [BC_OP_LT]     = bc_op_lt,     // TOK_LT
    [BC_OP_LE]     = bc_op_le,     // TOK_LE
    [BC_OP_GT]     = bc_op_gt,     // TOK_GT
    [BC_OP_GE]     = bc_op_ge,     // TOK_GE
    [BC_OP_NOT]    = bc_op_not,    // TOK_NOT
    [BC_OP_AND]    = bc_op_and,    // TOK_AND
    [BC_OP_OR]     = bc_op_or,     // TOK_OR
    [BC_OP_XOR]    = bc_op_xor,    // TOK_XOR
    [BC_OP_EQV]    = bc_op_eqv,    // TOK_EQV
    [BC_OP_IMP]    = bc_op_imp,    // TOK_IMP
    [BC_OP_NEGATE] = bc_op_negate,

    // Statement tokens (tokenizer.h)
    [BC_STMT_CLEAR]     = bc_stmt_clear,
    [BC_STMT_CLS]       = bc_stmt_cls,
    [BC_STMT_COLOR]     = bc_stmt_color,
    [BC_STMT_DIM]       = bc_stmt_dim,
    [BC_STMT_ERASE]     = bc_stmt_erase,
    [BC_STMT_ERROR]     = bc_stmt_error,
    [BC_STMT_INPUT]     = bc_stmt_input,
    [BC_STMT_INPUTs]    = bc_stmt_inputs,
    [BC_STMT_LOCATE]    = bc_stmt_locate,
    [BC_STMT_ON]        = bc_stmt_on,
    [BC_STMT_OPTION]    = bc_stmt_option,
    [BC_STMT_RANDOMIZE] = bc_stmt_randomize,
    [BC_STMT_RESUME]    = bc_stmt_resume,
    [BC_STMT_RETURN]    = bc_stmt_return,
    [BC_STMT_SWAP]      = bc_stmt_swap,
    [BC_STMT_TIMER]     = bc_stmt_timer,
    [BC_STMT_WIDTH]     = bc_stmt_width,

    // Keep in same order as function tokens (tokenizer.h)
    [BC_FUNC_ABS]     = bc_func_abs,
    [BC_FUNC_ASC]     = bc_func_asc,
    [BC_FUNC_ATN]     = bc_func_atn,
    [BC_FUNC_CDBL]    = bc_func_cdbl,
    [BC_FUNC_CHRs]    = bc_func_chr_s, // CHR$
    [BC_FUNC_CINT]    = bc_func_cint,
    [BC_FUNC_CLNG]    = bc_func_clng,
    [BC_FUNC_COS]     = bc_func_cos,
    [BC_FUNC_CSNG]    = bc_func_csng,
    [BC_FUNC_CSRLIN]  = bc_func_csrlin,
    [BC_FUNC_CVD]     = bc_func_cvd,
    [BC_FUNC_CVI]     = bc_func_cvi,
    [BC_FUNC_CVL]     = bc_func_cvl,
    [BC_FUNC_CVS]     = bc_func_cvs,
    [BC_FUNC_ERL]     = bc_func_erl,
    [BC_FUNC_ERR]     = bc_func_err,
    [BC_FUNC_EXP]     = bc_func_exp,
    [BC_FUNC_FIX]     = bc_func_fix,
    [BC_FUNC_HEXs]    = bc_func_hex_s,   // HEX$
    [BC_FUNC_INKEYs]  = bc_func_inkey_s, // INKEY$
    [BC_FUNC_INSTR]   = bc_func_instr,
    [BC_FUNC_INT]     = bc_func_int,
    [BC_FUNC_LEFTs]   = bc_func_left_s, // LEFT$
    [BC_FUNC_LEN]     = bc_func_len,
    [BC_FUNC_LOG]     = bc_func_log,
    [BC_FUNC_MIDs]    = bc_func_mid_s, // MID$
    [BC_FUNC_MKDs]    = bc_func_mkd_s, // MKD$
    [BC_FUNC_MKIs]    = bc_func_mki_s, // MKI$
    [BC_FUNC_MKLs]    = bc_func_mkl_s, // MKL$
    [BC_FUNC_MKSs]    = bc_func_mks_s, // MKS$
    [BC_FUNC_OCTs]    = bc_func_oct_s, // OCT$
    [BC_FUNC_POS]     = bc_func_pos,
    [BC_FUNC_RIGHTs]  = bc_func_right_s, // RIGHT$
    [BC_FUNC_RND]     = bc_func_rnd,
    [BC_FUNC_SGN]     = bc_func_sgn,
    [BC_FUNC_SIN]     = bc_func_sin,
    [BC_FUNC_SPACEs]  = bc_func_space_s, // SPACE$
    [BC_FUNC_SQR]     = bc_func_sqr,
    [BC_FUNC_STRINGs] = bc_func_string_s, // STRING$
    [BC_FUNC_STRs]    = bc_func_str_s,    // STR$
    [BC_FUNC_TAN]     = bc_func_tan,
    [BC_FUNC_VAL]     = bc_func_val,
};

void bytecode_run(void) {
    memset(buf_variables, 0, buf_variables_size);

    p_buf     = buf_bytecode;
    p_cur     = p_buf;
    stack_idx = STACK_DEPTH;

    while (1) {
        uint8_t      bc      = bc_get_u8();
        bc_handler_t handler = bc_handlers[bc];
        handler();
    }
}
