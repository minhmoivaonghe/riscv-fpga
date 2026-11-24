# Mã khởi động: đặt stack pointer, gọi main, rồi dừng
.section .text.init
.globl _start
_start:
    li   sp, 0x60         # đỉnh stack, nằm trong RAM 104 byte
    call main             # giá trị trả về nằm ở a0
    ebreak                # dừng hẳn,nhận ebreak