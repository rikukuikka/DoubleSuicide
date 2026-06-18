; =============================================================================
; main.asm — Wizard of Wor MSX1
; =============================================================================

    ORG     0x4000

ROM_HEADER:
    DB      0x41, 0x42
    DW      INIT
    DW      0x0000, 0x0000, 0x0000
    DS      6, 0x00

    INCLUDE "src/constants.asm"
    INCLUDE "src/vdp.asm"
    INCLUDE "src/maze.asm"
    INCLUDE "src/input.asm"
    INCLUDE "src/player.asm"
    INCLUDE "src/enemy.asm"
    INCLUDE "src/bullet.asm"

INIT:
    DI
    LD      SP, 0xF380

    CALL    VDP_INIT_SCREEN2

    LD      HL, VRAM_NAMETABLE
    LD      BC, 32*24
    LD      A, 0
    CALL    VDP_FILL

    CALL    INIT_MAZE
    CALL    INIT_PLAYERS
    CALL    INIT_ENEMIES
    CALL    INIT_BULLETS

    EI

MAINLOOP:
    HALT
    CALL    READ_INPUTS
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_ENEMIES
    CALL    UPDATE_BULLETS
    CALL    DRAW_ENEMIES
    CALL    DRAW_BULLETS
    JP      MAINLOOP

    DS      0x8000 - $, 0xFF
