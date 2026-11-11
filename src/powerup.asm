; =============================================================================
; powerup.asm — Power-ups (currently: the shield)
; =============================================================================
; A power-up is drawn with a 2x2 block of 8x8 background tiles (16x16 px,
; the size of a corridor and of the sprites), not with a sprite: in Screen 2
; every pixel row of a tile has its own foreground/background color pair, so
; the icon can be far more colorful than a one-color sprite, and it never
; counts against the 4-sprites-per-scanline limit (README gotcha 17).
;
; The tiles are only drawn in the name table; collision (IS_WALL) reads the
; MAZE data in ROM, so a power-up never blocks anything.
;
; Placement: a random tile-aligned spot where all four tiles of the 2x2
; block are floor in MAZE (columns 1-29, rows 1-19, so never in a portal
; opening). Corridors are two tiles wide, so the icon fills the corridor
; and a player walking along it covers the icon exactly. Not within
; PWR_MIN_PLAYER_DIST of a player.
;
; Life cycle (PWR_TIMER counts logic ticks, 60 per second):
;   not on the field: PWR_TIMER counts down the delay to the next spawn;
;                     at 0 a spot is searched every tick until one is found
;   on the field:     PWR_TIMER counts down its lifetime; the icon blinks
;                     for the last PWR_BLINK_TIME ticks and then disappears
;   picked up:        the player's shield is set to SHIELD_ON and a new
;                     spawn delay starts
;
; Shield: SHIELD_ON stays on, with no time limit, until the player is hit.
; The first enemy contact (CHECK_PLAYER_DEATH, player.asm) or enemy/tank/
; Wizard bullet (CHECK_ENEMY_BULLET_PLAYER_HIT, enemy.asm) is absorbed and
; starts SHIELD_BREAK_TIME (SHIELD_HIT): for those 2 s the shield still
; protects, then it is gone. The player sprite flashes white
; (SHIELD_SPRITE_COLOR): slowly while the shield is on, fast while it breaks.
; Picking up another shield restores SHIELD_ON.
;
; VDP writes happen only in DRAW_POWERUP (start of MAINLOOP): the logic
; only changes PWR_ACTIVE/PWR_TIMER, and DRAW_POWERUP compares what should
; be visible with what is in the name table (PWR_SHOWN).

; Tile numbers (after the radar border tiles 41-44, hud.asm)
PWR_TILE_TL         EQU 45      ; top-left
PWR_TILE_TR         EQU 46      ; top-right
PWR_TILE_BL         EQU 47      ; bottom-left
PWR_TILE_BR         EQU 48      ; bottom-right

; Timings in logic ticks (60/s on both PAL and NTSC)
PWR_FIRST_DELAY     EQU 600     ; first shield 10 s after the game starts
PWR_DELAY_MIN       EQU 480     ; next one 8 s + RAND*2 ticks (8-16.5 s) later
PWR_LIFETIME        EQU 600     ; stays 10 s on the field
PWR_BLINK_TIME      EQU 120     ; ...blinking for the last 2 s
SHIELD_ON           EQU 0xFF    ; P1_SHIELD/P2_SHIELD: shield on, waits for a hit
SHIELD_BREAK_TIME   EQU 120     ; after a hit: still protects, flashes fast 2 s, then gone
SHIELD_SPRITE_COLOR EQU 15      ; white

PWR_MIN_PLAYER_DIST EQU 32      ; px, no spawning this close to a player
PWR_SPAWN_TRIES     EQU 8       ; random spots tried per tick

; RAM
PWR_ACTIVE      EQU 0xC0B8      ; 1 = a power-up is on the field (can be picked up)
PWR_SHOWN       EQU 0xC0B9      ; 1 = its tiles are in the name table right now
PWR_TIMER       EQU 0xC0BA      ; 2 bytes: spawn delay / remaining lifetime
PWR_NAMEADDR    EQU 0xC0BC      ; 2 bytes: VRAM name table address of the top-left tile
PWR_X           EQU 0xC0BE      ; pixel X of the top-left corner
PWR_Y           EQU 0xC0BF      ; pixel Y
P1_SHIELD       EQU 0xC0C0      ; 0 = no shield, SHIELD_ON = on, 1-SHIELD_BREAK_TIME =
P2_SHIELD       EQU 0xC0C1      ;   hit, ticks left until it's gone (still protects)

; Shield icon, 16x16 px: a heraldic shield with a gold top edge, the left
; half white with a red cross arm and the right half red with a white one.
; On rows 2-9 the shield fills the whole 16 px, so the background color is
; the field and the foreground the cross; on the rounded top (rows 0-1) and
; the narrowing bottom (rows 10-15) the shield is the foreground on black.
; Data order = tile order 45-48: TL, TR, BL, BR (8 bytes each).
PWR_SHIELD_PATS:
    DB $3F,$7F,$00,$01,$01,$0F,$0F,$01  ; TL rows 0-7
    DB $FC,$FE,$00,$80,$80,$F0,$F0,$80  ; TR rows 0-7
    DB $01,$01,$7F,$7F,$3F,$1F,$07,$01  ; BL rows 8-15
    DB $80,$80,$FE,$FE,$FC,$F8,$E0,$80  ; BR rows 8-15
PWR_SHIELD_COLS:
    ; TL: light/dark yellow top edge, then red cross on white
    DB $B1,$A1,$8F,$8F,$8F,$8F,$8F,$8F
    ; TR: same top edge, then white cross on medium red
    DB $B1,$A1,$F8,$F8,$F8,$F8,$F8,$F8
    ; BL: red on white for rows 8-9, then white / gray tip on black
    DB $8F,$8F,$F1,$F1,$F1,$E1,$E1,$E1
    ; BR: white on red for rows 8-9, then medium / dark red tip on black
    DB $F8,$F8,$81,$81,$81,$61,$61,$61
PWR_SHIELD_END:

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
    LD      (P1_SHIELD), A
    LD      (P2_SHIELD), A
    LD      HL, PWR_FIRST_DELAY
    LD      (PWR_TIMER), HL
    RET

; HL = pattern table base of one bank; the color table is 0x2000 higher
.load_bank:
    LD      DE, PWR_TILE_TL*8 : ADD HL, DE
    PUSH    HL
    LD      DE, PWR_SHIELD_PATS : LD BC, PWR_SHIELD_COLS - PWR_SHIELD_PATS
    CALL    VDP_WRITE_BLOCK
    POP     HL
    LD      DE, 0x2000 : ADD HL, DE             ; color table, same tiles
    LD      DE, PWR_SHIELD_COLS : LD BC, PWR_SHIELD_END - PWR_SHIELD_COLS
    JP      VDP_WRITE_BLOCK

; =============================================================================
; UPDATE_POWERUPS — one logic tick: shield timers, spawning, pickup, expiry
; =============================================================================
UPDATE_POWERUPS:
    ; Shield break timers (SHIELD_ON doesn't count down)
    LD      HL, P1_SHIELD : CALL SHIELD_TICK
    LD      HL, P2_SHIELD : CALL SHIELD_TICK
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
    LD      A, SHIELD_ON : LD (P1_SHIELD), A
    JR      .picked
.p2:
    LD      A, (P2_DEAD_TMR) : OR A : RET NZ
    LD      A, (P2_LIVES)    : OR A : RET Z
    LD      A, (P2_X) : LD B, A
    LD      A, (P2_Y) : LD C, A
    CALL    PWR_TOUCHES : RET NZ
    LD      A, SHIELD_ON : LD (P2_SHIELD), A
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

; SHIELD_TICK — HL = P1_SHIELD/P2_SHIELD: count a broken shield down
SHIELD_TICK:
    LD      A, (HL) : OR A : RET Z              ; no shield
    INC     A : RET Z                           ; SHIELD_ON: waits for a hit
    DEC     (HL)
    RET

; PWR_TOUCHES — does a player at B=X, C=Y (sprite top-left) touch the icon?
; Both are 16x16 boxes: the distances between their top-left corners must
; be under 8 px on both axes, so the player has to be mostly on top of the
; icon. Output: Z = touches.
PWR_TOUCHES:
    LD      A, (PWR_X) : LD D, A
    LD      A, B : SUB D                ; X distance (|dx| <= 248, see below)
    JP      P, .xp
    NEG
.xp:
    CP      8 : JR NC, .no
    LD      A, (PWR_Y) : LD D, A
    LD      A, C : SUB D                ; Y distance
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
; (c,r) (c+1,r) (c,r+1) (c+1,r+1), and which is at least
; PWR_MIN_PLAYER_DIST px away from both players on some axis.
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
    LD      A, (HL) : INC HL : OR (HL)  ; top row of the 2x2 block
    JR      NZ, .fail_pop
    LD      DE, 31 : ADD HL, DE         ; (c, r+1)
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
    ; Tiles to write: D = top-left (top-right = D+1, bottom = D+2/D+3), 0 = floor
    LD      D, 0
    LD      A, B : OR A : JR Z, .write
    LD      D, PWR_TILE_TL
.write:
    LD      HL, (PWR_NAMEADDR) : CALL VDP_SETW
    CALL    .pair
    LD      A, L : ADD A, 32 : LD L, A          ; next name table row
    LD      A, H : ADC A, 0 : LD H, A
    CALL    VDP_SETW
    LD      A, D : OR A : JR Z, .pair           ; erasing: floor again
    LD      D, PWR_TILE_BL
; .pair — write tile D and the next one (both 0 when D = 0)
.pair:
    LD      A, D : OUT (VDP_DATA), A
    CALL    VDP_DLY
    OR      A : JR Z, .p0
    INC     A
.p0:
    OUT     (VDP_DATA), A
    RET

; =============================================================================
; SHIELD_COLOR — sprite color for a player: A = C (the player's own color)
; without a shield; with SHIELD_ON it flashes slowly between C and
; SHIELD_SPRITE_COLOR, and fast while a hit shield runs out.
; Input: HL = P1_SHIELD / P2_SHIELD, C = own color.
; =============================================================================
SHIELD_COLOR:
    LD      A, (HL) : OR A : JR Z, .own
    INC     A : JR Z, .slow                     ; SHIELD_ON
    LD      A, (FRAME_CTR) : AND 2 : JR .pick
.slow:
    LD      A, (FRAME_CTR) : AND 8
.pick:
    JR      Z, .own
    LD      A, SHIELD_SPRITE_COLOR
    RET
.own:
    LD      A, C
    RET

; =============================================================================
; SHIELD_HIT — an enemy or a bullet hits a player; does the shield protect?
; Input: HL = P1_SHIELD / P2_SHIELD.
; Output: Z = no shield (the player gets hurt), NZ = protected. The first
; hit on a SHIELD_ON shield starts SHIELD_BREAK_TIME (with the metallic
; clang); while that runs, further hits do nothing.
; Preserves BC, DE, HL.
; =============================================================================
SHIELD_HIT:
    LD      A, (HL) : OR A : RET Z
    INC     A : JR NZ, .prot                    ; already breaking
    LD      (HL), SHIELD_BREAK_TIME
    CALL    SFX_TANK_HIT
.prot:
    OR      1
    RET
