; =============================================================================
; maze.asm — Labyrinttidata ja piirtorutiinit
; =============================================================================

; Seinä- ja käytäväpatternit (ROM:issa ok, ei muutu)
WALL_PAT:   DB 0xFE,0xFE,0xFE,0x00,0xEF,0xEF,0xEF,0x00
FLOOR_PAT:  DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
WALL_COL:   DB 0x40,0x40,0x50,0x10,0x40,0x40,0x50,0x10
FLOOR_COL:  DB 0x10,0x10,0x10,0x10,0x10,0x10,0x10,0x10

; Kenttä 1 (ROM:issa ok, ei muutu)
MAZE:
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,1
    DB 1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1
    DB 1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,0,0,0,0,0,1
    DB 1,1,1,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1,1,1,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0,0,1,0,0,0,0,0,1
    DB 0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0
    DB 0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0
    DB 1,0,0,0,0,0,1,0,0,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,1,1,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1,1,1,1
    DB 1,0,0,0,0,0,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
    DB 1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1
    DB 1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1

; IS_WALL — törmäystarkistus
; Sisääntulo: B=X C=Y → Z=vapaa NZ=seinä
; Säästää HL, DE (BC ei muutu eikä tarvitse tallentaa)
IS_WALL:
    PUSH    HL
    PUSH    DE
    LD      A, B : SRL A : SRL A : SRL A : LD D, A    ; D = sarake = X/8
    LD      A, C : SRL A : SRL A : SRL A : LD E, A    ; E = rivi   = Y/8
    ; HUD-rivit (21+): käsittele erikseen jotta ei lueta MAZE:n ulkopuolelta
    LD      A, E : CP 21 : JR C, .normal
    JR      NZ, .wall                   ; rivi > 21 → seinä
    ; Rivi 21: ovi-aukot sarakkeilla 1-2 ja 29-30
    LD      A, D
    CP      1  : JR C,  .wall           ; sarake 0 → seinä
    CP      3  : JR C,  .free           ; sarakkeet 1-2 → ovi auki
    CP      29 : JR C,  .wall           ; sarakkeet 3-28 → seinä
    CP      31 : JR C,  .free           ; sarakkeet 29-30 → ovi auki
.wall:
    POP     DE : POP     HL : OR      1 : RET
.free:
    POP     DE : POP     HL : XOR     A : RET
.normal:
    LD      H, 0 : LD L, E
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL
    LD      A, L : ADD A, D : LD L, A
    LD      A, L : ADD A, LOW MAZE : LD L, A
    LD      A, H : ADC A, HIGH MAZE : LD H, A
    LD      A, (HL)
    POP     DE
    POP     HL
    OR      A
    RET

; LOAD_PATTERNS — lataa patternit VRAM:iin, HL = kohde
LOAD_PATTERNS:
    CALL    VDP_SETW
    LD      HL, FLOOR_PAT : LD B, 8
.f: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .f
    LD      HL, WALL_PAT  : LD B, 8
.w: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .w
    RET

; LOAD_COLORS — lataa värit VRAM:iin, HL = kohde
LOAD_COLORS:
    CALL    VDP_SETW
    LD      HL, FLOOR_COL : LD B, 8
.f: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .f
    LD      HL, WALL_COL  : LD B, 8
.w: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .w
    RET

; DRAW_MAZE — piirrä labyrintti name tableen
DRAW_MAZE:
    LD      HL, VRAM_NAMETABLE : CALL VDP_SETW
    LD      HL, MAZE
    LD      BC, 32*21
.lp:
    LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp
    RET


; =============================================================================
; FIND_PORTALS — skannaa labyrinttidata ja löytää porttirivit
; Etsii rivit joilla sarake 0 TAI sarake 31 on auki (=0)
; Tallentaa PORTAL_Y_MIN ja PORTAL_Y_MAX RAM:iin
; =============================================================================
FIND_PORTALS:
    LD      HL, MAZE
    LD      B, 21               ; 24 riviä
    LD      C, 0                ; rivi-laskuri
    LD      A, 0xFF
    LD      (PORTAL_Y_MIN), A   ; ei löydetty vielä
    XOR     A
    LD      (PORTAL_Y_MAX), A

.row_loop:
    ; Tarkista sarake 0 (ensimmäinen tavu rivillä)
    LD      A, (HL)
    OR      A                   ; 0 = auki
    JR      NZ, .check_col31

    ; Vasen reuna auki — tämä on porttirivi
    JR      .portal_row

.check_col31:
    ; Tarkista sarake 31 (viimeinen tavu rivillä = HL+31)
    PUSH    HL
    LD      DE, 31
    ADD     HL, DE
    LD      A, (HL)
    POP     HL
    OR      A
    JR      NZ, .not_portal

.portal_row:
    ; Laske Y-pikselit: rivi * 8
    LD      A, C
    RLCA : RLCA : RLCA          ; * 8

    ; Päivitä PORTAL_Y_MIN jos ei vielä asetettu
    PUSH    AF
    LD      A, (PORTAL_Y_MIN)
    CP      0xFF
    POP     AF
    JR      NZ, .update_max     ; min jo asetettu → päivitä vain max
    LD      (PORTAL_Y_MIN), A   ; tallenna min

.update_max:
    ; Max = tämä rivi + 7 (rivin alin pikseli)
    ADD     A, 7
    LD      (PORTAL_Y_MAX), A

.not_portal:
    ; Seuraava rivi
    LD      DE, 32
    ADD     HL, DE
    INC     C
    DJNZ    .row_loop

    ; Jos ei löydetty portteja, aseta turvallinen default
    LD      A, (PORTAL_Y_MIN)
    CP      0xFF
    JR      NZ, .done
    LD      A, 80  : LD (PORTAL_Y_MIN), A
    LD      A, 111 : LD (PORTAL_Y_MAX), A
.done:
    RET

; INIT_MAZE — lataa kaikki patternit ja piirtää kentän
INIT_MAZE:
    LD      HL, 0x0000 : CALL LOAD_PATTERNS
    LD      HL, 0x0800 : CALL LOAD_PATTERNS
    LD      HL, 0x1000 : CALL LOAD_PATTERNS
    LD      HL, 0x2000 : CALL LOAD_COLORS
    LD      HL, 0x2800 : CALL LOAD_COLORS
    LD      HL, 0x3000 : CALL LOAD_COLORS
    CALL    DRAW_MAZE
    RET

; INIT_NAVMAP — laskee risteyspisteet etukäteen NAVMAP-taulukkoon
; Kutsutaan kerran käynnistyksessä INIT_MAZE:n jälkeen.
; Joka (sarake, rivi) kohdalle tallennetaan 4-bittinen suuntakartta:
;   Bitti 0=RIGHT, 1=LEFT, 2=UP, 3=DOWN (0=ei kelvollinen paikka)
; 2×2-tileblokki täytyy olla vapaa ja kyseinen naapuritile vapaa.
INIT_NAVMAP:
    ; Nollaa NAVMAP
    XOR     A
    LD      HL, NAVMAP
    LD      (HL), A
    LD      DE, NAVMAP + 1
    LD      BC, 32*21 - 1
    LDIR

    ; IX = osoitin MAZE-taulukkoon (nykyinen solu)
    ; IY = osoitin NAVMAP-taulukkoon (nykyinen solu)
    ; D  = jäljellä olevia rivejä (23=rivi0 … 1=rivi22)
    ; E  = jäljellä olevia sarakkeita (31=sar0 … 1=sar30)
    LD      IX, MAZE
    LD      IY, NAVMAP
    LD      D, 20
.nv_row:
    LD      E, 31
.nv_col:
    ; Tarkista 2×2 blokki: kaikki neljä tileä täytyy olla vapaita
    LD      A, (IX+0)  : OR A : JR NZ, .nv_skip
    LD      A, (IX+1)  : OR A : JR NZ, .nv_skip
    LD      A, (IX+32) : OR A : JR NZ, .nv_skip
    LD      A, (IX+33) : OR A : JR NZ, .nv_skip

    ; Laske suuntabittikartta rekisteriin B
    LD      B, 0

    ; RIGHT: sar+2 ≤ 31 (E ≥ 2) ja molemmat tlet vapaita
    LD      A, E : CP 2 : JR C, .nv_nr
    LD      A, (IX+2)  : OR A : JR NZ, .nv_nr
    LD      A, (IX+34) : OR A : JR NZ, .nv_nr
    SET     0, B
.nv_nr:
    ; LEFT: sar > 0 (E < 31) ja molemmat tlet vapaita
    LD      A, E : CP 31 : JR Z, .nv_nl
    LD      A, (IX-1)  : OR A : JR NZ, .nv_nl
    LD      A, (IX+31) : OR A : JR NZ, .nv_nl
    SET     1, B
.nv_nl:
    ; UP: rivi > 0 (D < 20) ja molemmat tlet vapaita
    LD      A, D : CP 20 : JR Z, .nv_nu
    LD      A, (IX-32) : OR A : JR NZ, .nv_nu
    LD      A, (IX-31) : OR A : JR NZ, .nv_nu
    SET     2, B
.nv_nu:
    ; DOWN: rivi < 19 (D > 1) ja molemmat tlet vapaita
    LD      A, D : CP 1 : JR Z, .nv_nd
    LD      A, (IX+64) : OR A : JR NZ, .nv_nd
    LD      A, (IX+65) : OR A : JR NZ, .nv_nd
    SET     3, B
.nv_nd:
    LD      (IY+0), B
.nv_skip:
    INC     IX
    INC     IY
    DEC     E : JR NZ, .nv_col
    ; Ohita sarake 31 (siirry seuraavan rivin alkuun)
    INC     IX
    INC     IY
    DEC     D : JR NZ, .nv_row
    RET
