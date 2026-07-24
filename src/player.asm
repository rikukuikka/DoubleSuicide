; =============================================================================
; player.asm — Player sprite and movement
; =============================================================================

; Sprite patterns (fine in ROM, never changes)
SPR_PATS:

; --- Right 1
    DB $1F,$3F,$3A,$1F,$0C,$1F,$3F,$5F
    DB $9E,$FF,$1E,$1E,$1E,$0C,$0C,$0F
    DB $00,$E0,$80,$00,$00,$00,$80,$80
    DB $80,$F8,$00,$00,$00,$00,$00,$00
;
; --- Right 2
    DB $1F,$3F,$3A,$1F,$0C,$1F,$3F,$5E
    DB $5F,$7E,$1E,$1E,$1F,$31,$60,$C0
    DB $20,$C0,$80,$00,$00,$00,$80,$C0
    DB $FC,$00,$00,$00,$40,$C0,$80,$00
;
; --- Left 1
    DB $00,$07,$01,$00,$00,$00,$01,$01
    DB $01,$1F,$00,$00,$00,$00,$00,$00
    DB $F8,$FC,$5C,$F8,$30,$F8,$FC,$FA
    DB $79,$FF,$78,$78,$78,$30,$30,$F0
;
; --- Left 2
    DB $04,$03,$01,$00,$00,$00,$01,$03
    DB $3F,$00,$00,$00,$02,$03,$01,$00
    DB $F8,$FC,$5C,$F8,$30,$F8,$FC,$7A
    DB $FA,$7E,$78,$78,$F8,$8C,$06,$03
;
; --- Down 1
    DB $03,$02,$02,$1F,$FF,$FF,$9F,$82
    DB $03,$02,$02,$02,$02,$00,$00,$00
    DB $00,$80,$46,$EF,$FF,$FB,$EF,$EB
    DB $C6,$02,$02,$00,$00,$00,$00,$00
;
; --- Down 2
    DB $80,$C3,$62,$3F,$1F,$1F,$1F,$31
    DB $61,$31,$01,$01,$01,$01,$00,$00
    DB $00,$80,$46,$EF,$FF,$FB,$EF,$6B
    DB $C6,$82,$01,$00,$00,$00,$00,$00
;
; --- Up 1
    DB $00,$00,$00,$00,$00,$40,$40,$63
    DB $D7,$F7,$DF,$FF,$F7,$62,$01,$00
    DB $00,$00,$00,$40,$40,$40,$40,$C0
    DB $41,$F9,$FF,$FF,$F8,$40,$40,$C0
;
; --- Up 2
    DB $00,$00,$00,$00,$00,$80,$41,$63
    DB $D6,$F7,$DF,$FF,$F7,$62,$01,$00
    DB $00,$00,$80,$80,$80,$80,$8C,$86
    DB $8C,$F8,$F8,$F8,$FC,$46,$C3,$01

SPR_PATS_END:

; Direction → pattern base lookup table
; DIR_RIGHT=0→0, DIR_LEFT=1→8, DIR_UP=2→24, DIR_DOWN=3→16
    ALIGN   4           ; 4-byte boundary: L+direction cannot overflow
DIR_PAT_BASE:
    DB 0, 8, 24, 16

; INIT_PLAYERS — initialize player RAM data and sprites
INIT_PLAYERS:
    ; RAM values
    LD      A, P1_START_X : LD (P1_X), A
    LD      A, P1_START_Y : LD (P1_Y), A
    LD      A, DIR_RIGHT  : LD (P1_DIR), A
    LD      A, P2_START_X : LD (P2_X), A
    LD      A, P2_START_Y : LD (P2_Y), A
    LD      A, DIR_LEFT   : LD (P2_DIR), A
    LD      A, 3          : LD (P1_LIVES), A
    ; P2 lives: 3 in two-player mode, 0 in single-player mode
    LD      A, (GAME_MODE) : CP 2 : JR Z, .two_player
    XOR     A : JR .set_p2_lives
.two_player:
    LD      A, 3
.set_p2_lives:
    LD      (P2_LIVES), A
    XOR     A             : LD (P1_DEAD_TMR), A
                            LD (P2_DEAD_TMR), A

    ; Sprite patterns into VRAM
    LD      HL, VRAM_SPRITE_PAT : CALL VDP_SETW
    LD      HL, SPR_PATS
    LD      BC, SPR_PATS_END - SPR_PATS
.lp:
    LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp

    ; Hide all 32 sprites
    LD      HL, VRAM_SPRITE_ATT : CALL VDP_SETW
    LD      B, 32
.hs:
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    DJNZ    .hs

    CALL    DRAW_P1
    CALL    DRAW_P2
    RET

; DRAW_P1 — draw P1's sprite into VRAM
DRAW_P1:
    LD      HL, VRAM_SPRITE_ATT : CALL VDP_SETW
    LD      A, (P1_Y) : DEC A : OUT (VDP_DATA), A   ; TMS9918A: Y-1
    LD      A, (P1_X) : OUT (VDP_DATA), A
    ; Direction → base pattern (lookup table)
    LD      A, (P1_DIR) : LD HL, DIR_PAT_BASE
    ADD     A, L : LD L, A                       ; ALIGN 4 guarantees no carry into H
    LD      B, (HL)                              ; B = direction's base pattern
    ; Animate only while moving
    LD      A, (P1_INPUT) : AND 0x0F
    JR      Z, .p1_still
    LD      A, (FRAME_CTR) : AND 0x08 : RRCA    ; 0 or 4
    ADD     A, B                                 ; base + animation
    JR      .p1_pat
.p1_still:
    LD      A, B                                 ; base pattern (frame 1)
.p1_pat:
    OUT     (VDP_DATA), A
    LD      A, P1_COLOR : OUT (VDP_DATA), A
    RET

; DRAW_P2 — draw P2's sprite into VRAM
DRAW_P2:
    LD      HL, VRAM_SPRITE_ATT + 4 : CALL VDP_SETW
    LD      A, (P2_Y) : DEC A : OUT (VDP_DATA), A   ; TMS9918A: Y-1
    LD      A, (P2_X) : OUT (VDP_DATA), A
    LD      A, (P2_DIR) : LD HL, DIR_PAT_BASE
    ADD     A, L : LD L, A
    LD      B, (HL)
    LD      A, (P2_INPUT) : AND 0x0F
    JR      Z, .p2_still
    LD      A, (FRAME_CTR) : AND 0x08 : RRCA
    ADD     A, B
    JR      .p2_pat
.p2_still:
    LD      A, B
.p2_pat:
    OUT     (VDP_DATA), A
    LD      A, P2_COLOR : OUT (VDP_DATA), A
    RET


; =============================================================================
; SNAP_TO_GRID — snap A to the nearest 8px boundary (3px tolerance)
; =============================================================================
SNAP_TO_GRID:
    LD      B, A
    AND     0x07
    CP      4
    JR      NC, .round_up
    LD      A, B
    AND     0xF8
    RET
.round_up:
    LD      A, B
    AND     0xF8
    ADD     A, 8
    RET

; IN_PORTAL — check whether Y is within the portal range
; Input:  A = Y
; Output: Z=1 if in a portal, Z=0 if not
IN_PORTAL:
    ; Input: A = Y coordinate
    ; Output: Z=1 if in a portal (Y >= PORTAL_Y_MIN and Y <= PORTAL_Y_MAX)
    CP      PORTAL_Y_MIN    ; A < MIN?
    JR      C, .no          ; yes → not in a portal
    CP      PORTAL_Y_MAX+1  ; A > MAX?
    JR      NC, .no         ; yes → not in a portal
    XOR     A               ; Z=1 = in a portal
    RET
.no:
    OR      1               ; Z=0 = not in a portal
    RET

; UPDATE_PLAYERS — move both players according to input
UPDATE_PLAYERS:
    ; --- P1 ---
    ; If the death timer > 0, blink and wait
    LD      A, (P1_DEAD_TMR)
    OR      A
    JR      Z, .p1_alive
    DEC     A : LD (P1_DEAD_TMR), A
    ; If the timer just ran out (=0), respawn
    OR      A
    JR      NZ, .p1_skip_move
    LD      A, (P1_LIVES) : OR A : JR Z, .p1_skip_move
    LD      A, P1_START_X : LD (P1_X), A
    LD      A, P1_START_Y : LD (P1_Y), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
.p1_skip_move:
    XOR     A : LD (P1_INPUT), A
    JP      .p1_after_move
.p1_alive:
    ; If lives = 0, skip
    LD      A, (P1_LIVES) : OR A : JR NZ, .p1_has_lives
    XOR     A : LD (P1_INPUT), A
    JP      .p1_after_move
.p1_has_lives:
    LD      A, (P1_INPUT) : AND IN_UP : JR Z, .p1nu
    LD      A, (P1_Y) : SUB SPEED : CP 8 : JR C, .p1nu : LD E, A
    ; Snap X to the tile boundary
    LD      A, (P1_X) : CALL SNAP_TO_GRID : LD D, A
    LD      B, D : LD C, E : CALL IS_WALL : JR NZ, .p1nu
    LD      A, D : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JR NZ, .p1nu
    LD      A, E : LD (P1_Y), A : LD A, D : LD (P1_X), A
    LD      A, DIR_UP : LD (P1_DIR), A
.p1nu:
    LD      A, (P1_INPUT) : AND IN_DOWN : JR Z, .p1nd
    LD      A, (P1_Y) : ADD A, SPEED : CP 153 : JR NC, .p1nd : LD E, A
    ; Snap X to the tile boundary
    LD      A, (P1_X) : CALL SNAP_TO_GRID : LD D, A
    LD      B, D : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p1nd
    LD      A, D : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p1nd
    LD      A, E : LD (P1_Y), A : LD A, D : LD (P1_X), A
    LD      A, DIR_DOWN : LD (P1_DIR), A
.p1nd:
    LD      A, (P1_INPUT) : AND IN_LEFT : JR Z, .p1nl
    ; Portal check: if at portal height and X <= 8
    LD      A, (P1_X) : CP 3 : JR NC, .p1l_noport
    LD      A, (P1_Y) : CALL IN_PORTAL : JR NZ, .p1nl
    LD      A, 248 : LD (P1_X), A
    LD      A, DIR_LEFT : LD (P1_DIR), A
    JR      .p1nl
.p1l_noport:
    LD      A, (P1_X) : SUB SPEED : JR C, .p1nl : LD E, A
    LD      A, (P1_Y) : CALL SNAP_TO_GRID : LD D, A
    LD      B, E : LD C, D : CALL IS_WALL : JR NZ, .p1nl
    LD      B, E : LD A, D : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p1nl
    LD      A, E : LD (P1_X), A : LD A, D : LD (P1_Y), A
    LD      A, DIR_LEFT : LD (P1_DIR), A
.p1nl:
    LD      A, (P1_INPUT) : AND IN_RIGHT : JR Z, .p1nr
    ; Portal check: if at portal height and X >= 240
    LD      A, (P1_X) : CP 240 : JR C, .p1r_noport
    LD      A, (P1_Y) : CALL IN_PORTAL : JR NZ, .p1r_noport
    LD      A, 0 : LD (P1_X), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
    JR      .p1nr
.p1r_noport:
    LD      A, (P1_X) : ADD A, SPEED : CP 241 : JR NC, .p1nr : LD E, A
    LD      A, (P1_Y) : CALL SNAP_TO_GRID : LD D, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, D : CALL IS_WALL : JR NZ, .p1nr
    LD      A, E : ADD A, 15 : LD B, A : LD A, D : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p1nr
    LD      A, E : LD (P1_X), A : LD A, D : LD (P1_Y), A
    LD      A, DIR_RIGHT : LD (P1_DIR), A
.p1nr:
.p1_after_move:

    ; --- P2 ---
    LD      A, (P2_DEAD_TMR)
    OR      A
    JR      Z, .p2_alive
    DEC     A : LD (P2_DEAD_TMR), A
    OR      A
    JR      NZ, .p2_skip_move
    LD      A, (P2_LIVES) : OR A : JR Z, .p2_skip_move
    LD      A, P2_START_X : LD (P2_X), A
    LD      A, P2_START_Y : LD (P2_Y), A
    LD      A, DIR_LEFT  : LD (P2_DIR), A
.p2_skip_move:
    XOR     A : LD (P2_INPUT), A
    JP      .p2_after_move
.p2_alive:
    LD      A, (P2_LIVES) : OR A : JR NZ, .p2_has_lives
    XOR     A : LD (P2_INPUT), A
    JP      .p2_after_move
.p2_has_lives:
    LD      A, (P2_INPUT) : AND IN_UP : JR Z, .p2nu
    LD      A, (P2_Y) : SUB SPEED : CP 8 : JR C, .p2nu : LD E, A
    LD      A, (P2_X) : CALL SNAP_TO_GRID : LD D, A
    LD      B, D : LD C, E : CALL IS_WALL : JR NZ, .p2nu
    LD      A, D : ADD A, 15 : LD B, A : LD C, E : CALL IS_WALL : JR NZ, .p2nu
    LD      A, E : LD (P2_Y), A : LD A, D : LD (P2_X), A
    LD      A, DIR_UP : LD (P2_DIR), A
.p2nu:
    LD      A, (P2_INPUT) : AND IN_DOWN : JR Z, .p2nd
    LD      A, (P2_Y) : ADD A, SPEED : CP 153 : JR NC, .p2nd : LD E, A
    LD      A, (P2_X) : CALL SNAP_TO_GRID : LD D, A
    LD      B, D : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p2nd
    LD      A, D : ADD A, 15 : LD B, A : LD A, E : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p2nd
    LD      A, E : LD (P2_Y), A : LD A, D : LD (P2_X), A
    LD      A, DIR_DOWN : LD (P2_DIR), A
.p2nd:
    LD      A, (P2_INPUT) : AND IN_LEFT : JR Z, .p2nl
    LD      A, (P2_X) : CP 3 : JR NC, .p2l_noport
    LD      A, (P2_Y) : CALL IN_PORTAL : JR NZ, .p2nl
    LD      A, 248 : LD (P2_X), A
    LD      A, DIR_LEFT : LD (P2_DIR), A
    JR      .p2nl
.p2l_noport:
    LD      A, (P2_X) : SUB SPEED : JR C, .p2nl : LD E, A
    LD      A, (P2_Y) : CALL SNAP_TO_GRID : LD D, A
    LD      B, E : LD C, D : CALL IS_WALL : JR NZ, .p2nl
    LD      B, E : LD A, D : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p2nl
    LD      A, E : LD (P2_X), A : LD A, D : LD (P2_Y), A
    LD      A, DIR_LEFT : LD (P2_DIR), A
.p2nl:
    LD      A, (P2_INPUT) : AND IN_RIGHT : JR Z, .p2nr
    LD      A, (P2_X) : CP 240 : JR C, .p2r_noport
    LD      A, (P2_Y) : CALL IN_PORTAL : JR NZ, .p2r_noport
    LD      A, 0 : LD (P2_X), A
    LD      A, DIR_RIGHT : LD (P2_DIR), A
    JR      .p2nr
.p2r_noport:
    LD      A, (P2_X) : ADD A, SPEED : CP 241 : JR NC, .p2nr : LD E, A
    LD      A, (P2_Y) : CALL SNAP_TO_GRID : LD D, A
    LD      A, E : ADD A, 15 : LD B, A : LD C, D : CALL IS_WALL : JR NZ, .p2nr
    LD      A, E : ADD A, 15 : LD B, A : LD A, D : ADD A, 15 : LD C, A : CALL IS_WALL : JR NZ, .p2nr
    LD      A, E : LD (P2_X), A : LD A, D : LD (P2_Y), A
    LD      A, DIR_RIGHT : LD (P2_DIR), A
.p2nr:
.p2_after_move:
    RET

; DRAW_PLAYERS — draw P1 and P2 (called right after vblank)
DRAW_PLAYERS:
    ; --- P1 ---
    LD      A, (P1_DEAD_TMR) : OR A : JR Z, .p1_not_dead
    AND     0x02 : JR Z, .p1_hide
    CALL    DRAW_P1 : JR .p1_done
.p1_hide:
    LD      HL, VRAM_SPRITE_ATT : CALL HIDE_SPRITE : JR .p1_done
.p1_not_dead:
    LD      A, (P1_LIVES) : OR A : JR NZ, .p1_draw
    LD      HL, VRAM_SPRITE_ATT : CALL HIDE_SPRITE : JR .p1_done
.p1_draw:
    CALL    DRAW_P1
.p1_done:
    ; --- P2 ---
    LD      A, (P2_DEAD_TMR) : OR A : JR Z, .p2_not_dead
    AND     0x02 : JR Z, .p2_hide
    CALL    DRAW_P2 : JR .p2_done
.p2_hide:
    LD      HL, VRAM_SPRITE_ATT + 4 : CALL HIDE_SPRITE : JR .p2_done
.p2_not_dead:
    LD      A, (P2_LIVES) : OR A : JR NZ, .p2_draw
    LD      HL, VRAM_SPRITE_ATT + 4 : CALL HIDE_SPRITE : JR .p2_done
.p2_draw:
    CALL    DRAW_P2
.p2_done:
    RET

; =============================================================================
; CHECK_PLAYER_DEATH — check whether an enemy hits a player
; Centered hitboxes: player 6x6 + enemy 6x6 (each half 3)
; = threshold 6 (see bullet.asm's CHECK_BULLET_HIT for the same derivation)
; =============================================================================
CHECK_PLAYER_DEATH:
    LD      IX, ENEMIES
    LD      B, MAX_ENEMIES
.loop:
    PUSH    BC
    LD      A, (IX+4) : OR A : JR Z, .next    ; active?

    ; Check P1 (if alive and not in the death timer)
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .skip_p1
    LD      A, (P1_LIVES) : OR A : JR Z, .skip_p1
    ; X distance
    LD      A, (P1_X) : SUB (IX+0)
    JP      P, .p1xp
    NEG
.p1xp: CP      6 : JR NC, .skip_p1
    ; Y distance
    LD      A, (P1_Y) : SUB (IX+1)
    JP      P, .p1yp
    NEG
.p1yp: CP      6 : JR NC, .skip_p1
    ; HIT P1
    LD      A, (P1_LIVES) : DEC A : LD (P1_LIVES), A
    LD      A, 1 : LD (HUD_DIRTY), A
    LD      A, 60 : LD (P1_DEAD_TMR), A    ; 1 second of blinking
    CALL    SFX_ENEMY_DIE
    JR      .next

.skip_p1:
    ; Check P2
    LD      A, (P2_DEAD_TMR) : OR A : JR NZ, .next
    LD      A, (P2_LIVES) : OR A : JR Z, .next
    LD      A, (P2_X) : SUB (IX+0)
    JP      P, .p2xp
    NEG
.p2xp: CP      6 : JR NC, .next
    LD      A, (P2_Y) : SUB (IX+1)
    JP      P, .p2yp
    NEG
.p2yp: CP      6 : JR NC, .next
    ; HIT P2
    LD      A, (P2_LIVES) : DEC A : LD (P2_LIVES), A
    LD      A, 1 : LD (HUD_DIRTY), A
    LD      A, 60 : LD (P2_DEAD_TMR), A
    CALL    SFX_ENEMY_DIE

.next:
    LD      BC, ENEMY_SIZE
    ADD     IX, BC
    POP     BC
    DEC     B
    JP      NZ, .loop
    RET
