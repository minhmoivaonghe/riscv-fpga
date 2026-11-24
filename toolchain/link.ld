ENTRY(_start)
SECTIONS {
    . = 0x0;                          /* code bắt đầu từ địa chỉ 0 (khớp PC reset) */
    .text   : { *(.text.init) *(.text*) }
    .rodata : { *(.rodata*) }
    .data   : { *(.data*) }
    .bss    : { *(.bss*) }
}
