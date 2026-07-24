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
    INCLUDE "src/boss.asm"
    INCLUDE "src/sound.asm"
    INCLUDE "src/hud.asm"
    INCLUDE "src/title.asm"
    INCLUDE "src/gameover.asm"

INIT:
    DI
    LD      SP, 0xF380

    CALL    VDP_INIT_SCREEN2

    LD      HL, VRAM_NAMETABLE
    LD      BC, 32*24
    LD      A, 0
    CALL    VDP_FILL

    CALL    INIT_HUD             ; load tile patterns (letters, numbers)
    CALL    INIT_SOUND           ; music starts
    XOR     A : LD (FRAME_CTR), A
    CALL    TITLE_SCREEN         ; title screen — waits for selection

    ; Game setup after the selection
    CALL    INIT_MAZE
    CALL    INIT_NAVMAP
    ; Restore HUD colors to all banks after TITLE_SCREEN
    LD      HL, 0x2000 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x2800 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x3000 + 16 : CALL LOAD_HUD_COLORS
    CALL    INIT_PLAYERS
    CALL    INIT_BOSS              ; reset BOSS_ACTIVE, load the Wizard's patterns
    LD      A, 6 : LD (LEVEL), A
    LD      A, 1 : LD (ROUND), A   ; round 1 (slowest speed tier)
    CALL    APPLY_ROUND_SPEEDS     ; compute CUR_* speeds before spawning enemies
    CALL    INIT_ENEMIES
    CALL    INIT_BULLETS
    CALL    INIT_EXPLOSIONS
    XOR     A : LD (WAVE_TIMER), A
    LD      A, 1 : LD (HUD_DIRTY), A   ; DRAW_MAZE overwrote row 23
    ; Clear the sprite attribute table — the title screen may leave stray sprites
    LD      HL, VRAM_SPRITE_ATT
    LD      BC, 128
    LD      A, 0xD8
    CALL    VDP_FILL
    CALL    WAIT_VBLANK                 ; sync VDP writes to vblank
    CALL    DRAW_HUD_STATIC             ; rows 21-22 never change during play
    CALL    DRAW_HUD
    CALL    DRAW_RADAR

    ; Stay in DI mode: C-BIOS's V-blank interrupt doesn't run and
    ; won't clobber the PSG. Frame sync is done by polling the VDP status register.

MAINLOOP:
    CALL    WAIT_VBLANK
    LD      A, (FRAME_CTR) : INC A : LD (FRAME_CTR), A

    ; All VDP writes happen right after vblank
    CALL    DRAW_PLAYERS
    CALL    DRAW_ENEMIES
    CALL    DRAW_BULLETS
    CALL    DRAW_ENEMY_BULLETS
    CALL    DRAW_TANK_BULLETS
    CALL    DRAW_EXPLOSIONS
    CALL    DRAW_HUD
    CALL    DRAW_RADAR
    CALL    DRAW_WIZARD           ; the Wizard only uses sprites 26-28, no collision with others

    CALL    READ_INPUTS

    ; --- Wave timer ---
    LD      A, (WAVE_TIMER)
    OR      A
    JR      Z, .normal

    ; Delay running — count down
    DEC     A : LD (WAVE_TIMER), A
    OR      A
    JR      NZ, .wave_wait
    ; Timer ran out → spawn a new wave (may take several frames)
    CALL    SPAWN_WAVE

.wave_wait:
    ; Players move during the delay, enemies do not
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_BULLETS
    CALL    UPDATE_ENEMY_BULLETS
    CALL    UPDATE_TANK_BULLETS
    CALL    UPDATE_WIZARD_BULLET
    CALL    UPDATE_EXPLOSIONS
    CALL    UPDATE_SOUND
    JP      MAINLOOP

.normal:
    ; Normal gameplay state
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_ENEMIES
    CALL    CHECK_PLAYER_DEATH
    CALL    CHECK_GAME_OVER
    CALL    UPDATE_BULLETS
    CALL    UPDATE_ENEMY_BULLETS
    CALL    UPDATE_TANK_BULLETS
    CALL    UPDATE_WIZARD_BULLET
    CALL    UPDATE_EXPLOSIONS
    CALL    UPDATE_SOUND

    ; Check whether the wave is complete
    CALL    CHECK_WAVE_COMPLETE
    JP      NZ, MAINLOOP
    ; All enemies destroyed
    LD      A, (BOSS_ACTIVE) : OR A : JR Z, .next_level
    ; Wizard defeated — new, faster round; LEVEL resets to 1
    LD      A, (ROUND) : INC A : LD (ROUND), A
    CALL    APPLY_ROUND_SPEEDS
    LD      A, 1 : LD (LEVEL), A
    JR      .level_set
.next_level:
    LD      A, (LEVEL) : INC A : LD (LEVEL), A
.level_set:
    LD      A, 90 : LD (WAVE_TIMER), A    ; 1.5s delay
    JP      MAINLOOP

; =============================================================================
; WAIT_VBLANK — wait for V-blank by polling VDP status S#0 bit 7
; Reading port 0x99 returns the status register; reading the bit clears it.
; =============================================================================
WAIT_VBLANK:
    IN      A, (VDP_REG)     ; read 0x99 = status S#0
    AND     0x80             ; bit 7 = V-blank (F) flag
    JR      Z, WAIT_VBLANK
    RET

    DS      0x8000 - $, 0xFF
