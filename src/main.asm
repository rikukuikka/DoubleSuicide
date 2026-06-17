; =============================================================================
; main.asm — Wizard of Wor MSX1
; Kääntäminen: sjasmplus --raw=build/wow.rom src/main.asm
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

; =============================================================================
; INIT
; =============================================================================
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

    EI

; =============================================================================
; MAINLOOP
; =============================================================================
MAINLOOP:
    HALT
    CALL    READ_INPUTS
    CALL    UPDATE_PLAYERS
    JP      MAINLOOP

    DS      0x8000 - $, 0xFF
