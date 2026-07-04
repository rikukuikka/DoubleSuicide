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
    INCLUDE "src/title.asm"

INIT:
    DI
    LD      SP, 0xF380

    CALL    VDP_INIT_SCREEN2

    LD      HL, VRAM_NAMETABLE
    LD      BC, 32*24
    LD      A, 0
    CALL    VDP_FILL

    CALL    INIT_HUD             ; lataa tilepatternit (kirjaimet, numerot)
    CALL    INIT_SOUND           ; musiikki alkaa
    XOR     A : LD (FRAME_CTR), A
    CALL    TITLE_SCREEN         ; otsikkoruutu — odottaa valintaa

    ; Pelin alustus valinnan jälkeen
    CALL    INIT_MAZE
    CALL    INIT_NAVMAP
    ; Palauta HUD-värit kaikkiin pankkeihin TITLE_SCREENin jälkeen
    LD      HL, 0x2000 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x2800 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x3000 + 16 : CALL LOAD_HUD_COLORS
    CALL    INIT_PLAYERS
    CALL    INIT_ENEMIES
    CALL    INIT_BULLETS
    CALL    INIT_EXPLOSIONS
    LD      A, 1 : LD (LEVEL), A
    XOR     A : LD (WAVE_TIMER), A
    LD      A, 1 : LD (HUD_DIRTY), A   ; DRAW_MAZE ylikirjoitti rivin 23
    CALL    WAIT_VBLANK                 ; synkronoi VDP-kirjoitus vblankiin
    CALL    DRAW_HUD

    ; Pysytään DI-tilassa: C-BIOS:in V-blank-keskeytys ei aja eikä
    ; sotke PSG:tä. Frame-synkka tehdään pollaamalla VDP:n status-rekisteriä.

MAINLOOP:
    CALL    WAIT_VBLANK
    LD      A, (FRAME_CTR) : INC A : LD (FRAME_CTR), A

    ; Kaikki VDP-kirjoitukset heti vblankin jälkeen
    CALL    DRAW_PLAYERS
    CALL    DRAW_ENEMIES
    CALL    DRAW_BULLETS
    CALL    DRAW_ENEMY_BULLETS
    CALL    DRAW_EXPLOSIONS
    CALL    DRAW_HUD

    CALL    READ_INPUTS

    ; --- Wave timer ---
    LD      A, (WAVE_TIMER)
    OR      A
    JR      Z, .normal

    ; Viive käynnissä — laske alaspäin
    DEC     A : LD (WAVE_TIMER), A
    OR      A
    JR      NZ, .wave_wait
    ; Timer loppui → spawn uusi aalto (voi kestää useita frameja)
    CALL    SPAWN_WAVE

.wave_wait:
    ; Pelaajat liikkuvat viiveen aikana, viholliset eivät
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_BULLETS
    CALL    UPDATE_ENEMY_BULLETS
    CALL    UPDATE_EXPLOSIONS
    CALL    UPDATE_SOUND
    JP      MAINLOOP

.normal:
    ; Normaali pelitila
    CALL    UPDATE_PLAYERS
    CALL    UPDATE_ENEMIES
    CALL    CHECK_PLAYER_DEATH
    CALL    UPDATE_BULLETS
    CALL    UPDATE_ENEMY_BULLETS
    CALL    UPDATE_EXPLOSIONS
    CALL    UPDATE_SOUND

    ; Tarkista onko aalto valmis
    CALL    CHECK_WAVE_COMPLETE
    JP      NZ, MAINLOOP
    ; Kaikki viholliset tuhottu — seuraava taso
    LD      A, (LEVEL) : INC A : LD (LEVEL), A
    LD      A, 90 : LD (WAVE_TIMER), A    ; 1.5s viive
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
