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
    ; 16x16 ammus (pattern 12 = offset 96), pieni piste keskellä
    ; Vasen puoli ylä (rivit 0-7)
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0x03,0x07
    ; Vasen puoli ala (rivit 8-15)
    DB 0x07,0x03,0x00,0x00,0x00,0x00,0x00,0x00
    ; Oikea puoli ylä (rivit 0-7)
    DB 0x00,0x00,0x00,0x00,0x00,0x00,0xC0,0xE0
    ; Oikea puoli ala (rivit 8-15)
    DB 0xE0,0xC0,0x00,0x00,0x00,0x00,0x00,0x00
    ; Räjähdys 1
    DB $00,$00,$00,$00,$00,$01,$02,$01
    DB $05,$01,$01,$02,$00,$00,$00,$00
    DB $00,$00,$00,$00,$40,$00,$50,$A0
    DB $C0,$50,$80,$20,$80,$00,$00,$00
    ; Räjähdys 2
    DB $00,$01,$0A,$05,$13,$14,$29,$03
    DB $25,$53,$06,$29,$02,$08,$02,$00
    DB $00,$20,$48,$40,$10,$E4,$B0,$EA
    DB $D0,$F2,$AC,$E4,$12,$A4,$48,$00
BULLET_PATS_END:

; =============================================================================
; INIT_BULLETS — alusta ammukset
; =============================================================================
INIT_BULLETS:
    ; Lataa sprite patternit (pattern 8 alkaen = offset 8*8=64)
    LD      HL, VRAM_SPRITE_PAT + 288 : CALL VDP_SETW  ; 16x16: pelaaja 256 + enemy 32
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
    ; 16x16 moodissa: yksi pattern kaikille suunnille
    LD      A, 36 : RET    ; pattern 36 = offset 288

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
    CP      241 : JR NC, .deactivate
    LD      (HL), A

.check_hit:
    ; Tarkista törmäys seinään — 16x16 spriten keskipiste (X+8, Y+8)
    LD      A, (HL) : ADD A, 8 : LD B, A        ; B = X + 8
    PUSH    HL : INC HL : LD A, (HL) : POP HL
    ADD     A, 8 : LD C, A                       ; C = Y + 8
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
    CP      15 : JR NC, .enext

    PUSH    HL : INC HL : LD A, (HL) : POP HL
    SUB     E                 ; vihollinen Y - ammus Y
    JP      P, .ey_pos
    NEG
.ey_pos:
    CP      15 : JR NC, .enext

    ; OSUMA — deaktivoi vihollinen
    PUSH    HL
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    XOR     A : LD (HL), A
    POP     HL
    ; Käynnistä räjähdys vihollisen sijaintiin
    LD      B, (HL)
    PUSH    HL : INC HL : LD C, (HL) : POP HL
    CALL    START_EXPLOSION
    CALL    SFX_ENEMY_DIE

    ; Deaktivoi ammus ja lisää pisteet
    POP     HL : POP     BC
    POP     HL              ; HL = ammuksen osoite
    ; Lue omistaja (offset 3)
    PUSH    HL
    INC     HL : INC HL : INC HL
    LD      B, (HL)         ; B = omistaja (0=P1, 1=P2)
    POP     HL
    ; Deaktivoi ammus (offset 4 = 0)
    PUSH    HL : PUSH BC
    LD      A, L : ADD A, 4 : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    XOR     A : LD (HL), A
    POP     BC : POP HL
    ; Pisteet omistajan mukaan
    LD      A, B : OR A
    JR      NZ, .sc_p2
    CALL    ADD_SCORE_P1
    RET
.sc_p2:
    CALL    ADD_SCORE_P2
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
    LD      A, (0xC051) : DEC A : OUT (VDP_DATA), A  ; Y, TMS9918A: Y-1
    LD      A, (0xC050) : OUT (VDP_DATA), A       ; X
    ; pattern: DIR_RIGHT/LEFT=8, muut=9
    LD      A, 36                                 ; 16x16 ammus pattern
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
    LD      A, (0xC059) : DEC A : OUT (VDP_DATA), A  ; Y, TMS9918A: Y-1
    LD      A, (0xC058) : OUT (VDP_DATA), A       ; X
    LD      A, 36                                 ; 16x16 ammus pattern
    OUT     (VDP_DATA), A
    LD      A, BULLET_COLOR : OUT (VDP_DATA), A
    RET
.hide_p2:
    LD      A, 0xD8 : OUT (VDP_DATA), A   ; Y=0xD8 piilottaa (ei stop-merkki)
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    RET

; =============================================================================
; INIT_EXPLOSIONS — alusta räjähdykset
; =============================================================================
INIT_EXPLOSIONS:
    LD      HL, EXPLOSIONS
    LD      B, EXPL_SIZE * 2
.clr:
    XOR     A : LD (HL), A : INC HL : DJNZ .clr
    RET

; =============================================================================
; START_EXPLOSION — käynnistä räjähdys
; Sisääntulo: B=X, C=Y
; =============================================================================
START_EXPLOSION:
    LD      HL, EXPLOSIONS + 2              ; slot 0 timer
    LD      A, (HL) : OR A : JR Z, .slot0
    LD      HL, EXPLOSIONS + EXPL_SIZE + 2  ; slot 1 timer
    LD      A, (HL) : OR A : RET NZ         ; molemmat käytössä
    DEC     HL : DEC     HL                 ; slot 1 base (X)
    JR      .fill
.slot0:
    DEC     HL : DEC     HL                 ; slot 0 base (X)
.fill:
    LD      (HL), B                         ; X
    INC     HL
    LD      (HL), C                         ; Y
    INC     HL
    LD      A, EXPL_TIMER_MAX : LD (HL), A  ; Timer
    RET

; =============================================================================
; UPDATE_EXPLOSIONS — laske räjähdysten ajastimet alas
; =============================================================================
UPDATE_EXPLOSIONS:
    LD      HL, EXPLOSIONS + 2              ; slot 0 timer
    LD      A, (HL) : OR A : JR Z, .e1
    DEC     A : LD (HL), A
.e1:
    LD      HL, EXPLOSIONS + EXPL_SIZE + 2  ; slot 1 timer
    LD      A, (HL) : OR A : RET Z
    DEC     A : LD (HL), A
    RET

; =============================================================================
; DRAW_EXPLOSIONS — piirrä räjähdykset (spritet 10 ja 11)
; Timer 20-11 → Räjähdys 1 (kirkas), Timer 10-1 → Räjähdys 2 (haalistuva)
; =============================================================================
DRAW_EXPLOSIONS:
    ; --- Räjähdys 0 → sprite 10 ---
    LD      HL, EXPLOSIONS
    LD      A, (HL) : LD B, A   ; B = X
    INC     HL
    LD      A, (HL) : LD C, A   ; C = Y
    INC     HL
    LD      A, (HL)             ; A = Timer
    OR      A : JR Z, .hide0
    LD      D, EXPL_PAT2 : LD E, EXPL_COLOR2
    CP      11 : JR C, .show0
    LD      D, EXPL_PAT1 : LD E, EXPL_COLOR1
.show0:
    LD      HL, VRAM_SPRITE_ATT + 40 : CALL VDP_SETW
    LD      A, C : DEC A : OUT (VDP_DATA), A
    LD      A, B : OUT (VDP_DATA), A
    LD      A, D : OUT (VDP_DATA), A
    LD      A, E : OUT (VDP_DATA), A
    JR      .expl1
.hide0:
    LD      HL, VRAM_SPRITE_ATT + 40 : CALL VDP_SETW
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

    ; --- Räjähdys 1 → sprite 11 ---
.expl1:
    LD      HL, EXPLOSIONS + EXPL_SIZE
    LD      A, (HL) : LD B, A
    INC     HL
    LD      A, (HL) : LD C, A
    INC     HL
    LD      A, (HL)
    OR      A : JR Z, .hide1
    LD      D, EXPL_PAT2 : LD E, EXPL_COLOR2
    CP      11 : JR C, .show1
    LD      D, EXPL_PAT1 : LD E, EXPL_COLOR1
.show1:
    LD      HL, VRAM_SPRITE_ATT + 44 : CALL VDP_SETW
    LD      A, C : DEC A : OUT (VDP_DATA), A
    LD      A, B : OUT (VDP_DATA), A
    LD      A, D : OUT (VDP_DATA), A
    LD      A, E : OUT (VDP_DATA), A
    RET
.hide1:
    LD      HL, VRAM_SPRITE_ATT + 44 : CALL VDP_SETW
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    RET
