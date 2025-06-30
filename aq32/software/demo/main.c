#include "common.h"
#include "esp.h"
#include "csr.h"

extern const unsigned char samples_bin[];
extern const unsigned int  samples_bin_len;

uint64_t get_mcycle() {
    uint32_t h, l;
    while (1) {
        h = csr_read(mcycleh);
        l = csr_read(mcycle);
        if (h == csr_read(mcycleh))
            break;
    }

    return ((uint64_t)h << 32U) | (uint64_t)l;
}

int main(void) {
    while (1) {
        printf("%lu %lu\n", csr_read(time), csr_read(mcycle));
    }

    return 0;
}
