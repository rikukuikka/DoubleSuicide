; =============================================================================
; sound.asm — PSG AY-3-8910 ääniefektit + taustamusiikki
; =============================================================================
;
; R7 mixer bitit 7,6 aina: bit7=1 (portB out), bit6=0 (portA in)
; Kanavat: A = ampuminen, B = räjähdys, C = taustamusiikki
;
; R7 arvot (0b10xxxxx):
;   Hiljainen:    0b10111111 = 0xBF
;   A tone:       0b10111110 = 0xBE
;   B noise:      0b10101111 = 0xAF
;   A+B:          0b10101110 = 0xAE
;   C tone:       0b10111011 = 0xBB
;   A+C:          0b10111010 = 0xBA
;   B+C:          0b10101011 = 0xAB
;   A+B+C:        0b10101010 = 0xAA

PSG_REG_W   EQU 0xA0
PSG_DAT_W   EQU 0xA1

; SFX RAM
SFX_A_CTR   EQU 0xC060
SFX_A_FREQ  EQU 0xC061
SFX_B_CTR   EQU 0xC062

; BGM RAM
BGM_PTR     EQU 0xC074      ; nykyinen paikka biisissä (2 tavua)
BGM_START   EQU 0xC076      ; biisin alku looppausta varten (2 tavua)
BGM_TIMER   EQU 0xC078      ; laskuri seuraavaan nuottiin
BGM_ACTIVE  EQU 0xC079      ; 1 = musiikki soi

; =============================================================================
; INIT_SOUND
; =============================================================================
INIT_SOUND:
    LD      A, 7      : OUT (PSG_REG_W), A
    LD      A, 0xBF   : OUT (PSG_DAT_W), A
    ; Kanavat A, B, C hiljaa
    LD      A, 8      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    LD      A, 9      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    LD      A, 10     : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    ; SFX nollaus
    XOR     A
    LD      (SFX_A_CTR), A
    LD      (SFX_B_CTR), A
    ; BGM alustus
    CALL    BGM_INIT
    RET

; =============================================================================
; SFX_SHOOT — kanava A
; =============================================================================
SFX_SHOOT:
    LD      A, 12 : LD (SFX_A_CTR), A
    LD      A, 50 : LD (SFX_A_FREQ), A
    RET

; =============================================================================
; SFX_ENEMY_DIE — kanava B
; =============================================================================
SFX_ENEMY_DIE:
    LD      A, 16 : LD (SFX_B_CTR), A
    RET

; =============================================================================
; BGM_INIT — aloita taustamusiikki
; =============================================================================
BGM_INIT:
    LD      HL, SONG_DATA
    LD      (BGM_START), HL
    LD      (BGM_PTR), HL
    XOR     A
    LD      (BGM_TIMER), A
    LD      A, 1
    LD      (BGM_ACTIVE), A
    RET

; =============================================================================
; BGM_UPDATE — päivitä taustamusiikki (kanava C)
; =============================================================================
BGM_UPDATE:
    LD      A, (BGM_ACTIVE)
    OR      A
    RET     Z

    ; Laskuri > 0 → odota
    LD      A, (BGM_TIMER)
    OR      A
    JR      Z, .next_note
    DEC     A
    LD      (BGM_TIMER), A
    RET

.next_note:
    LD      HL, (BGM_PTR)
    LD      A, (HL) : INC HL    ; kesto
    LD      E, (HL) : INC HL    ; taajuus fine
    LD      D, (HL) : INC HL    ; taajuus coarse

    OR      A                   ; kesto = 0 = komento?
    JR      Z, .restart

    LD      (BGM_TIMER), A
    LD      (BGM_PTR), HL

    ; Tauko? (taajuus = 0)
    LD      A, E : OR D
    JR      Z, .mute

    ; Soita nuotti kanavalla C (R4=fine, R5=coarse)
    LD      A, 4  : OUT (PSG_REG_W), A
    LD      A, E  : OUT (PSG_DAT_W), A
    LD      A, 5  : OUT (PSG_REG_W), A
    LD      A, D  : OUT (PSG_DAT_W), A
    LD      A, 10 : OUT (PSG_REG_W), A
    LD      A, 10 : OUT (PSG_DAT_W), A    ; voimakkuus 10 (ei liian kovaa)
    RET

.mute:
    LD      A, 10 : OUT (PSG_REG_W), A
    XOR     A     : OUT (PSG_DAT_W), A    ; kanava C hiljaa
    RET

.restart:
    LD      HL, (BGM_START)
    LD      (BGM_PTR), HL
    XOR     A
    LD      (BGM_TIMER), A
    JR      .next_note

; =============================================================================
; UPDATE_SOUND — SFX + mixer, kutsu kerran per frame
; =============================================================================
UPDATE_SOUND:
    CALL    BGM_UPDATE

    ; --- Kanava A: ampuminen ---
    LD      A, (SFX_A_CTR)
    OR      A
    JR      Z, .a_off
    DEC     A : LD (SFX_A_CTR), A
    LD      A, (SFX_A_FREQ)
    ADD     A, 12 : LD (SFX_A_FREQ), A
    LD      A, 0  : OUT (PSG_REG_W), A
    LD      A, (SFX_A_FREQ) : OUT (PSG_DAT_W), A
    LD      A, 1  : OUT (PSG_REG_W), A
    XOR     A     : OUT (PSG_DAT_W), A
    LD      A, 8  : OUT (PSG_REG_W), A
    LD      A, 13 : OUT (PSG_DAT_W), A
    JR      .b_part
.a_off:
    LD      A, 8 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A

.b_part:
    ; --- Kanava B: räjähdys ---
    LD      A, (SFX_B_CTR)
    OR      A
    JR      Z, .b_off
    DEC     A : LD (SFX_B_CTR), A
    LD      A, 6 : OUT (PSG_REG_W), A
    LD      A, 7 : OUT (PSG_DAT_W), A
    LD      A, 9 : OUT (PSG_REG_W), A
    LD      A, (SFX_B_CTR) : OUT (PSG_DAT_W), A
    JR      .mixer
.b_off:
    LD      A, 9 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A

.mixer:
    ; R7: yhdistä SFX A, B ja BGM C
    ; Aloita hiljaisesta: 0b10111111
    LD      D, 0xBF

    LD      A, (SFX_A_CTR) : OR A : JR Z, .no_a
    RES     0, D            ; A tone päällä (bit 0 = 0)
.no_a:
    LD      A, (SFX_B_CTR) : OR A : JR Z, .no_b
    RES     4, D            ; B noise päällä (bit 4 = 0)
.no_b:
    LD      A, (BGM_ACTIVE) : OR A : JR Z, .no_c
    RES     2, D            ; C tone päällä (bit 2 = 0)
.no_c:
    LD      A, 7 : OUT (PSG_REG_W), A
    LD      A, D : OUT (PSG_DAT_W), A
    RET

; =============================================================================
; Biisidata — luuppaava dungeon-marssi E-mollissa
; Formaatti: 3 tavua per nuotti (kesto frameina, taajuus_lo, taajuus_hi)
; Kesto 0 = restart
; Taajuus 0,0 = tauko (mute)
;
; Nuotit (PSG period):
;   D3=762 (0x02FA)  E3=679 (0x02A7)  F3=641 (0x0281)
;   G3=571 (0x023B)  A3=508 (0x01FC)  Bb3=480 (0x01E0)
;   B3=453 (0x01C5)
; =============================================================================
SONG_DATA:
    ; --- Fraasi 1: nouseva marssi ---
    DB 10, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00    ; tauko
    DB 10, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00
    DB 10, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00
    DB 10, 0xFC, 0x01    ; A3
    DB 2,  0x00, 0x00
    DB 22, 0xC5, 0x01    ; B3 (pitkä)
    DB 2,  0x00, 0x00
    DB 22, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00

    ; --- Fraasi 2: laskeva ---
    DB 10, 0xFC, 0x01    ; A3
    DB 2,  0x00, 0x00
    DB 10, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00
    DB 10, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00
    DB 10, 0xFA, 0x02    ; D3
    DB 2,  0x00, 0x00
    DB 46, 0xA7, 0x02    ; E3 (pitkä pidätys)
    DB 2,  0x00, 0x00

    ; --- Fraasi 3: variaatio ---
    DB 10, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00
    DB 10, 0xFC, 0x01    ; A3
    DB 2,  0x00, 0x00
    DB 10, 0xC5, 0x01    ; B3
    DB 2,  0x00, 0x00
    DB 10, 0xFC, 0x01    ; A3
    DB 2,  0x00, 0x00
    DB 22, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00
    DB 22, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00

    ; --- Fraasi 4: purku ---
    DB 10, 0xFA, 0x02    ; D3
    DB 2,  0x00, 0x00
    DB 10, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00
    DB 10, 0x3B, 0x02    ; G3
    DB 2,  0x00, 0x00
    DB 10, 0xA7, 0x02    ; E3
    DB 2,  0x00, 0x00
    DB 46, 0xFA, 0x02    ; D3 (pitkä pidätys)
    DB 2,  0x00, 0x00

    ; --- Loop ---
    DB 0, 0, 0
