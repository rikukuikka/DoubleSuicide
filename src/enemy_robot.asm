; =============================================================================
; enemy_robot.asm — Robot enemy: graphics, spawning, wandering movement,
; shooting (into its own ENEMY_BULLETS slot) and sprite drawing.
; Shared enemy code (data structure, dispatch, RAND, spawn points,
; RANDOM_TURN etc.) is in enemy.asm.
; =============================================================================

ROBOT_COLOR     EQU 10          ; yellow

ROBOT_PATS:
    ; 16x16 Robot, 4 directions (patterns 32-47, loaded by LOAD_ROBOT_PATS)
    ;Right
    DB $00,$03,$07,$07,$03,$01,$03,$06
    DB $05,$05,$06,$3F,$49,$49,$3F,$00
    DB $00,$C0,$00,$E0,$E0,$80,$C0,$64
    DB $FE,$A0,$60,$FC,$92,$92,$FC,$00
    ;Left
    DB $00,$03,$00,$07,$07,$01,$03,$26
    DB $7F,$05,$06,$3F,$49,$49,$3F,$00
    DB $00,$C0,$E0,$E0,$C0,$80,$C0,$60
    DB $A0,$A0,$60,$FC,$92,$92,$FC,$00
    ;Down
    DB $00,$30,$48,$48,$78,$4F,$4C,$7B
    DB $7B,$4D,$4F,$79,$49,$49,$31,$00
    DB $00,$00,$00,$00,$00,$8C,$DE,$7E
    DB $7A,$DA,$98,$00,$00,$80,$00,$00
    ;Up
    DB $00,$00,$01,$00,$00,$19,$5B,$5E
    DB $7E,$7B,$31,$00,$00,$00,$00,$00
    DB $00,$8C,$92,$92,$9E,$F2,$B2,$DE
    DB $DE,$32,$F2,$1E,$12,$12,$0C,$00

ROBOT_PATS_END:

    ALIGN   4
ROBOT_DIR_PAT:
    DB 32, 36, 44, 40   ; DIR_RIGHT=0, DIR_LEFT=1, DIR_UP=2, DIR_DOWN=3

; LOAD_ROBOT_PATS — Robot patterns to VRAM (pattern 32 = offset 256)
LOAD_ROBOT_PATS:
    LD      HL, VRAM_SPRITE_PAT + 256
    LD      DE, ROBOT_PATS
    LD      BC, ROBOT_PATS_END - ROBOT_PATS
    JP      VDP_WRITE_BLOCK

; SPAWN_ROBOT — create a Robot at the IX address via a NAVMAP point
SPAWN_ROBOT:
    CALL    PICK_SPAWN_POS
    CALL    RAND : AND 0x03 : LD (IX+2), A
    LD      (IX+3), ENEMY_ROBOT
    LD      (IX+4), 1
    LD      A, (CUR_RT_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0                   ; half-pixel accumulator reset
    LD      (IX+7), 0                   ; shooting cooldown reset
    RET

; =============================================================================
; UPDATE_ROBOT — move a single Robot (IX = data), speed (IX+5, half-pixels).
; Wanders: goes straight, turns randomly at tile boundaries, RANDOM_TURN when
; blocked. The Wizard uses this for its movement too (UPDATE_WIZARD, boss.asm).
; =============================================================================
UPDATE_ROBOT:
    CALL    GET_MOVE_DELTA          ; (MOVE_DELTA) = this frame's pixel count
    LD      A, (IX+2) : LD D, A     ; D = direction

    ; Try moving in the current direction — blocked → RANDOM_TURN
    CP      DIR_UP : JR NZ, .not_up
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : SUB C : CP 8 : JP C, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+1), E : JP .maybe_turn
.not_up:
    CP      DIR_DOWN : JR NZ, .not_down
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : ADD A, C : CP 153 : JP NC, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+1), E : JP .maybe_turn
.not_down:
    CP      DIR_LEFT : JR NZ, .not_left
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : SUB C : JP C, RANDOM_TURN
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+0), E : JP .maybe_turn
.not_left:
    ; DIR_RIGHT
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : ADD A, C : CP 241 : JP NC, RANDOM_TURN
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+0), E

.maybe_turn:
    ; 8px alignment check — only turn when on a tile boundary
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    ; 25% probability gate
    CALL    RAND : AND 0x03 : RET NZ

    CALL    GET_NAVMAP_DIRS  ; A = direction bitmap
    OR      A : RET Z        ; no directions available

    ; Filter to directions perpendicular to the current movement direction
    LD      B, A             ; B = all available directions
    LD      A, (IX+2) : AND 0x02   ; bit 1 = axis (0=horizontal, 2=vertical)
    JR      NZ, .mt_vert
    ; Horizontal (RIGHT/LEFT) → vertical perpendiculars (UP=b2, DOWN=b3)
    LD      A, B : SRL A : SRL A : AND 0x03
    LD      C, 2            ; base direction UP=2, DOWN=3
    JR      .mt_pick
.mt_vert:
    ; Vertical (UP/DOWN) → horizontal perpendiculars (RIGHT=b0, LEFT=b1)
    LD      A, B : AND 0x03
    LD      C, 0            ; base direction RIGHT=0, LEFT=1
.mt_pick:
    OR      A : RET Z        ; no perpendiculars available → keep going straight
    LD      B, A
    CP      0x03 : JR NZ, .mt_one
    ; Both perpendicular directions free → pick one at random
    CALL    RAND : AND 0x01 : OR C : LD (IX+2), A
    RET
.mt_one:
    ; Only one perpendicular direction — pick it
    BIT     0, B : JR NZ, .mt_b0
    LD      A, C : INC A : LD (IX+2), A   ; bit1 → LEFT or DOWN
    RET
.mt_b0:
    LD      A, C : LD (IX+2), A            ; bit0 → RIGHT or UP
    RET

; =============================================================================
; ROBOT_TRY_SHOOT — try to have a Robot fire at a player
; Input: IX = enemy data, A = enemy index (0-5)
; Fires if the enemy is on the same row or column as the target (50% probability)
; Odd index → P1, even → P2
; =============================================================================
ROBOT_TRY_SHOOT:
    PUSH    BC
    PUSH    DE
    PUSH    HL

    LD      E, A                    ; E = enemy index
    ADD     A, A : ADD A, A         ; A = index * 4
    LD      HL, ENEMY_BULLETS
    ADD     A, L : LD L, A          ; HL = &ENEMY_BULLETS[index]
    PUSH    HL : POP IY             ; IY = bullet slot

    LD      A, (IY+3) : OR A : JR NZ, .done  ; already active → don't fire

    ; Pick target: single-player always P1; two-player odd→P1, even→P2
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
    ; Same row? |enemyY - targetY| < 4
    LD      A, (IX+1) : SUB C
    JP      P, .ry_ok
    NEG
.ry_ok:
    CP      4 : JR C, .same_row

    ; Same column? |enemyX - targetX| < 4
    LD      A, (IX+0) : SUB B
    JP      P, .cx_ok
    NEG
.cx_ok:
    CP      4 : JR NC, .done        ; not in line

    ; Same column: fire up or down
    LD      A, C : CP (IX+1)
    JR      NC, .col_down
    LD      D, DIR_UP : JR .fire
.col_down:
    LD      D, DIR_DOWN : JR .fire

.same_row:
    ; Same row: fire left or right
    LD      A, B : CP (IX+0)
    JR      NC, .row_right
    LD      D, DIR_LEFT : JR .fire
.row_right:
    LD      D, DIR_RIGHT

.fire:
    LD      A, (IX+2) : CP D : JR NZ, .done  ; only fire in the direction it's moving toward
    LD      B, ENEMY_SHOOT_COOLDOWN
    CALL    ENEMY_SHOOT_ROLL : JR NZ, .done  ; cooldown+50% (Z=fire)

    LD      A, (IX+0) : LD (IY+0), A       ; X
    LD      A, (IX+1) : LD (IY+1), A       ; Y
    LD      A, D        : LD (IY+2), A      ; direction
    LD      (IY+3), 1                        ; active

.done:
    POP     HL
    POP     DE
    POP     BC
    RET

; =============================================================================
; DRAW_ROBOT_SPRITE — write the Robot's 4 sprite attribute bytes (Y, X,
; pattern, color) to the VDP. Input: IX = enemy data, VDP address already set.
; Clobbers A, HL. Must preserve B and DE (DRAW_ENEMIES's loop counter/step).
; =============================================================================
DRAW_ROBOT_SPRITE:
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    LD      HL, ROBOT_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, ROBOT_COLOR : OUT (VDP_DATA), A
    RET
