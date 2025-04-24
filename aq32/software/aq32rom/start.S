    .section ".text.init"
    .global reset_handler
reset_handler:
    // Initialize GP
.option push
.option norelax
    la      gp, __global_pointer$
.option pop

    // Initialize SP
    la      sp, __ram_end
    la      t0, _start
    jr      t0
