; =============================================================================
; boss.asm — Wizard boss (boss level)
; =============================================================================
;
; The Wizard is a normal-sized 16x16 sprite, but two-colored: two sprites
; (WIZARD_SPRITE_BASE and +1) at the same X/Y position, with different
; patterns and colors. On the TMS9918A the lower sprite number is drawn ON
; TOP, so WIZARD_SPRITE_BASE (highlight color, partial pattern) is in front
; and WIZARD_SPRITE_BASE+1 (base color, full pattern) is behind — this way
; the highlight color shows up over the full-color base.
;
; DIRECTION+ANIMATION: the WIZARD_DIR_PAT table has 16 entries (4 directions x
; 2 animation frames x 2 layers), the same way as GHOST_DIR_PAT. All 16
; pattern groups (WIZARD_PATS) are genuine, independent graphics — the
; color-9 versions as the front layer, the color-13 versions behind.
;
; The Wizard "lives" in ENEMIES[0] using the same data structure as the
; other enemies (X,Y,direction,type,active,speed) — that's why UPDATE_ROBOT
; works for its movement as-is.
;
; BOSS MODE: while BOSS_ACTIVE=1, SPAWN_ENEMIES_FOR_LEVEL doesn't spawn any
; Robots/Tanks/Ghosts at all (only the Wizard + players). Since the Wizard
; is now just 3 sprites (2 body + 1 bullet) in slots 26-28, it already fits
; into sprite indices that were free and doesn't collide with anything —
; MAINLOOP doesn't need to skip any other DRAW/UPDATE calls.
;
; KNOWN LIMITATION: CHECK_BULLET_HIT and the enemy-touch check assume a
; ~16x16 hitbox — this still holds now that the Wizard is normal-sized, so
; no separate fix is (still) needed.
; =============================================================================

WIZARD_SPRITE_BASE    EQU 26      ; sprite 26 (front, highlight) + 27 (back, base); 28 = its own bullet
WIZARD_TOTAL_SPRITES  EQU 3       ; 26,27,28 — for the hide-all loop

; Speed of the Wizard and its bullet: see CUR_WIZARD_SPEED_X2 / CUR_WIZARD_BULLET_SPEED
; (enemy.asm) — per-round now, no longer fixed constants.
WIZARD_COLOR_A        EQU 13      ; back layer (body): magenta
WIZARD_COLOR_B        EQU 9       ; front layer (highlight): pink/red
WIZARD_TELEPORT_INTERVAL EQU 120  ; frames (~3s at 60fps) — tunable

; The WIZARD_PATS data has 16 groups (4 bytes/group = 16x16 pattern):
; groups 0-7 = color 9 (front layer), order Right1,Right2,Left1,Left2,
; Down1,Down2,Up1,Up2; groups 8-15 = same order with color 13 (back layer)
WIZARD_PAT_BASE       EQU 108     ; GHOST_PAT_BASE(76)+32 patterns further

; RAM (free area between TANK_BULLETS (0xC099-0xC0A0) and NAVMAP (0xC100))
BOSS_ACTIVE           EQU 0xC0A1  ; 1 = boss level running
WIZARD_BULLET         EQU 0xC0A2  ; 4 bytes: X,Y,direction,active
WIZARD_TELEPORT_TIMER EQU 0xC0A6  ; 1 byte: frame counter to the next teleport

; Dummy patterns (quadrants always in order: top-left, bottom-left,
; top-right, bottom-right — same convention as elsewhere in this file)
WIZARD_PATS:
    ; Right 1 color 9
    DB $00,$00,$00,$00,$03,$03,$01,$00
    DB $00,$00,$01,$03,$00,$00,$00,$00
    DB $00,$00,$00,$00,$A0,$F0,$C0,$00
    DB $00,$00,$20,$20,$00,$00,$00,$00
    ; Right 2 color 9
    DB $00,$00,$00,$00,$03,$03,$01,$00
    DB $00,$00,$00,$0C,$00,$00,$00,$00
    DB $00,$00,$00,$00,$A0,$F0,$C0,$00
    DB $00,$08,$08,$00,$00,$00,$00,$00
    ; Left 1 color 9
    DB $00,$00,$00,$00,$05,$0F,$03,$00
    DB $00,$00,$04,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$C0,$C0,$80,$00
    DB $00,$00,$80,$C0,$00,$00,$00,$00
    ; Left 2 color 9
    DB $00,$00,$00,$00,$05,$0F,$03,$00
    DB $00,$10,$10,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$C0,$C0,$80,$00
    DB $00,$00,$00,$30,$00,$00,$00,$00
    ; Down 1 color 9
    DB $00,$00,$00,$00,$00,$00,$0C,$0E
    DB $0E,$06,$0C,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$10,$30
    DB $00,$00,$30,$00,$00,$00,$00,$00
    ; Down 2 color 9
    DB $00,$00,$00,$00,$00,$00,$0C,$0E
    DB $0E,$06,$0C,$04,$00,$00,$00,$00
    DB $00,$00,$00,$00,$10,$10,$00,$00
    DB $00,$00,$00,$00,$60,$00,$00,$00
    ; Up 1 color 9
    DB $00,$00,$00,$00,$00,$0C,$00,$00
    DB $0C,$08,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$20,$30,$60,$70
    DB $70,$30,$00,$00,$00,$00,$00,$00
    ; Up 2 color 9
    DB $00,$00,$00,$06,$00,$00,$00,$00
    DB $00,$00,$08,$08,$00,$00,$00,$00
    DB $00,$00,$00,$00,$20,$30,$60,$70
    DB $70,$30,$00,$00,$00,$00,$00,$00
    ; Right 1 color 13
    DB $02,$06,$07,$03,$00,$00,$00,$00
    DB $03,$03,$02,$00,$01,$01,$01,$01
    DB $A0,$B0,$F0,$E0,$00,$00,$00,$80
    DB $C0,$C6,$D8,$C0,$C0,$80,$80,$C0
    ; Right 2 color 13
    DB $02,$06,$07,$03,$00,$00,$00,$00
    DB $03,$07,$0F,$01,$01,$03,$06,$06
    DB $A0,$B0,$F0,$E2,$02,$04,$04,$88
    DB $E8,$F0,$F0,$C0,$D0,$70,$30,$00
    ; Left 1 color 13
    DB $05,$0D,$0F,$07,$00,$00,$00,$01
    DB $03,$63,$1B,$03,$03,$01,$01,$03
    DB $40,$60,$E0,$C0,$00,$00,$00,$00
    DB $C0,$C0,$40,$00,$80,$80,$80,$80
    ; Left 2 color 13
    DB $05,$0D,$0F,$47,$40,$20,$20,$11
    DB $17,$0F,$0F,$03,$0B,$0E,$0C,$00
    DB $40,$60,$E0,$C0,$00,$00,$00,$00
    DB $C0,$E0,$F0,$80,$80,$C0,$60,$60
    ; Down 1 color 13
    DB $00,$00,$00,$00,$00,$60,$F0,$30
    DB $F1,$30,$F0,$60,$00,$00,$00,$00
    DB $00,$00,$00,$00,$00,$00,$E0,$CF
    DB $FF,$F9,$00,$20,$20,$40,$40,$00
    ; Down 2 color 13
    DB $00,$00,$00,$00,$00,$60,$F0,$30
    DB $F1,$30,$F0,$60,$01,$06,$18,$00
    DB $00,$00,$00,$00,$20,$63,$E7,$FC
    DB $F8,$FC,$E6,$6E,$80,$00,$00,$00
    ; Up 1 color 13
    DB $00,$02,$02,$04,$04,$00,$9F,$FF
    DB $F3,$07,$00,$00,$00,$00,$00,$00
    DB $00,$00,$00,$00,$06,$0F,$0C,$8F
    DB $0C,$0F,$06,$00,$00,$00,$00,$00
    ; Up 2 color 13
    DB $00,$00,$00,$01,$76,$67,$3F,$1F
    DB $3F,$E7,$C6,$04,$00,$00,$00,$00
    DB $00,$18,$60,$80,$06,$0F,$0C,$8F
    DB $0C,$0F,$06,$00,$00,$00,$00,$00
WIZARD_PATS_END:

    ALIGN   16
; Direction+frame → (front layer color 9, back layer color 13). Index = (direction*2+frame)*2
; WIZARD_PATS groups: 0=Right1 1=Right2 2=Left1 3=Left2 4=Down1 5=Down2
; 6=Up1 7=Up2 (color 9), +8 same order with color 13. Group g = BASE+g*4.
WIZARD_DIR_PAT:
    DB WIZARD_PAT_BASE+0,  WIZARD_PAT_BASE+32   ; DIR_RIGHT frame0 (Right1)
    DB WIZARD_PAT_BASE+4,  WIZARD_PAT_BASE+36   ; DIR_RIGHT frame1 (Right2)
    DB WIZARD_PAT_BASE+8,  WIZARD_PAT_BASE+40   ; DIR_LEFT  frame0 (Left1)
    DB WIZARD_PAT_BASE+12, WIZARD_PAT_BASE+44   ; DIR_LEFT  frame1 (Left2)
    DB WIZARD_PAT_BASE+24, WIZARD_PAT_BASE+56   ; DIR_UP    frame0 (Up1)
    DB WIZARD_PAT_BASE+28, WIZARD_PAT_BASE+60   ; DIR_UP    frame1 (Up2)
    DB WIZARD_PAT_BASE+16, WIZARD_PAT_BASE+48   ; DIR_DOWN  frame0 (Down1)
    DB WIZARD_PAT_BASE+20, WIZARD_PAT_BASE+52   ; DIR_DOWN  frame1 (Down2)

; =============================================================================
; INIT_BOSS — load the dummy patterns and reset boss state
; =============================================================================
INIT_BOSS:
    LD      HL, VRAM_SPRITE_PAT + WIZARD_PAT_BASE*8 : CALL VDP_SETW
    LD      HL, WIZARD_PATS
    ; 512 bytes (16 groups * 32) — DJNZ+LD B doesn't fit (B is 8-bit),
    ; use a BC counter instead (same fix as in GHOST_PATS)
    LD      BC, WIZARD_PATS_END - WIZARD_PATS
.lp: LD     A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp

    XOR     A : LD (BOSS_ACTIVE), A
    LD      HL, WIZARD_BULLET
    LD      (HL), A : INC HL : LD (HL), A : INC HL : LD (HL), A : INC HL : LD (HL), A
    RET

; =============================================================================
; SPAWN_WIZARD — create the Wizard in ENEMIES[0]
; Input: IX = ENEMIES (set by the caller)
; =============================================================================
SPAWN_WIZARD:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_WIZARD
    LD      (IX+4), 1
    LD      A, (CUR_WIZARD_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0                   ; half-pixel accumulator reset
    LD      (IX+7), 0                   ; shooting cooldown reset
    LD      A, WIZARD_TELEPORT_INTERVAL : LD (WIZARD_TELEPORT_TIMER), A
    RET

; =============================================================================
; UPDATE_WIZARD — moves like the Robot + teleports at a fixed interval
; Input: IX = ENEMIES[0] (Wizard)
; =============================================================================
UPDATE_WIZARD:
    CALL    UPDATE_ROBOT

    LD      A, (WIZARD_TELEPORT_TIMER)
    DEC     A
    LD      (WIZARD_TELEPORT_TIMER), A
    OR      A : RET NZ

    ; Timer at zero — teleport to a new NAVMAP point and reset the timer.
    ; Mix FRAME_CTR into the RAND seed first: since the teleport interval is
    ; fixed (180 frames), the number of RAND calls since the previous
    ; teleport could be the same every time if the Wizard's movement is
    ; deterministic enough — in that case the LFSR would always be in the
    ; same state and roll the same point. FRAME_CTR keeps increasing, so it
    ; breaks any such cycle.
    LD      A, (FRAME_CTR)
    LD      HL, (RAND_SEED)
    XOR     L : LD L, A
    LD      (RAND_SEED), HL
    CALL    PICK_SPAWN_POS
    LD      A, WIZARD_TELEPORT_INTERVAL : LD (WIZARD_TELEPORT_TIMER), A
    RET

; =============================================================================
; WIZARD_TRY_SHOOT — fires like the Robot (ENEMY_TRY_SHOOT), but into its own
; WIZARD_BULLET slot (not shared with ENEMY_BULLETS). Target: P1 if
; in line, otherwise P2.
; Input: IX = ENEMIES[0] (Wizard)
; =============================================================================
WIZARD_TRY_SHOOT:
    PUSH    BC : PUSH DE : PUSH HL

    LD      A, (WIZARD_BULLET+3) : OR A : JR NZ, .done   ; already active

    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .try_p2
    LD      A, (P1_LIVES)    : OR A : JR Z, .try_p2
    LD      A, (P1_X) : LD B, A : LD A, (P1_Y) : LD C, A
    JR      .check
.try_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .done
    LD      A, (P2_LIVES)    : OR A : JR Z, .done
    LD      A, (P2_X) : LD B, A : LD A, (P2_Y) : LD C, A

.check:
    ; Same row? |wizardY - targetY| < 4
    LD      A, (IX+1) : SUB C
    JP      P, .ry_ok
    NEG
.ry_ok:
    CP      4 : JR C, .same_row

    ; Same column? |wizardX - targetX| < 4
    LD      A, (IX+0) : SUB B
    JP      P, .cx_ok
    NEG
.cx_ok:
    CP      4 : JR NC, .done        ; not in line

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
    LD      A, (IX+2) : CP D : JR NZ, .done   ; only fire in the direction it's moving toward
    CALL    ENEMY_SHOOT_ROLL : JR NZ, .done    ; cooldown+50% (Z=fire)

    LD      HL, WIZARD_BULLET
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, D : LD (HL), A : INC HL : LD (HL), 1

.done:
    POP     HL : POP DE : POP BC
    RET

; =============================================================================
; UPDATE_WIZARD_BULLET — move the Wizard's bullet at its own speed
; (a copy of UPDATE_ENEMY_BULLET using CUR_WIZARD_BULLET_SPEED — can't use
; CUR_BULLET_SPEED as-is, since that's shared by the Robot/Tank bullets and
; the Wizard's formula differs, see enemy.asm)
; =============================================================================
UPDATE_WIZARD_BULLET:
    LD      IX, WIZARD_BULLET
    LD      A, (IX+3) : OR A : RET Z        ; not active

    LD      A, (CUR_WIZARD_BULLET_SPEED) : LD B, A  ; B = current speed
    LD      A, (IX+2)                        ; direction
    CP      DIR_UP : JR NZ, .wbu_nd
    LD      A, (IX+1) : SUB B
    JR      C, .wbu_deact
    CP      8 : JR C, .wbu_deact
    LD      (IX+1), A : JR .wbu_wall
.wbu_nd:
    CP      DIR_DOWN : JR NZ, .wbu_nl
    LD      A, (IX+1) : ADD A, B
    CP      153 : JR NC, .wbu_deact
    LD      (IX+1), A : JR .wbu_wall
.wbu_nl:
    CP      DIR_LEFT : JR NZ, .wbu_nr
    LD      A, (IX+0) : SUB B
    JR      C, .wbu_deact
    LD      (IX+0), A : JR .wbu_wall
.wbu_nr:
    LD      A, (IX+0) : ADD A, B
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
; DRAW_WIZARD — draw the Wizard's 2 sprites + bullet. Hides itself if the
; boss isn't active. Uses a .vdp_dly delay (31T) between each OUT, because
; some of the writes are too fast back-to-back without it.
; =============================================================================
DRAW_WIZARD:
    LD      A, (BOSS_ACTIVE) : OR A : JP Z, .hide_all
    LD      IX, ENEMIES                 ; Wizard = ENEMIES[0]
    LD      A, (IX+4) : OR A : JP Z, .hide_all

    ; Pattern index into WIZARD_DIR_PAT = direction*4 + frame*2
    ; (frame = FRAME_CTR bit 3, changes roughly every 8 frames, same as the Ghost)
    LD      A, (IX+2) : ADD A, A : ADD A, A : LD C, A      ; C = direction*4
    LD      A, (FRAME_CTR) : SRL A : SRL A : SRL A : AND 1
    ADD     A, A : ADD A, C                                  ; A = direction*4 + frame*2
    LD      HL, WIZARD_DIR_PAT : ADD A, L : LD L, A
    LD      A, (HL) : LD D, A                                ; D = highlight pattern
    INC     HL : LD A, (HL) : LD E, A                         ; E = base pattern

    LD      HL, VRAM_SPRITE_ATT + WIZARD_SPRITE_BASE*4 : CALL VDP_SETW

    ; Sprite 26 (front): highlight color, direction+frame pattern
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, (IX+0) : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, D : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, WIZARD_COLOR_B : OUT (VDP_DATA), A
    CALL    .vdp_dly

    ; Sprite 27 (back): base color, same direction+frame pattern (base layer)
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, (IX+0) : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, E : OUT (VDP_DATA), A
    CALL    .vdp_dly
    LD      A, WIZARD_COLOR_A : OUT (VDP_DATA), A
    CALL    .vdp_dly

    ; The Wizard's bullet (its own sprite, not shared with ENEMY_BULLETS)
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
