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
ENEMY_TANK      EQU 2
ENEMY_SIZE      EQU 8
MAX_ENEMIES     EQU 6

ENEMIES         EQU 0xC010      ; 6*8=48 tavua RAM:issa
RAND_SEED       EQU 0xC040      ; 2 tavua

WORRIT_COLOR    EQU 10          ; keltainen
TANK_COLOR      EQU 13          ; magenta

WORRIT_PATS:
    ; 16x16 Worrit (pattern 8 = offset 64, yksi frame)
    ;Oikea
    DB $00,$03,$07,$07,$03,$01,$03,$06
    DB $05,$05,$06,$3F,$49,$49,$3F,$00
    DB $00,$C0,$00,$E0,$E0,$80,$C0,$64
    DB $FE,$A0,$60,$FC,$92,$92,$FC,$00
    ;Vasen
    DB $00,$03,$00,$07,$07,$01,$03,$26
    DB $7F,$05,$06,$3F,$49,$49,$3F,$00
    DB $00,$C0,$E0,$E0,$C0,$80,$C0,$60
    DB $A0,$A0,$60,$FC,$92,$92,$FC,$00
    ;Alas
    DB $00,$30,$48,$48,$78,$4F,$4C,$7B
    DB $7B,$4D,$4F,$79,$49,$49,$31,$00
    DB $00,$00,$00,$00,$00,$8C,$DE,$7E
    DB $7A,$DA,$98,$00,$00,$80,$00,$00
    ;Ylös
    DB $00,$00,$01,$00,$00,$19,$5B,$5E
    DB $7E,$7B,$31,$00,$00,$00,$00,$00
    DB $00,$8C,$92,$92,$9E,$F2,$B2,$DE
    DB $DE,$32,$F2,$1E,$12,$12,$0C,$00

WORRIT_PATS_END:

TANK_PATS:

    ; Oikea ja vasen
    DB $00,$00,$01,$06,$CE,$FF,$CA,$0A
    DB $7F,$CD,$B5,$B5,$CD,$7F,$00,$00
    DB $00,$00,$80,$60,$73,$FF,$53,$50
    DB $FE,$B3,$AD,$AD,$B3,$FE,$00,$00
    ; Alas ja ylös
    DB $1E,$33,$2D,$2D,$33,$3F,$21,$3F
    DB $3F,$21,$3F,$33,$2D,$2D,$33,$1E
    DB $70,$70,$20,$20,$F0,$38,$F8,$24
    DB $24,$F8,$38,$F0,$20,$20,$70,$70

TANK_PATS_END:

; Tutkan piste-sprite (8x8, vain 2x2 pikseliä vasemmassa yläkulmassa —
; sprite sijoitetaan niin että tämä kulma osuu oikeaan kohtaan)
RADAR_DOT_PATS:
    DB $C0,$C0,$00,$00,$00,$00,$00,$00

    ALIGN   4
WORRIT_DIR_PAT:
    DB 32, 36, 44, 40   ; DIR_RIGHT=0, DIR_LEFT=1, DIR_UP=2, DIR_DOWN=3
TANK_DIR_PAT:
    DB 60, 60, 64, 64   ; vaaka sama sprite molemmille suunnille, sama pystylle

; =============================================================================
; WAVE_TABLE — vihollismäärät per taso (muokkaa tätä helposti!)
; Muoto: DB worritit, tankit
; Yhteensä ei saa ylittää MAX_ENEMIES (= 6)
; Viimeinen rivi toistuu kaikilla myöhemmillä tasoilla automaattisesti
; =============================================================================
WAVE_TABLE:
    DB  2, 0    ; taso 1: 2 worritia, 0 tankkia
    DB  0, 2    ; taso 2: 0 worritia, 2 tankkia
    DB  3, 1    ; taso 3: 3 worritia, 1 tankki
    DB  2, 2    ; taso 4: 2 worritia, 2 tankkia
    DB  4, 2    ; taso 5: 4 worritia, 2 tankkia
    DB  4, 2    ; taso 6+: sama
WAVE_TABLE_END:
MAX_WAVE_ENTRIES EQU (WAVE_TABLE_END - WAVE_TABLE) / 2

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

    ; Lataa Worrit-patternit (pattern 32 = offset 256)
    LD      HL, VRAM_SPRITE_PAT + 256 : CALL VDP_SETW
    LD      HL, WORRIT_PATS
    LD      B, WORRIT_PATS_END - WORRIT_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .pp
    ; Lataa Tank-patternit (pattern 60 = offset 480, bullet/explosion jälkeen)
    LD      HL, VRAM_SPRITE_PAT + 480 : CALL VDP_SETW
    LD      HL, TANK_PATS
    LD      B, TANK_PATS_END - TANK_PATS
.tp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .tp
    ; Lataa tutkan piste-pattern (RADAR_DOT_PAT=64, offset 512, tank-patternien jälkeen)
    LD      HL, VRAM_SPRITE_PAT + RADAR_DOT_PAT*8 : CALL VDP_SETW
    LD      HL, RADAR_DOT_PATS
    LD      B, 8
.rdp:LD     A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .rdp

    ; Nollaa viholliset ja niiden ammukset
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr
    LD      HL, ENEMY_BULLETS
    LD      B, MAX_ENEMIES * ENEMY_BULLET_SIZE
.clrb:XOR   A : LD (HL), A : INC HL : DJNZ .clrb
    LD      HL, TANK_BULLETS
    LD      B, 2 * ENEMY_BULLET_SIZE
.clrt:XOR   A : LD (HL), A : INC HL : DJNZ .clrt

    ; Ensimmäisen aallon viholliset WAVE_TABLE:n mukaan (LEVEL asetetaan main.asm:ssa ennen tätä kutsua)
    JP      SPAWN_ENEMIES_FOR_LEVEL

; SPAWN_WORRIT — luo Worrit IX-osoitteeseen NAVMAP-pisteiden kautta
SPAWN_WORRIT:
    CALL    PICK_SPAWN_POS
    CALL    RAND : AND 0x03 : LD (IX+2), A
    LD      (IX+3), ENEMY_WORRIT
    LD      (IX+4), 1
    RET

; SPAWN_TANK — luo Tankki IX-osoitteeseen NAVMAP-pisteiden kautta
SPAWN_TANK:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_TANK
    LD      (IX+4), 1
    RET

; =============================================================================
; PICK_SPAWN_POS — valitsee spawn-pisteen NAVMAP:ista
; Sisääntulo: IX = kohdeslotti
; Vaatimukset: NAVMAP-piste vapaa, etäisyys pelaajiin >= 30px,
;              ei päällekkäisyyttä aiemmin spawnattujen vihollisten kanssa
; Ulostulo: IX+0=X, IX+1=Y asetettu (tai fallback jos 64 yritystä epäonnistuu)
; Tuhoaa: A, B, C, D, E, H, L, IY (IX säilyy)
; =============================================================================
PICK_SPAWN_POS:
    LD      B, 64
.psptry:
    PUSH    BC
    ; Satunnainen sarake 0-31
    CALL    RAND : AND 0x1F : LD D, A
    ; Satunnainen rivi 0-31, hylkää >= 21
    CALL    RAND : AND 0x1F
    CP      21 : JP NC, .pspbad
    LD      E, A
    ; NAVMAP[rivi*32 + sarake] != 0 → kelvollinen paikka
    LD      H, 0 : LD L, E
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL
    LD      A, L : ADD A, D : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL) : OR A : JP Z, .pspbad
    ; Laske pikselikoordinaatit (8px/tile)
    LD      A, D : ADD A, A : ADD A, A : ADD A, A : LD (IX+0), A
    LD      A, E : ADD A, A : ADD A, A : ADD A, A : LD (IX+1), A
    ; Tarkista P1-etäisyys (jos elossa)
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .psp_p2
    LD      A, (P1_LIVES) : OR A : JR Z, .psp_p2
    LD      A, (P1_X) : LD B, A : LD A, (IX+0) : SUB B
    JP      P, .psp_p1xp : NEG
.psp_p1xp:
    CP      30 : JR NC, .psp_p2
    LD      A, (P1_Y) : LD B, A : LD A, (IX+1) : SUB B
    JP      P, .psp_p1yp : NEG
.psp_p1yp:
    CP      30 : JR C, .pspbad
.psp_p2:
    ; Tarkista P2-etäisyys (jos elossa)
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .psp_prev
    LD      A, (P2_LIVES) : OR A : JR Z, .psp_prev
    LD      A, (P2_X) : LD B, A : LD A, (IX+0) : SUB B
    JP      P, .psp_p2xp : NEG
.psp_p2xp:
    CP      30 : JR NC, .psp_prev
    LD      A, (P2_Y) : LD B, A : LD A, (IX+1) : SUB B
    JP      P, .psp_p2yp : NEG
.psp_p2yp:
    CP      30 : JR C, .pspbad
.psp_prev:
    ; Tarkista päällekkäisyys jo aktiivisten vihollisten kanssa (vain active=1)
    LD      A, (IX+0) : LD D, A
    LD      A, (IX+1) : LD E, A
    LD      IY, ENEMIES
    LD      B, MAX_ENEMIES
.psp_elp:
    LD      A, (IY+4) : OR A : JR Z, .psp_enxt   ; ei aktiivinen → ohita
    LD      A, (IY+0) : SUB D
    JP      P, .psp_expos : NEG
.psp_expos:
    CP      16 : JR NC, .psp_enxt
    LD      A, (IY+1) : SUB E
    JP      P, .psp_eypos : NEG
.psp_eypos:
    CP      16 : JR C, .pspbad                    ; liian lähellä → hylkää
.psp_enxt:
    INC     IY : INC IY : INC IY : INC IY
    INC     IY : INC IY : INC IY : INC IY
    DJNZ    .psp_elp
    ; Kaikki tarkistukset läpäisty
    POP     BC : RET
.pspbad:
    POP     BC : DEC B : JP NZ, .psptry
    ; Kaikki 64 satunnaisyritystä epäonnistuivat (esim. kartta täynnä muita
    ; vihollisia/pelaajia lähellä) — skannaa NAVMAP varmalla logiikalla, joka
    ; TAKAA ettei koskaan osuta seinään (toisin kuin vanha kiinteä koordinaatti)
    LD      HL, NAVMAP
    LD      B, 0            ; B = sarake 0-31
    LD      C, 0            ; C = rivi 0-20
.pspf_try:
    LD      A, (HL) : OR A : JR Z, .pspf_advance
    PUSH    HL
    LD      A, B : ADD A, A : ADD A, A : ADD A, A : LD D, A   ; D = X
    LD      A, C : ADD A, A : ADD A, A : ADD A, A : LD E, A   ; E = Y
    ; Ohita jos täsmälleen sama piste kuin jokin jo aktiivinen vihollinen
    PUSH    BC
    LD      IY, ENEMIES
    LD      B, MAX_ENEMIES
.pspf_chk:
    LD      A, (IY+4) : OR A : JR Z, .pspf_chknext
    LD      A, (IY+0) : CP D : JR NZ, .pspf_chknext
    LD      A, (IY+1) : CP E : JR Z, .pspf_dupe
.pspf_chknext:
    INC     IY : INC IY : INC IY : INC IY
    INC     IY : INC IY : INC IY : INC IY
    DJNZ    .pspf_chk
    ; Ei törmäystä — käytä tätä pistettä
    POP     BC
    POP     HL
    LD      (IX+0), D
    LD      (IX+1), E
    RET
.pspf_dupe:
    POP     BC
    POP     HL
.pspf_advance:
    INC     HL
    INC     B
    LD      A, B : CP 32 : JR NZ, .pspf_try
    LD      B, 0
    INC     C
    LD      A, C : CP 21 : JR NZ, .pspf_try
    ; Ei pitäisi koskaan tapahtua (koko NAVMAP tyhjä) — viimeinen varasija
    LD      A, 16 : LD (IX+0), A
    LD      A, 16 : LD (IX+1), A
    RET

; =============================================================================
; UPDATE_WORRIT — liikuta yksi Worrit (IX = data)
; =============================================================================
UPDATE_WORRIT:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    ; Kokeile liikkua nykyiseen suuntaan
    CP      DIR_UP : JR NZ, .not_up
    LD      A, (IX+1) : SUB ENEMY_SPEED : CP 8 : JP C, .change
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .change
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .change
    LD      (IX+1), E : JP .maybe_turn
.not_up:
    CP      DIR_DOWN : JR NZ, .not_down
    LD      A, (IX+1) : ADD A, ENEMY_SPEED : CP 153 : JP NC, .change
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+1), E : JP .maybe_turn
.not_down:
    CP      DIR_LEFT : JR NZ, .not_left
    LD      A, (IX+0) : SUB ENEMY_SPEED : JP C, .change
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .change
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+0), E : JP .maybe_turn
.not_left:
    ; DIR_RIGHT
    LD      A, (IX+0) : ADD A, ENEMY_SPEED : CP 241 : JP NC, .change
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .change
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .change
    LD      (IX+0), E

.maybe_turn:
    ; 8px tasaustarkistus — käänny vain tiilirajan kohdalla
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    ; 50% todennäköisyysportti
    CALL    RAND : AND 0x03 : RET NZ

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
    LD      A, (IX+1) : SUB ENEMY_SPEED : CP 8 : JR C, .tbad
    LD      E, A : LD B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tu:CP      DIR_DOWN : JR NZ, .td
    LD      A, (IX+1) : ADD A, ENEMY_SPEED : CP 153 : JR NC, .tbad
    LD      E, A : LD B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.td:CP      DIR_LEFT : JR NZ, .tl
    LD      A, (IX+0) : SUB ENEMY_SPEED : JR C, .tbad
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tl:LD      A, (IX+0) : ADD A, ENEMY_SPEED : CP 241 : JR NC, .tbad
    LD      E, A : LD A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
.tok:
    LD      (IX+2), D
    POP     BC : RET
.tbad:
    POP     BC : DJNZ .try
    RET

; =============================================================================
; TANK_TOWARD_PLAYER — palauttaa A = suunta kohti elossaolevaa pelaajaa
; Käyttää: B, C, D, E, H, L. Säilyttää: IX, alkuperäiset D, E.
; =============================================================================
TANK_TOWARD_PLAYER:
    PUSH    DE
    PUSH    HL

    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .ttp2
    LD      A, (P1_LIVES)    : OR A : JR Z, .ttp2
    LD      A, (P1_X) : LD B, A : LD A, (P1_Y) : LD C, A
    JR      .ttp_got
.ttp2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .ttp_nopl
    LD      A, (P2_LIVES)    : OR A : JR Z, .ttp_nopl
    LD      A, (P2_X) : LD B, A : LD A, (P2_Y) : LD C, A
    JR      .ttp_got
.ttp_nopl:
    LD      A, (IX+2)   ; ei elossaolevia pelaajia: pidä nykyinen suunta
    POP     HL : POP DE : RET

.ttp_got:
    ; Laske |dx| ja vaakasuuntainen preferenssi
    LD      A, B : SUB (IX+0)   ; dx = targetX - tankX (allekirjoitettu)
    JP      P, .ttp_dxp
    NEG : LD H, A : LD D, DIR_LEFT  : JR .ttp_dxd
.ttp_dxp:
    LD      H, A : LD D, DIR_RIGHT
.ttp_dxd:
    ; Laske |dy| ja pystysuuntainen preferenssi
    LD      A, C : SUB (IX+1)   ; dy = targetY - tankY (allekirjoitettu)
    JP      P, .ttp_dyp
    NEG : LD E, A : LD L, DIR_UP   : JR .ttp_dyd
.ttp_dyp:
    LD      E, A : LD L, DIR_DOWN
.ttp_dyd:
    LD      A, E : CP H          ; |dy| vs |dx|
    JR      NC, .ttp_vert        ; |dy| >= |dx|: preferoi pystyä
    LD      A, D : JR .ttp_done  ; preferoi vaakaa
.ttp_vert:
    LD      A, L
.ttp_done:
    POP     HL : POP DE : RET

; =============================================================================
; UPDATE_TANK — liikuta yksi tankki pelaajaa kohti (IX = data)
; =============================================================================
UPDATE_TANK:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    CP      DIR_UP : JR NZ, .tnup
    LD      A, (IX+1) : SUB ENEMY_SPEED : CP 8 : JP C, .tchg
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tnup:
    CP      DIR_DOWN : JR NZ, .tndn
    LD      A, (IX+1) : ADD A, ENEMY_SPEED : CP 153 : JP NC, .tchg
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tndn:
    CP      DIR_LEFT : JR NZ, .tnlt
    LD      A, (IX+0) : SUB ENEMY_SPEED : JP C, .tchg
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E : JP .tmt
.tnlt:
    LD      A, (IX+0) : ADD A, ENEMY_SPEED : CP 241 : JP NC, .tchg
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E

.tmt:
    ; Grid-raja: käänny pelaajaa kohti NAVMAP:in avulla — ei taaksepäin
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    CALL    TANK_TOWARD_PLAYER   ; A = preferred direction
    LD      D, A
    ; Suodata: käänny vain jos preferenssi on kohtisuora nykyiseen akseliin
    LD      A, (IX+2) : AND 0x02
    LD      B, A
    LD      A, D : AND 0x02
    CP      B : RET Z            ; sama akseli → jatka suoraan
    ; NAVMAP-haku
    LD      A, (IX+1) : SRL A : SRL A : SRL A
    LD      H, 0 : LD L, A
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL
    LD      A, (IX+0) : SRL A : SRL A : SRL A
    ADD     A, L : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL)
    LD      B, A             ; B = saatavilla olevat suunnat (NAVMAP-bitit)
    ; Onko preferenssisuunta D auki? (bit D = bitti suuntanumerolla)
    LD      A, D : CP DIR_LEFT : JR C, .tmt_r
    CP      DIR_UP   : JR C, .tmt_l
    CP      DIR_DOWN : JR C, .tmt_u
    BIT     3, B : RET Z : LD (IX+2), D : RET   ; DOWN
.tmt_u:
    BIT     2, B : RET Z : LD (IX+2), D : RET   ; UP
.tmt_l:
    BIT     1, B : RET Z : LD (IX+2), D : RET   ; LEFT
.tmt_r:
    BIT     0, B : RET Z : LD (IX+2), D : RET   ; RIGHT

.tchg:
    ; Seinä edessä — laske suunta pelaajaa kohti ja kokeile sitä
    CALL    TANK_TOWARD_PLAYER
    LD      D, A

.ttry:
    ; Kokeile suuntaa D — tarkista MOLEMMAT kulmat (sama kuin pääliikuntakoodi)
    LD      A, D : CP DIR_UP : JR NZ, .ttu_nd
    LD      A, (IX+1) : SUB ENEMY_SPEED : CP 8 : JP C, .talt
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .talt
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .talt
    LD      (IX+2), D : RET
.ttu_nd:
    CP      DIR_DOWN : JR NZ, .ttu_nl
    LD      A, (IX+1) : ADD A, ENEMY_SPEED : CP 153 : JP NC, .talt
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .talt
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .talt
    LD      (IX+2), D : RET
.ttu_nl:
    CP      DIR_LEFT : JR NZ, .ttu_nr
    LD      A, (IX+0) : SUB ENEMY_SPEED : JP C, .talt
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .talt
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .talt
    LD      (IX+2), D : RET
.ttu_nr:
    LD      A, (IX+0) : ADD A, ENEMY_SPEED : CP 241 : JP NC, .talt
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .talt
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .talt
    LD      (IX+2), D : RET

.talt:
    ; Preferenssisuunta tukossa — kokeile satunnaisia
    LD      B, 12
.trand:
    PUSH    BC
    CALL    RAND : AND 0x03 : LD D, A
    CP      DIR_UP : JR NZ, .tr_nd
    LD      A, (IX+1) : SUB ENEMY_SPEED : CP 8 : JR C, .tr_bad
    LD      E, A : LD B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .tr_bad
    JR      .tr_ok
.tr_nd:
    CP      DIR_DOWN : JR NZ, .tr_nl
    LD      A, (IX+1) : ADD A, ENEMY_SPEED : CP 153 : JR NC, .tr_bad
    LD      E, A : LD B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .tr_bad
    JR      .tr_ok
.tr_nl:
    CP      DIR_LEFT : JR NZ, .tr_nr
    LD      A, (IX+0) : SUB ENEMY_SPEED : JR C, .tr_bad
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tr_bad
    JR      .tr_ok
.tr_nr:
    LD      A, (IX+0) : ADD A, ENEMY_SPEED : CP 241 : JR NC, .tr_bad
    LD      E, A : LD A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tr_bad
.tr_ok:
    LD      (IX+2), D
    POP     BC : RET
.tr_bad:
    POP     BC : DJNZ .trand
    RET

; =============================================================================
; TANK_TRY_SHOOT — ampuu molempiin suuntiin kun samalla rivillä/sarakkeella
; Sisääntulo: IX = tankki-data
; =============================================================================
TANK_TRY_SHOOT:
    PUSH    BC
    PUSH    DE
    PUSH    HL

    ; Etsi elossaoleva pelaaja (B=X, C=Y)
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .tts_p2
    LD      A, (P1_LIVES)    : OR A : JR Z,  .tts_p2
    LD      A, (P1_X) : LD B, A : LD A, (P1_Y) : LD C, A
    JR      .tts_chk
.tts_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .tts_done
    LD      A, (P2_LIVES)    : OR A : JR Z,  .tts_done
    LD      A, (P2_X) : LD B, A : LD A, (P2_Y) : LD C, A

.tts_chk:
    ; Ampumaakseli = tankin liikkumasuunnan akseli (ei pelaajan sijainnista)
    LD      A, (IX+2) : AND 0x02   ; 0=vaaka, 2=pysty
    JR      NZ, .tts_vert_axis

    ; Vaaka-akseli (RIGHT/LEFT): ammu vain jos samalla rivillä
    LD      A, (IX+1) : SUB C
    JP      P, .tts_ry
    NEG
.tts_ry:
    CP      4 : JR NC, .tts_done
    CALL    RAND : AND 1 : JR NZ, .tts_done
    LD      E, DIR_LEFT : LD D, DIR_RIGHT
    JR      .tts_fire

.tts_vert_axis:
    ; Pysty-akseli (UP/DOWN): ammu vain jos samassa sarakkeessa
    LD      A, (IX+0) : SUB B
    JP      P, .tts_cx
    NEG
.tts_cx:
    CP      4 : JR NC, .tts_done
    CALL    RAND : AND 1 : JR NZ, .tts_done
    LD      E, DIR_UP : LD D, DIR_DOWN

.tts_fire:
    ; E = ensimmäinen suunta, D = toinen suunta
    LD      HL, TANK_BULLETS + 3       ; slot 0 active-lippu
    LD      A, (HL) : OR A : JR NZ, .tts_b1
    DEC     HL : DEC HL : DEC HL
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, E : LD (HL), A : INC HL : LD (HL), 1
.tts_b1:
    LD      HL, TANK_BULLETS + 7       ; slot 1 active-lippu
    LD      A, (HL) : OR A : JR NZ, .tts_done
    DEC     HL : DEC HL : DEC HL
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, D : LD (HL), A : INC HL : LD (HL), 1

.tts_done:
    POP     HL : POP DE : POP BC
    RET

; =============================================================================
; UPDATE_ENEMIES — päivitä kaikki viholliset
; =============================================================================
UPDATE_ENEMIES:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
    LD      D, 0                    ; D = vihollisindeksi (0-5)
.loop:
    PUSH    BC
    PUSH    DE
    LD      A, (IX+4) : OR A : JR Z, .skip
    LD      A, (IX+3)
    CP      ENEMY_WORRIT : JR NZ, .chk_tank
    PUSH    DE : CALL UPDATE_WORRIT : POP DE
    LD      A, D : CALL ENEMY_TRY_SHOOT
    JR      .skip
.chk_tank:
    CP      ENEMY_TANK : JR NZ, .skip
    PUSH    DE : CALL UPDATE_TANK : POP DE
    CALL    TANK_TRY_SHOOT
.skip:
    POP     DE : INC D
    LD      BC, ENEMY_SIZE : ADD IX, BC
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
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .dtank
    LD      HL, WORRIT_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, WORRIT_COLOR : OUT (VDP_DATA), A
    JR      .next
.dtank:
    LD      HL, TANK_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, TANK_COLOR : OUT (VDP_DATA), A
    JR      .next

.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

.next:
    ADD     IX, DE          ; B (laskuri) ei koske — LD BC,n olisi nollannut B:n
    DJNZ    .loop
    RET

; =============================================================================
; DRAW_RADAR — piirtää vihollisten sijainnit tutkaan spriteinä (spritet
; RADAR_SPRITE_BASE..+5, yksi per ENEMIES-slotti). Kehys (hud.asm) on kiinteä,
; tämä piirtää vain pisteet oikean värisinä (WORRIT_COLOR/TANK_COLOR).
; 1 pelikentän tile = 1 pikseli, 1px alaspäin siirrettynä keskitystä varten.
; =============================================================================
DRAW_RADAR:
    LD      IX, ENEMIES
    LD      HL, VRAM_SPRITE_ATT + RADAR_SPRITE_BASE*4 : CALL VDP_SETW
    LD      B, MAX_ENEMIES
.rloop:
    LD      A, (IX+4) : OR A : JR Z, .rhide

    ; map_row = Y/8 (0-20 kelvollinen, muu ohitetaan)
    LD      A, (IX+1) : SRL A : SRL A : SRL A
    CP      21 : JR NC, .rhide
    ADD     A, RADAR_ORIGIN_Y : OUT (VDP_DATA), A     ; Y (jo Y-1 -sovitettu)

    ; map_col = X/8 (0-31) → sprite X
    LD      A, (IX+0) : SRL A : SRL A : SRL A
    ADD     A, RADAR_ORIGIN_X : OUT (VDP_DATA), A

    LD      A, RADAR_DOT_PAT : OUT (VDP_DATA), A

    ; Väri: worrit=keltainen, tank=magenta
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .rtankcol
    LD      A, WORRIT_COLOR : JR .rcolout
.rtankcol:
    LD      A, TANK_COLOR
.rcolout:
    OUT     (VDP_DATA), A
    JR      .rnext
.rhide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
.rnext:
    LD      DE, ENEMY_SIZE : ADD IX, DE
    DJNZ    .rloop
    RET

; =============================================================================
; ENEMY_TRY_SHOOT — yritä ampua viholliselta pelaajaan
; Sisääntulo: IX = vihollisdata, A = vihollisindeksi (0-5)
; Ampuu jos vihollinen on samalla rivillä tai sarakkeella kuin kohde (50% todennäköisyys)
; Pariton indeksi → P1, parillinen → P2
; =============================================================================
ENEMY_TRY_SHOOT:
    PUSH    BC
    PUSH    DE
    PUSH    HL

    LD      E, A                    ; E = vihollisindeksi
    ADD     A, A : ADD A, A         ; A = indeksi * 4
    LD      HL, ENEMY_BULLETS
    ADD     A, L : LD L, A          ; HL = &ENEMY_BULLETS[indeksi]
    PUSH    HL : POP IY             ; IY = bullet-slotti

    LD      A, (IY+3) : OR A : JR NZ, .done  ; jo aktiivinen → ei ammuta

    ; Valitse kohde: yksinpelissä aina P1; kaksinpelissä pariton→P1, parillinen→P2
    LD      A, (GAME_MODE) : CP 2 : JR NZ, .target_p1
    LD      A, E : AND 1 : JR Z, .pick_p2
.target_p1:
    LD      A, (P1_X) : LD B, A
    LD      A, (P1_Y) : LD C, A
    JR      .check
.pick_p2:
    LD      A, (P2_X) : LD B, A
    LD      A, (P2_Y) : LD C, A

.check:
    ; Sama rivi? |enemyY - targetY| < 4
    LD      A, (IX+1) : SUB C
    JP      P, .ry_ok
    NEG
.ry_ok:
    CP      4 : JR C, .same_row

    ; Sama sarake? |enemyX - targetX| < 4
    LD      A, (IX+0) : SUB B
    JP      P, .cx_ok
    NEG
.cx_ok:
    CP      4 : JR NC, .done        ; ei linjassa

    ; Sama sarake: ammu ylös tai alas
    LD      A, C : CP (IX+1)
    JR      NC, .col_down
    LD      D, DIR_UP : JR .fire
.col_down:
    LD      D, DIR_DOWN : JR .fire

.same_row:
    ; Sama rivi: ammu vasemmalle tai oikealle
    LD      A, B : CP (IX+0)
    JR      NC, .row_right
    LD      D, DIR_LEFT : JR .fire
.row_right:
    LD      D, DIR_RIGHT

.fire:
    LD      A, (IX+2) : CP D : JR NZ, .done  ; ammu vain jos liikkuu pelaajaa kohti
    CALL    RAND : AND 1 : JR NZ, .done       ; 50% todennäköisyys

    LD      A, (IX+0) : LD (IY+0), A       ; X
    LD      A, (IX+1) : LD (IY+1), A       ; Y
    LD      A, D        : LD (IY+2), A      ; suunta
    LD      (IY+3), 1                        ; aktiivinen

.done:
    POP     HL
    POP     DE
    POP     BC
    RET

; =============================================================================
; UPDATE_ENEMY_BULLETS — liikuta kaikki vihollisammukset
; =============================================================================
UPDATE_ENEMY_BULLETS:
    LD      IX, ENEMY_BULLETS
    LD      B, MAX_ENEMIES
.loop:
    PUSH    BC
    CALL    UPDATE_ENEMY_BULLET
    INC     IX : INC IX : INC IX : INC IX
    POP     BC : DJNZ .loop
    RET

; UPDATE_ENEMY_BULLET — liikuta yksi vihollisammus
; Sisääntulo: IX = bullet slot (X, Y, dir, active)
UPDATE_ENEMY_BULLET:
    LD      A, (IX+3) : OR A : RET Z        ; ei aktiivinen

    LD      A, (IX+2)                        ; suunta
    CP      DIR_UP : JR NZ, .ebu_nd
    LD      A, (IX+1) : SUB ENEMY_BULLET_SPEED
    JR      C, .ebu_deact
    CP      8 : JR C, .ebu_deact
    LD      (IX+1), A : JR .ebu_wall
.ebu_nd:
    CP      DIR_DOWN : JR NZ, .ebu_nl
    LD      A, (IX+1) : ADD A, ENEMY_BULLET_SPEED
    CP      153 : JR NC, .ebu_deact
    LD      (IX+1), A : JR .ebu_wall
.ebu_nl:
    CP      DIR_LEFT : JR NZ, .ebu_nr
    LD      A, (IX+0) : SUB ENEMY_BULLET_SPEED
    JR      C, .ebu_deact
    LD      (IX+0), A : JR .ebu_wall
.ebu_nr:
    LD      A, (IX+0) : ADD A, ENEMY_BULLET_SPEED
    CP      241 : JR NC, .ebu_deact
    LD      (IX+0), A
.ebu_wall:
    LD      A, (IX+0) : ADD A, 8 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A
    CALL    IS_WALL : JR NZ, .ebu_deact
    CALL    CHECK_ENEMY_BULLET_PLAYER_HIT
    RET
.ebu_deact:
    LD      (IX+3), 0
    RET

; CHECK_ENEMY_BULLET_PLAYER_HIT — tarkista osuuko vihollisammus pelaajaan
; Sisääntulo: IX = bullet slot
CHECK_ENEMY_BULLET_PLAYER_HIT:
    PUSH    BC
    PUSH    DE
    LD      D, (IX+0) : LD E, (IX+1)    ; D=X, E=Y

    ; Tarkista P1
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .chk_p2
    LD      A, (P1_LIVES)    : OR A : JR Z, .chk_p2
    LD      A, (P1_X) : SUB D
    JP      P, .p1x
    NEG
.p1x:
    CP      15 : JR NC, .chk_p2
    LD      A, (P1_Y) : SUB E
    JP      P, .p1y
    NEG
.p1y:
    CP      15 : JR NC, .chk_p2
    LD      (IX+3), 0
    LD      A, (P1_LIVES) : DEC A : LD (P1_LIVES), A
    LD      A, 1 : LD (HUD_DIRTY), A
    LD      A, 60 : LD (P1_DEAD_TMR), A
    CALL    SFX_ENEMY_DIE
    JR      .ebph_done

.chk_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .ebph_done
    LD      A, (P2_LIVES)    : OR A : JR Z, .ebph_done
    LD      A, (P2_X) : SUB D
    JP      P, .p2x
    NEG
.p2x:
    CP      15 : JR NC, .ebph_done
    LD      A, (P2_Y) : SUB E
    JP      P, .p2y
    NEG
.p2y:
    CP      15 : JR NC, .ebph_done
    LD      (IX+3), 0
    LD      A, (P2_LIVES) : DEC A : LD (P2_LIVES), A
    LD      A, 1 : LD (HUD_DIRTY), A
    LD      A, 60 : LD (P2_DEAD_TMR), A
    CALL    SFX_ENEMY_DIE
.ebph_done:
    POP     DE
    POP     BC
    RET

; =============================================================================
; DRAW_ENEMY_BULLETS — piirrä vihollisammukset (spritet 12-17)
; =============================================================================
DRAW_ENEMY_BULLETS:
    LD      IX, ENEMY_BULLETS
    LD      B, MAX_ENEMIES
    LD      HL, VRAM_SPRITE_ATT + 48    ; sprite 12 alkaen
    CALL    VDP_SETW
.loop:
    LD      A, (IX+3) : OR A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      A, ENEMY_BULLET_PAT   : OUT (VDP_DATA), A
    LD      A, ENEMY_BULLET_COLOR : OUT (VDP_DATA), A
    JR      .next
.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
.next:
    INC     IX : INC IX : INC IX : INC IX
    DJNZ    .loop
    RET

; =============================================================================
; UPDATE_TANK_BULLETS — liikuta tankin 2 ammusta (reuse UPDATE_ENEMY_BULLET)
; =============================================================================
UPDATE_TANK_BULLETS:
    LD      IX, TANK_BULLETS
    LD      B, 2
.loop:
    PUSH    BC
    CALL    UPDATE_ENEMY_BULLET
    INC     IX : INC IX : INC IX : INC IX
    POP     BC : DJNZ .loop
    RET

; =============================================================================
; DRAW_TANK_BULLETS — piirrä tankin ammukset (spritet 18-19)
; =============================================================================
DRAW_TANK_BULLETS:
    LD      IX, TANK_BULLETS
    LD      B, 2
    LD      HL, VRAM_SPRITE_ATT + 72   ; sprite 18 alkaen
    CALL    VDP_SETW
.loop:
    LD      A, (IX+3) : OR A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      A, ENEMY_BULLET_PAT   : OUT (VDP_DATA), A
    LD      A, TANK_BULLET_COLOR  : OUT (VDP_DATA), A
    JR      .next
.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
.next:
    INC     IX : INC IX : INC IX : INC IX
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
; SPAWN_WAVE — luo uusi aalto vihollisia WAVE_TABLE:n mukaan
; =============================================================================
SPAWN_WAVE:
    ; Nollaa viholliset ja niiden ammukset (myös tankin)
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr
    LD      HL, ENEMY_BULLETS
    LD      B, MAX_ENEMIES * ENEMY_BULLET_SIZE
.clrb:XOR   A : LD (HL), A : INC HL : DJNZ .clrb
    LD      HL, TANK_BULLETS
    LD      B, 2 * ENEMY_BULLET_SIZE
.clrt:XOR   A : LD (HL), A : INC HL : DJNZ .clrt
    ; Nollaa myös pelaajien ammukset
    LD      HL, BULLETS
    LD      B, BULLET_SIZE * 2
.clrp:XOR   A : LD (HL), A : INC HL : DJNZ .clrp
    ; Varmista että musiikki soi (ei resetoida kohtaa biisissä)
    LD      A, 1 : LD (BGM_ACTIVE), A

    JP      SPAWN_ENEMIES_FOR_LEVEL

; =============================================================================
; SPAWN_ENEMIES_FOR_LEVEL — spawnaa (LEVEL):n mukaiset viholliset WAVE_TABLE:sta
; Olettaa että ENEMIES on jo tyhjennetty kutsujan toimesta.
; =============================================================================
SPAWN_ENEMIES_FOR_LEVEL:
    ; Hae tason vihollismäärät WAVE_TABLE:sta
    LD      A, (LEVEL) : DEC A              ; 0-indeksoitu
    CP      MAX_WAVE_ENTRIES : JR C, .wt_ok
    LD      A, MAX_WAVE_ENTRIES - 1         ; leikkaa viimeiseen riviin
.wt_ok:
    ADD     A, A                             ; 2 tavua per merkintä
    LD      HL, WAVE_TABLE
    ADD     A, L : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      B, (HL) : INC HL : LD C, (HL)  ; B = worritit, C = tankit

    LD      IX, ENEMIES

    ; Spawnaa tankit
    LD      A, C : OR A : JR Z, .sw_worrits
    LD      D, C
.sw_tank:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_TANK
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_tank

.sw_worrits:
    ; Spawnaa worritit
    LD      A, B : OR A : RET Z
    LD      D, B
.sw_worrit:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_WORRIT
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_worrit
    RET
