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
    DB #28,#6C,#C6,#C6,#C6,#C6,#6C,#28  ; '0'
    DB #18,#38,#18,#18,#18,#18,#18,#7E  ; '1'
    DB #58,#CC,#8E,#1C,#38,#62,#FE,#BC  ; '2'
    DB #5C,#C6,#46,#1C,#1C,#46,#C6,#5C  ; '3'
    DB #0C,#0C,#2C,#4C,#8C,#EE,#0C,#1E  ; '4'
    DB #72,#FC,#80,#DC,#0E,#06,#CE,#5C  ; '5'
    DB #34,#62,#C6,#C0,#DC,#C6,#66,#34  ; '6'
    DB #BA,#FE,#F8,#86,#0C,#1E,#1E,#0C  ; '7'
    DB #6C,#EE,#C6,#6C,#6C,#C6,#EE,#6C  ; '8'
    DB #58,#CC,#C6,#E6,#76,#06,#CC,#58  ; '9'
; Pelaaja-ikonit (tileet 12, 13) — täytetty neliö
    DB $30,$78,$FF,$FC,$F4,$FE,$F8,$7C  ; P1 ikoni
    DB $0C,$1E,$FF,$3F,$2F,$7F,$1F,$3E  ; P2 ikoni
; Patterns 14-39: kirjaimet A-Z
    DB #30,#30,#38,#58,#48,#5C,#4C,#DE  ; 'A'
    DB #EC,#66,#66,#6C,#6C,#66,#66,#EC  ; 'B'
    DB #36,#66,#C2,#C0,#C0,#C2,#62,#34  ; 'C'
    DB #EC,#6E,#66,#66,#66,#66,#6E,#EC  ; 'D'
    DB #EE,#66,#62,#68,#68,#62,#66,#EE  ; 'E'
    DB #EE,#66,#62,#6C,#68,#60,#60,#F0  ; 'F'
    DB #36,#62,#C0,#C0,#CE,#C6,#66,#36  ; 'G'
    DB #E6,#66,#66,#66,#7E,#66,#66,#E6  ; 'H'
    DB #7C,#38,#38,#38,#38,#38,#38,#7C  ; 'I'
    DB #1E,#0C,#0C,#0C,#0C,#CC,#CC,#58  ; 'J'
    DB #E6,#62,#64,#68,#6C,#6C,#66,#E6  ; 'K'
    DB #F0,#60,#60,#60,#60,#62,#66,#EE  ; 'L'
    DB #C6,#C6,#6E,#6E,#B6,#B6,#96,#96  ; 'M'
    DB #C6,#E2,#F2,#7A,#3C,#9E,#8E,#C6  ; 'N'
    DB #6C,#C6,#C6,#C6,#C6,#C6,#C6,#6C  ; 'O'
    DB #EC,#66,#66,#66,#6C,#60,#60,#F0  ; 'P'
    DB #6C,#C6,#C6,#C6,#C6,#D6,#6C,#0E  ; 'Q'  ;; UUSI
    DB #EC,#66,#66,#66,#6C,#6C,#66,#E6  ; 'R'
    DB #7A,#E6,#E2,#78,#3C,#8E,#CE,#BC  ; 'S'
    DB #FE,#FE,#BA,#38,#38,#38,#38,#7C  ; 'T'
    DB #F6,#62,#62,#62,#62,#62,#62,#34  ; 'U'
    DB #F6,#62,#62,#34,#34,#34,#18,#18  ; 'V'
    DB #C2,#C2,#C2,#5A,#5A,#7E,#24,#24  ; 'W'
    DB #EE,#6C,#6C,#38,#38,#6C,#6C,#EE  ; 'X'  ;; UUSI
    DB #F6,#62,#74,#38,#18,#18,#18,#3C  ; 'Y'
    DB #FE,#86,#0C,#18,#30,#60,#C2,#FE  ; 'Z'  ;; UUSI
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
    ; Merkitse likainen ja piirrä HUD
    LD      A, 1 : LD (HUD_DIRTY), A
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
    ; P1 ikoni: 8 tavua sininen mustalla (0x21)
    LD      B, 8
    LD      A, 0x41
.c2: OUT    (VDP_DATA), A : DJNZ .c2
    ; P2 ikoni: 8 tavua vihreä mustalla (0x41)
    LD      B, 8
    LD      A, 0x21
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
    LD      A, (HUD_DIRTY) : OR A : RET Z  ; ei muutoksia → ohita
    XOR     A : LD (HUD_DIRTY), A           ; nollaa lippu
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
    LD      A, 1 : LD (HUD_DIRTY), A
    RET

; =============================================================================
; ADD_SCORE_P2 — lisää 100 pistettä P2:lle
; =============================================================================
ADD_SCORE_P2:
    LD      A, (P2_SCORE_H)
    ADD     A, 0x01
    DAA
    LD      (P2_SCORE_H), A
    LD      A, 1 : LD (HUD_DIRTY), A
    RET
