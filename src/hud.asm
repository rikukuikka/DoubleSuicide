; =============================================================================
; hud.asm — Pisteet ja elämät
; =============================================================================
;
; Name table rivi 23 (alin) = HUD
; Tileet:  0=tyhjä(musta) 1=seinä 2-11=digit 0-9  12=P1 ikoni  13=P2 ikoni
;
; Layout rivi 23:
;   ■ 3  0000                ■ 3  0000
;   0 1 2 3456  7...23  24 25 26 27282930 31

; RAM
P1_SCORE_H  EQU 0xC070      ; BCD: tuhannet/sadat
P1_SCORE_L  EQU 0xC071      ; BCD: kymmenet/ykköset
P2_SCORE_H  EQU 0xC072
P2_SCORE_L  EQU 0xC073

; Numero-patternit 0–9 (tileet 2–11)
DIGIT_PATS:
    DB 0x3C,0x66,0x6E,0x76,0x66,0x66,0x3C,0x00  ; 0
    DB 0x18,0x38,0x18,0x18,0x18,0x18,0x7E,0x00  ; 1
    DB 0x3C,0x66,0x06,0x0C,0x18,0x30,0x7E,0x00  ; 2
    DB 0x3C,0x66,0x06,0x1C,0x06,0x66,0x3C,0x00  ; 3
    DB 0x0C,0x1C,0x2C,0x4C,0x7E,0x0C,0x0C,0x00  ; 4
    DB 0x7E,0x60,0x7C,0x06,0x06,0x66,0x3C,0x00  ; 5
    DB 0x3C,0x66,0x60,0x7C,0x66,0x66,0x3C,0x00  ; 6
    DB 0x7E,0x06,0x0C,0x18,0x18,0x18,0x18,0x00  ; 7
    DB 0x3C,0x66,0x66,0x3C,0x66,0x66,0x3C,0x00  ; 8
    DB 0x3C,0x66,0x66,0x3E,0x06,0x66,0x3C,0x00  ; 9
; Pelaaja-ikonit (tileet 12, 13) — täytetty neliö
    DB $30,$78,$FF,$FC,$F4,$FE,$F8,$7C  ; P1 ikoni
    DB $0C,$1E,$FF,$3F,$2F,$7F,$1F,$3E  ; P2 ikoni
; Patterns 14-39: kirjaimet A-Z
    DB 0x3C,0x66,0x66,0x7E,0x66,0x66,0x66,0x00  ; A (14)
    DB 0x7C,0x66,0x66,0x7C,0x66,0x66,0x7C,0x00  ; B (15)
    DB 0x3C,0x66,0x60,0x60,0x60,0x66,0x3C,0x00  ; C (16)
    DB 0x78,0x6C,0x66,0x66,0x66,0x6C,0x78,0x00  ; D (17)
    DB 0x7E,0x60,0x60,0x7C,0x60,0x60,0x7E,0x00  ; E (18)
    DB 0x7E,0x60,0x60,0x7C,0x60,0x60,0x60,0x00  ; F (19)
    DB 0x3C,0x66,0x60,0x6E,0x66,0x66,0x3C,0x00  ; G (20)
    DB 0x66,0x66,0x66,0x7E,0x66,0x66,0x66,0x00  ; H (21)
    DB 0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00  ; I (22)
    DB 0x1E,0x0C,0x0C,0x0C,0x0C,0x6C,0x38,0x00  ; J (23)
    DB 0x66,0x6C,0x78,0x70,0x78,0x6C,0x66,0x00  ; K (24)
    DB 0x60,0x60,0x60,0x60,0x60,0x60,0x7E,0x00  ; L (25)
    DB 0x63,0x77,0x7F,0x6B,0x63,0x63,0x63,0x00  ; M (26)
    DB 0x66,0x76,0x7E,0x7E,0x6E,0x66,0x66,0x00  ; N (27)
    DB 0x3C,0x66,0x66,0x66,0x66,0x66,0x3C,0x00  ; O (28)
    DB 0x7C,0x66,0x66,0x7C,0x60,0x60,0x60,0x00  ; P (29)
    DB 0x3C,0x66,0x66,0x66,0x6A,0x6C,0x36,0x00  ; Q (30)
    DB 0x7C,0x66,0x66,0x7C,0x78,0x6C,0x66,0x00  ; R (31)
    DB 0x3C,0x66,0x60,0x3C,0x06,0x66,0x3C,0x00  ; S (32)
    DB 0x7E,0x18,0x18,0x18,0x18,0x18,0x18,0x00  ; T (33)
    DB 0x66,0x66,0x66,0x66,0x66,0x66,0x3C,0x00  ; U (34)
    DB 0x66,0x66,0x66,0x66,0x66,0x3C,0x18,0x00  ; V (35)
    DB 0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00  ; W (36)
    DB 0x66,0x66,0x3C,0x18,0x3C,0x66,0x66,0x00  ; X (37)
    DB 0x66,0x66,0x66,0x3C,0x18,0x18,0x18,0x00  ; Y (38)
    DB 0x7E,0x06,0x0C,0x18,0x30,0x60,0x7E,0x00  ; Z (39)
DIGIT_PATS_END:

; =============================================================================
; INIT_HUD — lataa HUD-patternit ja -värit VRAM:iin
; =============================================================================
INIT_HUD:
    ; Lataa pattern 0 (tyhjä) kaikkiin pankkeihin — otsikkoruudun tausta
    LD      HL, 0x0000 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z0: OUT    (VDP_DATA), A : DJNZ .z0
    LD      HL, 0x0800 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z1: OUT    (VDP_DATA), A : DJNZ .z1
    LD      HL, 0x1000 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z2: OUT    (VDP_DATA), A : DJNZ .z2
    ; Pattern 0 väri (musta) kaikkiin pankkeihin
    LD      HL, 0x2000 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc0: OUT   (VDP_DATA), A : DJNZ .zc0
    LD      HL, 0x2800 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc1: OUT   (VDP_DATA), A : DJNZ .zc1
    LD      HL, 0x3000 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc2: OUT   (VDP_DATA), A : DJNZ .zc2
    ; Lataa digit+ikoni+kirjain patternit kolmeen pankkiin
    LD      HL, 0x0000 + 16 : CALL .load_dp
    LD      HL, 0x0800 + 16 : CALL .load_dp
    LD      HL, 0x1000 + 16 : CALL .load_dp
    ; Lataa värit kolmeen pankkiin
    LD      HL, 0x2000 + 16 : CALL .load_dc
    LD      HL, 0x2800 + 16 : CALL .load_dc
    LD      HL, 0x3000 + 16 : CALL .load_dc
    ; Nollaa pisteet
    XOR     A
    LD      (P1_SCORE_H), A : LD (P1_SCORE_L), A
    LD      (P2_SCORE_H), A : LD (P2_SCORE_L), A
    ; Piirrä HUD
    CALL    DRAW_HUD
    RET

.load_dp:
    CALL    VDP_SETW
    LD      HL, DIGIT_PATS
    LD      BC, DIGIT_PATS_END - DIGIT_PATS
.dp: LD     A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .dp
    RET

.load_dc:
    CALL    VDP_SETW
    ; 10 numeroa * 8 tavua: valkoinen mustalla (0xF1)
    LD      B, 80
    LD      A, 0xF1
.c1: OUT    (VDP_DATA), A : DJNZ .c1
    ; P1 ikoni: 8 tavua vihreä mustalla (0x21)
    LD      B, 8
    LD      A, 0x21
.c2: OUT    (VDP_DATA), A : DJNZ .c2
    ; P2 ikoni: 8 tavua sininen mustalla (0x41)
    LD      B, 8
    LD      A, 0x41
.c3: OUT    (VDP_DATA), A : DJNZ .c3
    ; Kirjaimet A-Z: 26 * 8 = 208 tavua, valkoinen mustalla
    LD      B, 208
    LD      A, 0xF1
.c4: OUT    (VDP_DATA), A : DJNZ .c4
    RET

; =============================================================================
; DRAW_HUD — piirrä pisteet ja elämät riville 23
; =============================================================================
DRAW_HUD:
    LD      HL, VRAM_NAMETABLE + 23*32  ; rivi 23
    CALL    VDP_SETW

    ; Tile 0-3: seinä (4 kpl) — säilyttää kartan reunan
    LD      B, 4
    LD      A, 1
.ws1: OUT   (VDP_DATA), A : DJNZ .ws1
    ; Tile 5: P1 elämät
    LD      A, (P1_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 6: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 4: P1 ikoni (tilee 12)
    LD      A, 12 : OUT (VDP_DATA), A
    ; Tile 6: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 4-7: P1 pisteet (4 BCD-numeroa)
    LD      A, (P1_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_H)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 11-20: tyhjä (10 kpl)
    LD      B, 8
    XOR     A
.sp: OUT    (VDP_DATA), A : DJNZ .sp
    ; Tile 24-27: P2 pisteet
    LD      A, (P2_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_H)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 6: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 21: P2 ikoni (tilee 13)
    LD      A, 13 : OUT (VDP_DATA), A
    ; Tile 6: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 22: P2 elämät
    LD      A, (P2_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 28-31: seinä (4 kpl)
    LD      B, 4
    LD      A, 1
.ws2: OUT   (VDP_DATA), A : DJNZ .ws2
    RET

; =============================================================================
; ADD_SCORE_P1 — lisää 100 pistettä P1:lle (BCD)
; =============================================================================
ADD_SCORE_P1:
    LD      A, (P1_SCORE_H)
    ADD     A, 0x01
    DAA
    LD      (P1_SCORE_H), A
    RET

; =============================================================================
; ADD_SCORE_P2 — lisää 100 pistettä P2:lle
; =============================================================================
ADD_SCORE_P2:
    LD      A, (P2_SCORE_H)
    ADD     A, 0x01
    DAA
    LD      (P2_SCORE_H), A
    RET
