; =============================================================================
; constants.asm — All constants and RAM addresses
; =============================================================================

; VDP ports
VDP_DATA    EQU 0x98
VDP_REG     EQU 0x99

; PSG ports — register select / data write / data read.
; Shared by input.asm (joystick, via register 14/15) and sound.asm (audio registers).
PSG_REG     EQU 0xA0
PSG_REG15   EQU 0xA1
PSG_READ    EQU 0xA2
PSG_P1      EQU 0x8F
PSG_P2      EQU 0x40

; PPI ports (keyboard)
PPI_ROW     EQU 0xAA
PPI_COL     EQU 0xA9

; VRAM addresses
VRAM_NAMETABLE  EQU 0x1800
VRAM_SPRITE_ATT EQU 0x1B00
VRAM_SPRITE_PAT EQU 0x3800

; Directions (= sprite pattern number)
DIR_RIGHT   EQU 0
DIR_LEFT    EQU 1
DIR_UP      EQU 2
DIR_DOWN    EQU 3

; Input bits
IN_UP       EQU 0x01
IN_DOWN     EQU 0x02
IN_LEFT     EQU 0x04
IN_RIGHT    EQU 0x08
IN_FIRE     EQU 0x10

; Game speed
SPEED       EQU 2

; Sprite colors
P1_COLOR    EQU 4   ; blue
P2_COLOR    EQU 2   ; green

; =============================================================================
; RAM addresses 0xC000+
; IMPORTANT: all mutable data must live in RAM, not ROM!
; =============================================================================

; Player coordinates and directions
P1_START_X  EQU 8
P1_START_Y  EQU 176
P1_X        EQU 0xC000
P1_Y        EQU 0xC001
P1_DIR      EQU 0xC002
P2_START_X  EQU 232
P2_START_Y  EQU 176
P2_X        EQU 0xC003
P2_Y        EQU 0xC004
P2_DIR      EQU 0xC005

; Input state
P1_INPUT    EQU 0xC006
P2_INPUT    EQU 0xC007

; Player state
P1_LIVES    EQU 0xC008
P2_LIVES    EQU 0xC009
P1_DEAD_TMR EQU 0xC00A      ; death animation timer (0=alive)
P2_DEAD_TMR EQU 0xC00B

GAME_MODE   EQU 0xC00C      ; 1=single player, 2=two players
FRAME_CTR   EQU 0xC00D      ; frame counter for animations
LEVEL       EQU 0xC00E      ; level number (1+)
WAVE_TIMER  EQU 0xC00F      ; delay between levels

; Portal row Y coordinates — computed from maze data
; Rows 10-13 are open: Y = 80-111
PORTAL_Y_MIN    EQU 80
PORTAL_Y_MAX    EQU 111

; HUD dirty flag
HUD_DIRTY       EQU 0xC080      ; 1 = DRAW_HUD must run, 0 = skip

; Junction direction bitmap (computed once at startup)
; Bit 0=RIGHT, 1=LEFT, 2=UP, 3=DOWN; 0=not a valid spot
NAVMAP          EQU 0xC100      ; 32*24=768 bytes (0xC100-0xC3FF)

; Enemy bullets
ENEMY_BULLETS       EQU 0xC081      ; 6*4=24 bytes (0xC081-0xC098)
ENEMY_BULLET_SIZE   EQU 4           ; X, Y, dir, active
ENEMY_BULLET_COLOR  EQU 8           ; red
; Speed: see CUR_BULLET_SPEED (enemy.asm) — per-round now, no longer fixed

; Tank bullets (2 directions at once)
TANK_BULLETS        EQU 0xC099      ; 2*4=8 bytes (0xC099-0xC0A0)
TANK_BULLET_COLOR   EQU 7           ; cyan, same as tank

; Explosions
EXPLOSIONS      EQU 0xC07A      ; 2*3=6 bytes in RAM (0xC060-0xC062 = SFX RAM)
EXPL_SIZE       EQU 3
EXPL_TIMER_MAX  EQU 20
EXPL_PAT1       EQU 56          ; Explosion 1 (bright) = offset 448
EXPL_PAT2       EQU 60          ; Explosion 2 (fading) = offset 480
EXPL_COLOR1     EQU 15          ; white flash
EXPL_COLOR2     EQU 9           ; pink fade-out

; Radar — in the middle of the HUD, 4x3-tile frame (32x24px), contents as sprites
; The border is fixed nametable tiles (DIGIT_PATS, hud.asm):
;   row 21 columns 14-17 = RADAR_BORDER_TOP (columns 13/18 are plain wall tiles)
;   row 22-23 columns 13/18 = RADAR_BORDER_L/R
;   row 23 columns 14-17 = RADAR_BORDER_BOTTOM
; Enemy positions are drawn by DRAW_RADAR (enemy.asm) using sprites
; RADAR_SPRITE_BASE.. (1 sprite per ENEMIES slot), colored with the enemy's own color.
; 1 playfield tile = 1 pixel, offset 1px down (centering).
RADAR_BORDER_TOP    EQU 41      ; top edge (row 21, columns 14-17)
RADAR_BORDER_BOTTOM EQU 42      ; bottom edge (row 23, columns 14-17)
RADAR_BORDER_R      EQU 43      ; right edge (rows 22-23)
RADAR_BORDER_L      EQU 44      ; left edge (rows 22-23)

RADAR_SPRITE_BASE   EQU 20      ; sprites 20-25 (6 total, free)
RADAR_DOT_PAT       EQU 72      ; small dot pattern (tank uses 64-71, see enemy.asm)
RADAR_ORIGIN_X      EQU 112     ; column14 * 8
RADAR_ORIGIN_Y      EQU 168     ; row21 * 8, already includes the Y-1 adjustment
