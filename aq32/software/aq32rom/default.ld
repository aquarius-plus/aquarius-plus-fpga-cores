MEMORY {
    ram (rwx) : ORIGIN = 0x80000, LENGTH = 0x80000  /* 512k */
}

PROVIDE(__ram_end = ORIGIN(ram) + LENGTH(ram));

ENTRY(reset_handler)

SECTIONS {
    .text : {
        *(.text.init)
        *(.text.unlikely .text.unlikely.*)
        *(.text.startup .text.startup.*)
        *(.text .text.*)
        *(.gnu.linkonce.t.*)
    } > ram

    .preinit_array : ALIGN(8) {
        PROVIDE_HIDDEN(__preinit_array_start = .);
        KEEP (*(.preinit_array))
        PROVIDE_HIDDEN(__preinit_array_end = .);
    } > ram

    .init_array : ALIGN(8) {
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.init_array.*) SORT_BY_INIT_PRIORITY(.ctors.*)))
        KEEP (*(.init_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .ctors))
        PROVIDE_HIDDEN(__init_array_end = .);
        PROVIDE_HIDDEN( metal_constructors_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.metal.init_array.*)));
        KEEP (*(.metal.init_array));
        PROVIDE_HIDDEN( metal_constructors_end = .);
    } > ram

    .fini_array : ALIGN(8) {
        PROVIDE_HIDDEN(__fini_array_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.fini_array.*) SORT_BY_INIT_PRIORITY(.dtors.*)))
        KEEP (*(.fini_array EXCLUDE_FILE (*crtbegin.o *crtbegin?.o *crtend.o *crtend?.o ) .dtors))
        PROVIDE_HIDDEN(__fini_array_end = .);
        PROVIDE_HIDDEN( metal_destructors_start = .);
        KEEP (*(SORT_BY_INIT_PRIORITY(.metal.fini_array.*)));
        KEEP (*(.metal.fini_array));
        PROVIDE_HIDDEN( metal_destructors_end = .);
    } > ram

    .ctors : {
        KEEP (*crtbegin.o(.ctors))
        KEEP (*crtbegin?.o(.ctors))
        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .ctors))
        KEEP (*(SORT(.ctors.*)))
        KEEP (*(.ctors))
        KEEP (*(.metal.ctors .metal.ctors.*))
    } > ram

    .dtors : {
        KEEP (*crtbegin.o(.dtors))
        KEEP (*crtbegin?.o(.dtors))
        KEEP (*(EXCLUDE_FILE (*crtend.o *crtend?.o ) .dtors))
        KEEP (*(SORT(.dtors.*)))
        KEEP (*(.dtors))
        KEEP (*(.metal.dtors .metal.dtors.*))
    } > ram

    .rodata : ALIGN(8) {
        *(.rdata)
        *(.rodata)
        *(.rodata.*)
        *(.gnu.linkonce.r.*)
        *(.srodata.*)
    } > ram

    .data : ALIGN(8) {
        *(.data .data.*)
        *(.gnu.linkonce.d.*)
        . = ALIGN(8);
        PROVIDE( __global_pointer$ = . + 0x800 );
        *(.sdata .sdata.* .sdata2.*)
        *(.gnu.linkonce.s.*)
    } > ram

    .tdata : ALIGN(8) {
        PROVIDE( __tls_base = . );
	    *(.tdata .tdata.* .gnu.linkonce.td.*)
    } > ram

    .bss : ALIGN(8) {
        *(.sbss*)
        *(.gnu.linkonce.sb.*)
        *(.bss .bss.*)
        *(.gnu.linkonce.b.*)
        *(COMMON)
    } > ram

    PROVIDE(_bss_source_start = LOADADDR(.bss));
    PROVIDE(_bss_target_start = ADDR(.bss));
    PROVIDE(_bss_target_end   = ADDR(.bss) + SIZEOF(.bss));

    . = ALIGN(8);
    end = . ;
    _end = . ;
}
