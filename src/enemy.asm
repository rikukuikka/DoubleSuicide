; =============================================================================
; enemy.asm — Enemies: shared code
; =============================================================================
; Everything common to all enemy types lives here: the data structure, the
; round/speed system, RAND, spawn point selection, the shared movement AI
; (RANDOM_TURN, UPDATE_CHASER), the per-frame UPDATE/DRAW dispatch by type,
; the radar, the per-slot enemy bullets (ENEMY_BULLETS) and WAVE_TABLE.
; Type-specific code is in enemy_robot.asm, enemy_tank.asm and
; enemy_ghost.asm (and the Wizard boss in boss.asm).
;
; Enemy data structure (8 bytes, accessed via the IX register):
;   IX+0: X
;   IX+1: Y
;   IX+2: direction (DIR_*)
;   IX+3: type (ENEMY_ROBOT etc.)
;   IX+4: active (1=yes)
;   IX+5: speed*2 (half-pixels/frame) — set in SPAWN_* from the round's
;         CUR_*_SPEED_X2 value. GET_MOVE_DELTA converts this and IX+6
;         (accumulator) into the actual pixel count for this frame.
;   IX+6: half-pixel accumulator (0/1) — updated by GET_MOVE_DELTA, don't set directly
;   IX+7: shooting cooldown counter (frames remaining, see ENEMY_SHOOT_ROLL)

ENEMY_ROBOT     EQU 1
ENEMY_TANK      EQU 2
ENEMY_GHOST     EQU 3
ENEMY_WIZARD    EQU 4           ; boss — see boss.asm, lives in ENEMIES[0]
ENEMY_SIZE      EQU 8
MAX_ENEMIES     EQU 6

ENEMIES         EQU 0xC010      ; 6*8=48 bytes in RAM
RAND_SEED       EQU 0xC040      ; 2 bytes

; Minimum distance from a player when spawning/teleporting (PICK_SPAWN_POS), px
SPAWN_MIN_PLAYER_DIST EQU 50

; Shooting cooldown: how many frames an enemy (Robot/Tank/Wizard) must wait
; after one roll before the next (see ENEMY_SHOOT_ROLL)
ENEMY_SHOOT_COOLDOWN EQU 10

; Hits taken per ENEMIES slot (1 byte per slot, index = slot number). Only
; the Tank uses it: the first player-bullet hit sets it to 1 (the tank turns
; TANK_HURT_COLOR), the second hit kills (CHECK_BULLET_HIT, bullet.asm).
; Cleared in INIT_ENEMIES and SPAWN_WAVE, and per slot in SPAWN_TANK. Kept outside the 8-byte enemy record, which is full.
ENEMY_HITS      EQU 0xC0B1      ; MAX_ENEMIES bytes (0xC0B1-0xC0B6)
; DRAW_ENEMIES's starting slot (0..MAX_ENEMIES-1), advanced every frame
; for sprite flicker
SPR_ROTATE      EQU 0xC0B7

; =============================================================================
; ROUND SYSTEM — enemy/bullet speed increases every time the Wizard is
; defeated (LEVEL resets back to 1, main.asm). One value (BASE_X2 =
; 2*base speed) drives everything — just edit BASE_X2_TABLE to tune it.
; The base speed is the Robot's/Tank's own speed, which can be 0.5
; (BASE_X2=1), so movement uses GET_MOVE_DELTA for half-pixel precision
; (see below).
; Formulas (base = BASE_X2/2):
;   Robot/Tank speed            = base        (speed_x2 = BASE_X2)
;   Ghost speed                 = 2*base       (speed_x2 = 2*BASE_X2, same as the Wizard)
;   Wizard speed                = 2*base       (speed_x2 = 2*BASE_X2)
;   Robot/Tank bullet speed     = 2*base       (always an integer, no accumulator)
;   Wizard bullet speed         = 2*base+1     (always an integer, no accumulator)
; =============================================================================
BASE_X2_TABLE:
    DB 1    ; round 1: base=0.5
    DB 2    ; round 2: base=1
    DB 4    ; round 3+: base=2 (levels off here)
BASE_X2_TABLE_END:
MAX_BASE_ENTRIES EQU BASE_X2_TABLE_END - BASE_X2_TABLE

; RAM: round number + speeds computed at the start of the round (APPLY_ROUND_SPEEDS)
ROUND                   EQU 0xC0A7  ; 1, 2, 3...
CUR_RT_SPEED_X2         EQU 0xC0A8  ; Robot & Tank, speed_x2 (into IX+5)
CUR_GHOST_SPEED_X2      EQU 0xC0A9  ; Ghost, speed_x2 (into IX+5)
CUR_WIZARD_SPEED_X2     EQU 0xC0AA  ; Wizard, speed_x2 (into IX+5, boss.asm)
CUR_BULLET_SPEED        EQU 0xC0AB  ; Robot/Tank bullet speed (integer)
CUR_WIZARD_BULLET_SPEED EQU 0xC0AC  ; Wizard bullet speed (integer, boss.asm)
MOVE_DELTA              EQU 0xC0AD  ; pixel count/frame computed by GET_MOVE_DELTA

; =============================================================================
; APPLY_ROUND_SPEEDS — computes the CUR_* speeds from (ROUND). Called at
; game start and whenever a new round begins (main.asm, after the Wizard dies).
; =============================================================================
APPLY_ROUND_SPEEDS:
    LD      A, (ROUND) : DEC A          ; 0-indexed
    CP      MAX_BASE_ENTRIES : JR C, .ok
    LD      A, MAX_BASE_ENTRIES - 1     ; clamp to the last (leveled-off) value
.ok:
    LD      HL, BASE_X2_TABLE : ADD A, L : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      A, (HL)                     ; A = BASE_X2

    LD      (CUR_RT_SPEED_X2), A        ; Robot/Tank: speed_x2 = BASE_X2
    LD      B, A                        ; B = BASE_X2 (keep it)

    ADD     A, A                        ; A = 2*BASE_X2
    LD      (CUR_WIZARD_SPEED_X2), A    ; Wizard: speed_x2 = 2*BASE_X2
    LD      (CUR_GHOST_SPEED_X2), A     ; Ghost: speed_x2 = 2*BASE_X2 (same as the Wizard)

    LD      A, B                        ; A = BASE_X2
    LD      (CUR_BULLET_SPEED), A       ; Robot/Tank bullet = BASE_X2
    INC     A
    LD      (CUR_WIZARD_BULLET_SPEED), A ; Wizard bullet = BASE_X2+1
    RET

; =============================================================================
; GET_MOVE_DELTA — compute this frame's movement using the half-pixel accumulator.
; Input: IX = enemy data (IX+5=speed*2, IX+6=accumulator 0/1)
; Output: (MOVE_DELTA) = pixel count for this frame. Updates (IX+6).
; Call EXACTLY ONCE per UPDATE_ROBOT/UPDATE_CHASER call (at the start of the
; function) — RANDOM_TURN etc. tail-calls read the same already-computed
; value and don't call this again, so the accumulator isn't consumed twice.
; =============================================================================
GET_MOVE_DELTA:
    LD      A, (IX+6) : ADD A, (IX+5)
    SRL     A                          ; A = pixels, carry = new accumulator bit
    LD      (MOVE_DELTA), A
    LD      A, 0 : ADC A, 0
    LD      (IX+6), A
    RET

; =============================================================================
; ENEMY_SHOOT_ROLL — cooldown + 50% roll for the firing decision. Shared by
; the Robot, Tank, and Wizard (WIZARD_TRY_SHOOT, boss.asm) — called only
; after the caller has already confirmed the in-line+direction conditions.
; Input: IX = enemy data (IX+7 = cooldown counter, frames remaining)
;        B  = cooldown length to apply after this roll (caller decides —
;             e.g. ENEMY_SHOOT_COOLDOWN for Robot/Tank, WIZARD_SHOOT_COOLDOWN
;             for the Wizard, boss.asm)
; Output: Z=1 → fire, Z=0 (NZ) → don't fire (on cooldown or lost the roll)
; Clobbers: A. Preserves B (RAND doesn't touch BC either).
; =============================================================================
ENEMY_SHOOT_ROLL:
    LD      A, (IX+7) : OR A : JR Z, .roll
    DEC     A : LD (IX+7), A
    OR      0xFF                 ; force NZ (on cooldown, don't fire)
    RET
.roll:
    LD      A, B : LD (IX+7), A
    CALL    RAND : AND 1          ; Z=1 → fire (50%)
    RET

; =============================================================================
; ENEMY_SHOOT_COOLDOWN_ONLY — cooldown only, no 50% roll: fires every time
; the cooldown allows. Used by the Wizard (WIZARD_TRY_SHOOT, boss.asm) so it
; shoots more aggressively than the Robot/Tank, which use ENEMY_SHOOT_ROLL.
; Input: IX = enemy data (IX+7 = cooldown counter), B = cooldown length to
;        apply once it fires.
; Output: Z=1 → fire, Z=0 (NZ) → still on cooldown
; Clobbers: A
; =============================================================================
ENEMY_SHOOT_COOLDOWN_ONLY:
    LD      A, (IX+7) : OR A : JR Z, .go
    DEC     A : LD (IX+7), A
    OR      0xFF                 ; force NZ (on cooldown, don't fire)
    RET
.go:
    LD      A, B : LD (IX+7), A
    XOR     A                   ; force Z (fire)
    RET

; Radar dot sprite. 16x16 sprite mode ALWAYS reserves 4 consecutive patterns
; per sprite (even though only one 8x8 quadrant is actually drawn) — the
; other 3 must be blank so the next loaded sprite's data doesn't leak into them.
; The dot is 2x2 pixels in the top-left corner (quadrant 1/4, top-left).
RADAR_DOT_PATS:
    DB $C0,$C0,$00,$00,$00,$00,$00,$00      ; top-left: dot
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; bottom-left: blank
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; top-right: blank
    DB $00,$00,$00,$00,$00,$00,$00,$00      ; bottom-right: blank
RADAR_DOT_PATS_END:

; =============================================================================
; WAVE_TABLE — enemy counts per level (easy to tweak here!)
; Format: DB robots, tanks, ghosts, wizard(0/1)
; robots+tanks+ghosts must not exceed MAX_ENEMIES (= 6). If wizard=1, the
; other columns are ignored and ONLY the Wizard is spawned (boss level) —
; see boss.asm. The last row repeats for all later levels.
; =============================================================================
WAVE_TABLE:
    DB  2, 0, 0, 0    ; level 1: 2 robots
    DB  0, 2, 0, 0    ; level 2: 2 tanks
    DB  3, 1, 1, 0    ; level 3: 3 robots, 1 tank, 1 ghost
    DB  2, 2, 1, 0    ; level 4: 2 robots, 2 tanks, 1 ghost
    DB  3, 2, 1, 0    ; level 5: 3 robots, 2 tanks, 1 ghost
    DB  0, 0, 0, 1    ; level 6: BOSS (Wizard)
    DB  3, 2, 1, 0    ; level 7+: back to normal, repeats
WAVE_TABLE_END:
MAX_WAVE_ENTRIES EQU (WAVE_TABLE_END - WAVE_TABLE) / 4

; =============================================================================
; RAND — 16-bit LFSR random number, output in A
; Fibonacci LFSR, taps at bits 16,14,13,11 (= state bits 15,13,12,10),
; polynomial x^16+x^14+x^13+x^11+1 (maximal length 65535). Advances a whole
; byte (8 bits) per call so consecutive outputs are decorrelated.
;
; The 8 shift steps are computed WITHOUT a loop: every tap position is >= 10,
; and the bits inserted during 8 left-shifts only ever reach positions 0-6,
; so all 8 feedback bits depend on the ORIGINAL state S alone:
;   F  = low8( (S>>8) XOR (S>>6) XOR (S>>5) XOR (S>>3) )
;   S' = (low8(S) << 8) | F
; Verified bit-exact against the old 8-step loop over all 65536 states
; (Python simulation). ~220 T-states vs ~1100 for the loop version — this
; matters because RANDOM_TURN can call RAND up to 16 times per blocked
; enemy per frame.
; Preserves BC, DE, HL.
; =============================================================================
RAND:
    PUSH    DE
    PUSH    HL
    LD      HL, (RAND_SEED)
    LD      D, H
    LD      E, L
    LD      A, H                ; A = low8(S>>8)
    SRL     D : RR E
    SRL     D : RR E
    SRL     D : RR E            ; DE = S>>3
    XOR     E                   ; A ^= low8(S>>3)
    SRL     D : RR E
    SRL     D : RR E            ; DE = S>>5
    XOR     E                   ; A ^= low8(S>>5)
    SRL     D : RR E            ; DE = S>>6
    XOR     E                   ; A = F (all 8 new bits)
    LD      H, L                ; new high byte = old low byte
    LD      L, A                ; new low byte = F
    LD      (RAND_SEED), HL
    POP     HL
    POP     DE
    RET                         ; A = new random byte

; =============================================================================
; INIT_ENEMIES
; =============================================================================
INIT_ENEMIES:
    ; Initialize the LFSR seed
    LD      HL, 0xACE1 : LD (RAND_SEED), HL

    ; Sprite patterns of each enemy type (enemy_*.asm)
    CALL    LOAD_ROBOT_PATS
    CALL    LOAD_TANK_PATS
    ; Load the radar dot pattern (RADAR_DOT_PAT=72, after the tank patterns).
    ; 16x16 mode reserves 4 patterns even though only 1 is drawn — load the whole block.
    LD      HL, VRAM_SPRITE_PAT + RADAR_DOT_PAT*8
    LD      DE, RADAR_DOT_PATS
    LD      BC, RADAR_DOT_PATS_END - RADAR_DOT_PATS
    CALL    VDP_WRITE_BLOCK
    CALL    LOAD_GHOST_PATS

    ; Clear enemies and their bullets
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr
    LD      HL, ENEMY_BULLETS
    LD      B, MAX_ENEMIES * ENEMY_BULLET_SIZE
.clrb:XOR   A : LD (HL), A : INC HL : DJNZ .clrb
    LD      HL, TANK_BULLETS
    LD      B, 2 * ENEMY_BULLET_SIZE
.clrt:XOR   A : LD (HL), A : INC HL : DJNZ .clrt
    ; Reset the per-slot hit counters (Tank takes two hits)
    LD      HL, ENEMY_HITS
    LD      B, MAX_ENEMIES
.clrh:XOR   A : LD (HL), A : INC HL : DJNZ .clrh

    ; First wave's enemies according to WAVE_TABLE (LEVEL is set in main.asm before this call)
    JP      SPAWN_ENEMIES_FOR_LEVEL

; =============================================================================
; PICK_SPAWN_POS — pick a spawn point from NAVMAP
; Input: IX = target slot
; Requirements: NAVMAP point free, distance to players >= SPAWN_MIN_PLAYER_DIST px,
;              no overlap with already-spawned enemies
; Output: IX+0=X, IX+1=Y set (or a fallback if 64 attempts fail)
; Clobbers: A, B, C, D, E, H, L, IY (IX is preserved)
; =============================================================================
PICK_SPAWN_POS:
    LD      B, 64
.psptry:
    PUSH    BC
    ; Random column 0-31
    CALL    RAND : AND 0x1F : LD D, A
    ; Random row 0-31, reject >= 21
    CALL    RAND : AND 0x1F
    CP      21 : JP NC, .pspbad
    LD      E, A
    ; NAVMAP[row*32 + column] != 0 → valid spot
    LD      H, 0 : LD L, E
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL
    LD      A, L : ADD A, D : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL) : OR A : JP Z, .pspbad
    ; Compute pixel coordinates (8px/tile)
    LD      A, D : ADD A, A : ADD A, A : ADD A, A : LD (IX+0), A
    LD      A, E : ADD A, A : ADD A, A : ADD A, A : LD (IX+1), A
    ; Check P1 distance (if alive)
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
    ; Check P2 distance (if alive)
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
    ; Check for overlap with already-active enemies (only active=1)
    LD      A, (IX+0) : LD D, A
    LD      A, (IX+1) : LD E, A
    LD      IY, ENEMIES
    LD      B, MAX_ENEMIES
.psp_elp:
    LD      A, (IY+4) : OR A : JR Z, .psp_enxt   ; not active → skip
    ; Skip the caller's own slot (IY == IX) — otherwise repositioning an
    ; already-active enemy (e.g. the Wizard's teleport) would compare
    ; itself against itself (distance always 0) and reject every candidate.
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
    CP      16 : JR C, .pspbad                    ; too close → reject
.psp_enxt:
    INC     IY : INC IY : INC IY : INC IY
    INC     IY : INC IY : INC IY : INC IY
    DJNZ    .psp_elp
    ; All checks passed
    POP     BC : RET
.pspbad:
    POP     BC : DEC B : JP NZ, .psptry
    ; All 64 random attempts failed (e.g. the map is full of other enemies/
    ; players nearby) — scan NAVMAP with deterministic logic that
    ; GUARANTEES it never lands on a wall (unlike the old fixed coordinate)
    LD      HL, NAVMAP
    LD      B, 0            ; B = column 0-31
    LD      C, 0            ; C = row 0-20
.pspf_try:
    LD      A, (HL) : OR A : JR Z, .pspf_advance
    PUSH    HL
    LD      A, B : ADD A, A : ADD A, A : ADD A, A : LD D, A   ; D = X
    LD      A, C : ADD A, A : ADD A, A : ADD A, A : LD E, A   ; E = Y
    ; Skip if this is exactly the same point as an already-active enemy
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
    ; No collision — use this point
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
    ; Should never happen (the whole NAVMAP is empty) — last-resort fallback
    LD      A, 16 : LD (IX+0), A
    LD      A, 16 : LD (IX+1), A
    RET

; =============================================================================
; GET_NAVMAP_DIRS — A = NAVMAP[(IX+1)/8 * 32 + (IX+0)/8]
; Free-direction bitmap for the enemy's (IX) current tile.
; Clobbers only A and HL — B, C, D, E are preserved (callers rely on this).
; =============================================================================
GET_NAVMAP_DIRS:
    LD      A, (IX+1) : SRL A : SRL A : SRL A   ; A = Y/8 = tile row
    LD      H, 0 : LD L, A
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL   ; row*32
    LD      A, (IX+0) : SRL A : SRL A : SRL A   ; A = X/8 = tile column
    ADD     A, L : LD L, A
    LD      A, L : ADD A, LOW NAVMAP : LD L, A
    LD      A, H : ADC A, HIGH NAVMAP : LD H, A
    LD      A, (HL)
    RET

; =============================================================================
; RANDOM_TURN — wall ahead: try random directions (16 attempts)
; Sets (IX+2) if a free direction is found. Uses (MOVE_DELTA) — the caller
; (UPDATE_ROBOT/UPDATE_CHASER) has already computed it via GET_MOVE_DELTA.
; Shared by the Robot and the Chaser (tank/ghost). Clobbers A, B, C, D, E.
; =============================================================================
RANDOM_TURN:
    LD      B, 16
.try:
    PUSH    BC
    CALL    RAND : AND 0x03 : LD D, A

    CP      DIR_UP : JR NZ, .tu
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : SUB C : CP 8 : JR C, .tbad
    LD      E, A : LD B, (IX+0) : LD C, E : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tu:CP      DIR_DOWN : JR NZ, .td
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : ADD A, C : CP 153 : JR NC, .tbad
    LD      E, A : LD B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.td:CP      DIR_LEFT : JR NZ, .tl
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : SUB C : JR C, .tbad
    LD      E, A : LD B, E : LD A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
    JR      .tok
.tl:LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : ADD A, C : CP 241 : JR NC, .tbad
    LD      E, A : LD A, E : ADD A, 15 : LD B, A
    LD      A, (IX+1) : ADD A, 8 : LD C, A : CALL IS_WALL : JR NZ, .tbad
.tok:
    LD      (IX+2), D
    POP     BC : RET
.tbad:
    POP     BC : DEC B : JP NZ, .try   ; DJNZ isn't enough (loop >128 bytes)
    RET

; =============================================================================
; ENEMY_PORTAL_WRAP — side portals for enemies. Called by UPDATE_ROBOT (also
; the Wizard) and UPDATE_CHASER (Tank, Ghost) when a horizontal move would
; leave the screen (LEFT past X=0, RIGHT past X=ENEMY_PORTAL_X_RIGHT). If the
; enemy is on a portal row (IN_PORTAL, player.asm) it jumps to the opposite
; edge and keeps its direction; elsewhere the edge is just a wall.
; Input:  IX = enemy data, A = new X (0 or ENEMY_PORTAL_X_RIGHT)
; Output: Z=1 → wrapped (IX+0 set), Z=0 → not on a portal row, nothing changed
; Clobbers: A, C
; =============================================================================
ENEMY_PORTAL_X_RIGHT EQU 240    ; rightmost X an enemy can stand at (same limit as CP 241)
ENEMY_PORTAL_WRAP:
    LD      C, A
    LD      A, (IX+1) : CALL IN_PORTAL : RET NZ
    LD      (IX+0), C               ; LD doesn't touch flags: Z=1 still from IN_PORTAL
    RET

; =============================================================================
; CHASER_TOWARD_PLAYER — returns A = direction toward a living player
; Uses: B, C, D, E, H, L. Preserves: IX, the original D, E.
; =============================================================================
CHASER_TOWARD_PLAYER:
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
    LD      A, (IX+2)   ; no living players: keep the current direction
    POP     HL : POP DE : RET

.ttp_got:
    ; Compute |dx| and the horizontal preference
    LD      A, B : SUB (IX+0)   ; dx = targetX - tankX (signed)
    JP      P, .ttp_dxp
    NEG : LD H, A : LD D, DIR_LEFT  : JR .ttp_dxd
.ttp_dxp:
    LD      H, A : LD D, DIR_RIGHT
.ttp_dxd:
    ; Compute |dy| and the vertical preference
    LD      A, C : SUB (IX+1)   ; dy = targetY - tankY (signed)
    JP      P, .ttp_dyp
    NEG : LD E, A : LD L, DIR_UP   : JR .ttp_dyd
.ttp_dyp:
    LD      E, A : LD L, DIR_DOWN
.ttp_dyd:
    LD      A, E : CP H          ; |dy| vs |dx|
    JR      NC, .ttp_vert        ; |dy| >= |dx|: prefer vertical
    LD      A, D : JR .ttp_done  ; prefer horizontal
.ttp_vert:
    LD      A, L
.ttp_done:
    POP     HL : POP DE : RET

; =============================================================================
; UPDATE_CHASER — move an enemy toward the player (IX = data)
; Shared by the tank and the ghost: SPAWN_* sets the speed*2 (IX+5), the
; logic is otherwise identical. Shooting is separate (UPDATE_TANK fires after
; this, the ghost doesn't fire).
; =============================================================================
UPDATE_CHASER:
    CALL    GET_MOVE_DELTA          ; (MOVE_DELTA) = this frame's pixel count
    LD      A, (IX+2) : LD D, A     ; D = direction

    CP      DIR_UP : JR NZ, .tnup
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : SUB C : CP 8 : JP C, .tchg
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tnup:
    CP      DIR_DOWN : JR NZ, .tndn
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : ADD A, C : CP 153 : JP NC, .tchg
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+1), E : JP .tmt
.tndn:
    CP      DIR_LEFT : JR NZ, .tnlt
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : SUB C : JP C, .edge_left
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E : JP .tmt
.tnlt:
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : ADD A, C : CP 241 : JP NC, .edge_right
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E

.tmt:
    ; Grid boundary: turn toward the player using NAVMAP — never backward
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    CALL    CHASER_TOWARD_PLAYER   ; A = preferred direction
    LD      D, A
    ; Filter: only turn if the preference is perpendicular to the current axis
    LD      A, (IX+2) : AND 0x02
    LD      B, A
    LD      A, D : AND 0x02
    CP      B : RET Z            ; same axis → keep going straight
    CALL    GET_NAVMAP_DIRS      ; doesn't touch B/C/D/E
    LD      B, A             ; B = available directions (NAVMAP bits)
    ; Is the preferred direction D open? (bit D = bit at the direction number)
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

    ; Screen edge reached: on a portal row wrap to the other side (keeping
    ; the direction), otherwise treat the edge as a wall → .tchg
.edge_left:
    LD      A, ENEMY_PORTAL_X_RIGHT : CALL ENEMY_PORTAL_WRAP : RET Z
    JR      .tchg
.edge_right:
    XOR     A : CALL ENEMY_PORTAL_WRAP : RET Z

.tchg:
    ; Wall ahead — compute the direction toward the player and try it;
    ; blocked → shared RANDOM_TURN (tail-call)
    CALL    CHASER_TOWARD_PLAYER
    LD      D, A

    ; Try direction D — check BOTH corners (same as the main movement code)
    CP      DIR_UP : JR NZ, .ttu_nd
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : SUB C : CP 8 : JP C, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nd:
    CP      DIR_DOWN : JR NZ, .ttu_nl
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+1) : ADD A, C : CP 153 : JP NC, RANDOM_TURN
    LD      E, A
    LD      B, (IX+0) : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, (IX+0) : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nl:
    CP      DIR_LEFT : JR NZ, .ttu_nr
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : SUB C : JP C, RANDOM_TURN
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET
.ttu_nr:
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : ADD A, C : CP 241 : JP NC, RANDOM_TURN
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, RANDOM_TURN
    LD      (IX+2), D : RET

; =============================================================================
; UPDATE_ENEMIES — update all enemies
; =============================================================================
UPDATE_ENEMIES:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
    LD      D, 0                    ; D = enemy index (0-5)
.loop:
    PUSH    BC
    PUSH    DE
    LD      A, (IX+4) : OR A : JR Z, .skip
    LD      A, (IX+3)
    CP      ENEMY_ROBOT : JR NZ, .chk_tank
    PUSH    DE : CALL UPDATE_ROBOT : POP DE
    LD      A, D : CALL ROBOT_TRY_SHOOT
    JR      .skip
.chk_tank:
    CP      ENEMY_TANK : JR NZ, .chk_ghost
    CALL    UPDATE_TANK           ; enemy_tank.asm: chase + two-way shot
    JR      .skip
.chk_ghost:
    CP      ENEMY_GHOST : JR NZ, .chk_wizard
    CALL    UPDATE_GHOST          ; enemy_ghost.asm: chase, doesn't fire
    JR      .skip
.chk_wizard:
    CP      ENEMY_WIZARD : JR NZ, .skip
    CALL    UPDATE_WIZARD         ; boss.asm: robot movement + teleporting
    CALL    WIZARD_TRY_SHOOT      ; its own bullet slot, not shared with ENEMY_BULLETS
.skip:
    POP     DE : INC D
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     BC : DJNZ .loop
    RET

; =============================================================================
; DRAW_ENEMIES — draw all enemies as sprites
; =============================================================================
DRAW_ENEMIES:
    ; Sprite flicker: start from a different ENEMIES slot every frame
    ; (SPR_ROTATE = 0..5) and wrap around, so the sprite numbers of the
    ; enemies rotate. On a scanline with more than 4 sprites a different
    ; enemy is dropped each frame — they flicker instead of one of them
    ; vanishing for good (README gotcha 17).
    LD      A, (SPR_ROTATE) : INC A
    CP      MAX_ENEMIES : JR C, .rot_ok
    XOR     A
.rot_ok:
    LD      (SPR_ROTATE), A
    ADD     A, A : ADD A, A : ADD A, A  ; * ENEMY_SIZE (8)
    ADD     A, ENEMIES & 0xFF
    LD      L, A : LD H, ENEMIES >> 8   ; ENEMIES + start slot * 8 (no carry)
    PUSH    HL : POP IX
    LD      B, MAX_ENEMIES
    LD      DE, ENEMY_SIZE              ; DE stays the same for the whole loop
    LD      HL, VRAM_SPRITE_ATT + SPR_ENEMIES*4
    CALL    VDP_SETW                    ; VDP address is set once

.loop:
    ; Each type's DRAW_*_SPRITE (enemy_*.asm) writes the 4 attribute bytes;
    ; they must preserve B (loop counter) and DE (IX step)
    LD      A, (IX+4) : OR A : JR Z, .hide
    LD      A, (IX+3)
    CP      ENEMY_ROBOT : JR NZ, .not_robot
    CALL    DRAW_ROBOT_SPRITE
    JR      .next
.not_robot:
    CP      ENEMY_TANK : JR NZ, .not_tank
    CALL    DRAW_TANK_SPRITE
    JR      .next
.not_tank:
    CP      ENEMY_GHOST : JR NZ, .hide     ; Wizard: drawn separately in DRAW_WIZARD
    ; The ghost is only visible when the player is on the same row/column
    CALL    GHOST_VISIBLE
    OR      A : JR Z, .hide
    CALL    DRAW_GHOST_SPRITE
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
    ADD     IX, DE          ; doesn't touch B (the counter) — LD BC,n would have zeroed B
    PUSH    IX : POP HL : LD A, L       ; HL is free scratch here
    CP      (ENEMIES + MAX_ENEMIES*ENEMY_SIZE) & 0xFF : JR NZ, .nowrap
    LD      IX, ENEMIES     ; past the last slot → wrap to slot 0
.nowrap:
    DJNZ    .loop
    RET

; =============================================================================
; DRAW_RADAR — draws enemy positions on the radar as sprites (sprites
; RADAR_SPRITE_BASE..+5, one per ENEMIES slot). The frame (hud.asm) is
; fixed; this just draws the dots in the right color (ROBOT/TANK/GHOST_COLOR).
; 1 playfield tile = 1 pixel, offset 1px down for centering.
; =============================================================================
DRAW_RADAR:
    LD      IX, ENEMIES
    LD      HL, VRAM_SPRITE_ATT + RADAR_SPRITE_BASE*4 : CALL VDP_SETW
    LD      B, MAX_ENEMIES
.rloop:
    LD      A, (IX+4) : OR A : JR Z, .rhide

    ; map_row = Y/8 (0-20 valid, otherwise skipped)
    LD      A, (IX+1) : SRL A : SRL A : SRL A
    CP      21 : JR NC, .rhide
    ADD     A, RADAR_ORIGIN_Y : OUT (VDP_DATA), A     ; Y (already Y-1 adjusted)

    ; map_col = X/8 (0-31) → sprite X
    LD      A, (IX+0) : SRL A : SRL A : SRL A
    ADD     A, RADAR_ORIGIN_X : OUT (VDP_DATA), A

    LD      A, RADAR_DOT_PAT : OUT (VDP_DATA), A

    ; Color: robot=yellow, tank=cyan (light blue once hit), ghost=white, wizard=magenta
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .rtank
    CP      ENEMY_GHOST : JR Z, .rghostcol
    CP      ENEMY_WIZARD : JR Z, .rwizcol
    LD      A, ROBOT_COLOR : JR .rcolout
.rtank:
    ; Hurt tank: TANK_HURT_COLOR, same as on the field (HL is free scratch)
    CALL    TANK_CUR_COLOR : JR .rcolout
.rghostcol:
    LD      A, GHOST_COLOR : JR .rcolout
.rwizcol:
    LD      A, WIZARD_COLOR_A
.rcolout:
    OUT     (VDP_DATA), A
    JR      .rnext
.rhide:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    CALL    VDP_DLY
    XOR     A : OUT (VDP_DATA), A
    CALL    VDP_DLY
    OUT     (VDP_DATA), A
    CALL    VDP_DLY
    OUT     (VDP_DATA), A
.rnext:
    LD      DE, ENEMY_SIZE : ADD IX, DE
    DJNZ    .rloop
    RET

; =============================================================================
; UPDATE_ENEMY_BULLETS — move all enemy bullets
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

; UPDATE_ENEMY_BULLET — move a single enemy bullet
; Input: IX = bullet slot (X, Y, dir, active)
; Speed is read from (CUR_BULLET_SPEED) on every call (per-round now,
; no longer a fixed constant) — Z80 doesn't allow "SUB (nn)" directly, so
; the value is loaded into B first.
UPDATE_ENEMY_BULLET:
    LD      A, (IX+3) : OR A : RET Z        ; not active

    LD      A, (CUR_BULLET_SPEED) : LD B, A  ; B = current bullet speed
    LD      A, (IX+2)                        ; direction
    CP      DIR_UP : JR NZ, .ebu_nd
    LD      A, (IX+1) : SUB B
    JR      C, .ebu_deact
    CP      8 : JR C, .ebu_deact
    LD      (IX+1), A : JR .ebu_wall
.ebu_nd:
    CP      DIR_DOWN : JR NZ, .ebu_nl
    LD      A, (IX+1) : ADD A, B
    CP      153 : JR NC, .ebu_deact
    LD      (IX+1), A : JR .ebu_wall
.ebu_nl:
    CP      DIR_LEFT : JR NZ, .ebu_nr
    LD      A, (IX+0) : SUB B
    JR      C, .ebu_deact
    LD      (IX+0), A : JR .ebu_wall
.ebu_nr:
    LD      A, (IX+0) : ADD A, B
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

; CHECK_ENEMY_BULLET_PLAYER_HIT — check whether an enemy bullet hits a player
; Input: IX = bullet slot
; Centered hitboxes: bullet 4x4 (half 2) + player 6x6 (half 3)
; = threshold 5 (see bullet.asm's CHECK_BULLET_HIT for the same derivation)
CHECK_ENEMY_BULLET_PLAYER_HIT:
    PUSH    BC
    PUSH    DE
    LD      D, (IX+0) : LD E, (IX+1)    ; D=X, E=Y

    ; Check P1
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .chk_p2
    LD      A, (P1_LIVES)    : OR A : JR Z, .chk_p2
    LD      A, (P1_X) : SUB D
    JP      P, .p1x
    NEG
.p1x:
    CP      5 : JR NC, .chk_p2
    LD      A, (P1_Y) : SUB E
    JP      P, .p1y
    NEG
.p1y:
    CP      5 : JR NC, .chk_p2
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
    CP      5 : JR NC, .ebph_done
    LD      A, (P2_Y) : SUB E
    JP      P, .p2y
    NEG
.p2y:
    CP      5 : JR NC, .ebph_done
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
; DRAW_ENEMY_BULLETS — draw enemy bullets (sprites SPR_EBULLETS..+5)
; =============================================================================
DRAW_ENEMY_BULLETS:
    LD      IX, ENEMY_BULLETS
    LD      B, MAX_ENEMIES
    LD      HL, VRAM_SPRITE_ATT + SPR_EBULLETS*4
    CALL    VDP_SETW
.loop:
    LD      A, (IX+3) : OR A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A
    LD      A, (IX+0) : OUT (VDP_DATA), A
    LD      HL, BULLET_DIR_PAT : LD A, (IX+2) : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A                             ; pattern based on direction
    LD      A, ENEMY_BULLET_COLOR : OUT (VDP_DATA), A
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

; =============================================================================
; CHECK_WAVE_COMPLETE — check whether all enemies are dead
; Output: Z=1 if all dead, Z=0 if some are still alive
; =============================================================================
CHECK_WAVE_COMPLETE:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
.chk:
    LD      A, (IX+4)
    OR      A
    RET     NZ              ; found an active one → Z=0, return immediately
    LD      DE, ENEMY_SIZE
    ADD     IX, DE
    DJNZ    .chk
    XOR     A               ; all dead → Z=1
    RET

; =============================================================================
; SPAWN_WAVE — create a new wave of enemies according to WAVE_TABLE
; =============================================================================
SPAWN_WAVE:
    ; Clear enemies and their bullets (including the tank's)
    LD      HL, ENEMIES
    LD      B, MAX_ENEMIES * ENEMY_SIZE
.clr:XOR    A : LD (HL), A : INC HL : DJNZ .clr
    LD      HL, ENEMY_BULLETS
    LD      B, MAX_ENEMIES * ENEMY_BULLET_SIZE
.clrb:XOR   A : LD (HL), A : INC HL : DJNZ .clrb
    LD      HL, TANK_BULLETS
    LD      B, 2 * ENEMY_BULLET_SIZE
.clrt:XOR   A : LD (HL), A : INC HL : DJNZ .clrt
    ; Reset the per-slot hit counters (Tank takes two hits)
    LD      HL, ENEMY_HITS
    LD      B, MAX_ENEMIES
.clrhw:XOR  A : LD (HL), A : INC HL : DJNZ .clrhw
    ; Also clear the players' bullets
    LD      HL, BULLETS
    LD      B, BULLET_SIZE * 2
.clrp:XOR   A : LD (HL), A : INC HL : DJNZ .clrp
    ; Make sure the music is playing (don't reset the position in the track)
    LD      A, 1 : LD (MUSIC_ON), A

    JP      SPAWN_ENEMIES_FOR_LEVEL

; =============================================================================
; SPAWN_ENEMIES_FOR_LEVEL — spawn the enemies for (LEVEL) from WAVE_TABLE
; Assumes ENEMIES has already been cleared by the caller.
; =============================================================================
SPAWN_ENEMIES_FOR_LEVEL:
    ; Get the level's enemy counts from WAVE_TABLE
    LD      A, (LEVEL) : DEC A              ; 0-indexed
    CP      MAX_WAVE_ENTRIES : JR C, .wt_ok
    LD      A, MAX_WAVE_ENTRIES - 1         ; clamp to the last row
.wt_ok:
    ; index * 4 (4 bytes per entry: robots, tanks, ghosts, wizard)
    ADD     A, A : ADD A, A
    LD      HL, WAVE_TABLE
    ADD     A, L : LD L, A
    LD      A, H : ADC A, 0 : LD H, A
    LD      B, (HL) : INC HL : LD C, (HL) : INC HL
    LD      D, (HL) : INC HL : LD A, (HL)
                        ; B = robots, C = tanks, D = ghosts, A = wizard (freshest)

    ; The wizard column is checked right away — if 1, spawn ONLY the Wizard (boss level)
    OR      A : JR Z, .no_boss
    LD      A, 1 : LD (BOSS_ACTIVE), A
    LD      IX, ENEMIES
    JP      SPAWN_WIZARD
.no_boss:
    XOR     A : LD (BOSS_ACTIVE), A

    LD      IX, ENEMIES

    ; Spawn ghosts first (D is fresh, before B/C get used in their own loops)
    LD      A, D : OR A : JR Z, .sw_tanks
.sw_ghost:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_GHOST
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_ghost

.sw_tanks:
    ; Spawn tanks
    LD      A, C : OR A : JR Z, .sw_robots
    LD      D, C
.sw_tank:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_TANK
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_tank

.sw_robots:
    ; Spawn robots
    LD      A, B : OR A : RET Z
    LD      D, B
.sw_robot:
    PUSH    BC : PUSH    DE
    CALL    SPAWN_ROBOT
    LD      BC, ENEMY_SIZE : ADD IX, BC
    POP     DE : POP     BC
    DEC     D : JR NZ, .sw_robot
    RET
