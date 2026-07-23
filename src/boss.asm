; =============================================================================
; boss.asm — Wizard-pomo (boss-taso)
; =============================================================================
;
; Wizard on normaalikokoinen 16x16-sprite, mutta kaksivärinen: kaksi
; spriteä (WIZARD_SPRITE_BASE ja +1) samassa X/Y-kohdassa, eri pattern
; ja väri. TMS9918A:ssa pienempi sprite-numero piirtyy PÄÄLLE, joten
; WIZARD_SPRITE_BASE (korostusväri, osittainen pattern) on edessä ja
; WIZARD_SPRITE_BASE+1 (perusväri, täysi pattern) takana — näin
; korostusväri näkyy täysvärisen pohjan päällä.
;
; SUUNTA+ANIMAATIO: WIZARD_DIR_PAT-taulukossa on 16 alkiota (4 suuntaa x
; 2 animaatiokehystä x 2 kerrosta), samaan tapaan kuin GHOST_DIR_PAT. Kaikki
; 16 pattern-ryhmää (WIZARD_PATS) ovat aitoa, toisistaan riippumatonta
; grafiikkaa — väri9-versiot etukerroksena, väri13-versiot takana.
;
; Wizard "asuu" ENEMIES[0]:ssa samalla tietorakenteella kuin muutkin
; viholliset (X,Y,suunta,tyyppi,aktiivinen,nopeus) — siksi UPDATE_ROBOT
; kelpaa liikkumiseen sellaisenaan.
;
; BOSS-TILA: kun BOSS_ACTIVE=1, SPAWN_ENEMIES_FOR_LEVEL ei spawnaa
; Robotteja/Tankkeja/Haamuja lainkaan (vain Wizard + pelaajat). Koska
; Wizard on nyt vain 3 spriteä (2 runko + 1 ammus) sloteissa 26-28, se
; mahtuu jo ennestään vapaisiin sprite-indekseihin eikä törmää mihinkään
; — MAINLOOP:in ei tarvitse ohittaa muita DRAW/UPDATE-kutsuja.
;
; TUNNETTU RAJOITUS: CHECK_BULLET_HIT ja vihollisen kosketustarkistus
; olettavat ~16x16 hitboxin — tämä pitää paikkansa nyt kun Wizard on
; normaalikokoinen, joten erillistä korjausta ei (enää) tarvita.
; =============================================================================

WIZARD_SPRITE_BASE    EQU 26      ; sprite 26 (edessä, korostus) + 27 (takana, pohja)
WIZARD_BULLET_SPRITE  EQU 28      ; oma ammussprite
WIZARD_TOTAL_SPRITES  EQU 3       ; 26,27,28 — hide_all-silmukalle

WIZARD_SPEED          EQU 2
WIZARD_BULLET_SPEED   EQU 3       ; nopeampi kuin Robotin/Tankin ammukset (ENEMY_BULLET_SPEED)
WIZARD_COLOR_A        EQU 13      ; takakerros (runko): magenta
WIZARD_COLOR_B        EQU 9       ; etukerros (korostus): vaaleanpunainen/-punainen
WIZARD_TELEPORT_INTERVAL EQU 180  ; framea (~3s 60fps) — säädettävissä

; WIZARD_PATS-datassa on 16 ryhmää (4 tavua/ryhmä = 16x16-pattern):
; ryhmät 0-7 = väri9 (etukerros), järjestys Oikea1,Oikea2,Vasen1,Vasen2,
; Alas1,Alas2,Ylös1,Ylös2; ryhmät 8-15 = sama järjestys väri13:lla (takakerros)
WIZARD_PAT_BASE       EQU 108     ; GHOST_PAT_BASE(76)+32 patternia jälkeen

; RAM (vapaa alue TANK_BULLETS:n (0xC099-0xC0A0) ja NAVMAP:in (0xC100) välissä)
BOSS_ACTIVE           EQU 0xC0A1  ; 1 = boss-taso käynnissä
WIZARD_BULLET         EQU 0xC0A2  ; 4 tavua: X,Y,suunta,aktiivinen
WIZARD_TELEPORT_TIMER EQU 0xC0A6  ; 1 tavu: framelaskuri seuraavaan teleporttaukseen

; Dummy-patternit (kvadrantit aina järjestyksessä: vasen-ylä, vasen-ala,
; oikea-ylä, oikea-ala — sama käytäntö kuin muualla tässä tiedostossa)
WIZARD_PATS:
    ; Oikea 1 väri 9
    DB $00,$00,$00,$00,$03,$03,$01,$00
    DB $00,$00,$01,$03,$00,$00,$00,$00
    DB $00,$00,$00,$00,$A0,$F0,$C0,$00
    DB $00,$00,$20,$20,$00,$00,$00,$00
    ; Oikea 2 väri 9
    DB $00,$00,$00,$00,$03,$03,$01,$00
    DB $00,$00,$00,$0C,$00,$00,$00,$00
    DB $00,$00,$00,$00,$A0,$F0,$C0,$00
    DB $00,$08,$08,$00,$00,$00,$00,$00
    ; Vasen 1 väri 9
    DB $00,$00,$00,$00,$05,$0F,$03,$00
    DB $00,$00,$04,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$C0,$C0,$80,$00
    DB $00,$00,$80,$C0,$00,$00,$00,$00
    ; Vasen 2 väri 9
    DB $00,$00,$00,$00,$05,$0F,$03,$00
    DB $00,$10,$10,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$C0,$C0,$80,$00
    DB $00,$00,$00,$30,$00,$00,$00,$00
    ; Alas 1 väri 9
    DB $00,$00,$00,$00,$00,$00,$0C,$0E
    DB $0E,$06,$0C,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$10,$30
    DB $00,$00,$30,$00,$00,$00,$00,$00
    ; Alas 2 väri 9
    DB $00,$00,$00,$00,$00,$00,$0C,$0E
    DB $0E,$06,$0C,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$10,$10,$00,$00
    DB $00,$00,$00,$00,$60,$00,$00,$00
    ; Ylös 1 väri 9
    DB $00,$00,$00,$00,$00,$0C,$00,$00
    DB $0C,$08,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$20,$30,$60,$70
    DB $70,$30,$00,$00,$00,$00,$00,$00
    ; Ylös 2 väri 9
    DB $00,$00,$00,$06,$00,$00,$00,$00
    DB $00,$00,$08,$08,$00,$00,$00,$00
    DB $00,$00,$00,$00,$20,$30,$60,$70
    DB $70,$30,$00,$00,$00,$00,$00,$00
    ; Oikea 1 väri 13
    DB $02,$06,$07,$03,$00,$00,$00,$00
    DB $03,$03,$02,$00,$01,$01,$01,$01
    DB $A0,$B0,$F0,$E0,$00,$00,$00,$80
    DB $C0,$C6,$D8,$C0,$C0,$80,$80,$C0
    ; Oikea 2 väri 13
    DB $02,$06,$07,$03,$00,$00,$00,$00
    DB $03,$07,$0F,$01,$01,$03,$06,$06
    DB $A0,$B0,$F0,$E2,$02,$04,$04,$88
    DB $E8,$F0,$F0,$C0,$D0,$70,$30,$00
    ; Vasen 1 väri 13
    DB $05,$0D,$0F,$07,$00,$00,$00,$01
    DB $03,$63,$1B,$03,$03,$01,$01,$03
    DB $40,$60,$E0,$C0,$00,$00,$00,$00
    DB $C0,$C0,$40,$00,$80,$80,$80,$80
    ; Vasen 2 väri 13
    DB $05,$0D,$0F,$47,$40,$20,$20,$11
    DB $17,$0F,$0F,$03,$0B,$0E,$0C,$00
    DB $40,$60,$E0,$C0,$00,$00,$00,$00
    DB $C0,$E0,$F0,$80,$80,$C0,$60,$60
    ; Alas 1 väri 13
    DB $00,$00,$00,$00,$00,$60,$F0,$30
    DB $F1,$30,$F0,$60,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$E0,$CF
    DB $FF,$F9,$00,$20,$20,$40,$40,$00
    ; Alas 2 väri 13
    DB $00,$00,$00,$00,$00,$60,$F0,$30
    DB $F1,$30,$F0,$60,$01,$06,$18,$00
    DB $00,$00,$00,$00,$20,$63,$E7,$FC
    DB $F8,$FC,$E6,$6E,$80,$00,$00,$00
    ; Ylös 1 väri 13
    DB $00,$02,$02,$04,$04,$00,$9F,$FF
    DB $F3,$07,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$06,$0F,$0C,$8F
    DB $0C,$0F,$06,$00,$00,$00,$00,$00
    ; Ylös 2 väri 13
    DB $00,$00,$00,$01,$76,$67,$3F,$1F
    DB $3F,$E7,$C6,$04,$00,$00,$00,$00
    DB $00,$18,$60,$80,$06,$0F,$0C,$8F
    DB $0C,$0F,$06,$00,$00,$00,$00,$00
WIZARD_PATS_END:

    ALIGN   16
; Suunta+kehys → (etukerros väri9, takakerros väri13). Indeksi = (suunta*2+kehys)*2
; WIZARD_PATS-ryhmät: 0=Oikea1 1=Oikea2 2=Vasen1 3=Vasen2 4=Alas1 5=Alas2
; 6=Ylös1 7=Ylös2 (väri9), +8 sama järjestys väri13:lla. Ryhmä g = BASE+g*4.
WIZARD_DIR_PAT:
    DB WIZARD_PAT_BASE+0,  WIZARD_PAT_BASE+32   ; DIR_RIGHT kehys0 (Oikea1)
    DB WIZARD_PAT_BASE+4,  WIZARD_PAT_BASE+36   ; DIR_RIGHT kehys1 (Oikea2)
    DB WIZARD_PAT_BASE+8,  WIZARD_PAT_BASE+40   ; DIR_LEFT  kehys0 (Vasen1)
    DB WIZARD_PAT_BASE+12, WIZARD_PAT_BASE+44   ; DIR_LEFT  kehys1 (Vasen2)
    DB WIZARD_PAT_BASE+24, WIZARD_PAT_BASE+56   ; DIR_UP    kehys0 (Ylös1)
    DB WIZARD_PAT_BASE+28, WIZARD_PAT_BASE+60   ; DIR_UP    kehys1 (Ylös2)
    DB WIZARD_PAT_BASE+16, WIZARD_PAT_BASE+48   ; DIR_DOWN  kehys0 (Alas1)
    DB WIZARD_PAT_BASE+20, WIZARD_PAT_BASE+52   ; DIR_DOWN  kehys1 (Alas2)

; =============================================================================
; INIT_BOSS — lataa dummy-patternit ja nollaa boss-tilan
; =============================================================================
INIT_BOSS:
    LD      HL, VRAM_SPRITE_PAT + WIZARD_PAT_BASE*8 : CALL VDP_SETW
    LD      HL, WIZARD_PATS
    ; 512 tavua (16 ryhmää * 32) — DJNZ+LD B ei sovi (B on 8-bittinen),
    ; käytetään BC-laskuria (sama korjaus kuin GHOST_PATS:issa)
    LD      BC, WIZARD_PATS_END - WIZARD_PATS
.lp: LD     A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp

    XOR     A : LD (BOSS_ACTIVE), A
    LD      HL, WIZARD_BULLET
    LD      (HL), A : INC HL : LD (HL), A : INC HL : LD (HL), A : INC HL : LD (HL), A
    RET

; =============================================================================
; SPAWN_WIZARD — luo Wizard ENEMIES[0]:aan
; Sisääntulo: IX = ENEMIES (kutsuja asettaa)
; =============================================================================
SPAWN_WIZARD:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_WIZARD
    LD      (IX+4), 1
    LD      (IX+5), WIZARD_SPEED
    LD      A, WIZARD_TELEPORT_INTERVAL : LD (WIZARD_TELEPORT_TIMER), A
    RET

; =============================================================================
; UPDATE_WIZARD — liikkuu kuten Robotti + teleporttaus kiinteällä välillä
; Sisääntulo: IX = ENEMIES[0] (Wizard)
; =============================================================================
UPDATE_WIZARD:
    CALL    UPDATE_ROBOT

    LD      A, (WIZARD_TELEPORT_TIMER)
    DEC     A
    LD      (WIZARD_TELEPORT_TIMER), A
    OR      A : RET NZ

    ; Ajastin nollassa — teleporttaa uuteen NAVMAP-pisteeseen ja nollaa ajastin.
    ; Sekoita FRAME_CTR RAND-siemeneen ensin: koska teleport-väli on kiinteä
    ; (180 framea), RAND-kutsujen määrä siitä edellisestä teleportista voi
    ; olla sama joka kerta jos Wizardin liike on tarpeeksi deterministinen —
    ; tällöin LFSR olisi aina samassa tilassa ja arpoisi saman pisteen.
    ; FRAME_CTR kasvaa koko ajan, joten se rikkoo mahdollisen jakson.
    LD      A, (FRAME_CTR)
    LD      HL, (RAND_SEED)
    XOR     L : LD L, A
    LD      (RAND_SEED), HL
    CALL    PICK_SPAWN_POS
    LD      A, WIZARD_TELEPORT_INTERVAL : LD (WIZARD_TELEPORT_TIMER), A
    RET

; =============================================================================
; WIZARD_TRY_SHOOT — ampuu kuten Robotti (ENEMY_TRY_SHOOT), mutta omaan
; WIZARD_BULLET-slottiin (ei jaeta ENEMY_BULLETSin kanssa). Kohde: P1 jos
; linjassa, muuten P2.
; Sisääntulo: IX = ENEMIES[0] (Wizard)
; =============================================================================
WIZARD_TRY_SHOOT:
    PUSH    BC : PUSH DE : PUSH HL

    LD      A, (WIZARD_BULLET+3) : OR A : JR NZ, .done   ; jo aktiivinen

    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .try_p2
    LD      A, (P1_LIVES)    : OR A : JR Z, .try_p2
    LD      A, (P1_X) : LD B, A : LD A, (P1_Y) : LD C, A
    JR      .check
.try_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .done
    LD      A, (P2_LIVES)    : OR A : JR Z, .done
    LD      A, (P2_X) : LD B, A : LD A, (P2_Y) : LD C, A

.check:
    ; Sama rivi? |wizardY - targetY| < 4
    LD      A, (IX+1) : SUB C
    JP      P, .ry_ok
    NEG
.ry_ok:
    CP      4 : JR C, .same_row

    ; Sama sarake? |wizardX - targetX| < 4
    LD      A, (IX+0) : SUB B
    JP      P, .cx_ok
    NEG
.cx_ok:
    CP      4 : JR NC, .done        ; ei linjassa

    LD      A, C : CP (IX+1)
    JR      NC, .col_down
    LD      D, DIR_UP : JR .fire
.col_down:
    LD      D, DIR_DOWN : JR .fire

.same_row:
    LD      A, B : CP (IX+0)
    JR      NC, .row_right
    LD      D, DIR_LEFT : JR .fire
.row_right:
    LD      D, DIR_RIGHT

.fire:
    LD      A, (IX+2) : CP D : JR NZ, .done   ; ammu vain suuntaan jota kohti liikkuu
    CALL    RAND : AND 1 : JR NZ, .done        ; 50% todennäköisyys

    LD      HL, WIZARD_BULLET
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, D : LD (HL), A : INC HL : LD (HL), 1

.done:
    POP     HL : POP DE : POP BC
    RET

; =============================================================================
; UPDATE_WIZARD_BULLET — liikuta Wizardin ammus omalla nopeudellaan
; (kopio UPDATE_ENEMY_BULLET:sta WIZARD_BULLET_SPEED:llä — ei voi käyttää
; ENEMY_BULLET_SPEED:iä sellaisenaan, koska se on yhteinen kaikille
; Robotin/Tankin ammuksille)
; =============================================================================
UPDATE_WIZARD_BULLET:
    LD      IX, WIZARD_BULLET
    LD      A, (IX+3) : OR A : RET Z        ; ei aktiivinen

    LD      A, (IX+2)                        ; suunta
    CP      DIR_UP : JR NZ, .wbu_nd
    LD      A, (IX+1) : SUB WIZARD_BULLET_SPEED
    JR      C, .wbu_deact
    CP      8 : JR C, .wbu_deact
    LD      (IX+1), A : JR .wbu_wall
.wbu_nd:
    CP      DIR_DOWN : JR NZ, .wbu_nl
    LD      A, (IX+1) : ADD A, WIZARD_BULLET_SPEED
    CP      153 : JR NC, .wbu_deact
    LD      (IX+1), A : JR .wbu_wall
.wbu_nl:
    CP      DIR_LEFT : JR NZ, .wbu_nr
    LD      A, (IX+0) : SUB WIZARD_BULLET_SPEED
    JR      C, .wbu_deact
    LD      (IX+0), A : JR .wbu_wall
.wbu_nr:
    LD      A, (IX+0) : ADD A, WIZARD_BULLET_SPEED
    CP      241 : JR NC, .wbu_deact
    LD      (IX+0), A
.wbu_wall:
    LD      A, (IX+0) : ADD A, 8 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A
    CALL    IS_WALL : JR NZ, .wbu_deact
    CALL    CHECK_ENEMY_BULLET_PLAYER_HIT
    RET
.wbu_deact:
    LD      (IX+3), 0
    RET

; =============================================================================
; DRAW_WIZARD — piirrä Wizardin 2 spriteä + ammus. Piilottaa itsensä jos
; boss ei aktiivinen. Käyttää .vdp_dly-viivettä (31T) jokaisen OUT:in
; välissä, koska osa kirjoituksista on liian nopeita peräkkäin ilman sitä.
; =============================================================================
DRAW_WIZARD:
    LD      A, (BOSS_ACTIVE) : OR A : JP Z, .hide_all
    LD      IX, ENEMIES                 ; Wizard = ENEMIES[0]
    LD      A, (IX+4) : OR A : JP Z, .hide_all

    ; Pattern-indeksi WIZARD_DIR_PAT:iin = suunta*4 + kehys*2
    ; (kehys = FRAME_CTR bitti 3, vaihtuu n. 8 framen välein, sama kuin Haamulla)
    LD      A, (IX+2) : ADD A, A : ADD A, A : LD C, A      ; C = suunta*4
    LD      A, (FRAME_CTR) : SRL A : SRL A : SRL A : AND 1
    ADD     A, A : ADD A, C                                  ; A = suunta*4 + kehys*2
    LD      HL, WIZARD_DIR_PAT : ADD A, L : LD L, A
    LD      A, (HL) : LD D, A                                ; D = korostus-pattern
    INC     HL : LD A, (HL) : LD E, A                         ; E = pohja-pattern

    LD      HL, VRAM_SPRITE_ATT + WIZARD_SPRITE_BASE*4 : CALL VDP_SETW

    ; Sprite 26 (edessä): korostusväri, suunta+kehys-pattern
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, (IX+0) : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, D : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, WIZARD_COLOR_B : OUT (VDP_DATA), A
    CALL    .vdp_dly

    ; Sprite 27 (takana): perusväri, sama suunta+kehys-pattern (pohja)
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, (IX+0) : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, E : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, WIZARD_COLOR_A : OUT (VDP_DATA), A
    CALL    .vdp_dly

    ; Wizardin ammus (oma sprite, ei jaettu ENEMY_BULLETSin kanssa)
    LD      A, (WIZARD_BULLET+3) : OR A : JR Z, .hide_bullet
    LD      A, (WIZARD_BULLET+1) : DEC A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, (WIZARD_BULLET+0) : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      HL, BULLET_DIR_PAT : LD A, (WIZARD_BULLET+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, ENEMY_BULLET_COLOR : OUT (VDP_DATA), A
    RET
.hide_bullet:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    CALL    .vdp_dly
    XOR     A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    OUT     (VDP_DATA), A
    CALL    .vdp_dly
    OUT     (VDP_DATA), A
    RET

.hide_all:
    LD      HL, VRAM_SPRITE_ATT + WIZARD_SPRITE_BASE*4 : CALL VDP_SETW
    LD      B, WIZARD_TOTAL_SPRITES
.hloop:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    DJNZ    .hloop
    RET

.vdp_dly:
    NOP                         ; CALL(17T) + NOP(4T) + RET(10T) = 31T gap
    RET
