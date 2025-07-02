#include "bytecode_internal.h"
#include <errno.h>
#include <sys/stat.h>

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

static void check_errno_result(int result) {
    if (result >= 0)
        return;

    int baserr = ERR_INTERNAL_ERROR;

    switch (errno) {
        case ENOENT: baserr = ERR_FILE_NOT_FOUND; break;
        case ENFILE: baserr = ERR_TOO_MANY_FILES; break;
        case EINVAL: baserr = ERR_ILLEGAL_FUNC_CALL; break;
        case EEXIST: baserr = ERR_FILE_ALREADY_EXISTS; break;
        case EIO: baserr = ERR_DEVICE_IO_ERROR; break;
        case ENODEV: baserr = ERR_DEVICE_UNAVAILABLE; break;
        case ENOTEMPTY: baserr = ERR_PATH_FILE_ACCESS_ERROR; break;
        case EROFS: baserr = ERR_PERMISSION_DENIED; break;
    }
    _basic_error(baserr);
}

static void get_str(char *tmp, unsigned sizeof_tmp_size) {
    stkval_t stk = *bc_stack_pop_str();
    if (stk.val_str.length == 0 || stk.val_str.length + 1U > sizeof_tmp_size)
        _basic_error(ERR_ILLEGAL_FUNC_CALL);

    memcpy(tmp, stk.val_str.p, stk.val_str.length);
    tmp[stk.val_str.length] = 0;
}

void bc_stmt_chdir(void) {
    char tmp[256];
    get_str(tmp, sizeof(tmp));
    check_errno_result(chdir(tmp));
}

void bc_stmt_mkdir(void) {
    char tmp[256];
    get_str(tmp, sizeof(tmp));
    check_errno_result(mkdir(tmp, 0777));
}

void bc_stmt_rmdir(void) {
    char tmp[256];
    get_str(tmp, sizeof(tmp));
    check_errno_result(rmdir(tmp));
}
