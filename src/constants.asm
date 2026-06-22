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
P1_COLOR    EQU 7   ; syaani
P2_COLOR    EQU 8   ; punainen

; =============================================================================
; RAM-osoitteet 0xC000+
; TÄRKEÄÄ: kaikki muuttuva data täytyy olla RAM:issa, ei ROM:issa!
; =============================================================================

; Pelaajien koordinaatit ja suunnat
P1_X        EQU 0xC000
P1_Y        EQU 0xC001
P1_DIR      EQU 0xC002
P2_X        EQU 0xC003
P2_Y        EQU 0xC004
P2_DIR      EQU 0xC005

; Input-tila
P1_INPUT    EQU 0xC006
P2_INPUT    EQU 0xC007

; Vapaat RAM-osoitteet tulevaa käyttöä varten (viholliset jne.)
; 0xC010 - 0xC0FF

; Porttirivien Y-koordinaatit — laskettu kenttädatasta
; Rivit 10-13 ovat auki: Y = 80-111
PORTAL_Y_MIN    EQU 80
PORTAL_Y_MAX    EQU 111
