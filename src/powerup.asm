; =============================================================================
; powerup.asm — Power-ups (currently: the shield)
; =============================================================================
; A power-up is drawn with two side-by-side 8x8 background tiles (16x8 px),
; not with a sprite: in Screen 2 every pixel row of a tile has its own
; foreground/background color pair, so the icon can be far more colorful
; than a one-color sprite, and it never counts against the 4-sprites-per-
; scanline limit (README gotcha 17).
;
; The tiles are only drawn in the name table; collision (IS_WALL) reads the
; MAZE data in ROM, so a power-up never blocks anything.
;
; Placement: a random spot where both power-up tiles AND the two tiles
; directly above and below them are floor in MAZE — in practice a vertical
; corridor (or an open area), where a player walking along the corridor
; covers the icon completely. Not within PWR_MIN_PLAYER_DIST of a player.
;
; Life cycle (PWR_TIMER counts logic ticks, 60 per second):
;   not on the field: PWR_TIMER counts down the delay to the next spawn;
;                     at 0 a spot is searched every tick until one is found
;   on the field:     PWR_TIMER counts down its lifetime; the icon blinks
;                     for the last PWR_BLINK_TIME ticks and then disappears
;   picked up:        the player gets SHIELD_TIME ticks of shield and a new
;                     spawn delay starts
;
; Shield: while P1_SHIELD/P2_SHIELD is nonzero, enemy contact does nothing
; (CHECK_PLAYER_DEATH, player.asm) and enemy/tank/Wizard bullets are
; absorbed (CHECK_ENEMY_BULLET_PLAYER_HIT, enemy.asm). The player sprite
; flashes white (SHIELD_SPRITE_COLOR), faster during the last
; SHIELD_WARN_TIME ticks.
;
; VDP writes happen only in DRAW_POWERUP (start of MAINLOOP): the logic
; only changes PWR_ACTIVE/PWR_TIMER, and DRAW_POWERUP compares what should
; be visible with what is in the name table (PWR_SHOWN).

; Tile numbers (after the radar border tiles 41-44, hud.asm)
PWR_TILE_L          EQU 45
PWR_TILE_R          EQU 46

; Timings in logic ticks (60/s on both PAL and NTSC)
PWR_FIRST_DELAY     EQU 600     ; first shield 10 s after the game starts
PWR_DELAY_MIN       EQU 480     ; next one 8 s + RAND*2 ticks (8-16.5 s) later
PWR_LIFETIME        EQU 600     ; stays 10 s on the field
PWR_BLINK_TIME      EQU 120     ; ...blinking for the last 2 s
SHIELD_TIME         EQU 480     ; shield lasts 8 s
SHIELD_WARN_TIME    EQU 120     ; faster flashing for the last 2 s
SHIELD_SPRITE_COLOR EQU 15      ; white

PWR_MIN_PLAYER_DIST EQU 32      ; px, no spawning this close to a player
PWR_SPAWN_TRIES     EQU 8       ; random spots tried per tick

; RAM
PWR_ACTIVE      EQU 0xC0B8      ; 1 = a power-up is on the field (can be picked up)
PWR_SHOWN       EQU 0xC0B9      ; 1 = its tiles are in the name table right now
PWR_TIMER       EQU 0xC0BA      ; 2 bytes: spawn delay / remaining lifetime
PWR_NAMEADDR    EQU 0xC0BC      ; 2 bytes: VRAM name table address of the left tile
PWR_X           EQU 0xC0BE      ; pixel X of the left tile
PWR_Y           EQU 0xC0BF      ; pixel Y
P1_SHIELD       EQU 0xC0C0      ; 2 bytes: shield ticks left (0 = no shield)
P2_SHIELD       EQU 0xC0C2      ; 2 bytes

; Shield icon, 16x8 px: a dark blue heraldic shield on a gold capsule.
; Columns 0-7 = left tile, 8-15 = right tile. Rows 0 and 7 are the capsule's
; rounded top/bottom (gold/red on black); on rows 1-6 the background color
; is the capsule's shading and the foreground the dark blue shield.
PWR_SHIELD_PAT_L:
    DB $7F,$0F,$0F,$0F,$07,$03,$01,$7F
PWR_SHIELD_PAT_R:
    DB $FE,$F0,$F0,$F0,$E0,$C0,$80,$FE
PWR_SHIELD_COL:                     ; same colors for both tiles
    DB $B1                          ; row 0: light yellow on black
    DB $4B,$4B                      ; rows 1-2: dark blue on light yellow
    DB $4A,$4A                      ; rows 3-4: dark blue on dark yellow
    DB $49                          ; row 5: dark blue on light red
    DB $48                          ; row 6: dark blue on medium red
    DB $61                          ; row 7: dark red on black

; =============================================================================
; INIT_POWERUPS — load the tiles into all three banks and reset the state.
; Called from INIT after TITLE_SCREEN (which uses its own tiles) and after
; INIT_ENEMIES (which seeds RAND).
; =============================================================================
INIT_POWERUPS:
    LD      HL, 0x0000 : CALL .load_bank
    LD      HL, 0x0800 : CALL .load_bank
    LD      HL, 0x1000 : CALL .load_bank
    XOR     A
    LD      (PWR_ACTIVE), A
    LD      (PWR_SHOWN), A
    LD      HL, 0
    LD      (P1_SHIELD), HL
    LD      (P2_SHIELD), HL
    LD      HL, PWR_FIRST_DELAY
    LD      (PWR_TIMER), HL
    RET

; HL = pattern table base of one bank; the color table is 0x2000 higher
.load_bank:
    PUSH    HL
    LD      DE, PWR_TILE_L*8 : ADD HL, DE
    PUSH    HL
    LD      DE, PWR_SHIELD_PAT_L : LD BC, 16    ; L and R patterns are adjacent
    CALL    VDP_WRITE_BLOCK
    POP     HL
    LD      DE, 0x2000 : ADD HL, DE             ; color table, tile 45
    PUSH    HL
    LD      DE, PWR_SHIELD_COL : LD BC, 8
    CALL    VDP_WRITE_BLOCK
    POP     HL
    LD      DE, 8 : ADD HL, DE                  ; tile 46
    LD      DE, PWR_SHIELD_COL : LD BC, 8
    CALL    VDP_WRITE_BLOCK
    POP     HL
    RET

; =============================================================================
; UPDATE_POWERUPS — one logic tick: shield timers, spawning, pickup, expiry
; =============================================================================
UPDATE_POWERUPS:
    ; Shield timers
    LD      HL, (P1_SHIELD) : LD A, H : OR L : JR Z, .s1
    DEC     HL : LD (P1_SHIELD), HL
.s1:
    LD      HL, (P2_SHIELD) : LD A, H : OR L : JR Z, .s2
    DEC     HL : LD (P2_SHIELD), HL
.s2:
    LD      A, (PWR_ACTIVE) : OR A : JR NZ, .on_field

    ; --- Nothing on the field: spawn delay ---
    LD      HL, (PWR_TIMER) : LD A, H : OR L : JR Z, .try_spawn
    DEC     HL : LD (PWR_TIMER), HL
    RET
.try_spawn:
    LD      A, (PWR_SHOWN) : OR A : RET NZ      ; old icon not erased yet
    CALL    PWR_PICK_SPOT : RET NZ              ; no spot this tick, try again next
    LD      A, 1 : LD (PWR_ACTIVE), A
    LD      HL, PWR_LIFETIME : LD (PWR_TIMER), HL
    RET

    ; --- On the field: lifetime and pickup ---
.on_field:
    LD      HL, (PWR_TIMER) : DEC HL : LD (PWR_TIMER), HL
    LD      A, H : OR L : JR Z, PWR_REMOVE      ; expired

    ; P1
    LD      A, (P1_DEAD_TMR) : OR A : JR NZ, .p2
    LD      A, (P1_LIVES)    : OR A : JR Z, .p2
    LD      A, (P1_X) : LD B, A
    LD      A, (P1_Y) : LD C, A
    CALL    PWR_TOUCHES : JR NZ, .p2
    LD      HL, SHIELD_TIME : LD (P1_SHIELD), HL
    JR      .picked
.p2:
    LD      A, (P2_DEAD_TMR) : OR A : RET NZ
    LD      A, (P2_LIVES)    : OR A : RET Z
    LD      A, (P2_X) : LD B, A
    LD      A, (P2_Y) : LD C, A
    CALL    PWR_TOUCHES : RET NZ
    LD      HL, SHIELD_TIME : LD (P2_SHIELD), HL
.picked:
    CALL    SFX_POWERUP
    ; fall through
; PWR_REMOVE — take the power-up off the field and start a new spawn delay
; (DRAW_POWERUP erases the tiles on the next frame)
PWR_REMOVE:
    XOR     A : LD (PWR_ACTIVE), A
    CALL    RAND
    LD      L, A : LD H, 0 : ADD HL, HL         ; 0-510
    LD      DE, PWR_DELAY_MIN : ADD HL, DE
    LD      (PWR_TIMER), HL
    RET

; PWR_TOUCHES — does a player at B=X, C=Y (sprite top-left) touch the icon?
; The player's 16x16 box center (X+8, Y+8) against the icon's 16x8 center
; (PWR_X+8, PWR_Y+4): both distances must be under 8 px, so the player has
; to be mostly on top of the icon. Output: Z = touches.
PWR_TOUCHES:
    LD      A, (PWR_X) : LD D, A
    LD      A, B : SUB D                ; X distance (|dx| <= 248, see below)
    JP      P, .xp
    NEG
.xp:
    CP      8 : JR NC, .no
    LD      A, (PWR_Y) : LD D, A
    LD      A, C : ADD A, 4 : SUB D     ; (Y+8) - (PWR_Y+4)
    JP      P, .yp
    NEG
.yp:
    CP      8 : JR NC, .no
    XOR     A                           ; Z
    RET
.no:
    OR      1                           ; NZ
    RET
; (Coordinates are 0-248, so a real distance of 128-248 wraps to a signed
; value whose magnitude is still >= 8: no false hits, same as CHECK_PLAYER_DEATH.)

; =============================================================================
; PWR_PICK_SPOT — try PWR_SPAWN_TRIES random spots for the power-up.
; A spot is column c (1-29) and row r (1-19) where MAZE has floor at
; (c,r) (c+1,r), (c,r-1) (c+1,r-1) and (c,r+1) (c+1,r+1), and which is at
; least PWR_MIN_PLAYER_DIST px away from both players on some axis.
; Output: Z = found (PWR_X, PWR_Y, PWR_NAMEADDR set), NZ = not found.
; =============================================================================
PWR_PICK_SPOT:
    LD      B, PWR_SPAWN_TRIES
.try:
    PUSH    BC
    CALL    RAND : AND 31               ; column
    CP      1 : JR C, .fail
    CP      30 : JR NC, .fail
    LD      C, A
    CALL    RAND : AND 31               ; row
    CP      1 : JR C, .fail
    CP      20 : JR NC, .fail
    LD      E, A
    ADD     A, A : ADD A, A : ADD A, A
    LD      B, A                        ; B = Y = row*8 (loop counter is on the stack)
    ; HL = row*32 + column = offset in MAZE and in the name table
    LD      L, E : LD H, 0
    ADD     HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL : ADD HL, HL
    LD      A, L : OR C : LD L, A       ; column < 32, low 5 bits were 0
    PUSH    HL
    LD      DE, MAZE : ADD HL, DE
    LD      A, (HL) : INC HL : OR (HL)  ; the icon's own two tiles
    JR      NZ, .fail_pop
    LD      DE, -33 : ADD HL, DE        ; (c, r-1)
    LD      A, (HL) : INC HL : OR (HL)
    JR      NZ, .fail_pop
    LD      DE, 63 : ADD HL, DE         ; (c, r+1)
    LD      A, (HL) : INC HL : OR (HL)
    JR      NZ, .fail_pop
    ; Pixel coordinates: D = X, E = Y
    LD      E, B
    LD      A, C : ADD A, A : ADD A, A : ADD A, A : LD D, A
    ; Not too close to either player
    LD      A, (P1_X) : LD B, A
    LD      A, (P1_Y) : LD C, A
    CALL    .near : JR Z, .fail_pop
    LD      A, (P2_X) : LD B, A
    LD      A, (P2_Y) : LD C, A
    CALL    .near : JR Z, .fail_pop
    ; Found
    LD      A, D : LD (PWR_X), A
    LD      A, E : LD (PWR_Y), A
    POP     HL
    LD      DE, VRAM_NAMETABLE : ADD HL, DE
    LD      (PWR_NAMEADDR), HL
    POP     BC
    XOR     A                           ; Z = found
    RET
.fail_pop:
    POP     HL
.fail:
    POP     BC
    DJNZ    .try
    OR      1                           ; NZ = not found
    RET

; Z if the player at B=X, C=Y is within PWR_MIN_PLAYER_DIST of D=X, E=Y on
; both axes. Preserves BC, DE, HL.
.near:
    LD      A, B : SUB D
    JP      P, .nx
    NEG
.nx:
    CP      PWR_MIN_PLAYER_DIST : JR NC, .far
    LD      A, C : SUB E
    JP      P, .ny
    NEG
.ny:
    CP      PWR_MIN_PLAYER_DIST : JR NC, .far
    XOR     A
    RET
.far:
    OR      1
    RET

; =============================================================================
; DRAW_POWERUP — draw or erase the icon (start of MAINLOOP, right after vblank).
; Writes to VRAM only when the wanted state differs from PWR_SHOWN.
; =============================================================================
DRAW_POWERUP:
    ; Wanted state in B: 1 = icon visible, 0 = floor
    LD      B, 0
    LD      A, (PWR_ACTIVE) : OR A : JR Z, .want
    LD      HL, (PWR_TIMER)
    LD      A, H : OR A : JR NZ, .on            ; >= 256 ticks left
    LD      A, L : CP PWR_BLINK_TIME : JR NC, .on
    AND     8 : JR Z, .want                     ; blinking: off 8 ticks, on 8
.on:
    INC     B
.want:
    LD      A, (PWR_SHOWN) : CP B : RET Z
    LD      A, B : LD (PWR_SHOWN), A
    LD      HL, (PWR_NAMEADDR) : CALL VDP_SETW
    LD      A, B : OR A : JR Z, .erase
    LD      A, PWR_TILE_L : OUT (VDP_DATA), A
    CALL    VDP_DLY
    LD      A, PWR_TILE_R : OUT (VDP_DATA), A
    RET
.erase:
    OUT     (VDP_DATA), A                       ; A = 0 = floor tile
    CALL    VDP_DLY
    OUT     (VDP_DATA), A
    RET

; =============================================================================
; SHIELD_COLOR — sprite color for a player: A = C (the player's own color)
; without a shield, otherwise flashing between C and SHIELD_SPRITE_COLOR
; (faster for the last SHIELD_WARN_TIME ticks).
; Input: HL = P1_SHIELD / P2_SHIELD, C = own color. Clobbers HL.
; =============================================================================
SHIELD_COLOR:
    LD      A, (HL) : INC HL : OR (HL)
    JR      Z, .own
    LD      A, (HL) : OR A : JR NZ, .slow       ; >= 256 ticks left
    DEC     HL : LD A, (HL)
    CP      SHIELD_WARN_TIME : JR NC, .slow
    LD      A, (FRAME_CTR) : AND 2 : JR .pick
.slow:
    LD      A, (FRAME_CTR) : AND 4
.pick:
    JR      Z, .own
    LD      A, SHIELD_SPRITE_COLOR
    RET
.own:
    LD      A, C
    RET
