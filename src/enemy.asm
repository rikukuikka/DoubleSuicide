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
    LD      HL, VRAM_SPRITE_PAT + 64 : CALL VDP_SETW   ; 16x16: pelaaja vie 64 tavua
    LD      HL, WORRIT_PATS
    LD      BC, WORRIT_PATS_END - WORRIT_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .pp

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
    LD      B, 32
.try:
    PUSH    BC
    CALL    RAND : AND 0x78 : ADD A, 16 : LD (IX+0), A   ; X 16-136
    CALL    RAND : AND 0x38 : ADD A, 16 : LD (IX+1), A   ; Y 16-72
    LD      B, (IX+0) : LD C, (IX+1) : CALL IS_WALL
    POP     BC
    JR      Z, .found
    DJNZ    .try
    LD      A, 80 : LD (IX+0), A    ; fallback
    LD      A, 48 : LD (IX+1), A
.found:
    CALL    RAND : AND 0x03 : LD (IX+2), A   ; satunnainen suunta
    LD      (IX+3), ENEMY_WORRIT
    LD      (IX+4), 1
    RET

; =============================================================================
; WORRIT_PATTERN — suunta → sprite pattern numero
; =============================================================================
WORRIT_PATTERN:
    ; 16x16 moodissa: yksi pattern kaikille suunnille
    LD      A, 8 : RET

; =============================================================================
; UPDATE_WORRIT — liikuta yksi Worrit (IX = data)
; =============================================================================
UPDATE_WORRIT:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    ; Kokeile liikkua nykyiseen suuntaan
    CP      DIR_UP : JR NZ, .not_up
    LD      A, (IX+1) : SUB SPEED : CP 8 : JR C, .change
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .change
    LD      (IX+1), E : RET
.not_up:
    CP      DIR_DOWN : JR NZ, .not_down
    LD      A, (IX+1) : ADD A, SPEED : CP 176 : JR NC, .change
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .change
    LD      (IX+1), E : RET
.not_down:
    CP      DIR_LEFT : JR NZ, .not_left
    LD      A, (IX+0) : SUB SPEED : JR C, .change
    LD      E, A
    LD      B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .change
    LD      (IX+0), E : RET
.not_left:
    ; DIR_RIGHT
    LD      A, (IX+0) : ADD A, SPEED : CP 241 : JR NC, .change
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .change
    LD      (IX+0), E : RET

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
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 3 : LD C, A : CALL IS_WALL : JR NZ, .tbad
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
    LD      HL, VRAM_SPRITE_ATT + 8    ; sprite 2 alkaen

.loop:
    PUSH    BC : PUSH HL

    LD      A, (IX+4) : OR A : JR Z, .hide

    CALL    VDP_SETW
    LD      A, (IX+1) : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      A, (IX+2) : CALL WORRIT_PATTERN : OUT (VDP_DATA), A
    LD      A, WORRIT_COLOR : OUT (VDP_DATA), A
    JR      .next

.hide:
    CALL    VDP_SETW
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

.next:
    POP     HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      BC, ENEMY_SIZE
    ADD     IX, BC
    POP     BC : DJNZ .loop
    RET
