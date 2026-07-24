; =============================================================================
; enemy.asm — Enemies
; =============================================================================
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

ROBOT_COLOR     EQU 10          ; yellow
TANK_COLOR      EQU 7           ; cyan
GHOST_COLOR     EQU 15          ; white
GHOST_PAT_BASE  EQU 76          ; RADAR_DOT_PAT(72) reserves 4 patterns (72-75), 32 patterns: 76-107
; Ghost sight buffer: how many pixels beyond the edge of the player's 16x16
; sprite visibility extends. Threshold = 16 (sprite) + buffer, because
; abs(difference) < threshold covers both the sprite overlap and the buffer
; on both sides (see GHOST_VISIBLE).
GHOST_SIGHT_BUFFER  EQU 10
GHOST_SIGHT_TOL     EQU 16 + GHOST_SIGHT_BUFFER

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

ROBOT_PATS:
    ; 16x16 Robot (pattern 8 = offset 64, one frame)
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

GHOST_PATS:

    ; Left 1
    DB $00,$07,$0F,$0A,$0F,$09,$1F,$1F
    DB $1F,$3F,$3F,$3F,$3D,$29,$24,$00
    DB $00,$00,$80,$80,$C0,$C0,$C0,$E0
    DB $F0,$F0,$F8,$FE,$F8,$24,$90,$00
    ; Left 2
    DB $00,$06,$1F,$15,$1F,$13,$1F,$1F
    DB $1F,$3F,$3F,$3F,$3D,$24,$12,$00
    DB $00,$00,$00,$00,$80,$80,$C0,$E0
    DB $F0,$F8,$F8,$FC,$FE,$92,$48,$00
    ; Right 1
    DB $00,$00,$01,$01,$03,$03,$03,$07
    DB $0F,$0F,$1F,$7F,$1F,$24,$09,$00
    DB $00,$E0,$F0,$50,$F0,$90,$F8,$F8
    DB $F8,$FC,$FC,$FC,$BC,$94,$24,$00
    ; Right 2
    DB $00,$00,$00,$00,$01,$01,$03,$07
    DB $0F,$1F,$1F,$3F,$7F,$49,$12,$00
    DB $00,$60,$F8,$A8,$F8,$C8,$F8,$F8
    DB $F8,$FC,$FC,$FC,$BC,$24,$48,$00
    ; Down 1
    DB $00,$08,$28,$1C,$5F,$3F,$1F,$5F
    DB $3F,$0F,$5F,$3F,$1F,$7E,$00,$00
    DB $00,$00,$00,$00,$00,$80,$F0,$FC
    DB $F6,$DE,$D6,$FC,$C0,$00,$00,$00
    ; Down 2
    DB $00,$30,$18,$5E,$3F,$1F,$5F,$3F
    DB $1F,$4F,$3F,$1F,$5F,$3E,$00,$00
    DB $00,$00,$00,$00,$00,$80,$C0,$F0
    DB $FC,$F6,$DE,$D4,$FC,$00,$00,$00
    ; Up 1
    DB $00,$00,$00,$03,$3F,$6B,$7B,$6F
    DB $3F,$0F,$01,$00,$00,$00,$00,$00
    DB $00,$00,$7E,$F8,$FC,$FA,$F0,$FC
    DB $FA,$F8,$FC,$FA,$38,$14,$10,$00
    ; Up 2
    DB $00,$00,$00,$3F,$2B,$7B,$6F,$3F
    DB $0F,$03,$01,$00,$00,$00,$00,$00
    DB $00,$00,$7C,$FA,$F8,$FC,$F2,$F8
    DB $FC,$FA,$F8,$FC,$7A,$18,$0C,$00

GHOST_PATS_END:

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

    ALIGN   4
ROBOT_DIR_PAT:
    DB 32, 36, 44, 40   ; DIR_RIGHT=0, DIR_LEFT=1, DIR_UP=2, DIR_DOWN=3
TANK_DIR_PAT:
    DB 64, 64, 68, 68   ; same sprite for both horizontal directions, same for vertical

    ALIGN   8
; Ghost direction+animation frame → pattern. Index = direction*2 + frame(0/1)
GHOST_DIR_PAT:
    DB GHOST_PAT_BASE+8,  GHOST_PAT_BASE+12   ; DIR_RIGHT frame0,1 (Right1,2)
    DB GHOST_PAT_BASE+0,  GHOST_PAT_BASE+4    ; DIR_LEFT  frame0,1 (Left1,2)
    DB GHOST_PAT_BASE+24, GHOST_PAT_BASE+28   ; DIR_UP    frame0,1 (Up1,2)
    DB GHOST_PAT_BASE+16, GHOST_PAT_BASE+20   ; DIR_DOWN  frame0,1 (Down1,2)

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

    ; Load Robot patterns (pattern 32 = offset 256)
    LD      HL, VRAM_SPRITE_PAT + 256 : CALL VDP_SETW
    LD      HL, ROBOT_PATS
    LD      B, ROBOT_PATS_END - ROBOT_PATS
.pp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .pp
    ; Load Tank patterns (pattern 64 = offset 512, after the bullet/explosion
    ; patterns — bullet.asm's two bullet directions + 2 explosions take 48-63)
    LD      HL, VRAM_SPRITE_PAT + 512 : CALL VDP_SETW
    LD      HL, TANK_PATS
    LD      B, TANK_PATS_END - TANK_PATS
.tp:LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .tp
    ; Load the radar dot pattern (RADAR_DOT_PAT=72, after the tank patterns).
    ; 16x16 mode reserves 4 patterns even though only 1 is drawn — load the whole block.
    LD      HL, VRAM_SPRITE_PAT + RADAR_DOT_PAT*8 : CALL VDP_SETW
    LD      HL, RADAR_DOT_PATS
    LD      B, RADAR_DOT_PATS_END - RADAR_DOT_PATS
.rdp:LD     A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .rdp
    ; Load Ghost patterns (GHOST_PAT_BASE=76, after the radar dot's 4 patterns)
    ; The size is exactly 256 bytes — DJNZ+LD B doesn't fit (B is 8-bit), use a BC counter
    LD      HL, VRAM_SPRITE_PAT + GHOST_PAT_BASE*8 : CALL VDP_SETW
    LD      HL, GHOST_PATS
    LD      BC, GHOST_PATS_END - GHOST_PATS
.gp: LD     A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .gp

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

    ; First wave's enemies according to WAVE_TABLE (LEVEL is set in main.asm before this call)
    JP      SPAWN_ENEMIES_FOR_LEVEL

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

; SPAWN_TANK — create a Tank at the IX address via a NAVMAP point
SPAWN_TANK:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_TANK
    LD      (IX+4), 1
    LD      A, (CUR_RT_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0
    LD      (IX+7), 0
    RET

; SPAWN_GHOST — create a Ghost at the IX address via a NAVMAP point
SPAWN_GHOST:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_GHOST
    LD      (IX+4), 1
    LD      A, (CUR_GHOST_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0
    RET

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
; UPDATE_ROBOT — move a single Robot (IX = data), speed (IX+5, half-pixels)
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
; TANK_TOWARD_PLAYER — returns A = direction toward a living player
; Uses: B, C, D, E, H, L. Preserves: IX, the original D, E.
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
; logic is otherwise identical. TANK_TRY_SHOOT is not called for the ghost.
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
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : SUB C : JP C, .tchg
    LD      E, A
    LD      B, E : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      B, E : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E : JP .tmt
.tnlt:
    LD      A, (MOVE_DELTA) : LD C, A : LD A, (IX+0) : ADD A, C : CP 241 : JP NC, .tchg
    LD      E, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, (IX+1) : CALL IS_WALL : JP NZ, .tchg
    LD      A, E : ADD A, 15 : LD B, A : LD A, (IX+1) : ADD A, 15 : LD C, A : CALL IS_WALL : JP NZ, .tchg
    LD      (IX+0), E

.tmt:
    ; Grid boundary: turn toward the player using NAVMAP — never backward
    LD      A, (IX+0) : AND 0x07 : RET NZ
    LD      A, (IX+1) : AND 0x07 : RET NZ
    CALL    TANK_TOWARD_PLAYER   ; A = preferred direction
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

.tchg:
    ; Wall ahead — compute the direction toward the player and try it;
    ; blocked → shared RANDOM_TURN (tail-call)
    CALL    TANK_TOWARD_PLAYER
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
    LD      A, D : CALL ENEMY_TRY_SHOOT
    JR      .skip
.chk_tank:
    CP      ENEMY_TANK : JR NZ, .chk_ghost
    PUSH    DE : CALL UPDATE_CHASER : POP DE
    CALL    TANK_TRY_SHOOT
    JR      .skip
.chk_ghost:
    CP      ENEMY_GHOST : JR NZ, .chk_wizard
    CALL    UPDATE_CHASER         ; same chase logic as the tank, doesn't fire
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
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
    LD      DE, ENEMY_SIZE              ; DE stays the same for the whole loop
    LD      HL, VRAM_SPRITE_ATT + 8    ; starting at sprite 2
    CALL    VDP_SETW                    ; VDP address is set once

.loop:
    LD      A, (IX+4) : OR A : JR Z, .hide
    LD      A, (IX+3) : CP ENEMY_WIZARD : JR Z, .hide  ; drawn separately in DRAW_WIZARD
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
    ; The ghost is only visible when the player is on the same row/column
    CALL    GHOST_VISIBLE
    OR      A : JR Z, .hide
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    ; Pattern: direction*2 + animation frame (FRAME_CTR bit 3, changes every 8 frames)
    ; NOTE: use C, not B — B is this loop's DJNZ counter (MAX_ENEMIES)
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
    ADD     IX, DE          ; doesn't touch B (the counter) — LD BC,n would have zeroed B
    DEC     B : JP NZ, .loop   ; DJNZ isn't enough (loop >128 bytes)
    RET

; =============================================================================
; GHOST_VISIBLE — is the ghost (IX) visible? (a living player on the same
; row OR column, tolerance <4px)
; Output: A=1 (visible) or A=0 (hidden). Clobbers: C.
; NOTE: must not use B, nor D/E — DRAW_ENEMIES's calling loop keeps the
; DJNZ counter in B and the constant ENEMY_SIZE step in DE (ADD IX,DE at
; the end of the loop) — neither may be disturbed.
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

    ; Color: robot=yellow, tank=cyan, ghost=white, wizard=magenta
    LD      A, (IX+3) : CP ENEMY_TANK : JR Z, .rtankcol
    CP      ENEMY_GHOST : JR Z, .rghostcol
    CP      ENEMY_WIZARD : JR Z, .rwizcol
    LD      A, ROBOT_COLOR : JR .rcolout
.rtankcol:
    LD      A, TANK_COLOR : JR .rcolout
.rghostcol:
    LD      A, GHOST_COLOR : JR .rcolout
.rwizcol:
    LD      A, WIZARD_COLOR_A
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
; ENEMY_TRY_SHOOT — try to have an enemy fire at a player
; Input: IX = enemy data, A = enemy index (0-5)
; Fires if the enemy is on the same row or column as the target (50% probability)
; Odd index → P1, even → P2
; =============================================================================
ENEMY_TRY_SHOOT:
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
; DRAW_ENEMY_BULLETS — draw enemy bullets (sprites 12-17)
; =============================================================================
DRAW_ENEMY_BULLETS:
    LD      IX, ENEMY_BULLETS
    LD      B, MAX_ENEMIES
    LD      HL, VRAM_SPRITE_ATT + 48    ; starting at sprite 12
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
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
.next:
    INC     IX : INC IX : INC IX : INC IX
    DJNZ    .loop
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
; DRAW_TANK_BULLETS — draw the tank's bullets (sprites 18-19)
; =============================================================================
DRAW_TANK_BULLETS:
    LD      IX, TANK_BULLETS
    LD      B, 2
    LD      HL, VRAM_SPRITE_ATT + 72   ; starting at sprite 18
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
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
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
    ; Also clear the players' bullets
    LD      HL, BULLETS
    LD      B, BULLET_SIZE * 2
.clrp:XOR   A : LD (HL), A : INC HL : DJNZ .clrp
    ; Make sure the music is playing (don't reset the position in the track)
    LD      A, 1 : LD (BGM_ACTIVE), A

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
