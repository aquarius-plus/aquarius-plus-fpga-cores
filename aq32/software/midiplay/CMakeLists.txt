cmake_minimum_required(VERSION 3.13)

project(midiplay VERSION 0.1 LANGUAGES C CXX ASM)

include(../lib/project.cmake)

target_compile_definitions(${PROJECT_NAME} PRIVATE SIZE_BUF_HEAP=131072)

target_sources(${PROJECT_NAME} PRIVATE
    main.c
    fmsynth.c
    playfile.c
)
