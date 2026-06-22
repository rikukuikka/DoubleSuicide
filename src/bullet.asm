; =============================================================================
; bullet.asm — Ammukset
; =============================================================================
;
; Tietorakenne (8 tavua per ammus, RAM:issa):
;   offset 0: X
;   offset 1: Y
;   offset 2: suunta (DIR_*)
;   offset 3: omistaja (0=P1, 1=P2)
;   offset 4: aktiivinen (1=kyllä)
;
; Yksi ammus per pelaaja

BULLET_SIZE     EQU 8
BULLET_SPEED    EQU 4
BULLET_COLOR    EQU 15          ; valkoinen

BULLETS         EQU 0xC050      ; 2*8=16 tavua RAM:issa

; Ammussprite patternit (pattern 8 ja 9)
BULLET_PATS:
    DB 0x00,0x00,0x18,0x3C,0x3C,0x18,0x00,0x00  ; vaaka-ammus (pat 8)
    DB 0x00,0x08,0x1C,0x3E,0x3E,0x1C,0x08,0x00  ; pysty-ammus (pat 9)
BULLET_PATS_END:

; =============================================================================
; INIT_BULLETS — alusta ammukset
; =============================================================================
INIT_BULLETS:
    ; Lataa sprite patternit (pattern 8 alkaen = offset 8*8=64)
    LD      HL, VRAM_SPRITE_PAT + 64 : CALL VDP_SETW
    LD      HL, BULLET_PATS
    LD      BC, BULLET_PATS_END - BULLET_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .pp

    ; Nollaa molemmat ammukset
    LD      HL, BULLETS
    LD      B, BULLET_SIZE * 2
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr

    RET

; =============================================================================
; BULLET_PATTERN — suunta → pattern numero
; =============================================================================
BULLET_PATTERN:
    CP      DIR_LEFT  : JR Z, .horiz
    CP      DIR_RIGHT : JR Z, .horiz
    LD      A, 9 : RET      ; ylös/alas = pysty
.horiz:
    LD      A, 8 : RET      ; vasen/oikea = vaaka

; =============================================================================
; TRY_FIRE — yritä ampua jos tulipainike pohjassa ja ammus ei aktiivinen
; Sisääntulo: B = omistaja (0=P1, 1=P2)
; =============================================================================
TRY_FIRE:
    ; Laske ammuksen RAM-osoite
    LD      HL, BULLETS
    LD      A, B : OR A : JR Z, .got_addr
    LD      A, L : ADD A, BULLET_SIZE : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
.got_addr:
    ; Aktiivinen jo? Jos kyllä, ei ampua (ääni tulee vain uudelle ammukselle)
    LD      A, B : ADD A, 4 : LD C, A   ; offset 4 = aktiivinen
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      A, (HL)
    POP     HL
    OR      A : RET NZ      ; jo aktiivinen

    ; Lue pelaajan sijainti ja suunta
    LD      A, B : OR A : JR NZ, .p2_data
    ; P1
    LD      A, (P1_X) : LD (HL), A     ; X
    INC     HL
    LD      A, (P1_Y) : LD (HL), A     ; Y
    INC     HL
    LD      A, (P1_DIR) : LD (HL), A   ; suunta
    JR      .set_owner
.p2_data:
    LD      A, (P2_X) : LD (HL), A
    INC     HL
    LD      A, (P2_Y) : LD (HL), A
    INC     HL
    LD      A, (P2_DIR) : LD (HL), A
.set_owner:
    INC     HL
    LD      A, B : LD (HL), A          ; omistaja
    INC     HL
    LD      A, 1 : LD (HL), A          ; aktiivinen = 1
    CALL    SFX_SHOOT
    RET

; =============================================================================
; UPDATE_BULLET — liikuta yksi ammus (HL = ammuksen data)
; =============================================================================
UPDATE_BULLET:
    ; Aktiivinen?
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      A, (HL)
    POP     HL
    OR      A : RET Z

    ; Hae suunta
    PUSH    HL
    LD      A, L : ADD A, 2 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      A, (HL)
    POP     HL
    LD      D, A            ; D = suunta

    ; Liiku suunnan mukaan
    CP      DIR_UP : JR NZ, .nu
    LD      A, (HL) : LD B, A          ; X → B
    PUSH    HL : INC HL : LD A, (HL) : POP HL  ; Y
    SUB     BULLET_SPEED
    JR      C, .deactivate
    CP      8 : JR C, .deactivate
    PUSH    HL : INC HL : LD (HL), A : POP HL
    JR      .check_hit
.nu:CP      DIR_DOWN : JR NZ, .nd
    LD      A, (HL) : LD B, A
    PUSH    HL : INC HL : LD A, (HL) : POP HL
    ADD     A, BULLET_SPEED
    CP      176 : JR NC, .deactivate
    PUSH    HL : INC HL : LD (HL), A : POP HL
    JR      .check_hit
.nd:CP      DIR_LEFT : JR NZ, .nl
    LD      A, (HL)
    SUB     BULLET_SPEED
    JR      C, .deactivate
    LD      (HL), A
    JR      .check_hit
.nl:; DIR_RIGHT
    LD      A, (HL)
    ADD     A, BULLET_SPEED
    CP      249 : JR NC, .deactivate
    LD      (HL), A

.check_hit:
    ; Tarkista törmäys seinään
    LD      B, (HL)
    PUSH    HL : INC HL : LD A, (HL) : POP HL
    LD      C, A
    CALL    IS_WALL
    JR      NZ, .deactivate

    ; Tarkista törmäys vihollisiin
    CALL    CHECK_BULLET_HIT
    RET

.deactivate:
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    XOR     A : LD (HL), A
    POP     HL
    RET

; =============================================================================
; CHECK_BULLET_HIT — tarkista osuuko ammus viholliseen
; Sisääntulo: HL = ammuksen data
; =============================================================================
CHECK_BULLET_HIT:
    ; Lue ammuksen sijainti
    LD      A, (HL) : LD D, A          ; D = ammuksen X
    PUSH    HL : INC HL : LD A, (HL) : POP HL
    LD      E, A                        ; E = ammuksen Y

    ; Käy kaikki viholliset läpi
    PUSH    HL
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES
.eloop:
    PUSH    BC : PUSH HL

    ; Aktiivinen?
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      A, (HL)
    POP     HL
    OR      A : JR Z, .enext

    ; Etäisyystarkistus — osuma jos < 8px
    LD      A, (HL) : SUB D   ; vihollinen X - ammus X
    JP      P, .ex_pos
    NEG
.ex_pos:
    CP      8 : JR NC, .enext

    PUSH    HL : INC HL : LD A, (HL) : POP HL
    SUB     E                 ; vihollinen Y - ammus Y
    JP      P, .ey_pos
    NEG
.ey_pos:
    CP      8 : JR NC, .enext

    ; OSUMA — deaktivoi vihollinen
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    XOR     A : LD (HL), A
    POP     HL
    CALL    SFX_ENEMY_DIE

    ; Deaktivoi ammus
    POP     HL : POP     BC
    POP     HL              ; alkuperäinen ammuksen osoite
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    XOR     A : LD (HL), A
    POP     HL
    RET

.enext:
    POP     HL
    LD      A, L : ADD A, ENEMY_SIZE : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    POP     BC : DJNZ .eloop

    POP     HL
    RET

; =============================================================================
; UPDATE_BULLETS — päivitä molemmat ammukset ja tarkista tulipainikkeet
; =============================================================================
UPDATE_BULLETS:
    ; P1 tuli?
    LD      A, (P1_INPUT) : AND IN_FIRE : JR Z, .no_p1_fire
    LD      B, 0 : CALL TRY_FIRE
.no_p1_fire:

    ; P2 tuli?
    LD      A, (P2_INPUT) : AND IN_FIRE : JR Z, .no_p2_fire
    LD      B, 1 : CALL TRY_FIRE
.no_p2_fire:

    ; Liikuta ammukset
    LD      HL, BULLETS : CALL UPDATE_BULLET
    LD      HL, BULLETS + BULLET_SIZE : CALL UPDATE_BULLET
    RET

; =============================================================================
; DRAW_BULLETS — piirrä ammukset (spritet 8 ja 9)
; =============================================================================
DRAW_BULLETS:
    ; P1 ammus = sprite 8
    LD      HL, VRAM_SPRITE_ATT + 32 : CALL VDP_SETW
    LD      A, (0xC054) : OR A : JR Z, .hide_p1  ; aktiivinen?
    LD      A, (0xC051) : OUT (VDP_DATA), A       ; Y
    LD      A, (0xC050) : OUT (VDP_DATA), A       ; X
    ; pattern: DIR_RIGHT/LEFT=8, muut=9
    LD      A, (0xC052)                           ; suunta
    CP      DIR_RIGHT : JR Z, .p1h
    CP      DIR_LEFT  : JR Z, .p1h
    LD      A, 9 : JR .p1pat
.p1h: LD    A, 8
.p1pat:
    OUT     (VDP_DATA), A
    LD      A, BULLET_COLOR : OUT (VDP_DATA), A
    JR      .p2_bullet
.hide_p1:
    LD      A, 0xD8 : OUT (VDP_DATA), A   ; Y=0xD8 piilottaa (ei stop-merkki)
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

    ; P2 ammus = sprite 9
.p2_bullet:
    LD      HL, VRAM_SPRITE_ATT + 36 : CALL VDP_SETW
    LD      A, (0xC05C) : OR A : JR Z, .hide_p2  ; aktiivinen? (BULLETS+BULLET_SIZE+4)
    LD      A, (0xC059) : OUT (VDP_DATA), A       ; Y
    LD      A, (0xC058) : OUT (VDP_DATA), A       ; X
    LD      A, (0xC05A)
    CP      DIR_RIGHT : JR Z, .p2h
    CP      DIR_LEFT  : JR Z, .p2h
    LD      A, 9 : JR .p2pat
.p2h: LD    A, 8
.p2pat:
    OUT     (VDP_DATA), A
    LD      A, BULLET_COLOR : OUT (VDP_DATA), A
    RET
.hide_p2:
    LD      A, 0xD8 : OUT (VDP_DATA), A   ; Y=0xD8 piilottaa (ei stop-merkki)
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    RET
