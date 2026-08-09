# ForgeRV RV32I legal-instruction and pipeline self-test
.option norvc
.option nopic
.option norelax

.section .text
.globl _start
.align 2

.macro CHECK code
    addi x31, x0, \code
    bne x29, x30, failed
.endm

_start:
    # x0, LUI and AUIPC
    addi x0, x0, 123                  # every following use of x0 also checks that this write was ignored

    lui x29, 0x1
    addi x30, x0, 1
    slli x30, x30, 12
    CHECK 1

    auipc x1, 0
    auipc x29, 0
    addi x30, x1, 4
    CHECK 2

    # Register-register Arithmetic Logic Unit operations
    addi x1, x0, 10
    addi x2, x0, 20
    add x29, x1, x2
    addi x30, x0, 30
    CHECK 3

    sub x29, x2, x1
    addi x30, x0, 10
    CHECK 4

    addi x1, x0, 1
    addi x2, x0, 5
    sll x29, x1, x2
    addi x30, x0, 32
    CHECK 5

    addi x1, x0, -1
    addi x2, x0, 1
    slt x29, x1, x2
    addi x30, x0, 1
    CHECK 6

    sltu x29, x2, x1
    CHECK 7

    addi x1, x0, 0x55
    addi x2, x0, 0x0F
    xor x29, x1, x2
    addi x30, x0, 0x5A
    CHECK 8

    addi x1, x0, 1
    slli x1, x1, 31
    addi x2, x0, 31
    srl x29, x1, x2
    addi x30, x0, 1
    CHECK 9

    addi x1, x0, -16
    addi x2, x0, 2
    sra x29, x1, x2
    addi x30, x0, -4
    CHECK 10

    addi x1, x0, 0x50
    addi x2, x0, 0x0F
    or x29, x1, x2
    addi x30, x0, 0x5F
    CHECK 11

    and x29, x1, x2
    addi x30, x0, 0
    CHECK 12

    # Immediate Arithmetic Logic Unit operations
    addi x1, x0, 7
    addi x29, x1, -3
    addi x30, x0, 4
    CHECK 13

    addi x1, x0, 1
    slli x29, x1, 5
    addi x30, x0, 32
    CHECK 14

    addi x1, x0, -1
    slti x29, x1, 1
    addi x30, x0, 1
    CHECK 15

    sltiu x29, x1, 1
    addi x30, x0, 0
    CHECK 16

    addi x1, x0, 0x55
    xori x29, x1, 0x0F
    addi x30, x0, 0x5A
    CHECK 17

    addi x1, x0, 1
    slli x1, x1, 31
    srli x29, x1, 31
    addi x30, x0, 1
    CHECK 18

    addi x1, x0, -16
    srai x29, x1, 2
    addi x30, x0, -4
    CHECK 19

    addi x1, x0, 0x50
    ori x29, x1, 0x0F
    addi x30, x0, 0x5F
    CHECK 20

    andi x29, x1, 0x0F
    addi x30, x0, 0
    CHECK 21

    # Word, byte and halfword memory operations
    addi x1, x0, 128
    lui x30, 0x12345
    addi x30, x30, 0x678
    sw x30, 0(x1)
    lw x29, 0(x1)
    CHECK 22

    addi x2, x0, 0x11
    sb x2, 0(x1)
    addi x2, x0, 0x22
    sb x2, 1(x1)
    addi x2, x0, 0x33
    sb x2, 2(x1)
    addi x2, x0, 0x44
    sb x2, 3(x1)
    lw x29, 0(x1)
    lui x30, 0x44332
    addi x30, x30, 0x211
    CHECK 23

    addi x2, x0, 128
    sb x2, 0(x1)
    lb x29, 0(x1)
    addi x30, x0, -128
    CHECK 24

    lbu x29, 0(x1)
    addi x30, x0, 128
    CHECK 25

    lui x2, 0x1
    addi x2, x2, 0x122
    sh x2, 0(x1)
    lui x3, 0x3
    addi x3, x3, 0x344
    sh x3, 2(x1)
    lw x29, 0(x1)
    lui x30, 0x33441
    addi x30, x30, 0x122
    CHECK 26

    lui x2, 0x8
    addi x2, x2, 1
    sh x2, 0(x1)
    lh x29, 0(x1)
    lui x30, 0xFFFF8
    addi x30, x30, 1
    CHECK 27

    lhu x29, 0(x1)
    add x30, x2, x0
    CHECK 28

    # Forwarding and load-use hazard handling
    addi x1, x0, 5
    addi x2, x1, 7
    addi x29, x2, 1
    addi x30, x0, 13
    CHECK 29

    addi x1, x0, 10
    addi x2, x1, 5
    add x29, x2, x1
    addi x30, x0, 25
    CHECK 30

    addi x30, x0, 0x123
    sw x30, 192(x0)
    lw x29, 192(x0)
    CHECK 31

    lw x2, 192(x0)
    addi x29, x2, 1
    addi x30, x0, 0x124
    CHECK 32

    # Taken conditional branches
    addi x27, x0, 0
    addi x1, x0, 5
    addi x2, x0, 5
    beq x1, x2, beq_taken
    addi x27, x0, 33
beq_taken:

    addi x2, x0, 6
    bne x1, x2, bne_taken
    addi x27, x0, 34
bne_taken:

    addi x1, x0, -1
    addi x2, x0, 1
    blt x1, x2, blt_taken
    addi x27, x0, 35
blt_taken:

    addi x1, x0, 1
    addi x2, x0, -1
    bge x1, x2, bge_taken
    addi x27, x0, 36
bge_taken:

    addi x1, x0, 1
    addi x2, x0, -1
    bltu x1, x2, bltu_taken
    addi x27, x0, 37
bltu_taken:

    addi x1, x0, -1
    addi x2, x0, 1
    bgeu x1, x2, bgeu_taken
    addi x27, x0, 38
bgeu_taken:

    add x31, x27, x0
    add x29, x27, x0
    addi x30, x0, 0
    bne x27, x0, failed

    # Not-taken branch behaviour
    addi x29, x0, 0
    beq x1, x2, beq_not_taken_wrong
    addi x29, x29, 1
beq_not_taken_wrong:
    addi x30, x0, 1
    CHECK 39

    add x2, x1, x0
    addi x29, x0, 0
    bne x1, x2, bne_not_taken_wrong
    addi x29, x29, 1
bne_not_taken_wrong:
    addi x30, x0, 1
    CHECK 40

    # JAL link value and pipeline flushing
    jal x29, jal_target
jal_link:
    jal x0, failed
    jal x0, failed
jal_target:
    la x30, jal_link
    CHECK 41

    # JALR target bit-zero clearing, link value and pipeline flushing
    la x1, jalr_target
    addi x1, x1, 1
    jalr x29, 0(x1)
jalr_link:
    jal x0, failed
    jal x0, failed
jalr_target:
    la x30, jalr_link
    CHECK 42

    # Instructions currently decoded as supported special operations
    fence
    ecall
    ebreak

passed:
    addi x1, x0, 1
    sw x1, 64(x0)                    # status = 1
    sw x0, 68(x0)                    # failure code = 0

finished:
    jal x0, finished                 # remain inside instruction memory

failed:
    addi x1, x0, -1
    sw x1, 64(x0)                    # status = 0xFFFFFFFF
    sw x31, 68(x0)                   # failing test code
    sw x29, 72(x0)                   # observed result
    sw x30, 76(x0)                   # expected result
    jal x0, failed

memory_guard:
    jal x0, memory_guard