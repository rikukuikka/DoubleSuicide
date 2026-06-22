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
    INCLUDE "src/sound.asm"
    INCLUDE "src/hud.asm"

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
    CALL    INIT_SOUND
    CALL    INIT_HUD

    ; Pysytään DI-tilassa: C-BIOS:in V-blank-keskeytys ei aja eikä
    ; sotke PSG:tä. Frame-synkka tehdään pollaamalla VDP:n status-rekisteriä.

MAINLOOP:
    CALL    WAIT_VBLANK
    CALL    READ_INPUTS
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_ENEMIES
    CALL    CHECK_PLAYER_DEATH
    CALL    UPDATE_BULLETS
    CALL    UPDATE_SOUND
    CALL    DRAW_ENEMIES
    CALL    DRAW_BULLETS
    CALL    DRAW_HUD
    JP      MAINLOOP

; =============================================================================
; WAIT_VBLANK — odota V-blank pollaamalla VDP status S#0 bittiä 7
; Luku portista 0x99 palauttaa status-rekisterin; bitin lukeminen nollaa sen.
; =============================================================================
WAIT_VBLANK:
    IN      A, (VDP_REG)     ; 0x99 luku = status S#0
    AND     0x80             ; bitti 7 = V-blank (F) lippu
    JR      Z, WAIT_VBLANK
    RET

    DS      0x8000 - $, 0xFF
