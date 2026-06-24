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
P1_COLOR    EQU 2   ; vihreä
P2_COLOR    EQU 4   ; sininen

; =============================================================================
; RAM-osoitteet 0xC000+
; TÄRKEÄÄ: kaikki muuttuva data täytyy olla RAM:issa, ei ROM:issa!
; =============================================================================

; Pelaajien koordinaatit ja suunnat
P1_START_X  EQU 8
P1_START_Y  EQU 168
P1_X        EQU 0xC000
P1_Y        EQU 0xC001
P1_DIR      EQU 0xC002
P2_START_X  EQU 232
P2_START_Y  EQU 168
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
