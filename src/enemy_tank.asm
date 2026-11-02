; =============================================================================
; enemy_tank.asm — Tank enemy: graphics, spawning, two-hit armor, chasing
; (UPDATE_CHASER, enemy.asm), two-way shooting with its own TANK_BULLETS and
; sprite drawing.
; =============================================================================

TANK_COLOR      EQU 7           ; cyan
TANK_HURT_COLOR EQU 5           ; light blue — tank after its first hit

TANK_PATS:

    ; Right and left
    DB $00,$00,$01,$06,$CE,$FF,$CA,$0A
    DB $7F,$CD,$B5,$B5,$CD,$7F,$00,$00
    DB $00,$00,$80,$60,$73,$FF,$53,$50
    DB $FE,$B3,$AD,$AD,$B3,$FE,$00,$00
    ; Down and up
    DB $1E,$33,$2D,$2D,$33,$3F,$21,$3F
    DB $3F,$21,$3F,$33,$2D,$2D,$33,$1E
    DB $70,$70,$20,$20,$F0,$38,$F8,$24
    DB $24,$F8,$38,$F0,$20,$20,$70,$70

TANK_PATS_END:

    ALIGN   4
TANK_DIR_PAT:
    DB 64, 64, 68, 68   ; same sprite for both horizontal directions, same for vertical

; LOAD_TANK_PATS — Tank patterns to VRAM (pattern 64 = offset 512, after the
; bullet/explosion patterns — bullet.asm's two bullet directions + 2
; explosions take 48-63)
LOAD_TANK_PATS:
    LD      HL, VRAM_SPRITE_PAT + 512
    LD      DE, TANK_PATS
    LD      BC, TANK_PATS_END - TANK_PATS
    JP      VDP_WRITE_BLOCK

; =============================================================================
; TANK_HITS_PTR — HL = &ENEMY_HITS[slot of IX]. Clobbers A only.
; =============================================================================
TANK_HITS_PTR:
    PUSH    IX : POP HL
    LD      A, L : SUB ENEMIES & 0xFF       ; slot * ENEMY_SIZE (8)
    RRCA : RRCA : RRCA                      ; slot number
    ADD     A, ENEMY_HITS & 0xFF
    LD      L, A : LD H, ENEMY_HITS >> 8
    RET

; SPAWN_TANK — create a Tank at the IX address via a NAVMAP point
SPAWN_TANK:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_TANK
    LD      (IX+4), 1
    LD      A, (CUR_RT_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0
    LD      (IX+7), 0
    ; A new tank is always intact: clear this slot's ENEMY_HITS entry (it may
    ; still hold 1 from a tank killed in this slot during an earlier wave)
    CALL    TANK_HITS_PTR
    LD      (HL), 0
    RET

; UPDATE_TANK — chase the player (shared UPDATE_CHASER, enemy.asm), then fire
UPDATE_TANK:
    CALL    UPDATE_CHASER
    JP      TANK_TRY_SHOOT

; =============================================================================
; TANK_TRY_SHOOT — fires in both directions when on the same row/column
; Input: IX = tank data
; =============================================================================
TANK_TRY_SHOOT:
    PUSH    BC
    PUSH    DE
    PUSH    HL

    ; Find a living player (B=X, C=Y)
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .tts_p2
    LD      A, (P1_LIVES)    : OR A : JR Z,  .tts_p2
    LD      A, (P1_X) : LD B, A : LD A, (P1_Y) : LD C, A
    JR      .tts_chk
.tts_p2:
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .tts_done
    LD      A, (P2_LIVES)    : OR A : JR Z,  .tts_done
    LD      A, (P2_X) : LD B, A : LD A, (P2_Y) : LD C, A

.tts_chk:
    ; Firing axis = the tank's movement axis (not the player's position)
    LD      A, (IX+2) : AND 0x02   ; 0=horizontal, 2=vertical
    JR      NZ, .tts_vert_axis

    ; Horizontal axis (RIGHT/LEFT): fire only if on the same row
    LD      A, (IX+1) : SUB C
    JP      P, .tts_ry
    NEG
.tts_ry:
    CP      4 : JR NC, .tts_done
    LD      B, ENEMY_SHOOT_COOLDOWN
    CALL    ENEMY_SHOOT_ROLL : JR NZ, .tts_done  ; cooldown+50% (Z=fire)
    LD      E, DIR_LEFT : LD D, DIR_RIGHT
    JR      .tts_fire

.tts_vert_axis:
    ; Vertical axis (UP/DOWN): fire only if in the same column
    LD      A, (IX+0) : SUB B
    JP      P, .tts_cx
    NEG
.tts_cx:
    CP      4 : JR NC, .tts_done
    LD      B, ENEMY_SHOOT_COOLDOWN
    CALL    ENEMY_SHOOT_ROLL : JR NZ, .tts_done  ; cooldown+50% (Z=fire)
    LD      E, DIR_UP : LD D, DIR_DOWN

.tts_fire:
    ; E = first direction, D = second direction
    LD      HL, TANK_BULLETS + 3       ; slot 0 active flag
    LD      A, (HL) : OR A : JR NZ, .tts_b1
    DEC     HL : DEC HL : DEC HL
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, E : LD (HL), A : INC HL : LD (HL), 1
.tts_b1:
    LD      HL, TANK_BULLETS + 7       ; slot 1 active flag
    LD      A, (HL) : OR A : JR NZ, .tts_done
    DEC     HL : DEC HL : DEC HL
    LD      A, (IX+0) : LD (HL), A : INC HL
    LD      A, (IX+1) : LD (HL), A : INC HL
    LD      A, D : LD (HL), A : INC HL : LD (HL), 1

.tts_done:
    POP     HL : POP DE : POP BC
    RET

; =============================================================================
; TANK_CUR_COLOR — A = the tank's (IX) color: TANK_COLOR, or TANK_HURT_COLOR
; once hit (ENEMY_HITS). Used on the field and on the radar. Clobbers HL.
; =============================================================================
TANK_CUR_COLOR:
    CALL    TANK_HITS_PTR
    LD      A, (HL) : OR A
    LD      A, TANK_COLOR : RET Z
    LD      A, TANK_HURT_COLOR
    RET

; =============================================================================
; DRAW_TANK_SPRITE — write the Tank's 4 sprite attribute bytes (Y, X,
; pattern, color) to the VDP. Input: IX = enemy data, VDP address already set.
; Clobbers A, HL. Must preserve B and DE (DRAW_ENEMIES's loop counter/step).
; =============================================================================
DRAW_TANK_SPRITE:
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    LD      HL, TANK_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    CALL    TANK_CUR_COLOR
    OUT     (VDP_DATA), A
    RET

; =============================================================================
; UPDATE_TANK_BULLETS — move the tank's 2 bullets (reuse UPDATE_ENEMY_BULLET)
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
; DRAW_TANK_BULLETS — draw the tank's bullets (sprites SPR_TBULLETS, +1)
; =============================================================================
DRAW_TANK_BULLETS:
    LD      IX, TANK_BULLETS
    LD      B, 2
    LD      HL, VRAM_SPRITE_ATT + SPR_TBULLETS*4
    CALL    VDP_SETW
.loop:
    LD      A, (IX+3) : OR A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      HL, BULLET_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A                             ; pattern based on direction
    LD      A, TANK_BULLET_COLOR  : OUT (VDP_DATA), A
    JR      .next
.hide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    CALL    VDP_DLY
    XOR     A : OUT (VDP_DATA), A
    CALL    VDP_DLY
    OUT     (VDP_DATA), A
    CALL    VDP_DLY
    OUT     (VDP_DATA), A
.next:
    INC     IX : INC IX : INC IX : INC IX
    DJNZ    .loop
    RET
