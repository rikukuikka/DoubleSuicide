; =============================================================================
; player.asm — Pelaajasprite ja liikkuminen
; =============================================================================

; Sprite patternit (ROM:issa ok, ei muutu)
SPR_PATS:
    DB 0x18,0x3C,0x7E,0xFC,0xFC,0x7E,0x3C,0x18  ; 0=oikea
    DB 0x18,0x3C,0x7E,0x3F,0x3F,0x7E,0x3C,0x18  ; 1=vasen
    DB 0x18,0x3C,0x7E,0xFF,0x18,0x18,0x18,0x18  ; 2=ylös
    DB 0x18,0x18,0x18,0x18,0xFF,0x7E,0x3C,0x18  ; 3=alas
SPR_PATS_END:

; INIT_PLAYERS — alusta pelaajien RAM-data ja spritet
INIT_PLAYERS:
    ; RAM-arvot
    LD      A, 40        : LD (P1_X), A
    LD      A, 88        : LD (P1_Y), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
    LD      A, 174       : LD (P2_X), A
    LD      A, 88        : LD (P2_Y), A
    LD      A, DIR_LEFT  : LD (P2_DIR), A

    ; Sprite patternit VRAM:iin
    LD      HL, VRAM_SPRITE_PAT : CALL VDP_SETW
    LD      HL, SPR_PATS
    LD      BC, SPR_PATS_END - SPR_PATS
.lp:
    LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp

    ; Piilota kaikki 32 spriteä
    LD      HL, VRAM_SPRITE_ATT : CALL VDP_SETW
    LD      B, 32
.hs:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    DJNZ    .hs

    CALL    DRAW_P1
    CALL    DRAW_P2
    RET

; DRAW_P1 — piirrä P1 sprite VRAM:iin
DRAW_P1:
    LD      HL, VRAM_SPRITE_ATT : CALL VDP_SETW
    LD      A, (P1_Y) : OUT (VDP_DATA), A
    LD      A, (P1_X) : OUT (VDP_DATA), A
    LD      A, (P1_DIR) : OUT (VDP_DATA), A
    LD      A, P1_COLOR : OUT (VDP_DATA), A
    RET

; DRAW_P2 — piirrä P2 sprite VRAM:iin
DRAW_P2:
    LD      HL, VRAM_SPRITE_ATT + 4 : CALL VDP_SETW
    LD      A, (P2_Y) : OUT (VDP_DATA), A
    LD      A, (P2_X) : OUT (VDP_DATA), A
    LD      A, (P2_DIR) : OUT (VDP_DATA), A
    LD      A, P2_COLOR : OUT (VDP_DATA), A
    RET


; =============================================================================
; SNAP_TO_GRID_Y — kohdista Y lähimpään 8px rajaan (toleranssi 3px)
; Käytetään kun liikutaan vaaka-suunnassa (vasen/oikea)
; Sisääntulo:  A = nykyinen Y
; Ulostulo:    A = kohdistettu Y (tai alkuperäinen jos ei tarpeeksi lähellä)
; =============================================================================
SNAP_TO_GRID_Y:
    LD      B, A            ; B = Y
    AND     0x07            ; A = Y mod 8 (jäännös)
    CP      4               ; jäännös >= 4 → pyöristä ylöspäin
    JR      NC, .round_up
    ; Pyöristä alaspäin (nollaa alimmat 3 bittiä)
    LD      A, B
    AND     0xF8
    RET
.round_up:
    LD      A, B
    AND     0xF8
    ADD     A, 8
    RET

; SNAP_TO_GRID_X — kohdista X lähimpään 8px rajaan (toleranssi 3px)
; Käytetään kun liikutaan pystysuunnassa (ylös/alas)
; Sisääntulo:  A = nykyinen X
; Ulostulo:    A = kohdistettu X
SNAP_TO_GRID_X:
    LD      B, A
    AND     0x07
    CP      4
    JR      NC, .round_up
    LD      A, B
    AND     0xF8
    RET
.round_up:
    LD      A, B
    AND     0xF8
    ADD     A, 8
    RET

; IN_PORTAL — tarkista onko Y porttivälin sisällä
; Sisääntulo: A = Y
; Ulostulo:   Z=1 jos portissa, Z=0 jos ei
IN_PORTAL:
    ; Sisääntulo: A = Y-koordinaatti
    ; Ulostulo: Z=1 jos portissa (Y >= PORTAL_Y_MIN ja Y <= PORTAL_Y_MAX)
    CP      PORTAL_Y_MIN    ; A < MIN?
    JR      C, .no          ; kyllä → ei portissa
    CP      PORTAL_Y_MAX+1  ; A > MAX?
    JR      NC, .no         ; kyllä → ei portissa
    XOR     A               ; Z=1 = portissa
    RET
.no:
    OR      1               ; Z=0 = ei portissa
    RET

; UPDATE_PLAYERS — liikuta molemmat pelaajat inputin mukaan
UPDATE_PLAYERS:
    ; --- P1 ---
    LD      A, (P1_INPUT) : AND IN_UP : JR Z, .p1nu
    LD      A, (P1_Y) : SUB SPEED : CP 8 : JR C, .p1nu : LD E, A
    ; Snap X ruuturajaan
    LD      A, (P1_X) : CALL SNAP_TO_GRID_X : LD D, A
    LD      B, D : LD C, E : CALL IS_WALL : JR NZ, .p1nu
    LD      A, D : ADD A, 7 : LD B, A : LD C, E : CALL IS_WALL : JR NZ, .p1nu
    LD      A, E : LD (P1_Y), A : LD A, D : LD (P1_X), A
    LD      A, DIR_UP : LD (P1_DIR), A
.p1nu:
    LD      A, (P1_INPUT) : AND IN_DOWN : JR Z, .p1nd
    LD      A, (P1_Y) : ADD A, SPEED : CP 176 : JR NC, .p1nd : LD E, A
    ; Snap X ruuturajaan
    LD      A, (P1_X) : CALL SNAP_TO_GRID_X : LD D, A
    LD      B, D : LD A, E : ADD A, 7 : LD C, A : CALL IS_WALL : JR NZ, .p1nd
    LD      A, D : ADD A, 7 : LD B, A : LD A, E : ADD A, 7 : LD C, A : CALL IS_WALL : JR NZ, .p1nd
    LD      A, E : LD (P1_Y), A : LD A, D : LD (P1_X), A
    LD      A, DIR_DOWN : LD (P1_DIR), A
.p1nd:
    LD      A, (P1_INPUT) : AND IN_LEFT : JR Z, .p1nl
    ; Porttitarkistus: jos porttikorkeudella ja X <= 8
    LD      A, (P1_X) : CP 3 : JR NC, .p1l_noport
    LD      A, (P1_Y) : CALL IN_PORTAL : JR NZ, .p1nl
    LD      A, 248 : LD (P1_X), A
    LD      A, DIR_LEFT : LD (P1_DIR), A
    JR      .p1nl
.p1l_noport:
    LD      A, (P1_X) : SUB SPEED : JR C, .p1nl : LD E, A
    LD      A, (P1_Y) : CALL SNAP_TO_GRID_Y : LD D, A
    LD      B, E : LD A, D : ADD A, 1 : LD C, A : CALL IS_WALL : JR NZ, .p1nl
    LD      B, E : LD A, D : ADD A, 6 : LD C, A : CALL IS_WALL : JR NZ, .p1nl
    LD      A, E : LD (P1_X), A : LD A, D : LD (P1_Y), A
    LD      A, DIR_LEFT : LD (P1_DIR), A
.p1nl:
    LD      A, (P1_INPUT) : AND IN_RIGHT : JR Z, .p1nr
    ; Porttitarkistus: jos porttikorkeudella ja X >= 240
    LD      A, (P1_X) : CP 248 : JR C, .p1r_noport
    LD      A, (P1_Y) : CALL IN_PORTAL : JR NZ, .p1r_noport
    LD      A, 0 : LD (P1_X), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
    JR      .p1nr
.p1r_noport:
    LD      A, (P1_X) : ADD A, SPEED : CP 249 : JR NC, .p1nr : LD E, A
    LD      A, (P1_Y) : CALL SNAP_TO_GRID_Y : LD D, A
    LD      A, E : ADD A, 7 : LD B, A : LD A, D : ADD A, 1 : LD C, A : CALL IS_WALL : JR NZ, .p1nr
    LD      A, E : ADD A, 7 : LD B, A : LD A, D : ADD A, 6 : LD C, A : CALL IS_WALL : JR NZ, .p1nr
    LD      A, E : LD (P1_X), A : LD A, D : LD (P1_Y), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
.p1nr:
    CALL    DRAW_P1

    ; --- P2 ---
    LD      A, (P2_INPUT) : AND IN_UP : JR Z, .p2nu
    LD      A, (P2_Y) : SUB SPEED : CP 8 : JR C, .p2nu : LD E, A
    LD      A, (P2_X) : CALL SNAP_TO_GRID_X : LD D, A
    LD      B, D : LD C, E : CALL IS_WALL : JR NZ, .p2nu
    LD      A, D : ADD A, 7 : LD B, A : LD C, E : CALL IS_WALL : JR NZ, .p2nu
    LD      A, E : LD (P2_Y), A : LD A, D : LD (P2_X), A
    LD      A, DIR_UP : LD (P2_DIR), A
.p2nu:
    LD      A, (P2_INPUT) : AND IN_DOWN : JR Z, .p2nd
    LD      A, (P2_Y) : ADD A, SPEED : CP 176 : JR NC, .p2nd : LD E, A
    LD      A, (P2_X) : CALL SNAP_TO_GRID_X : LD D, A
    LD      B, D : LD A, E : ADD A, 7 : LD C, A : CALL IS_WALL : JR NZ, .p2nd
    LD      A, D : ADD A, 7 : LD B, A : LD A, E : ADD A, 7 : LD C, A : CALL IS_WALL : JR NZ, .p2nd
    LD      A, E : LD (P2_Y), A : LD A, D : LD (P2_X), A
    LD      A, DIR_DOWN : LD (P2_DIR), A
.p2nd:
    LD      A, (P2_INPUT) : AND IN_LEFT : JR Z, .p2nl
    LD      A, (P2_X) : CP 3 : JR NC, .p2l_noport
    LD      A, (P2_Y) : CALL IN_PORTAL : JR NZ, .p2nl
    LD      A, 248 : LD (P2_X), A
    LD      A, DIR_LEFT : LD (P2_DIR), A
    JR      .p2nl
.p2l_noport:
    LD      A, (P2_X) : SUB SPEED : JR C, .p2nl : LD E, A
    LD      A, (P2_Y) : CALL SNAP_TO_GRID_Y : LD D, A
    LD      B, E : LD A, D : ADD A, 1 : LD C, A : CALL IS_WALL : JR NZ, .p2nl
    LD      B, E : LD A, D : ADD A, 6 : LD C, A : CALL IS_WALL : JR NZ, .p2nl
    LD      A, E : LD (P2_X), A : LD A, D : LD (P2_Y), A
    LD      A, DIR_LEFT : LD (P2_DIR), A
.p2nl:
    LD      A, (P2_INPUT) : AND IN_RIGHT : JR Z, .p2nr
    LD      A, (P2_X) : CP 248 : JR C, .p2r_noport
    LD      A, (P2_Y) : CALL IN_PORTAL : JR NZ, .p2r_noport
    LD      A, 0 : LD (P2_X), A
    LD      A, DIR_RIGHT : LD (P2_DIR), A
    JR      .p2nr
.p2r_noport:
    LD      A, (P2_X) : ADD A, SPEED : CP 249 : JR NC, .p2nr : LD E, A
    LD      A, (P2_Y) : CALL SNAP_TO_GRID_Y : LD D, A
    LD      A, E : ADD A, 7 : LD B, A : LD A, D : ADD A, 1 : LD C, A : CALL IS_WALL : JR NZ, .p2nr
    LD      A, E : ADD A, 7 : LD B, A : LD A, D : ADD A, 6 : LD C, A : CALL IS_WALL : JR NZ, .p2nr
    LD      A, E : LD (P2_X), A : LD A, D : LD (P2_Y), A
    LD      A, DIR_RIGHT : LD (P2_DIR), A
.p2nr:
    CALL    DRAW_P2
    RET
