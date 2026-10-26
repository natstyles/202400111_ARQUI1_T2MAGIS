    .ifdef SIM
    .ifndef SIM_CHIP
    .set SIM_CHIP, 8
    .endif
    .ifndef SIM_FAULT
    .set SIM_FAULT, 0
    .endif
    .endif

    .equ    NO_PIN, 0xFF

    .macro print s, l
    mov     x0, #1
    ldr     x1, =\s
    mov     x2, #\l
    mov     x8, #64
    svc     #0
    .endm

    .macro getbit dst, off
    mov     \dst, #0
    ldrb    w2, [x17, #\off]
    cmp     w2, #NO_PIN
    b.eq    9f
    lsr     \dst, x12, x2
    and     \dst, \dst, #1
9:
    .endm

    .section .rodata
msg_prompt:
    .ascii  "ingrese el tipo de compuerta, solo los últimos dos dígitos\n"
    .equ    msg_prompt_len, . - msg_prompt
msg_invalid:
    .ascii  "Compuerta no valida, use 00, 08, 27 o 32\n"
    .equ    msg_invalid_len, . - msg_invalid
msg_ok:
    .ascii  "IC. OK\n"
    .equ    msg_ok_len, . - msg_ok
msg_mal:
    .ascii  "IC MAL\n"
    .equ    msg_mal_len, . - msg_mal
msg_gate_a:
    .ascii  "COMPUERTA "
    .equ    msg_gate_a_len, . - msg_gate_a
msg_gate_b:
    .ascii  " DAÑADA\n"
    .equ    msg_gate_b_len, . - msg_gate_b

    .balign 8
chip_table:
    .quad   0,  chip_7400
    .quad   8,  chip_7408
    .quad   27, chip_7427
    .quad   32, chip_7432
    .quad   -1, 0

chip_7400:
    .byte   1, 2, 4, 0
    .byte   9, 11, 10, NO_PIN
    .byte   6, 8, 7, NO_PIN
    .byte   5, 4, 3, NO_PIN
    .byte   2, 1, 0, NO_PIN
chip_7408:
    .byte   0, 2, 4, 0
    .byte   9, 11, 10, NO_PIN
    .byte   6, 8, 7, NO_PIN
    .byte   5, 4, 3, NO_PIN
    .byte   2, 1, 0, NO_PIN
chip_7432:
    .byte   2, 2, 4, 0
    .byte   9, 11, 10, NO_PIN
    .byte   6, 8, 7, NO_PIN
    .byte   5, 4, 3, NO_PIN
    .byte   2, 1, 0, NO_PIN
chip_7427:
    .byte   3, 3, 3, 0
    .byte   6, 9, 8, 7
    .byte   5, 4, 3, 2
    .byte   1, 11, 10, 0

    .bss
ch:         .skip 1
linebuf:    .skip 8
digit:      .skip 1

    .text
    .global _start

_start:
main_loop:
    print   msg_prompt, msg_prompt_len

    mov     x25, #0
rd_char:
    mov     x0, #0
    ldr     x1, =ch
    mov     x2, #1
    mov     x8, #63
    svc     #0
    cmp     x0, #1
    b.ne    salir
    ldr     x1, =ch
    ldrb    w3, [x1]
    cmp     w3, #'\n'
    b.eq    linea_lista
    cmp     w3, #'\r'
    b.eq    rd_char
    cmp     x25, #8
    b.hs    1f
    ldr     x4, =linebuf
    strb    w3, [x4, x25]
1:  add     x25, x25, #1
    b       rd_char

linea_lista:
    cmp     x25, #2
    b.ne    invalido
    ldr     x4, =linebuf
    ldrb    w5, [x4]
    ldrb    w6, [x4, #1]
    sub     w5, w5, #'0'
    sub     w6, w6, #'0'
    cmp     w5, #9
    b.hi    invalido
    cmp     w6, #9
    b.hi    invalido
    mov     w7, #10
    madd    w0, w5, w7, w6
    bl      find_chip
    cbz     x0, invalido
    mov     x19, x0
    ldrb    w21, [x19, #2]

    mov     x0, x19
    bl      test_chip
    mov     x20, x0

    cbz     x20, ic_ok
    mov     x1, #1
    lsl     x1, x1, x21
    sub     x1, x1, #1
    cmp     x20, x1
    b.eq    ic_mal

    mov     x22, #0
rep_gate:
    lsr     x1, x20, x22
    tbz     x1, #0, 2f
    print   msg_gate_a, msg_gate_a_len
    add     w1, w22, #'1'
    ldr     x2, =digit
    strb    w1, [x2]
    mov     x0, #1
    mov     x1, x2
    mov     x2, #1
    mov     x8, #64
    svc     #0
    print   msg_gate_b, msg_gate_b_len
2:  add     x22, x22, #1
    cmp     x22, x21
    b.lo    rep_gate
    b       main_loop

ic_ok:
    print   msg_ok, msg_ok_len
    b       main_loop
ic_mal:
    print   msg_mal, msg_mal_len
    b       main_loop
invalido:
    print   msg_invalid, msg_invalid_len
    b       main_loop
salir:
    mov     x0, #0
    mov     x8, #93
    svc     #0

find_chip:
    ldr     x1, =chip_table
1:  ldr     x2, [x1]
    cmn     x2, #1
    b.eq    2f
    cmp     x2, x0
    b.eq    3f
    add     x1, x1, #16
    b       1b
2:  mov     x0, #0
    ret
3:  ldr     x0, [x1, #8]
    ret

eval_op:
    and     x8, x4, x5
    orr     x9, x4, x5
    orr     x9, x9, x6
    tst     w7, #2
    csel    x8, x9, x8, ne
    and     x10, x7, #1
    eor     x8, x8, x10
    ret

test_chip:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x19, x0
    ldrb    w20, [x19, #1]
    mov     x21, #1
    lsl     x21, x21, x20
    ldrb    w24, [x19, #2]
    mov     x22, #0
    mov     x23, #0
vec_loop:
    mov     x0, #0
    add     x1, x19, #4
    mov     x2, x24
1:  mov     x3, #0
2:  add     x4, x1, x3
    ldrb    w5, [x4, #1]
    cmp     w5, #NO_PIN
    b.eq    3f
    lsr     x6, x23, x3
    tbz     x6, #0, 3f
    mov     x7, #1
    lsl     x7, x7, x5
    orr     x0, x0, x7
3:  add     x3, x3, #1
    cmp     x3, #3
    b.lo    2b
    add     x1, x1, #4
    subs    x2, x2, #1
    b.ne    1b

    bl      hw_io

    ldrb    w7, [x19]
    and     x4, x23, #1
    ubfx    x5, x23, #1, #1
    ubfx    x6, x23, #2, #1
    bl      eval_op
    add     x1, x19, #4
    mov     x2, #0
chk:
    ldrb    w3, [x1]
    lsr     x3, x0, x3
    and     x3, x3, #1
    cmp     x3, x8
    b.eq    4f
    mov     x10, #1
    lsl     x10, x10, x2
    orr     x22, x22, x10
4:  add     x1, x1, #4
    add     x2, x2, #1
    cmp     x2, x24
    b.lo    chk
    add     x23, x23, #1
    cmp     x23, x21
    b.lo    vec_loop

    mov     x0, x22
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret

hw_io:
    mrs     x9, cntfrq_el0
    mov     x10, #100
    udiv    x9, x9, x10
    mrs     x10, cntvct_el0
    add     x10, x10, x9
5:  mrs     x11, cntvct_el0
    cmp     x11, x10
    b.lo    5b

    .ifdef SIM
    mov     x14, x30
    mov     x12, x0
    mov     x0, #SIM_CHIP
    bl      find_chip
    mov     x13, x0
    mov     x0, x12
    ldrb    w7, [x13]
    ldrb    w15, [x13, #2]
    add     x17, x13, #4
    mov     x16, #0
sim_gate:
    getbit  x4, 1
    getbit  x5, 2
    getbit  x6, 3
    bl      eval_op
    ldr     x2, =SIM_FAULT
    lsr     x2, x2, x16
    and     x2, x2, #1
    eor     x8, x8, x2
    ldrb    w2, [x17]
    lsl     x8, x8, x2
    orr     x0, x0, x8
    add     x17, x17, #4
    add     x16, x16, #1
    cmp     x16, x15
    b.lo    sim_gate
    mov     x30, x14
    .endif
    ret
