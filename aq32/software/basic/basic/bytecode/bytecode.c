#include "bytecode.h"
#include "../common/buffers.h"

int bytecode_get_line_for_offset(const uint8_t *buf, size_t buf_size, uint16_t offset) {
    const uint8_t *p        = buf;
    const uint8_t *p_end    = buf + buf_size;
    const uint8_t *p_offset = p + offset;
    uint16_t       linenr   = 0;

    while (p < p_end && p < p_offset) {
        uint8_t bc = *(p++);
        if (bc == BC_LINE_TAG) {
            linenr = p[0] | (p[1] << 8);
        }

        switch (bc) {
            case BC_PUSH_CONST_INT: p += 2; break;
            case BC_PUSH_CONST_LONG: p += 4; break;
            case BC_PUSH_CONST_SINGLE: p += 4; break;
            case BC_PUSH_CONST_DOUBLE: p += 8; break;
            case BC_PUSH_CONST_STRING: p += 1 + p[0]; break;

            case BC_JMP:
            case BC_JMP_NZ:
            case BC_JMP_Z:
            case BC_JSR:
            case BC_LINE_TAG:
            case BC_PUSH_VAR_INT:
            case BC_PUSH_VAR_LONG:
            case BC_PUSH_VAR_SINGLE:
            case BC_PUSH_VAR_DOUBLE:
            case BC_PUSH_VAR_STRING:
            case BC_STORE_VAR_INT:
            case BC_STORE_VAR_LONG:
            case BC_STORE_VAR_SINGLE:
            case BC_STORE_VAR_DOUBLE:
            case BC_STORE_VAR_STRING: p += 2; break;
        }
    }
    return linenr;
}
