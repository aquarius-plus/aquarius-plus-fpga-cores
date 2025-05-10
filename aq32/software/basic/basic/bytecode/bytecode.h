#pragma once

#include "common.h"

int  bytecode_get_line_for_offset(const uint8_t *buf, size_t buf_size, uint16_t offset);
void bytecode_dump(void);
void bytecode_run(void);

enum {
    BC_UNDEFINED = 0,
    BC_END,
    BC_LINE_TAG,

    BC_DUP,
    BC_OP_INC,
    BC_OP_LE_GE, // Used in for loop with step, takes 3 params: step/var/end
    BC_DATA_START,
    BC_DATA_END,
    BC_DATA_READ,
    BC_DATA_RESTORE,

    BC_PUSH_CONST_INT,
    BC_PUSH_CONST_LONG,
    BC_PUSH_CONST_SINGLE,
    BC_PUSH_CONST_DOUBLE,
    BC_PUSH_CONST_STRING,

    BC_PUSH_VAR_INT,
    BC_PUSH_VAR_LONG,
    BC_PUSH_VAR_SINGLE,
    BC_PUSH_VAR_DOUBLE,
    BC_PUSH_VAR_STRING,

    BC_STORE_VAR_INT,
    BC_STORE_VAR_LONG,
    BC_STORE_VAR_SINGLE,
    BC_STORE_VAR_DOUBLE,
    BC_STORE_VAR_STRING,

    BC_JMP,
    BC_JMP_NZ,
    BC_JMP_Z,
    BC_JSR,

    BC_PRINT_VAL,
    BC_PRINT_SPC,
    BC_PRINT_TAB,
    BC_PRINT_NEWLINE,

    // Keep in same order as operator tokens (tokenizer.h)
    BC_OP_POW, // TOK_POW
    BC_OP_FIRST = BC_OP_POW,
    BC_OP_MULT,   // TOK_MULT
    BC_OP_DIV,    // TOK_DIV
    BC_OP_INTDIV, // TOK_INTDIV
    BC_OP_MOD,    // TOK_MOD
    BC_OP_ADD,    // TOK_PLUS
    BC_OP_SUB,    // TOK_MINUS
    BC_OP_EQ,     // TOK_EQ
    BC_OP_NE,     // TOK_NE
    BC_OP_LT,     // TOK_LT
    BC_OP_LE,     // TOK_LE
    BC_OP_GT,     // TOK_GT
    BC_OP_GE,     // TOK_GE
    BC_OP_NOT,    // TOK_NOT
    BC_OP_AND,    // TOK_AND
    BC_OP_OR,     // TOK_OR
    BC_OP_XOR,    // TOK_XOR
    BC_OP_EQV,    // TOK_EQV
    BC_OP_IMP,    // TOK_IMP
    BC_OP_NEGATE,

    // Statement tokens (tokenizer.h)
    BC_STMT_CLEAR,
    BC_STMT_CLS,
    BC_STMT_COLOR,
    BC_STMT_DIM,
    BC_STMT_ERASE,
    BC_STMT_ERROR,
    BC_STMT_INPUT,
    BC_STMT_INPUTs,
    BC_STMT_LOCATE,
    BC_STMT_ON,
    BC_STMT_OPTION,
    BC_STMT_RANDOMIZE,
    BC_STMT_RESUME,
    BC_STMT_RETURN,
    BC_STMT_SWAP,
    BC_STMT_TIMER,
    BC_STMT_WIDTH,

    // Keep in same order as function tokens (tokenizer.h)
    BC_FUNC_ABS,
    BC_FUNC_FIRST = BC_FUNC_ABS,
    BC_FUNC_ASC,
    BC_FUNC_ATN,
    BC_FUNC_CDBL,
    BC_FUNC_CHRs, // CHR$
    BC_FUNC_CINT,
    BC_FUNC_CLNG,
    BC_FUNC_COS,
    BC_FUNC_CSNG,
    BC_FUNC_CSRLIN,
    BC_FUNC_CVD,
    BC_FUNC_CVI,
    BC_FUNC_CVL,
    BC_FUNC_CVS,
    BC_FUNC_ERL,
    BC_FUNC_ERR,
    BC_FUNC_EXP,
    BC_FUNC_FIX,
    BC_FUNC_HEXs,   // HEX$
    BC_FUNC_INKEYs, // INKEY$
    BC_FUNC_INSTR,
    BC_FUNC_INT,
    BC_FUNC_LEFTs, // LEFT$
    BC_FUNC_LEN,
    BC_FUNC_LOG,
    BC_FUNC_MIDs, // MID$
    BC_FUNC_MKDs, // MKD$
    BC_FUNC_MKIs, // MKI$
    BC_FUNC_MKLs, // MKL$
    BC_FUNC_MKSs, // MKS$
    BC_FUNC_OCTs, // OCT$
    BC_FUNC_POS,
    BC_FUNC_RIGHTs, // RIGHT$
    BC_FUNC_RND,
    BC_FUNC_SGN,
    BC_FUNC_SIN,
    BC_FUNC_SPACEs, // SPACE$
    BC_FUNC_SQR,
    BC_FUNC_STRINGs, // STRING$
    BC_FUNC_STRs,    // STR$
    BC_FUNC_TAN,
    BC_FUNC_VAL,
};
