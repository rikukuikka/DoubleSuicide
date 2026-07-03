; =============================================================================
; constants.asm — Kaikki vakiot ja RAM-osoitteet
; =============================================================================

; VDP portit
VDP_DATA    EQU 0x98
VDP_REG     EQU 0x99

; PSG portit (joystick)
PSG_REG     EQU 0xA0
PSG_REG15     EQU 0xA1
PSG_READ    EQU 0xA2
PSG_P1      EQU 0x8F
PSG_P2      EQU 0x40

; PPI portit (näppäimistö)
PPI_ROW     EQU 0xAA
PPI_COL     EQU 0xA9

; VRAM-osoitteet
VRAM_NAMETABLE  EQU 0x1800
VRAM_SPRITE_ATT EQU 0x1B00
VRAM_SPRITE_PAT EQU 0x3800

; Suunnat (= sprite pattern numero)
DIR_RIGHT   EQU 0
DIR_LEFT    EQU 1
DIR_UP      EQU 2
DIR_DOWN    EQU 3

; Input bitit
IN_UP       EQU 0x01
IN_DOWN     EQU 0x02
IN_LEFT     EQU 0x04
IN_RIGHT    EQU 0x08
IN_FIRE     EQU 0x10

; Pelinopeus
SPEED       EQU 2

; Sprite värit
P1_COLOR    EQU 4   ; sininen
P2_COLOR    EQU 2   ; vihreä

; =============================================================================
; RAM-osoitteet 0xC000+
; TÄRKEÄÄ: kaikki muuttuva data täytyy olla RAM:issa, ei ROM:issa!
; =============================================================================

; Pelaajien koordinaatit ja suunnat
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

; Input-tila
P1_INPUT    EQU 0xC006
P2_INPUT    EQU 0xC007

; Pelaajien tila
P1_LIVES    EQU 0xC008
P2_LIVES    EQU 0xC009
P1_DEAD_TMR EQU 0xC00A      ; kuolinanimaation ajastin (0=elossa)
P2_DEAD_TMR EQU 0xC00B

GAME_MODE   EQU 0xC00C      ; 1=yksinpeli, 2=kaksinpeli
FRAME_CTR   EQU 0xC00D      ; frame-laskuri animaatioille
LEVEL       EQU 0xC00E      ; kentän numero (1+)
WAVE_TIMER  EQU 0xC00F      ; viive kenttien välillä

; Vapaat RAM-osoitteet
; 0xC00D - 0xC00F vapaa

; Porttirivien Y-koordinaatit — laskettu kenttädatasta
; Rivit 10-13 ovat auki: Y = 80-111
PORTAL_Y_MIN    EQU 80
PORTAL_Y_MAX    EQU 111

; HUD-likainen lippu
HUD_DIRTY       EQU 0xC080      ; 1 = DRAW_HUD täytyy ajaa, 0 = ohita

; Risteyspisteiden suuntabittikartta (lasketaan kerran käynnistyksessä)
; Bitti 0=RIGHT, 1=LEFT, 2=UP, 3=DOWN; 0=ei kelvollinen paikka
NAVMAP          EQU 0xC100      ; 32*24=768 tavua (0xC100-0xC3FF)

; Räjähdykset
EXPLOSIONS      EQU 0xC07A      ; 2*3=6 tavua RAM:issa (0xC060-0xC062 = SFX RAM)
EXPL_SIZE       EQU 3
EXPL_TIMER_MAX  EQU 20
EXPL_PAT1       EQU 40          ; Räjähdys 1 (kirkas) = offset 320
EXPL_PAT2       EQU 44          ; Räjähdys 2 (haalistuva) = offset 352
EXPL_COLOR1     EQU 15          ; valkoinen välähdys
EXPL_COLOR2     EQU 9           ; vaaleanpunainen sammuminen
