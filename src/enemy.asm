; =============================================================================
; enemy.asm — Viholliset
; =============================================================================
;
; Vihollisen tietorakenne (8 tavua, IX-rekisterin kautta):
;   IX+0: X
;   IX+1: Y
;   IX+2: suunta (DIR_*)
;   IX+3: tyyppi (ENEMY_ROBOT jne.)
;   IX+4: aktiivinen (1=kyllä)
;   IX+5: nopeus (px/frame) — asetetaan SPAWN_*:ssä, liikelogiikka lukee tästä
;   IX+6-7: varattu

ENEMY_NONE      EQU 0
ENEMY_ROBOT     EQU 1
ENEMY_TANK      EQU 2
ENEMY_GHOST     EQU 3
ENEMY_WIZARD    EQU 4           ; boss — ks. boss.asm, elää ENEMIES[0]:ssa
ENEMY_SIZE      EQU 8
MAX_ENEMIES     EQU 6

ENEMIES         EQU 0xC010      ; 6*8=48 tavua RAM:issa
RAND_SEED       EQU 0xC040      ; 2 tavua

; Vähimmäisetäisyys pelaajasta spawnissa/teleportissa (PICK_SPAWN_POS), px
SPAWN_MIN_PLAYER_DIST EQU 50

ROBOT_COLOR     EQU 10          ; keltainen
TANK_COLOR      EQU 13          ; magenta
GHOST_COLOR     EQU 15          ; valkoinen
GHOST_SPEED     EQU 2           ; nopeampi kuin robotti/tankki (ENEMY_SPEED=1)
GHOST_PAT_BASE  EQU 76          ; RADAR_DOT_PAT(72) varaa 4 patternia (72-75), 32 patternia: 76-107
; Haamun näkyvyyspuskuri: kuinka monta pikseliä pelaajan 16x16-spriten
; reunan ulkopuolelle näkyvyys ulottuu. Kynnys = 16 (sprite) + puskuri,
; koska abs(erotus) < kynnys kattaa sekä spritejen limityksen että puskurin
; molemmin puolin (ks. GHOST_VISIBLE).
GHOST_SIGHT_BUFFER  EQU 10
GHOST_SIGHT_TOL     EQU 16 + GHOST_SIGHT_BUFFER

ROBOT_PATS:
    ; 16x16 Robotti (pattern 8 = offset 64, yksi frame)
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

ROBOT_PATS_END:

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

GHOST_PATS:

    ; Vasen 1
    DB $00,$07,$0F,$0A,$0F,$09,$1F,$1F
    DB $1F,$3F,$3F,$3F,$3D,$29,$24,$00
    DB $00,$00,$80,$80,$C0,$C0,$C0,$E0
    DB $F0,$F0,$F8,$FE,$F8,$24,$90,$00
    ; Vasen 2
    DB $00,$06,$1F,$15,$1F,$13,$1F,$1F
    DB $1F,$3F,$3F,$3F,$3D,$24,$12,$00
    DB $00,$00,$00,$00,$80,$80,$C0,$E0
    DB $F0,$F8,$F8,$FC,$FE,$92,$48,$00
    ; Oikea 1
    DB $00,$00,$01,$01,$03,$03,$03,$07
    DB $0F,$0F,$1F,$7F,$1F,$24,$09,$00
    DB $00,$E0,$F0,$50,$F0,$90,$F8,$F8
    DB $F8,$FC,$FC,$FC,$BC,$94,$24,$00
    ; Oikea 2
    DB $00,$00,$00,$00,$01,$01,$03,$07
    DB $0F,$1F,$1F,$3F,$7F,$49,$12,$00
    DB $00,$60,$F8,$A8,$F8,$C8,$F8,$F8
    DB $F8,$FC,$FC,$FC,$BC,$24,$48,$00
    ; Alas 1
    DB $00,$08,$28,$1C,$5F,$3F,$1F,$5F
    DB $3F,$0F,$5F,$3F,$1F,$7E,$00,$00
    DB $00,$00,$00,$00,$00,$80,$F0,$FC
    DB $F6,$DE,$D6,$FC,$C0,$00,$00,$00
    ; Alas 2
    DB $00,$30,$18,$5E,$3F,$1F,$5F,$3F
    DB $1F,$4F,$3F,$1F,$5F,$3E,$00,$00
    DB $00,$00,$00,$00,$00,$80,$C0,$F0
    DB $FC,$F6,$DE,$D4,$FC,$00,$00,$00
    ; Ylös 1
    DB $00,$00,$00,$03,$3F,$6B,$7B,$6F
    DB $3F,$0F,$01,$00,$00,$00,$00,$00
    DB $00,$00,$7E,$F8,$FC,$FA,$F0,$FC
    DB $FA,$F8,$FC,$FA,$38,$14,$10,$00
    ; Ylös 2
    DB $00,$00,$00,$3F,$2B,$7B,$6F,$3F
    DB $0F,$03,$01,$00,$00,$00,$00,$00
    DB $00,$00,$7C,$FA,$F8,$FC,$F2,$F8
    DB $FC,$FA,$F8,$FC,$7A,$18,$0C,$00

GHOST_PATS_END:

; Tutkan piste-sprite. 16x16-spritetila varaa AINA 4 peräkkäistä patternia
; per sprite (vaikka piirretäänkin vain yksi 8x8-neljännes) — loput 3 täytyy
; olla tyhjiä ettei seuraavan ladatun spriten data vuoda niihin.
; Piste on 2x2 pikseliä vasemmassa yläkulmassa (neljännes 1/4, ylä-vasen).
RADAR_DOT_PATS:
    DB $C0,$C0,$00,$00,$00,$00,$00,$00      ; ylä-vasen: piste
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; ala-vasen: tyhjä
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; ylä-oikea: tyhjä
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; ala-oikea: tyhjä
RADAR_DOT_PATS_END:

    ALIGN   4
ROBOT_DIR_PAT:
    DB 32, 36, 44, 40   ; DIR_RIGHT=0, DIR_LEFT=1, DIR_UP=2, DIR_DOWN=3
TANK_DIR_PAT:
    DB 64, 64, 68, 68   ; vaaka sama sprite molemmille suunnille, sama pystylle

    ALIGN   8
; Haamun suunta+animaatiokehys → pattern. Indeksi = suunta*2 + kehys(0/1)
GHOST_DIR_PAT:
    DB GHOST_PAT_BASE+8,  GHOST_PAT_BASE+12   ; DIR_RIGHT kehys0,1 (Oikea1,2)
    DB GHOST_PAT_BASE+0,  GHOST_PAT_BASE+4    ; DIR_LEFT  kehys0,1 (Vasen1,2)
    DB GHOST_PAT_BASE+24, GHOST_PAT_BASE+28   ; DIR_UP    kehys0,1 (Ylös1,2)
    DB GHOST_PAT_BASE+16, GHOST_PAT_BASE+20   ; DIR_DOWN  kehys0,1 (Alas1,2)

; =============================================================================
; WAVE_TABLE — vihollismäärät per taso (muokkaa tätä helposti!)
; Muoto: DB robotit, tankit, haamut, wizard(0/1)
; robotit+tankit+haamut ei saa ylittää MAX_ENEMIES (= 6). Jos wizard=1,
; muut sarakkeet jätetään huomiotta ja spawnataan VAIN Wizard (boss-taso) —
; ks. boss.asm. Viimeinen rivi toistuu kaikilla myöhemmillä tasoilla.
; =============================================================================
WAVE_TABLE:
    DB  2, 0, 0, 0    ; taso 1: 2 robottia
    DB  0, 2, 0, 0    ; taso 2: 2 tankkia
    DB  3, 1, 1, 0    ; taso 3: 3 robottia, 1 tankki, 1 haamu
    DB  2, 2, 1, 0    ; taso 4: 2 robottia, 2 tankkia, 1 haamu
    DB  3, 2, 1, 0    ; taso 5: 3 robottia, 2 tankkia, 1 haamu
    DB  0, 0, 0, 1    ; taso 6: BOSS (Wizard)
    DB  3, 2, 1, 0    ; taso 7+: takaisin normaaliin, toistuu
WAVE_TABLE_END:
MAX_WAVE_ENTRIES EQU (WAVE_TABLE_END - WAVE_TABLE) / 4

; =============================================================================
; RAND — 16-bit LFSR satunnaisluku, ulostulo A
; Fibonacci-LFSR, hanat bitit 16,14,13,11 (= H:n bitit 7,5,4,2), polynomi
; x^16+x^14+x^13+x^11+1 (maksimipituus 65535).
;
; HUOM #1: vanha versio yhdisti feedback-bitin LSB:ksi "OR H":lla nollaamatta
; kohdebittiä ensin — jos rotaation tuoma LSB oli jo 1, feedback ei koskaan
; voinut kirjoittaa sitä nollaksi. Tämä lyhensi jakson 22 tilaan 65535:stä.
; Korjattu: SLA/RL siirtää LSB:n eksplisiittisesti nollaksi ennen
; feedback-bitin OR:aamista.
;
; HUOM #2: yhden bitin siirto per kutsu tekee PERÄKKÄISISTÄ kutsuista
; voimakkaasti korreloituneita (tila muuttuu vain 1 bitin verran), koska
; koko 16-bittinen tila on lähes sama kahden peräkkäisen kutsun välillä.
; Tämä näkyi esim. PICK_SPAWN_POS:issa (sarake+rivi peräkkäin) niin, että
; vain ~64 eri (sarake,rivi)-yhdistelmää oli koskaan mahdollisia, vaikka
; itse LFSR:n jakso on täysi. Korjattu siirtämällä kokonainen tavu (8 bittiä)
; per RAND-kutsu — tämä nostaa erillisten peräkkäisten parien määrän lähes
; teoreettiseen maksimiin.
; =============================================================================
RAND:
    PUSH    BC
    PUSH    DE
    PUSH    HL
    LD      HL, (RAND_SEED)
    LD      B, 8               ; siirrä koko tavu (8 bittiä) kutsua kohti
.rstep:
    ; feedback = H.bit7 XOR H.bit2 XOR H.bit4 XOR H.bit5 (hanat 16,11,13,14)
    LD      A, H
    RLCA                        ; A.bit0 = H.bit7
    LD      C, A
    LD      A, H
    RRCA : RRCA                 ; A.bit0 = H.bit2
    XOR     C
    LD      C, A
    LD      A, H
    RLCA : RLCA : RLCA : RLCA   ; A.bit0 = H.bit4
    XOR     C
    LD      C, A
    LD      A, H
    RLCA : RLCA : RLCA          ; A.bit0 = H.bit5
    XOR     C
    AND     0x01
    LD      E, A                ; E.bit0 = feedback

    ; Siirrä HL vasemmalle 1 bitti (LSB nollautuu), lisää feedback LSB:ksi
    SLA     L
    RL      H
    LD      A, L : OR E : LD L, A
    DJNZ    .rstep

    LD      (RAND_SEED), HL
    LD      A, L
    POP     HL
    POP     DE
    POP     BC
    RET

; =============================================================================
; INIT_ENEMIES
; =============================================================================
INIT_ENEMIES:
    ; Alusta LFSR siemen
    LD      HL, 0xACE1 : LD (RAND_SEED), HL

    ; Lataa Robotti-patternit (pattern 32 = offset 256)
    LD      HL, VRAM_SPRITE_PAT + 256 : CALL VDP_SETW
    LD      HL, ROBOT_PATS
    LD      B, ROBOT_PATS_END - ROBOT_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .pp
    ; Lataa Tank-patternit (pattern 64 = offset 512, bullet/explosion-patternien
    ; jälkeen — bullet.asm:n kaksi ammus-suuntaa + 2 räjähdystä vievät 48-63)
    LD      HL, VRAM_SPRITE_PAT + 512 : CALL VDP_SETW
    LD      HL, TANK_PATS
    LD      B, TANK_PATS_END - TANK_PATS
.tp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .tp
    ; Lataa tutkan piste-pattern (RADAR_DOT_PAT=72, tank-patternien jälkeen).
    ; 16x16-tila varaa 4 patternia vaikka piirretään vain 1 — ladataan koko lohko.
    LD      HL, VRAM_SPRITE_PAT + RADAR_DOT_PAT*8 : CALL VDP_SETW
    LD      HL, RADAR_DOT_PATS
    LD      B, RADAR_DOT_PATS_END - RADAR_DOT_PATS
.rdp:LD     A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .rdp
    ; Lataa Haamu-patternit (GHOST_PAT_BASE=76, tutkan pisteen 4 patternin jälkeen)
    ; Koko on tasan 256 tavua — DJNZ+LD B ei sovi (B on 8-bittinen), käytetään BC-laskuria
    LD      HL, VRAM_SPRITE_PAT + GHOST_PAT_BASE*8 : CALL VDP_SETW
    LD      HL, GHOST_PATS
    LD      BC, GHOST_PATS_END - GHOST_PATS
.gp: LD     A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .gp

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

; SPAWN_ROBOT — luo Robotti IX-osoitteeseen NAVMAP-pisteiden kautta
SPAWN_ROBOT:
    CALL    PICK_SPAWN_POS
    CALL    RAND : AND 0x03 : LD (IX+2), A
    LD      (IX+3), ENEMY_ROBOT
    LD      (IX+4), 1
    LD      (IX+5), ENEMY_SPEED
    RET

; SPAWN_TANK — luo Tankki IX-osoitteeseen NAVMAP-pisteiden kautta
SPAWN_TANK:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_TANK
    LD      (IX+4), 1
    LD      (IX+5), ENEMY_SPEED
    RET

; SPAWN_GHOST — luo Haamu IX-osoitteeseen NAVMAP-pisteiden kautta
SPAWN_GHOST:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_GHOST
    LD      (IX+4), 1
    LD      (IX+5), GHOST_SPEED
    RET

; =============================================================================
; PICK_SPAWN_POS — valitsee spawn-pisteen NAVMAP:ista
; Sisääntulo: IX = kohdeslotti
; Vaatimukset: NAVMAP-piste vapaa, etäisyys pelaajiin >= SPAWN_MIN_PLAYER_DIST px,
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
    CP      SPAWN_MIN_PLAYER_DIST : JR NC, .psp_p2
    LD      A, (P1_Y) : LD B, A : LD A, (IX+1) : SUB B
    JP      P, .psp_p1yp : NEG
.psp_p1yp:
    CP      SPAWN_MIN_PLAYER_DIST : JR C, .pspbad
.psp_p2:
    ; Tarkista P2-etäisyys (jos elossa)
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .psp_prev
    LD      A, (P2_LIVES) : OR A : JR Z, .psp_prev
    LD      A, (P2_X) : LD B, A : LD A, (IX+0) : SUB B
    JP      P, .psp_p2xp : NEG
.psp_p2xp:
    CP      SPAWN_MIN_PLAYER_DIST : JR NC, .psp_prev
    LD      A, (P2_Y) : LD B, A : LD A, (IX+1) : SUB B
    JP      P, .psp_p2yp : NEG
.psp_p2yp:
    CP      SPAWN_MIN_PLAYER_DIST : JR C, .pspbad
.psp_prev:
    ; Tarkista päällekkäisyys jo aktiivisten vihollisten kanssa (vain active=1)
    LD      A, (IX+0) : LD D, A
    LD      A, (IX+1) : LD E, A
    LD      IY, ENEMIES
    LD      B, MAX_ENEMIES
.psp_elp:
    LD      A, (IY+4) : OR A : JR Z, .psp_enxt   ; ei aktiivinen → ohita
    ; Ohita kutsujan oma slotti (IY == IX) — muuten jo aktiivisen vihollisen
    ; uudelleensijoitus (esim. Wizardin teleportti) vertaisi itseään itseensä
    ; (etäisyys aina 0) ja hylkäisi jokaisen ehdokkaan.
    PUSH    BC
    PUSH    IX : POP HL
    PUSH    IY : POP BC
    OR      A : SBC HL, BC
    POP     BC
    JR      Z, .psp_enxt
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
; GET_NAVMAP_DIRS — A = NAVMAP[(IX+1)/8 * 32 + (IX+0)/8]
; Vapaan suunnan bittikartta vihollisen (IX) nykyisestä ruudusta.
; Tuhoaa vain A ja HL — B, C, D, E säilyvät (kutsujat luottavat tähän).
; =============================================================================
GET_NAVMAP_DIRS:
    LD      A, (IX+1) : SRL A : SRL A : SRL A   ; A = Y/8 = tiilirivi
    LD      H, 0 : LD L, A
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL   ; rivi*32
    LD      A, (IX+0) : SRL A : SRL A : SRL A   ; A = X/8 = tiilisarake
    ADD     A, L : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL)
    RET

; =============================================================================
; RANDOM_TURN — seinä edessä: kokeile satunnaisia suuntia (16 yritystä)
; Asettaa (IX+2) jos vapaa suunta löytyy. Nopeus luetaan (IX+5):stä.
; Yhteinen Robotille ja Chaserille (tankki/haamu). Tuhoaa A, B, C, D, E.
; =============================================================================
RANDOM_TURN:
    LD      B, 16
.try:
    PUSH    BC
    CALL    RAND : AND 0x03 : LD D, A

    CP      DIR_UP : JR NZ, .tu
    LD      A, (IX+1) : SUB (IX+5) : CP 8 : JR C, .tbad
    LD      E, A : LD B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tu:CP      DIR_DOWN : JR NZ, .td
    LD      A, (IX+1) : ADD A, (IX+5) : CP 153 : JR NC, .tbad
    LD      E, A : LD B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.td:CP      DIR_LEFT : JR NZ, .tl
    LD      A, (IX+0) : SUB (IX+5) : JR C, .tbad
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tl:LD      A, (IX+0) : ADD A, (IX+5) : CP 241 : JR NC, .tbad
    LD      E, A : LD A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
.tok:
    LD      (IX+2), D
    POP     BC : RET
.tbad:
    POP     BC : DJNZ .try
    RET

; =============================================================================
; UPDATE_ROBOT — liikuta yksi Robotti (IX = data), nopeus (IX+5)
; =============================================================================
UPDATE_ROBOT:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    ; Kokeile liikkua nykyiseen suuntaan — tukossa → RANDOM_TURN
    CP      DIR_UP : JR NZ, .not_up
    LD      A, (IX+1) : SUB (IX+5) : CP 8 : JP C, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+1), E : JP .maybe_turn
.not_up:
    CP      DIR_DOWN : JR NZ, .not_down
    LD      A, (IX+1) : ADD A, (IX+5) : CP 153 : JP NC, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+1), E : JP .maybe_turn
.not_down:
    CP      DIR_LEFT : JR NZ, .not_left
    LD      A, (IX+0) : SUB (IX+5) : JP C, RANDOM_TURN
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+0), E : JP .maybe_turn
.not_left:
    ; DIR_RIGHT
    LD      A, (IX+0) : ADD A, (IX+5) : CP 241 : JP NC, RANDOM_TURN
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+0), E

.maybe_turn:
    ; 8px tasaustarkistus — käänny vain tiilirajan kohdalla
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    ; 25% todennäköisyysportti
    CALL    RAND : AND 0x03 : RET NZ

    CALL    GET_NAVMAP_DIRS  ; A = suuntabittikartta
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
; UPDATE_CHASER — liikuta vihollista pelaajaa kohti (IX = data), nopeus (IX+5)
; Yhteinen tankille ja haamulle: SPAWN_* asettaa nopeuden (IX+5),
; muuten logiikka on identtinen. Haamulle ei kutsuta TANK_TRY_SHOOT:ia.
; =============================================================================
UPDATE_CHASER:
    LD      A, (IX+2) : LD D, A     ; D = suunta

    CP      DIR_UP : JR NZ, .tnup
    LD      A, (IX+1) : SUB (IX+5) : CP 8 : JP C, .tchg
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tnup:
    CP      DIR_DOWN : JR NZ, .tndn
    LD      A, (IX+1) : ADD A, (IX+5) : CP 153 : JP NC, .tchg
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tndn:
    CP      DIR_LEFT : JR NZ, .tnlt
    LD      A, (IX+0) : SUB (IX+5) : JP C, .tchg
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E : JP .tmt
.tnlt:
    LD      A, (IX+0) : ADD A, (IX+5) : CP 241 : JP NC, .tchg
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
    CALL    GET_NAVMAP_DIRS      ; ei koske B/C/D/E:tä
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
    ; Seinä edessä — laske suunta pelaajaa kohti ja kokeile sitä;
    ; tukossa → yhteinen RANDOM_TURN (tail-call)
    CALL    TANK_TOWARD_PLAYER
    LD      D, A

    ; Kokeile suuntaa D — tarkista MOLEMMAT kulmat (sama kuin pääliikuntakoodi)
    CP      DIR_UP : JR NZ, .ttu_nd
    LD      A, (IX+1) : SUB (IX+5) : CP 8 : JP C, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nd:
    CP      DIR_DOWN : JR NZ, .ttu_nl
    LD      A, (IX+1) : ADD A, (IX+5) : CP 153 : JP NC, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nl:
    CP      DIR_LEFT : JR NZ, .ttu_nr
    LD      A, (IX+0) : SUB (IX+5) : JP C, RANDOM_TURN
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nr:
    LD      A, (IX+0) : ADD A, (IX+5) : CP 241 : JP NC, RANDOM_TURN
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET

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
    CP      ENEMY_ROBOT : JR NZ, .chk_tank
    PUSH    DE : CALL UPDATE_ROBOT : POP DE
    LD      A, D : CALL ENEMY_TRY_SHOOT
    JR      .skip
.chk_tank:
    CP      ENEMY_TANK : JR NZ, .chk_ghost
    PUSH    DE : CALL UPDATE_CHASER : POP DE
    CALL    TANK_TRY_SHOOT
    JR      .skip
.chk_ghost:
    CP      ENEMY_GHOST : JR NZ, .chk_wizard
    CALL    UPDATE_CHASER         ; sama jahtauslogiikka kuin tankilla, ei ammu
    JR      .skip
.chk_wizard:
    CP      ENEMY_WIZARD : JR NZ, .skip
    CALL    UPDATE_WIZARD         ; boss.asm: robotti-liike + teleporttaus
    CALL    WIZARD_TRY_SHOOT      ; oma ammusslotti, ei jaeta ENEMY_BULLETSin kanssa
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
    LD      A, (IX+3) : CP ENEMY_WIZARD : JR Z, .hide  ; piirretään erikseen DRAW_WIZARD:issa
    CP      ENEMY_GHOST : JR Z, .dghost
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .dtank
    LD      HL, ROBOT_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, ROBOT_COLOR : OUT (VDP_DATA), A
    JR      .next
.dtank:
    LD      HL, TANK_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, TANK_COLOR : OUT (VDP_DATA), A
    JR      .next

.dghost:
    ; Haamu näkyy vain kun pelaaja on samalla rivillä/sarakkeella
    CALL    GHOST_VISIBLE
    OR      A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    ; Pattern: suunta*2 + animaatiokehys (FRAME_CTR bitti 3, vaihtuu 8 framen välein)
    ; HUOM: käytä C:tä, ei B:tä — B on tämän silmukan DJNZ-laskuri (MAX_ENEMIES)
    LD      A, (IX+2) : ADD A, A : LD C, A
    LD      A, (FRAME_CTR) : SRL A : SRL A : SRL A : AND 0x01
    ADD     A, C
    LD      HL, GHOST_DIR_PAT : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, GHOST_COLOR : OUT (VDP_DATA), A
    JR      .next

.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A

.next:
    ADD     IX, DE          ; B (laskuri) ei koske — LD BC,n olisi nollannut B:n
    DEC     B : JP NZ, .loop   ; DJNZ ei riitä (silmukka >128 tavua)
    RET

; =============================================================================
; GHOST_VISIBLE — onko haamu (IX) näkyvissä? (elossaoleva pelaaja samalla
; rivillä TAI sarakkeella, toleranssi <4px)
; Ulostulo: A=1 (näkyvissä) tai A=0 (piilossa). Tuhoaa: C.
; HUOM: ei saa käyttää B:tä eikä D/E:tä — DRAW_ENEMIES:n kutsuva silmukka
; pitää B:ssä DJNZ-laskurin ja DE:ssä pysyvän ENEMY_SIZE-askeleen (ADD IX,DE
; silmukan lopussa) — kumpaakaan ei saa sotkea.
; =============================================================================
GHOST_VISIBLE:
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .gv_p2
    LD      A, (P1_LIVES) : OR A : JR Z, .gv_p2
    LD      A, (P1_Y) : LD C, A : LD A, (IX+1) : SUB C
    JP      P, .gv_p1y : NEG
.gv_p1y:
    CP      GHOST_SIGHT_TOL : JR C, .gv_yes
    LD      A, (P1_X) : LD C, A : LD A, (IX+0) : SUB C
    JP      P, .gv_p1x : NEG
.gv_p1x:
    CP      GHOST_SIGHT_TOL : JR C, .gv_yes
.gv_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .gv_no
    LD      A, (P2_LIVES) : OR A : JR Z, .gv_no
    LD      A, (P2_Y) : LD C, A : LD A, (IX+1) : SUB C
    JP      P, .gv_p2y : NEG
.gv_p2y:
    CP      GHOST_SIGHT_TOL : JR C, .gv_yes
    LD      A, (P2_X) : LD C, A : LD A, (IX+0) : SUB C
    JP      P, .gv_p2x : NEG
.gv_p2x:
    CP      GHOST_SIGHT_TOL : JR C, .gv_yes
.gv_no:
    XOR     A : RET
.gv_yes:
    LD      A, 1 : RET

; =============================================================================
; DRAW_RADAR — piirtää vihollisten sijainnit tutkaan spriteinä (spritet
; RADAR_SPRITE_BASE..+5, yksi per ENEMIES-slotti). Kehys (hud.asm) on kiinteä,
; tämä piirtää vain pisteet oikean värisinä (ROBOT/TANK/GHOST_COLOR).
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

    ; Väri: robotti=keltainen, tank=magenta, ghost=valkoinen
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .rtankcol
    CP      ENEMY_GHOST : JR Z, .rghostcol
    LD      A, ROBOT_COLOR : JR .rcolout
.rtankcol:
    LD      A, TANK_COLOR : JR .rcolout
.rghostcol:
    LD      A, GHOST_COLOR
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
    LD      HL, BULLET_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A                             ; pattern suunnan mukaan
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
    LD      HL, BULLET_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A                             ; pattern suunnan mukaan
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
    ; indeksi * 4 (4 tavua per merkintä: robotit, tankit, haamut, wizard)
    ADD     A, A : ADD A, A
    LD      HL, WAVE_TABLE
    ADD     A, L : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      B, (HL) : INC HL : LD C, (HL) : INC HL
    LD      D, (HL) : INC HL : LD A, (HL)
                        ; B = robotit, C = tankit, D = haamut, A = wizard (tuorein)

    ; Wizard-sarake tarkistetaan heti — jos 1, spawnaa VAIN Wizard (boss-taso)
    OR      A : JR Z, .no_boss
    LD      A, 1 : LD (BOSS_ACTIVE), A
    LD      IX, ENEMIES
    JP      SPAWN_WIZARD
.no_boss:
    XOR     A : LD (BOSS_ACTIVE), A

    LD      IX, ENEMIES

    ; Spawnaa haamut ensin (D tuoreena ennen kuin B/C käytetään omissa silmukoissaan)
    LD      A, D : OR A : JR Z, .sw_tanks
.sw_ghost:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_GHOST
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_ghost

.sw_tanks:
    ; Spawnaa tankit
    LD      A, C : OR A : JR Z, .sw_robots
    LD      D, C
.sw_tank:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_TANK
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_tank

.sw_robots:
    ; Spawnaa robotit
    LD      A, B : OR A : RET Z
    LD      D, B
.sw_robot:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_ROBOT
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_robot
    RET
