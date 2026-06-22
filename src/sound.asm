; =============================================================================
; sound.asm — PSG AY-3-8910 ääniefektit
; =============================================================================
;
; R7 (mixer + I/O suunnat) — KRIITTINEN:
;   bit 7 = I/O port B suunta: 1 = output (R15 kirjoitus vaatii tämän)
;   bit 6 = I/O port A suunta: 0 = input  (R14 joystick-luku vaatii tämän)
;   bit 5-0 = kanavien mixer (0 = päällä, 1 = pois)
;
;   => Kaikki R7-arvot muotoa 0b10xxxxxx jotta portit ovat oikein
;      eikä openMSX:n "unsafe PSG port directions" -varoitusta tule.
;
;   Hiljainen:         0b10111111 = 0xBF
;   Kanava A tone:     0b10111110 = 0xBE
;   Kanava B noise:    0b10101111 = 0xAF
;   A tone + B noise:  0b10101110 = 0xAE

PSG_REG_W   EQU 0xA0
PSG_DAT_W   EQU 0xA1

R7_SILENT   EQU 0xBF
R7_A        EQU 0xBE
R7_B        EQU 0xAF
R7_AB       EQU 0xAE

SFX_A_CTR   EQU 0xC060      ; kanava A laskuri (0 = ei ääntä)
SFX_A_FREQ  EQU 0xC061      ; kanava A nykyinen taajuus
SFX_B_CTR   EQU 0xC062      ; kanava B laskuri

; =============================================================================
; INIT_SOUND — alusta PSG hiljaiseksi, portit oikein
; =============================================================================
INIT_SOUND:
    LD      A, 7      : OUT (PSG_REG_W), A
    LD      A, R7_SILENT : OUT (PSG_DAT_W), A
    LD      A, 8      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A     ; kanava A äänenvoimakkuus 0
    LD      A, 9      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A     ; kanava B äänenvoimakkuus 0
    XOR     A
    LD      (SFX_A_CTR), A
    LD      (SFX_B_CTR), A
    RET

; =============================================================================
; SFX_SHOOT — ammuksen ääni (kanava A, laskeva sävel)
; =============================================================================
SFX_SHOOT:
    LD      A, 12 : LD (SFX_A_CTR), A
    LD      A, 50 : LD (SFX_A_FREQ), A
    RET

; =============================================================================
; SFX_ENEMY_DIE — vihollisen kuolema (kanava B, kohina)
; =============================================================================
SFX_ENEMY_DIE:
    LD      A, 16 : LD (SFX_B_CTR), A
    RET

; =============================================================================
; UPDATE_SOUND — kutsu kerran per frame
; Laskee mixer-tilan A- ja B-laskureista ja kirjoittaa R7:n AINA
; turvallisella arvolla (bitit 7,6 oikein).
; =============================================================================
UPDATE_SOUND:
    ; --- Kanava A ---
    LD      A, (SFX_A_CTR)
    OR      A
    JR      Z, .a_off

    DEC     A : LD (SFX_A_CTR), A
    LD      A, (SFX_A_FREQ)
    ADD     A, 12 : LD (SFX_A_FREQ), A       ; taajuus kasvaa = sävel laskee

    LD      A, 0  : OUT (PSG_REG_W), A
    LD      A, (SFX_A_FREQ) : OUT (PSG_DAT_W), A
    LD      A, 1  : OUT (PSG_REG_W), A
    XOR     A     : OUT (PSG_DAT_W), A
    LD      A, 8  : OUT (PSG_REG_W), A
    LD      A, 13 : OUT (PSG_DAT_W), A        ; äänenvoimakkuus
    JR      .b_part

.a_off:
    LD      A, 8 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A         ; kanava A vaiti

.b_part:
    ; --- Kanava B ---
    LD      A, (SFX_B_CTR)
    OR      A
    JR      Z, .b_off

    DEC     A : LD (SFX_B_CTR), A
    LD      A, 6 : OUT (PSG_REG_W), A
    LD      A, 7 : OUT (PSG_DAT_W), A         ; kohinan taajuus
    LD      A, 9 : OUT (PSG_REG_W), A
    LD      A, (SFX_B_CTR) : OUT (PSG_DAT_W), A  ; äänenvoimakkuus haipuu
    JR      .mixer

.b_off:
    LD      A, 9 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A         ; kanava B vaiti

.mixer:
    ; Valitse R7 sen mukaan kumpi kanava soi (bitit 7,6 aina oikein)
    LD      A, (SFX_A_CTR) : LD B, A
    LD      A, (SFX_B_CTR) : LD C, A
    LD      A, B : OR A : JR NZ, .a_on
    ; A pois
    LD      A, C : OR A : JR NZ, .only_b
    LD      A, R7_SILENT : JR .write_r7
.only_b:
    LD      A, R7_B : JR .write_r7
.a_on:
    LD      A, C : OR A : JR NZ, .both
    LD      A, R7_A : JR .write_r7
.both:
    LD      A, R7_AB
.write_r7:
    LD      B, A
    LD      A, 7 : OUT (PSG_REG_W), A
    LD      A, B : OUT (PSG_DAT_W), A
    RET
