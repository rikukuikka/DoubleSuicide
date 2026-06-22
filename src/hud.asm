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
    DB 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF  ; P1 ikoni
    DB 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF  ; P2 ikoni
DIGIT_PATS_END:

; =============================================================================
; INIT_HUD — lataa HUD-patternit ja -värit VRAM:iin
; =============================================================================
INIT_HUD:
    ; Lataa digit+ikoni patternit kolmeen pankkiin (offset 16 = tilee 2 alkaen)
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
    ; P2 ikoni: 8 tavua violetti mustalla (0xD1)
    LD      B, 8
    LD      A, 0xD1
.c3: OUT    (VDP_DATA), A : DJNZ .c3
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
    ; Tile 4: P1 ikoni (tilee 12)
    LD      A, 12 : OUT (VDP_DATA), A
    ; Tile 5: P1 elämät
    LD      A, (P1_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 6: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 7-10: P1 pisteet (4 BCD-numeroa)
    LD      A, (P1_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_H)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 11-20: tyhjä (10 kpl)
    LD      B, 10
    XOR     A
.sp: OUT    (VDP_DATA), A : DJNZ .sp
    ; Tile 21: P2 ikoni (tilee 13)
    LD      A, 13 : OUT (VDP_DATA), A
    ; Tile 22: P2 elämät
    LD      A, (P2_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 23: tyhjä
    XOR     A : OUT (VDP_DATA), A
    ; Tile 24-27: P2 pisteet
    LD      A, (P2_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_H)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    AND     0x0F : ADD A, 2 : OUT (VDP_DATA), A
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
