#include "bytecode.h"
#include "common/buffers.h"

static const char *bc_names[] = {
    [BC_END]                          = "END",
    [BC_LINE_TAG]                     = "LINE_TAG",
    [BC_DUP]                          = "DUP",
    [BC_SWAP]                         = "SWAP",
    [BC_PUSH_CONST_UNSPECIFIED_PARAM] = "PUSH_CONST_UNSPECIFIED_PARAM",
    [BC_OP_INC]                       = "OP_INC",
    [BC_OP_LE_GE]                     = "OP_LE_GE",
    [BC_DATA]                         = "DATA",
    [BC_DATA_READ]                    = "DATA_READ",
    [BC_DATA_RESTORE]                 = "DATA_RESTORE",
    [BC_PUSH_CONST_INT]               = "PUSH_CONST_INT",
    [BC_PUSH_CONST_LONG]              = "PUSH_CONST_LONG",
    [BC_PUSH_CONST_SINGLE]            = "PUSH_CONST_SINGLE",
    [BC_PUSH_CONST_DOUBLE]            = "PUSH_CONST_DOUBLE",
    [BC_PUSH_CONST_STRING]            = "PUSH_CONST_STRING",
    [BC_PUSH_VAR_INT]                 = "PUSH_VAR_INT",
    [BC_PUSH_VAR_LONG]                = "PUSH_VAR_LONG",
    [BC_PUSH_VAR_SINGLE]              = "PUSH_VAR_SINGLE",
    [BC_PUSH_VAR_DOUBLE]              = "PUSH_VAR_DOUBLE",
    [BC_PUSH_VAR_STRING]              = "PUSH_VAR_STRING",
    [BC_STORE_VAR_INT]                = "STORE_VAR_INT",
    [BC_STORE_VAR_LONG]               = "STORE_VAR_LONG",
    [BC_STORE_VAR_SINGLE]             = "STORE_VAR_SINGLE",
    [BC_STORE_VAR_DOUBLE]             = "STORE_VAR_DOUBLE",
    [BC_STORE_VAR_STRING]             = "STORE_VAR_STRING",
    [BC_JMP]                          = "JMP",
    [BC_JMP_NZ]                       = "JMP_NZ",
    [BC_JMP_Z]                        = "JMP_Z",
    [BC_JSR]                          = "JSR",
    [BC_PRINT_VAL]                    = "PRINT_VAL",
    [BC_PRINT_SPC]                    = "PRINT_SPC",
    [BC_PRINT_TAB]                    = "PRINT_TAB",
    [BC_PRINT_NEWLINE]                = "PRINT_NEWLINE",
    [BC_OP_POW]                       = "OP_POW",
    [BC_OP_MULT]                      = "OP_MULT",
    [BC_OP_DIV]                       = "OP_DIV",
    [BC_OP_INTDIV]                    = "OP_INTDIV",
    [BC_OP_MOD]                       = "OP_MOD",
    [BC_OP_ADD]                       = "OP_ADD",
    [BC_OP_SUB]                       = "OP_SUB",
    [BC_OP_EQ]                        = "OP_EQ",
    [BC_OP_NE]                        = "OP_NE",
    [BC_OP_LT]                        = "OP_LT",
    [BC_OP_LE]                        = "OP_LE",
    [BC_OP_GT]                        = "OP_GT",
    [BC_OP_GE]                        = "OP_GE",
    [BC_OP_NOT]                       = "OP_NOT",
    [BC_OP_AND]                       = "OP_AND",
    [BC_OP_OR]                        = "OP_OR",
    [BC_OP_XOR]                       = "OP_XOR",
    [BC_OP_EQV]                       = "OP_EQV",
    [BC_OP_IMP]                       = "OP_IMP",
    [BC_OP_NEGATE]                    = "OP_NEGATE",
    [BC_STMT_CLEAR]                   = "STMT_CLEAR",
    [BC_STMT_CLS]                     = "STMT_CLS",
    [BC_STMT_COLOR]                   = "STMT_COLOR",
    [BC_STMT_DIM]                     = "STMT_DIM",
    [BC_STMT_ERASE]                   = "STMT_ERASE",
    [BC_STMT_ERROR]                   = "STMT_ERROR",
    [BC_STMT_INPUT]                   = "STMT_INPUT",
    [BC_STMT_INPUTs]                  = "STMT_INPUTs",
    [BC_STMT_LOCATE]                  = "STMT_LOCATE",
    [BC_STMT_ON]                      = "STMT_ON",
    [BC_STMT_OPTION]                  = "STMT_OPTION",
    [BC_STMT_RANDOMIZE]               = "STMT_RANDOMIZE",
    [BC_STMT_RESUME]                  = "STMT_RESUME",
    [BC_STMT_RETURN]                  = "STMT_RETURN",
    [BC_STMT_RETURN_TO]               = "STMT_RETURN_TO",
    [BC_STMT_TIMER]                   = "STMT_TIMER",
    [BC_STMT_WIDTH]                   = "STMT_WIDTH",
    [BC_FUNC_ABS]                     = "FUNC_ABS",
    [BC_FUNC_ASC]                     = "FUNC_ASC",
    [BC_FUNC_ATN]                     = "FUNC_ATN",
    [BC_FUNC_CDBL]                    = "FUNC_CDBL",
    [BC_FUNC_CHRs]                    = "FUNC_CHRs",
    [BC_FUNC_CINT]                    = "FUNC_CINT",
    [BC_FUNC_CLNG]                    = "FUNC_CLNG",
    [BC_FUNC_COS]                     = "FUNC_COS",
    [BC_FUNC_CSNG]                    = "FUNC_CSNG",
    [BC_FUNC_CSRLIN]                  = "FUNC_CSRLIN",
    [BC_FUNC_CVD]                     = "FUNC_CVD",
    [BC_FUNC_CVI]                     = "FUNC_CVI",
    [BC_FUNC_CVL]                     = "FUNC_CVL",
    [BC_FUNC_CVS]                     = "FUNC_CVS",
    [BC_FUNC_ERL]                     = "FUNC_ERL",
    [BC_FUNC_ERR]                     = "FUNC_ERR",
    [BC_FUNC_EXP]                     = "FUNC_EXP",
    [BC_FUNC_FIX]                     = "FUNC_FIX",
    [BC_FUNC_HEXs]                    = "FUNC_HEXs",
    [BC_FUNC_INKEYs]                  = "FUNC_INKEYs",
    [BC_FUNC_INSTR]                   = "FUNC_INSTR",
    [BC_FUNC_INT]                     = "FUNC_INT",
    [BC_FUNC_LEFTs]                   = "FUNC_LEFTs",
    [BC_FUNC_LEN]                     = "FUNC_LEN",
    [BC_FUNC_LOG]                     = "FUNC_LOG",
    [BC_FUNC_MIDs]                    = "FUNC_MIDs",
    [BC_FUNC_MKDs]                    = "FUNC_MKDs",
    [BC_FUNC_MKIs]                    = "FUNC_MKIs",
    [BC_FUNC_MKLs]                    = "FUNC_MKLs",
    [BC_FUNC_MKSs]                    = "FUNC_MKSs",
    [BC_FUNC_OCTs]                    = "FUNC_OCTs",
    [BC_FUNC_POS]                     = "FUNC_POS",
    [BC_FUNC_RIGHTs]                  = "FUNC_RIGHTs",
    [BC_FUNC_RND]                     = "FUNC_RND",
    [BC_FUNC_SGN]                     = "FUNC_SGN",
    [BC_FUNC_SIN]                     = "FUNC_SIN",
    [BC_FUNC_SPACEs]                  = "FUNC_SPACEs",
    [BC_FUNC_SQR]                     = "FUNC_SQR",
    [BC_FUNC_STRINGs]                 = "FUNC_STRINGs",
    [BC_FUNC_STRs]                    = "FUNC_STRs",
    [BC_FUNC_TAN]                     = "FUNC_TAN",
    [BC_FUNC_VAL]                     = "FUNC_VAL",
};

void bytecode_dump(void) {
    const uint8_t *p = buf_bytecode;

    while (p < buf_bytecode_end) {
        uint8_t bc = *(p++);
        if (bc >= sizeof(bc_names) / sizeof(bc_names[0])) {
            printf("Byte code out of bounds! %02x\n", bc);
            exit(1);
        }

        printf("%5d %s%s", (int)(p - 1 - buf_bytecode), bc == BC_LINE_TAG ? "- " : "  - ", bc_names[bc]);

        switch (bc) {
            case BC_PUSH_CONST_INT: {
                printf(": %d", (int16_t)(p[0] | (p[1] << 8)));
                p += 2;
                break;
            }
            case BC_PUSH_CONST_LONG: {
                printf(": %d", (int)(int32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24)));
                p += 4;
                break;
            }
            case BC_PUSH_CONST_SINGLE: {
                uint32_t v = p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);
                p += 4;
                printf(": %g", (double)*(float *)&v);
                break;
            }
            case BC_PUSH_CONST_DOUBLE: {
                uint64_t v =
                    (uint64_t)p[0] |
                    ((uint64_t)p[1] << 8) |
                    ((uint64_t)p[2] << 16) |
                    ((uint64_t)p[3] << 24) |
                    ((uint64_t)p[4] << 32) |
                    ((uint64_t)p[5] << 40) |
                    ((uint64_t)p[6] << 48) |
                    ((uint64_t)p[7] << 56);
                p += 8;
                printf(": %lg", *(double *)&v);
                break;
            }
            case BC_PUSH_CONST_STRING: {
                printf(": \"%.*s\"", p[0], p + 1);
                p += 1 + p[0];
                break;
            }

            case BC_DATA:
            case BC_JMP:
            case BC_JMP_NZ:
            case BC_JMP_Z:
            case BC_JSR:
            case BC_STMT_RETURN_TO:
            case BC_PUSH_VAR_INT:
            case BC_PUSH_VAR_LONG:
            case BC_PUSH_VAR_SINGLE:
            case BC_PUSH_VAR_DOUBLE:
            case BC_PUSH_VAR_STRING:
            case BC_STORE_VAR_INT:
            case BC_STORE_VAR_LONG:
            case BC_STORE_VAR_SINGLE:
            case BC_STORE_VAR_DOUBLE:
            case BC_STORE_VAR_STRING: {
                printf(": %u", p[0] | (p[1] << 8));
                p += 2;
                break;
            }

            case BC_LINE_TAG: {
                printf(": %u", (p[0] | (p[1] << 8)) + 1);
                p += 2;
                break;
            }
        }

        printf("\n");
    }
}
