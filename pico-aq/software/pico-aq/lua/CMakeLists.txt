cmake_minimum_required(VERSION 3.15)

project(lua
    VERSION 5.2.4
    DESCRIPTION "Lua"
    LANGUAGES C
)

add_executable(${CMAKE_PROJECT_NAME})

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE .)

target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    lapi.c
    lcode.c
    lctype.c
    ldebug.c
    ldo.c
    ldump.c
    lfunc.c
    lgc.c
    linit.c
    llex.c
    lmem.c
    lobject.c
    lopcodes.c
    lparser.c
    lstate.c
    lstring.c
    ltable.c
    ltm.c
    lua.c
    lundump.c
    lvm.c
    lzio.c

    lauxlib.c
    lbaselib.c
    lmathlib.c
    lstrlib.c
    ltablib.c
)


target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE m)
target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE -Wall -Wextra -Wpedantic -Wno-psabi -Wno-unused-parameter)
target_compile_options(${CMAKE_PROJECT_NAME} PRIVATE -fdata-sections -ffunction-sections)

target_link_options(${CMAKE_PROJECT_NAME} PRIVATE -Wl,--gc-sections -Wl,--print-gc-sections)

