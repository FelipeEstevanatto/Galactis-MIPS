.data
.eqv COLOR_BLACK 0x000000
.text

.macro clearScreen
clearScreen:
    li   $t0, COLOR_BLACK
    move $t1, $s0           # dst = bitmap base
    li   $t2, 16384         # 128*128 pixels
clearScreen_loop:
    sw   $t0, 0($t1)
    addiu $t1, $t1, 4
    addiu $t2, $t2, -1
    bnez $t2, clearScreen_loop
    nop
.end_macro
