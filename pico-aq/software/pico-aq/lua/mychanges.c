#include "lua.h"
#include "lauxlib.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

int my_number2str(char *s, int32_t n) {
    int len = sprintf(s, "%.4f", (double)n / 65536.0);

    // Trim trailing zeros
    char *s2 = s + len;
    while (s2[-1] == '0')
        s2--;
    if (s2[-1] == '.')
        s2--;
    *s2 = 0;

    return s2 - s;
}

int32_t my_str2number(const char *s, char **endp) {
    return (int32_t)(strtod(s, endp) * 65536.0);
}

int32_t my_nummul(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a * (int64_t)b) >> 16LL);
}

int32_t my_numdiv(int32_t a, int32_t b) {
    return (int32_t)(((int64_t)a << 16LL) / (int64_t)b);
}

int32_t my_nummod(int32_t a, int32_t b) {
    return a - my_nummul(my_numdiv(a, b) & ~0xFFFF, b);
}

int32_t my_numpow(int32_t a, int32_t b) {
    double fa = (double)a / 65536.0;
    double fb = (double)b / 65536.0;
    return (int32_t)(pow(fa, fb) * 65536.0);
}