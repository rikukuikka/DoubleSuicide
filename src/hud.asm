; =============================================================================
; hud.asm — Score and lives
; =============================================================================
;
; Name table row 23 (bottom) = HUD
; Tiles:  0=blank(black) 1=wall 2-11=digit 0-9  12=P1 icon  13=P2 icon
;
; Row 23 layout:
;   ■ 3  0000                ■ 3  0000
;   0 1 2 3456  7...23  24 25 26 27282930 31

; Tile numbers (DIGIT_PATS is loaded starting at tile 2)
; 10 digits (2-11) + 2 icons (12-13) + 26 letters (14-39) + 1 door (40)
OVI_TILE    EQU 40

; RAM
P1_SCORE_H  EQU 0xC070      ; BCD: thousands/hundreds
P1_SCORE_L  EQU 0xC071      ; BCD: tens/ones
P2_SCORE_H  EQU 0xC072
P2_SCORE_L  EQU 0xC073

; Digit patterns 0-9 (tiles 2-11)
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
; Player icons (tiles 12, 13) — filled square
    DB $30,$78,$FF,$FC,$F4,$FE,$F8,$7C  ; P1 icon
    DB $0C,$1E,$FF,$3F,$2F,$7F,$1F,$3E  ; P2 icon
; Patterns 14-39: letters A-Z
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
    DB #6C,#C6,#C6,#C6,#C6,#D6,#6C,#0E  ; 'Q'  ;; NEW
    DB #EC,#66,#66,#66,#6C,#6C,#66,#E6  ; 'R'
    DB #7A,#E6,#E2,#78,#3C,#8E,#CE,#BC  ; 'S'
    DB #FE,#FE,#BA,#38,#38,#38,#38,#7C  ; 'T'
    DB #F6,#62,#62,#62,#62,#62,#62,#34  ; 'U'
    DB #F6,#62,#62,#34,#34,#34,#18,#18  ; 'V'
    DB #C2,#C2,#C2,#5A,#5A,#7E,#24,#24  ; 'W'
    DB #EE,#6C,#6C,#38,#38,#6C,#6C,#EE  ; 'X'  ;; NEW
    DB #F6,#62,#74,#38,#18,#18,#18,#3C  ; 'Y'
    DB #FE,#86,#0C,#18,#30,#60,#C2,#FE  ; 'Z'  ;; NEW
; Door tile
    DB $55,$AA,$00,$00,$00,$00,$00,$00  ; Top edge
; Radar edges
    DB $FF,$00,$00,$00,$00,$00,$00,$00 ; Top edge
    DB $00,$00,$00,$00,$00,$00,$00,$FF ; Bottom edge
    DB $80,$80,$80,$80,$80,$80,$80,$80 ; Right edge
    DB $01,$01,$01,$01,$01,$01,$01,$01 ; Left edge


DIGIT_PATS_END:

; =============================================================================
; INIT_HUD — load the HUD patterns and colors into VRAM
; =============================================================================
INIT_HUD:
    ; Load pattern 0 (blank) into all banks — the title screen background
    LD      HL, 0x0000 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z0: OUT    (VDP_DATA), A : DJNZ .z0
    LD      HL, 0x0800 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z1: OUT    (VDP_DATA), A : DJNZ .z1
    LD      HL, 0x1000 : CALL VDP_SETW
    LD      B, 8 : XOR A
.z2: OUT    (VDP_DATA), A : DJNZ .z2
    ; Pattern 0's color (black) into all banks
    LD      HL, 0x2000 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc0: OUT   (VDP_DATA), A : DJNZ .zc0
    LD      HL, 0x2800 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc1: OUT   (VDP_DATA), A : DJNZ .zc1
    LD      HL, 0x3000 : CALL VDP_SETW
    LD      B, 8 : LD A, 0x11
.zc2: OUT   (VDP_DATA), A : DJNZ .zc2
    ; Load the digit+icon+letter patterns into all three banks
    LD      HL, 0x0000 + 16 : CALL .load_dp
    LD      HL, 0x0800 + 16 : CALL .load_dp
    LD      HL, 0x1000 + 16 : CALL .load_dp
    ; Load the colors into all three banks
    LD      HL, 0x2000 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x2800 + 16 : CALL LOAD_HUD_COLORS
    LD      HL, 0x3000 + 16 : CALL LOAD_HUD_COLORS
    ; Color of the radar's border tiles (blue on black) — bank 2 only
    ; Tiles 41-44: borders (4 tiles, all rows blue). The radar's contents
    ; (enemy positions) are drawn by DRAW_RADAR using sprites, not tiles.
    LD      HL, 0x3000 + 41*8 : CALL VDP_SETW
    LD      B, 4*8 : LD A, 0x41
.rc1: OUT   (VDP_DATA), A : DJNZ .rc1
    ; Reset the score
    XOR     A
    LD      (P1_SCORE_H), A : LD (P1_SCORE_L), A
    LD      (P2_SCORE_H), A : LD (P2_SCORE_L), A
    ; Mark dirty and draw the HUD
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
    ; 10 digits * 8 bytes: white on black (0xF1)
    LD      B, 80
    LD      A, 0xF1
.c1: OUT    (VDP_DATA), A : DJNZ .c1
    ; P1 icon: 8 bytes blue on black
    LD      B, 8
    LD      A, 0x41
.c2: OUT    (VDP_DATA), A : DJNZ .c2
    ; P2 icon: 8 bytes green on black
    LD      B, 8
    LD      A, 0x21
.c3: OUT    (VDP_DATA), A : DJNZ .c3
    ; Letters A-Z: 26 * 8 = 208 bytes, white on black
    LD      B, 208
    LD      A, 0xF1
.c4: OUT    (VDP_DATA), A : DJNZ .c4
    ; Door tile (40): 2 bytes 0x54 (pixel rows 0-1), 6 bytes 0x51 (rows 2-7)
    LD      B, 2
    LD      A, 0x54
.c5: OUT    (VDP_DATA), A : DJNZ .c5
    LD      B, 6
    LD      A, 0x51
.c6: OUT    (VDP_DATA), A : DJNZ .c6
    RET

; =============================================================================
; DRAW_HUD — draw the score and lives on row 23
; =============================================================================
DRAW_HUD:
    LD      A, (HUD_DIRTY) : OR A : RET Z  ; no changes → skip
    XOR     A : LD (HUD_DIRTY), A           ; clear the flag

    ; Row 21 — its own VDP_SETW, so a timing error doesn't shift row 23's address
    LD      HL, VRAM_NAMETABLE + 21*32 : CALL VDP_SETW
    ; Tile 0: wall
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: door (2x)
    LD      B, 2
    LD      A, OVI_TILE
.ds1: OUT    (VDP_DATA), A : DJNZ .ds1
    ; Tile 3-13: wall (11x — includes the radar's side edges, drawn as plain wall here)
    LD      B, 11
    LD      A, 1
.ws1: OUT   (VDP_DATA), A : DJNZ .ws1
    ; Tile 14-17: radar's top edge (fixed, contents drawn as sprites)
    CALL    .vdp_dly
    LD      B, 4 : LD A, RADAR_BORDER_TOP
.rtop21: OUT (VDP_DATA), A : DJNZ .rtop21
    ; Tile 18-28: wall (11x)
    CALL    .vdp_dly
    LD      B, 11
    LD      A, 1
.ws1b: OUT  (VDP_DATA), A : DJNZ .ws1b
    ; Tile 30-31: door (2x)
    LD      B, 2
    LD      A, OVI_TILE
.ds2: OUT    (VDP_DATA), A : DJNZ .ds2
    ; Tile 32: wall
    LD      A, 1 : OUT (VDP_DATA), A

    ; Row 22 — its own VDP_SETW
    LD      HL, VRAM_NAMETABLE + 22*32 : CALL VDP_SETW
    ; Tile 0: wall
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: blank (2x)
    LD      B, 2
    XOR     A
.sp1: OUT    (VDP_DATA), A : DJNZ .sp1
    ; Tile 3: wall
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 4-12: blank (9x)
    LD      B, 9
    XOR     A
.sp2: OUT    (VDP_DATA), A : DJNZ .sp2
    ; Tile 13: radar's left edge
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_L : OUT (VDP_DATA), A
    ; Tile 14-17: blank (the radar's contents are drawn as sprites)
    CALL    .vdp_dly
    LD      B, 4 : XOR A
.rmid22: OUT (VDP_DATA), A : DJNZ .rmid22
    ; Tile 18: radar's right edge
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_R : OUT (VDP_DATA), A
    ; Tile 19-27: blank (9x)
    CALL    .vdp_dly
    LD      B, 9
    XOR     A
.sp2b: OUT   (VDP_DATA), A : DJNZ .sp2b
    ; Tile 29: wall
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 30-31: blank (2x)
    LD      B, 2
    XOR     A
.sp3: OUT    (VDP_DATA), A : DJNZ .sp3
    ; Tile 32: wall
    LD      A, 1 : OUT (VDP_DATA), A

    ; Row 23 — its own VDP_SETW guarantees the correct address regardless of rows 21-22's timing
    LD      HL, VRAM_NAMETABLE + 23*32 : CALL VDP_SETW
    ; Tile 0: wall
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 1-2: blank (2x) — loop, CALL VDP_DELAY keeps a >=27T gap between OUTs
    NOP : NOP : NOP : NOP   ; 11T(LD B,2+XOR A)+16T(NOPs)=27T gap OK
    LD      B, 2 : XOR A
.sp4: OUT    (VDP_DATA), A : CALL .vdp_dly : DJNZ .sp4
    ; Tile 3: wall (DJNZ fall-through 8T + LD A,1 7T = 15T → needs more delay)
    NOP : NOP : NOP
    LD      A, 1 : OUT (VDP_DATA), A
    ; Tile 4: P1 lives (LD A,(nn) 13T + ADD 4T = 17T → needs a delay)
    CALL    .vdp_dly
    LD      A, (P1_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 5: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 6: P1 icon (tile 12)
    CALL    .vdp_dly : LD A, 12 : OUT (VDP_DATA), A
    ; Tile 7: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 8-11: P1 score (4 BCD digits) — LD A,(nn) gives enough delay
    LD      A, (P1_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP                         ; 24T+4T=28T >= 27T OK
    LD      A, (P1_SCORE_H) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P1_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P1_SCORE_L) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 12: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 13: radar's left edge
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_L : OUT (VDP_DATA), A
    ; Tile 14-17: radar's bottom edge (fixed, contents drawn as sprites)
    CALL    .vdp_dly
    LD      B, 4 : LD A, RADAR_BORDER_BOTTOM
.rbot23: OUT (VDP_DATA), A : DJNZ .rbot23
    ; Tile 18: radar's right edge
    CALL    .vdp_dly
    LD      A, RADAR_BORDER_R : OUT (VDP_DATA), A
    ; Tile 19: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 20-23: P2 score
    LD      A, (P2_SCORE_H)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P2_SCORE_H) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    LD      A, (P2_SCORE_L)
    RRCA : RRCA : RRCA : RRCA : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    NOP
    LD      A, (P2_SCORE_L) : AND 0x0F : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 24: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 25: P2 icon (tile 13)
    CALL    .vdp_dly : LD A, 13 : OUT (VDP_DATA), A
    ; Tile 26: blank
    CALL    .vdp_dly : XOR A : OUT (VDP_DATA), A
    ; Tile 27: P2 lives (LD A,(nn) 13T + ADD 4T = 17T → needs a delay)
    CALL    .vdp_dly
    LD      A, (P2_LIVES) : ADD A, 2 : OUT (VDP_DATA), A
    ; Tile 28: wall
    CALL    .vdp_dly : LD A, 1 : OUT (VDP_DATA), A
    ; Tile 29-30: blank (2x)
    NOP : NOP : NOP : NOP   ; 11T(LD B,2+XOR A)+16T=27T gap OK
    LD      B, 2 : XOR A
.sp6: OUT    (VDP_DATA), A : CALL .vdp_dly : DJNZ .sp6
    ; Tile 31: wall
    NOP : NOP : NOP
    LD      A, 1 : OUT (VDP_DATA), A
    RET
.vdp_dly:
    NOP                         ; CALL(17T) + NOP(4T) + RET(10T) = 31T gap
    RET

; =============================================================================
; ADD_SCORE_P1 — add 100 points for P1 (BCD)
; =============================================================================
ADD_SCORE_P1:
    LD      A, (P1_SCORE_H)
    ADD     A, 0x01
    DAA
    LD      (P1_SCORE_H), A
    LD      A, 1 : LD (HUD_DIRTY), A
    RET

; =============================================================================
; ADD_SCORE_P2 — add 100 points for P2
; =============================================================================
ADD_SCORE_P2:
    LD      A, (P2_SCORE_H)
    ADD     A, 0x01
    DAA
    LD      (P2_SCORE_H), A
    LD      A, 1 : LD (HUD_DIRTY), A
    RET
