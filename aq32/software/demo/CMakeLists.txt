cmake_minimum_required(VERSION 3.13)

project(demo VERSION 0.1 LANGUAGES C CXX ASM)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(EXECNAME demo)

set(APPLE FALSE)
set(CMAKE_C_COMPILER riscv-none-elf-gcc)
set(CMAKE_CXX_COMPILER riscv-none-elf-g++)
set(CMAKE_ASM_COMPILER riscv-none-elf-gcc)
set(CMAKE_C_STANDARD 17)

# Get git version
execute_process(
    COMMAND git describe --tags --always
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE BUILD_ID
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

##############################################################################
# Project files
##############################################################################
add_executable(${PROJECT_NAME})
set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "${EXECNAME}.elf")

add_custom_command(
    TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND riscv-none-elf-objcopy -O binary ${EXECNAME}.elf ${EXECNAME}.aq32
    COMMAND riscv-none-elf-objdump -d ${EXECNAME}.elf > dump.txt
    COMMAND riscv-none-elf-objdump -x ${EXECNAME}.elf > dump_x.txt
    COMMAND riscv-none-elf-objdump -t ${EXECNAME}.elf | expand -t36 | tail -n +5 | sort > dump_symbols.txt
    COMMAND riscv-none-elf-size -A ${EXECNAME}.elf
    # COMMAND riscv-none-elf-size -G ${EXECNAME}.elf
)

target_compile_options(${PROJECT_NAME} PRIVATE -Os -g)

target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra -Wshadow -Winit-self -Wfloat-conversion -Wdouble-promotion -Wmissing-include-dirs -Wlogical-op)
target_compile_options(${PROJECT_NAME} PRIVATE -Wno-unused-parameter -Wno-shadow)
target_compile_options(${PROJECT_NAME} PRIVATE -fdata-sections -ffunction-sections -fno-strict-aliasing)
target_compile_options(${PROJECT_NAME} PRIVATE -march=rv32im -mabi=ilp32 -ffreestanding -specs=nano.specs)

target_link_options(${PROJECT_NAME} PRIVATE -march=rv32im -mabi=ilp32 -ffreestanding -specs=nano.specs) # -u _printf_float)
target_link_options(${PROJECT_NAME} PRIVATE -nostartfiles)
target_link_options(${PROJECT_NAME} PRIVATE -Wl,--gc-sections)
target_link_options(${PROJECT_NAME} PRIVATE -Wl,--print-memory-usage)
target_link_options(${PROJECT_NAME} PRIVATE -Wl,-T${CMAKE_CURRENT_SOURCE_DIR}/default.ld)

target_include_directories(${PROJECT_NAME} PRIVATE
    .
    ../basic/lib
)

target_sources(${PROJECT_NAME} PRIVATE
    main.c

    ../basic/lib/start.S
    ../basic/lib/syscalls.c
    ../basic/lib/screen.c
    ../basic/lib/esp.c
    ../basic/lib/common.c
    ../basic/lib/malloc.c
)
