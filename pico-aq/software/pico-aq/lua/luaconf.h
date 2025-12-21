/*
** $Id: luaconf.h,v 1.176.1.2 2013/11/21 17:26:16 roberto Exp $
** Configuration file for Lua
** See Copyright Notice in lua.h
*/

#ifndef lconfig_h
#define lconfig_h

#include <limits.h>
#include <stddef.h>

/*
@@ LUA_ENV is the name of the variable that holds the current
@@ environment, used to access global names.
** CHANGE it if you do not like this name.
*/
#define LUA_ENV "_ENV"

#define LUA_API extern

/* more often than not the libs go together with the core */
#define LUALIB_API LUA_API
#define LUAMOD_API LUALIB_API

#define LUAI_FUNC extern
#define LUAI_DDEC extern
#define LUAI_DDEF /* empty */

/*
@@ LUA_QL describes how error messages quote program elements.
** CHANGE it if you want a different appearance.
*/
#define LUA_QL(x) "'" x "'"
#define LUA_QS    LUA_QL("%s")

/*
@@ LUA_IDSIZE gives the maximum size for the description of the source
@* of a function in debug information.
** CHANGE it if you want a different size.
*/
#define LUA_IDSIZE 60

/*
@@ luai_writestring/luai_writeline define how 'print' prints its results.
** They are only used in libraries and the stand-alone program. (The #if
** avoids including 'stdio.h' everywhere.)
*/
#if defined(LUA_LIB) || defined(lua_c)
#include <stdio.h>
#define luai_writestring(s, l) fwrite((s), sizeof(char), (l), stdout)
#define luai_writeline()       (luai_writestring("\n", 1), fflush(stdout))
#endif

/*
@@ luai_writestringerror defines how to print error messages.
** (A format string with one argument is enough for Lua...)
*/
#define luai_writestringerror(s, p) \
    (fprintf(stderr, (s), (p)), fflush(stderr))

/*
@@ LUAI_MAXSHORTLEN is the maximum length for short strings, that is,
** strings that are internalized. (Cannot be smaller than reserved words
** or tags for metamethods, as these strings must be internalized;
** #("function") = 8, #("__newindex") = 10.)
*/
#define LUAI_MAXSHORTLEN 40

/* }================================================================== */

/*
@@ LUAI_BITSINT defines the number of bits in an int.
** CHANGE here if Lua cannot automatically detect the number of bits of
** your machine. Probably you do not need to change this.
*/
/* avoid overflows in comparison */
#if INT_MAX - 20 < 32760 /* { */
#define LUAI_BITSINT 16
#elif INT_MAX > 2147483640L /* }{ */
/* int has at least 32 bits */
#define LUAI_BITSINT 32
#else /* }{ */
#error "you must define LUA_BITSINT with number of bits in an integer"
#endif /* } */

/*
@@ LUA_INT32 is a signed integer with exactly 32 bits.
@@ LUAI_UMEM is an unsigned integer big enough to count the total
@* memory used by Lua.
@@ LUAI_MEM is a signed integer big enough to count the total memory
@* used by Lua.
** CHANGE here if for some weird reason the default definitions are not
** good enough for your machine. Probably you do not need to change
** this.
*/
#if LUAI_BITSINT >= 32 /* { */
#define LUA_INT32 int
#define LUAI_UMEM size_t
#define LUAI_MEM  ptrdiff_t
#else /* }{ */
/* 16-bit ints */
#define LUA_INT32 long
#define LUAI_UMEM unsigned long
#define LUAI_MEM  long
#endif /* } */

/*
@@ LUAI_MAXSTACK limits the size of the Lua stack.
** CHANGE it if you need a different limit. This limit is arbitrary;
** its only purpose is to stop Lua from consuming unlimited stack
** space (and to reserve some numbers for pseudo-indices).
*/
#if LUAI_BITSINT >= 32
#define LUAI_MAXSTACK 1000000
#else
#define LUAI_MAXSTACK 15000
#endif

/* reserve some space for error handling */
#define LUAI_FIRSTPSEUDOIDX (-LUAI_MAXSTACK - 1000)

/*
@@ LUAL_BUFFERSIZE is the buffer size used by the lauxlib buffer system.
** CHANGE it if it uses too much C-stack space.
*/
#define LUAL_BUFFERSIZE BUFSIZ

/*
** {==================================================================
@@ LUA_NUMBER is the type of numbers in Lua.
** CHANGE the following definitions only if you want to build Lua
** with a number type different from double. You may also need to
** change lua_number2int & lua_number2integer.
** ===================================================================
*/

#define LUA_NUMBER_DOUBLE
#define LUA_NUMBER double

/*
@@ LUAI_UACNUMBER is the result of an 'usual argument conversion'
@* over a number.
*/
#define LUAI_UACNUMBER double

/*
@@ LUA_NUMBER_SCAN is the format for reading numbers.
@@ LUA_NUMBER_FMT is the format for writing numbers.
@@ lua_number2str converts a number to a string.
@@ LUAI_MAXNUMBER2STR is maximum size of previous conversion.
*/
#define LUA_NUMBER_SCAN      "%lf"
#define LUA_NUMBER_FMT       "%.14g"
#define lua_number2str(s, n) sprintf((s), LUA_NUMBER_FMT, (n))
#define LUAI_MAXNUMBER2STR   32 /* 16 digits, sign, point, and \0 */

/*
@@ l_mathop allows the addition of an 'l' or 'f' to all math operations
*/
#define l_mathop(x) (x)

/*
@@ lua_str2number converts a decimal numeric string to a number.
@@ lua_strx2number converts an hexadecimal numeric string to a number.
** In C99, 'strtod' does both conversions. C89, however, has no function
** to convert floating hexadecimal strings to numbers. For these
** systems, you can leave 'lua_strx2number' undefined and Lua will
** provide its own implementation.
*/
#define lua_str2number(s, p) strtod((s), (p))

#if defined(LUA_USE_STRTODHEX)
#define lua_strx2number(s, p) strtod((s), (p))
#endif

/*
@@ The luai_num* macros define the primitive operations over numbers.
*/

/* the following operations need the math library */
#if defined(lobject_c) || defined(lvm_c)
#include <math.h>
#define luai_nummod(L, a, b) ((a) - l_mathop(floor)((a) / (b)) * (b))
#define luai_numpow(L, a, b) (l_mathop(pow)(a, b))
#endif

/* these are quite standard operations */
#if defined(LUA_CORE)
#define luai_numadd(L, a, b) ((a) + (b))
#define luai_numsub(L, a, b) ((a) - (b))
#define luai_nummul(L, a, b) ((a) * (b))
#define luai_numdiv(L, a, b) ((a) / (b))
#define luai_numunm(L, a)    (-(a))
#define luai_numeq(a, b)     ((a) == (b))
#define luai_numlt(L, a, b)  ((a) < (b))
#define luai_numle(L, a, b)  ((a) <= (b))
#define luai_numisnan(L, a)  (!luai_numeq((a), (a)))
#endif

/*
@@ LUA_INTEGER is the integral type used by lua_pushinteger/lua_tointeger.
** CHANGE that if ptrdiff_t is not adequate on your machine. (On most
** machines, ptrdiff_t gives a good choice between int or long.)
*/
#define LUA_INTEGER ptrdiff_t

/*
@@ LUA_UNSIGNED is the integral type used by lua_pushunsigned/lua_tounsigned.
** It must have at least 32 bits.
*/
#define LUA_UNSIGNED unsigned LUA_INT32

#endif
