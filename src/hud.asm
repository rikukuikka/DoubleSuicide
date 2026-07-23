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

; Tile-numerot (DIGIT_PATS ladataan tilestä 2 alkaen)
; 10 digitiä (2-11) + 2 ikonia (12-13) + 26 kirjainta (14-39) + 1 ovi (40)
OVI_TILE    EQU 40

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
; Ovi-tile
    DB $55,$AA,$00,$00,$00,$00,$00,$00  ; Ylälaita
; Tutkan laidat
    DB $FF,$00,$00,$00,$00,$00,$00,$00 ; Ylälaita
    DB $00,$00,$00,$00,$00,$00,$00,$FF ; Alalaita
    DB $80,$80,$80,$80,$80,$80,$80,$80 ; Oikea laita
    DB $01,$01,$01,$01,$01,$01,$01,$01 ; Vasen laita
    DB $FF,$FF,$FF,$01,$EF,$EF,$EF,$01 ; Vasen laita muurin kohdalla
    DB $FE,$FE,$FE,$80,$EF,$EF,$EF,$80 ; Oikea laita muurin kohdalla


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
    LD      HL, 0x2000 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x2800 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x3000 + 16 : CALL LOAD_HUD_COLORS
    ; Tutkan reunatileiden väri (sininen mustalla) — vain pankki 2
    ; Tileet 41-46: reunat (6 tileä, kaikki rivit siniset). Tutkan sisältö
    ; (vihollisten sijainnit) piirretään DRAW_RADAR:issa spriteillä, ei tileillä.
    LD      HL, 0x3000 + 41*8 : CALL VDP_SETW
    LD      B, 6*8 : LD A, 0x41
.rc1: OUT   (VDP_DATA), A : DJNZ .rc1
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

LOAD_HUD_COLORS:
    CALL    VDP_SETW
    ; 10 numeroa * 8 tavua: valkoinen mustalla (0xF1)
    LD      B, 80
    LD      A, 0xF1
.c1: OUT    (VDP_DATA), A : DJNZ .c1
    ; P1 ikoni: 8 tavua sininen mustalla
    LD      B, 8
    LD      A, 0x41
.c2: OUT    (VDP_DATA), A : DJNZ .c2
    ; P2 ikoni: 8 tavua vihreä mustalla
    LD      B, 8
    LD      A, 0x21
.c3: OUT    (VDP_DATA), A : DJNZ .c3
    ; Kirjaimet A-Z: 26 * 8 = 208 tavua, valkoinen mustalla
    LD      B, 208
    LD      A, 0xF1
.c4: OUT    (VDP_DATA), A : DJNZ .c4
    ; Ovi-tile (40): 2 tavua 0x54 (pikselli-rivit 0-1), 6 tavua 0x51 (rivit 2-7)
    LD      B, 2
    LD      A, 0x54
.c5: OUT    (VDP_DATA), A : DJNZ .c5
    LD      B, 6
    LD      A, 0x51
.c6: OUT    (VDP_DATA), A : DJNZ .c6
    RET

; =============================================================================
; DRAW_HUD — piirrä pisteet ja elämät riville 23
; =============================================================================
DRAW_HUD:
    LD      A, (HUD_DIRTY) : OR A : RET Z  ; ei muutoksia → ohita
    XOR     A : LD (HUD_DIRTY), A           ; nollaa lippu

    ; Rivi 21 — oma VDP_SETW, jotta ajoitusvirhe ei siirrä rivin 23 osoitetta
    LD      HL, VRAM_NAMETABLE + 21*32 : CALL VDP_SETW
    ; Tile 0: seinä
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: ovi (2 kpl)
    LD      B, 2
    LD      A, OVI_TILE
.ds1: OUT    (VDP_DATA), A : DJNZ .ds1
    ; Tile 3-12: seinä (10 kpl)
    LD      B, 11
    LD      A, 1
.ws1: OUT   (VDP_DATA), A : DJNZ .ws1
    ; Tile 13: tutkan vasen laita muurin kohdalla
 ;   CALL    .vdp_dly
  ;  LD      A, RADAR_BORDER_L_WALL : OUT (VDP_DATA), A
    ; Tile 14-17: tutkan yläreuna (kiinteä, sisältö piirretään spriteillä)
    CALL    .vdp_dly
    LD      B, 4 : LD A, RADAR_BORDER_TOP
.rtop21: OUT (VDP_DATA), A : DJNZ .rtop21
    ; Tile 18: tutkan oikea laita muurin kohdalla
 ;   CALL    .vdp_dly
 ;   LD      A, RADAR_BORDER_R_WALL : OUT (VDP_DATA), A
    ; Tile 19-28: seinä (10 kpl)
    CALL    .vdp_dly
    LD      B, 11
    LD      A, 1
.ws1b: OUT  (VDP_DATA), A : DJNZ .ws1b
    ; Tile 30-31: ovi (2 kpl)
    LD      B, 2
    LD      A, OVI_TILE
.ds2: OUT    (VDP_DATA), A : DJNZ .ds2
    ; Tile 32: seinä
    LD      A, 1 : OUT (VDP_DATA), A

    ; Rivi 22 — oma VDP_SETW
    LD      HL, VRAM_NAMETABLE + 22*32 : CALL VDP_SETW
    ; Tile 0: seinä
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: tyhjä (2 kpl)
    LD      B, 2
    XOR     A
.sp1: OUT    (VDP_DATA), A : DJNZ .sp1
    ; Tile 3: seinä
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 4-12: tyhjä (9 kpl)
    LD      B, 9
    XOR     A
.sp2: OUT    (VDP_DATA), A : DJNZ .sp2
    ; Tile 13: tutkan vasen laita
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_L : OUT (VDP_DATA), A
    ; Tile 14-17: tyhjä (tutkan sisältö piirretään spriteillä)
    CALL    .vdp_dly
    LD      B, 4 : XOR A
.rmid22: OUT (VDP_DATA), A : DJNZ .rmid22
    ; Tile 18: tutkan oikea laita
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_R : OUT (VDP_DATA), A
    ; Tile 19-27: tyhjä (9 kpl)
    CALL    .vdp_dly
    LD      B, 9
    XOR     A
.sp2b: OUT   (VDP_DATA), A : DJNZ .sp2b
    ; Tile 29: seinä
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 30-31: tyhjä (2 kpl)
    LD      B, 2
    XOR     A
.sp3: OUT    (VDP_DATA), A : DJNZ .sp3
    ; Tile 32: seinä
    LD      A, 1 : OUT (VDP_DATA), A

    ; Rivi 23 — oma VDP_SETW takaa oikean osoitteen riippumatta rivien 21-22 ajoituksesta
    LD      HL, VRAM_NAMETABLE + 23*32 : CALL VDP_SETW
    ; Tile 0: seinä
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: tyhjä (2 kpl) — loop, CALL VDP_DELAY pitää ≥27T välin OUTien välillä
    NOP : NOP : NOP : NOP   ; 11T(LD B,2+XOR A)+16T(NOPs)=27T gap ✓
    LD      B, 2 : XOR A
.sp4: OUT    (VDP_DATA), A : CALL .vdp_dly : DJNZ .sp4
    ; Tile 3: seinä (DJNZ fall-through 8T + LD A,1 7T = 15T → lisää viivettä)
    NOP : NOP : NOP
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 4: P1 elämät (LD A,(nn) 13T + ADD 4T = 17T → tarvitaan viive)
    CALL    .vdp_dly
    LD      A, (P1_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 5: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 6: P1 ikoni (tilee 12)
    CALL    .vdp_dly : LD A, 12 : OUT (VDP_DATA), A
    ; Tile 7: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 8-11: P1 pisteet (4 BCD-numeroa) — LD A,(nn) antaa riittävän viiveen
    LD      A, (P1_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP                         ; 24T+4T=28T ≥ 27T ✓
    LD      A, (P1_SCORE_H) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P1_SCORE_L) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 12: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 13: tutkan vasen laita
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_L : OUT (VDP_DATA), A
    ; Tile 14-17: tutkan alareuna (kiinteä, sisältö piirretään spriteillä)
    CALL    .vdp_dly
    LD      B, 4 : LD A, RADAR_BORDER_BOTTOM
.rbot23: OUT (VDP_DATA), A : DJNZ .rbot23
    ; Tile 18: tutkan oikea laita
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_R : OUT (VDP_DATA), A
    ; Tile 19: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 20-23: P2 pisteet
    LD      A, (P2_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P2_SCORE_H) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P2_SCORE_L) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 24: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 25: P2 ikoni (tilee 13)
    CALL    .vdp_dly : LD A, 13 : OUT (VDP_DATA), A
    ; Tile 26: tyhjä
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 27: P2 elämät (LD A,(nn) 13T + ADD 4T = 17T → tarvitaan viive)
    CALL    .vdp_dly
    LD      A, (P2_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 28: seinä
    CALL    .vdp_dly : LD A, 1 : OUT (VDP_DATA), A
    ; Tile 29-30: tyhjä (2 kpl)
    NOP : NOP : NOP : NOP   ; 11T(LD B,2+XOR A)+16T=27T gap ✓
    LD      B, 2 : XOR A
.sp6: OUT    (VDP_DATA), A : CALL .vdp_dly : DJNZ .sp6
    ; Tile 31: seinä
    NOP : NOP : NOP
    LD      A, 1 : OUT (VDP_DATA), A
    RET
.vdp_dly:
    NOP                         ; CALL(17T) + NOP(4T) + RET(10T) = 31T gap
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
