; =============================================================================
; enemy_ghost.asm — Ghost enemy: graphics, spawning, visibility and sprite
; drawing. Moves with the shared UPDATE_CHASER (enemy.asm) at twice the
; Robot/Tank speed and never fires.
; =============================================================================

GHOST_COLOR     EQU 15          ; white
GHOST_PAT_BASE  EQU 76          ; RADAR_DOT_PAT(72) reserves 4 patterns (72-75), 32 patterns: 76-107
; Ghost sight buffer: how many pixels beyond the edge of the player's 16x16
; sprite visibility extends. Threshold = 16 (sprite) + buffer, because
; abs(difference) < threshold covers both the sprite overlap and the buffer
; on both sides (see GHOST_VISIBLE).
GHOST_SIGHT_BUFFER  EQU 10
GHOST_SIGHT_TOL     EQU 16 + GHOST_SIGHT_BUFFER

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

    ALIGN   8
; Ghost direction+animation frame → pattern. Index = direction*2 + frame(0/1)
GHOST_DIR_PAT:
    DB GHOST_PAT_BASE+8,  GHOST_PAT_BASE+12   ; DIR_RIGHT frame0,1 (Right1,2)
    DB GHOST_PAT_BASE+0,  GHOST_PAT_BASE+4    ; DIR_LEFT  frame0,1 (Left1,2)
    DB GHOST_PAT_BASE+24, GHOST_PAT_BASE+28   ; DIR_UP    frame0,1 (Up1,2)
    DB GHOST_PAT_BASE+16, GHOST_PAT_BASE+20   ; DIR_DOWN  frame0,1 (Down1,2)

; LOAD_GHOST_PATS — Ghost patterns to VRAM (GHOST_PAT_BASE=76, after the
; radar dot's 4 patterns). Exactly 256 bytes, hence a BC counter.
LOAD_GHOST_PATS:
    LD      HL, VRAM_SPRITE_PAT + GHOST_PAT_BASE*8
    LD      DE, GHOST_PATS
    LD      BC, GHOST_PATS_END - GHOST_PATS
    JP      VDP_WRITE_BLOCK

; SPAWN_GHOST — create a Ghost at the IX address via a NAVMAP point
SPAWN_GHOST:
    CALL    PICK_SPAWN_POS
    LD      (IX+2), DIR_RIGHT
    LD      (IX+3), ENEMY_GHOST
    LD      (IX+4), 1
    LD      A, (CUR_GHOST_SPEED_X2) : LD (IX+5), A
    LD      (IX+6), 0
    RET

; UPDATE_GHOST — same chase logic as the tank, doesn't fire
UPDATE_GHOST    EQU UPDATE_CHASER

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
; DRAW_GHOST_SPRITE — write the Ghost's 4 sprite attribute bytes (Y, X,
; pattern, color) to the VDP. Visibility (GHOST_VISIBLE) is checked by the
; caller. Input: IX = enemy data, VDP address already set.
; Clobbers A, C, HL. Must preserve B and DE (DRAW_ENEMIES's loop counter/step).
; =============================================================================
DRAW_GHOST_SPRITE:
    LD      A, (IX+1) : DEC A : OUT (VDP_DATA), A    ; Y
    LD      A, (IX+0) : OUT (VDP_DATA), A              ; X
    ; Pattern: direction*2 + animation frame (FRAME_CTR bit 3, changes every 8 frames)
    ; NOTE: use C, not B — B is DRAW_ENEMIES's DJNZ counter (MAX_ENEMIES)
    LD      A, (IX+2) : ADD A, A : LD C, A
    LD      A, (FRAME_CTR) : SRL A : SRL A : SRL A : AND 0x01
    ADD     A, C
    LD      HL, GHOST_DIR_PAT : ADD A, L : LD L, A : LD A, (HL)
    OUT     (VDP_DATA), A
    LD      A, GHOST_COLOR : OUT (VDP_DATA), A
    RET
