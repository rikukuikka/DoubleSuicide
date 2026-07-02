; =============================================================================
; enemy.asm — Viholliset
; =============================================================================
;
; Vihollisen tietorakenne (8 tavua, IX-rekisterin kautta):
;   IX+0: X
;   IX+1: Y
;   IX+2: suunta (DIR_*)
;   IX+3: tyyppi (ENEMY_WORRIT jne.)
;   IX+4: aktiivinen (1=kyllä)
;   IX+5-7: varattu

ENEMY_NONE      EQU 0
ENEMY_WORRIT    EQU 1
ENEMY_SIZE      EQU 8
MAX_ENEMIES     EQU 6

ENEMIES         EQU 0xC010      ; 6*8=48 tavua RAM:issa
RAND_SEED       EQU 0xC040      ; 2 tavua

WORRIT_COLOR    EQU 14          ; keltainen

WORRIT_PATS:
    ; 16x16 Worrit (pattern 8 = offset 64, yksi frame)
    ; Vasen puoli ylä (rivit 0-7)
    DB 0x03,0x0F,0x1F,0x3F,0x3B,0x3B,0x3F,0x3F
    ; Vasen puoli ala (rivit 8-15)
    DB 0x3F,0x3F,0x3F,0x3F,0x3B,0x2D,0x00,0x00
    ; Oikea puoli ylä (rivit 0-7)
    DB 0xC0,0xF0,0xF8,0xFC,0xDC,0xDC,0xFC,0xFC
    ; Oikea puoli ala (rivit 8-15)
    DB 0xFC,0xFC,0xFC,0xFC,0xDC,0xB4,0x00,0x00
WORRIT_PATS_END:

; =============================================================================
; RAND — 16-bit LFSR satunnaisluku, ulostulo A
; =============================================================================
RAND:
    PUSH    HL
    LD      HL, (RAND_SEED)
    ; LFSR tap bits 16,14,13,11
    LD      A, H : RLA
    RL      L : RL H
    LD      A, H : XOR L : LD A, H
    XOR     L
    RRA
    XOR     H
    AND     0x01
    OR      H
    LD      H, A
    LD      (RAND_SEED), HL
    LD      A, L
    POP     HL
    RET

; =============================================================================
; INIT_ENEMIES
; =============================================================================
INIT_ENEMIES:
    ; Alusta LFSR siemen
    LD      HL, 0xACE1 : LD (RAND_SEED), HL

    ; Lataa sprite patternit (pattern 4 alkaen)
    LD      HL, VRAM_SPRITE_PAT + 256 : CALL VDP_SETW  ; 16x16: pelaaja vie 256 tavua (4 suuntaa × 2 framea)
    LD      HL, WORRIT_PATS
    LD      B, WORRIT_PATS_END - WORRIT_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .pp

    ; Nollaa kaikki
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr

    ; Luo 3 Worrittia
    LD      IX, ENEMIES
    CALL    SPAWN_WORRIT
    LD      IX, ENEMIES + ENEMY_SIZE
    CALL    SPAWN_WORRIT
    LD      IX, ENEMIES + ENEMY_SIZE*2
    CALL    SPAWN_WORRIT
    RET

; SPAWN_WORRIT — luo Worrit IX-osoitteeseen satunnaiseen vapaaseen paikkaan
SPAWN_WORRIT:
    LD      B, 64               ; enemmän yrityksiä
.try:
    PUSH    BC
    ; 16px-kohdistettu satunnaispaikka
    CALL    RAND : AND 0xF0 : LD (IX+0), A               ; X: 0-240, 16px askel
    CALL    RAND : AND 0x70 : ADD A, 16 : LD (IX+1), A   ; Y: 16-128, 16px askel
    ; Tarkista kaikki 4 kulmaa (16x16 alue)
    LD      B, (IX+0) : LD C, (IX+1) : CALL IS_WALL                      ; vasen ylä
    JR      NZ, .bad
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL ; oikea ylä
    JR      NZ, .bad
    LD      B, (IX+0) : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL ; vasen ala
    JR      NZ, .bad
    LD      A, (IX+0) : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL                ; oikea ala
    JR      NZ, .bad
    ; Kaikki vapaat
    POP     BC
    JR      .found
.bad:
    POP     BC
    DJNZ    .try
    ; Fallback: tunnettu vapaa paikka
    LD      A, 80 : LD (IX+0), A
    LD      A, 48 : LD (IX+1), A
.found:
    CALL    RAND : AND 0x03 : LD (IX+2), A   ; satunnainen suunta
    LD      (IX+3), ENEMY_WORRIT
    LD      (IX+4), 1
    RET

; =============================================================================
; UPDATE_WORRIT — liikuta yksi Worrit (IX = data)
; =============================================================================
UPDATE_WORRIT:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    ; Kokeile liikkua nykyiseen suuntaan
    CP      DIR_UP : JR NZ, .not_up
    LD      A, (IX+1) : SUB SPEED : CP 8 : JP C, .change
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .change
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .change
    LD      (IX+1), E : JP .maybe_turn
.not_up:
    CP      DIR_DOWN : JR NZ, .not_down
    LD      A, (IX+1) : ADD A, SPEED : CP 176 : JP NC, .change
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+1), E : JP .maybe_turn
.not_down:
    CP      DIR_LEFT : JR NZ, .not_left
    LD      A, (IX+0) : SUB SPEED : JP C, .change
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .change
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+0), E : JP .maybe_turn
.not_left:
    ; DIR_RIGHT
    LD      A, (IX+0) : ADD A, SPEED : CP 241 : JP NC, .change
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .change
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+0), E

.maybe_turn:
    ; 8px tasaustarkistus — käänny vain tiilirajan kohdalla
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    ; 50% todennäköisyysportti
    CALL    RAND : AND 0x01 : RET NZ

    ; NAVMAP-haku: indeksi = (Y/8)*32 + (X/8)
    LD      A, (IX+1) : SRL A : SRL A : SRL A   ; A = Y/8 = tiilirivi
    LD      H, 0 : LD L, A
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL   ; rivi*32
    LD      A, (IX+0) : SRL A : SRL A : SRL A   ; A = X/8 = tiilisarake
    ADD     A, L : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL)          ; A = suuntabittikartta
    OR      A : RET Z        ; ei saatavilla olevia suuntia

    ; Suodata kohtisuorat suunnat nykyiselle liikkumissuunnalle
    LD      B, A             ; B = kaikki saatavilla olevat suunnat
    LD      A, (IX+2) : AND 0x02   ; bitti 1 = akseli (0=vaaka, 2=pysty)
    JR      NZ, .mt_vert
    ; Vaakasuuntainen (RIGHT/LEFT) → pystysuorat kohtisuorat (UP=b2, DOWN=b3)
    LD      A, B : SRL A : SRL A : AND 0x03
    LD      C, 2            ; pohjasuunta UP=2, DOWN=3
    JR      .mt_pick
.mt_vert:
    ; Pystysuuntainen (UP/DOWN) → vaakasuorat kohtisuorat (RIGHT=b0, LEFT=b1)
    LD      A, B : AND 0x03
    LD      C, 0            ; pohjasuunta RIGHT=0, LEFT=1
.mt_pick:
    OR      A : RET Z        ; ei kohtisuoria saatavilla → jatka suoraan
    LD      B, A
    CP      0x03 : JR NZ, .mt_one
    ; Molemmat kohtisuorat vapaina → arvo satunnaisesti
    CALL    RAND : AND 0x01 : OR C : LD (IX+2), A
    RET
.mt_one:
    ; Vain yksi kohtisuora suunta — valitse se
    BIT     0, B : JR NZ, .mt_b0
    LD      A, C : INC A : LD (IX+2), A   ; bitti1 → LEFT tai DOWN
    RET
.mt_b0:
    LD      A, C : LD (IX+2), A            ; bitti0 → RIGHT tai UP
    RET

.change:
    ; Seinä edessä — kokeile satunnaisia suuntia
    LD      B, 16
.try:
    PUSH    BC
    CALL    RAND : AND 0x03 : LD D, A

    CP      DIR_UP : JR NZ, .tu
    LD      A, (IX+1) : SUB SPEED : CP 8 : JR C, .tbad
    LD      E, A : LD B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tu:CP      DIR_DOWN : JR NZ, .td
    LD      A, (IX+1) : ADD A, SPEED : CP 176 : JR NC, .tbad
    LD      E, A : LD B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.td:CP      DIR_LEFT : JR NZ, .tl
    LD      A, (IX+0) : SUB SPEED : JR C, .tbad
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tl:LD      A, (IX+0) : ADD A, SPEED : CP 241 : JR NC, .tbad
    LD      E, A : LD A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
.tok:
    LD      (IX+2), D
    POP     BC : RET
.tbad:
    POP     BC : DJNZ .try
    RET

; =============================================================================
; UPDATE_ENEMIES — päivitä kaikki viholliset
; =============================================================================
UPDATE_ENEMIES:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
.loop:
    PUSH    BC
    LD      A, (IX+4) : OR A : JR Z, .skip
    LD      A, (IX+3) : CP ENEMY_WORRIT : JR NZ, .skip
    CALL    UPDATE_WORRIT
.skip:
    LD      BC, ENEMY_SIZE
    ADD     IX, BC
    POP     BC : DJNZ .loop
    RET

; =============================================================================
; DRAW_ENEMIES — piirrä kaikki viholliset spriteiksi
; =============================================================================
DRAW_ENEMIES:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
    LD      DE, ENEMY_SIZE              ; DE säilyy koko silmukan ajan
    LD      HL, VRAM_SPRITE_ATT + 8    ; sprite 2 alkaen
    CALL    VDP_SETW                    ; VDP osoite asetetaan kerran

.loop:
    LD      A, (IX+4) : OR A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      A, 32     : OUT (VDP_DATA), A    ; Worrit pattern (aina 32)
    LD      A, WORRIT_COLOR : OUT (VDP_DATA), A
    JR      .next

.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

.next:
    ADD     IX, DE          ; B (laskuri) ei koske — LD BC,n olisi nollannut B:n
    DJNZ    .loop
    RET

; =============================================================================
; CHECK_WAVE_COMPLETE — tarkista onko kaikki viholliset kuolleet
; Ulostulo: Z=1 jos kaikki kuolleet, Z=0 jos vielä elossa
; =============================================================================
CHECK_WAVE_COMPLETE:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
.chk:
    LD      A, (IX+4)
    OR      A
    RET     NZ              ; löytyi aktiivinen → Z=0, palaa heti
    LD      DE, ENEMY_SIZE
    ADD     IX, DE
    DJNZ    .chk
    XOR     A               ; kaikki kuolleet → Z=1
    RET

; =============================================================================
; SPAWN_WAVE — luo uusi aalto vihollisia LEVEL:in mukaan
; Level 1 = 3, Level 2 = 4, Level 3 = 5, Level 4+ = 6
; =============================================================================
SPAWN_WAVE:
    ; Nollaa kaikki viholliset
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr

    ; Laske montako: LEVEL + 2, max MAX_ENEMIES
    LD      A, (LEVEL)
    ADD     A, 2
    CP      MAX_ENEMIES + 1
    JR      C, .cnt_ok
    LD      A, MAX_ENEMIES
.cnt_ok:
    LD      B, A            ; B = spawnaittavien määrä
    LD      IX, ENEMIES
.spawn_lp:
    PUSH    BC
    CALL    SPAWN_WORRIT
    LD      DE, ENEMY_SIZE
    ADD     IX, DE
    POP     BC
    DJNZ    .spawn_lp
    RET
