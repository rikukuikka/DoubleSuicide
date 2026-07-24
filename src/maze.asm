; =============================================================================
; maze.asm — Maze data and drawing routines
; =============================================================================

; Wall and floor patterns (fine in ROM, never changes)
WALL_PAT:   DB 0xFE,0xFE,0xFE,0x00,0xEF,0xEF,0xEF,0x00
FLOOR_PAT:  DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
WALL_COL:   DB 0x40,0x40,0x50,0x10,0x40,0x40,0x50,0x10
FLOOR_COL:  DB 0x10,0x10,0x10,0x10,0x10,0x10,0x10,0x10

; Level 1 (fine in ROM, never changes)
MAZE:
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,1
    DB 1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1
    DB 1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,0,0,0,0,0,1
    DB 1,1,1,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1,1,1,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0,0,1,0,0,0,0,0,1
    DB 0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0
    DB 0,0,0,1,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,0,1,0,0,0
    DB 1,0,0,0,0,0,1,0,0,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1
    DB 1,1,1,1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1,1,1,1
    DB 1,0,0,0,0,0,1,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,1,0,0,0,0,0,1
    DB 1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1
    DB 1,0,0,1,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,1
    DB 1,0,0,1,0,0,1,0,0,1,0,0,1,1,1,1,1,1,1,1,0,0,1,0,0,1,0,0,1,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1
    DB 1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1

; IS_WALL — collision check
; Input: B=X C=Y → Z=free NZ=wall
; Preserves HL; BC and DE are not touched at all.
; Hottest routine in the game (up to ~30 calls/frame), so the address math
; is minimized: (Y/8)*32 is computed as (Y AND 0xF8)*4, and the HUD-row
; test is done directly on the pixel Y (tile row 21 starts at Y=168).
IS_WALL:
    PUSH    HL
    ; HUD rows (Y >= 168 = tile row 21+): handle separately so we don't
    ; read past the end of MAZE
    LD      A, C : CP 168 : JR C, .normal
    CP      176 : JR NC, .wall          ; row 22+ → wall
    ; Row 21: door openings at columns 1-2 and 29-30
    LD      A, B : SRL A : SRL A : SRL A    ; A = column = X/8
    CP      1  : JR C,  .wall           ; column 0 → wall
    CP      3  : JR C,  .free           ; columns 1-2 → door open
    CP      29 : JR C,  .wall           ; columns 3-28 → wall
    CP      31 : JR C,  .free           ; columns 29-30 → door open
.wall:
    POP     HL : OR      1 : RET
.free:
    POP     HL : XOR     A : RET
.normal:
    AND     0xF8                            ; A still holds Y; (Y AND 0xF8)*4 = (Y/8)*32
    LD      L, A : LD H, 0
    ADD     HL, HL : ADD HL, HL             ; HL = row*32
    LD      A, B : SRL A : SRL A : SRL A    ; A = column = X/8
    ADD     A, L                            ; never carries: L is a multiple of 32, column <= 31
    ADD     A, LOW MAZE : LD L, A
    LD      A, H : ADC A, HIGH MAZE : LD H, A
    LD      A, (HL)
    POP     HL
    OR      A
    RET

; LOAD_PATTERNS — load patterns into VRAM, HL = destination
LOAD_PATTERNS:
    CALL    VDP_SETW
    LD      HL, FLOOR_PAT : LD B, 8
.f: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .f
    LD      HL, WALL_PAT  : LD B, 8
.w: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .w
    RET

; LOAD_COLORS — load colors into VRAM, HL = destination
LOAD_COLORS:
    CALL    VDP_SETW
    LD      HL, FLOOR_COL : LD B, 8
.f: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .f
    LD      HL, WALL_COL  : LD B, 8
.w: LD      A, (HL) : OUT (VDP_DATA), A : INC HL : DJNZ .w
    RET

; DRAW_MAZE — draw the maze into the name table
DRAW_MAZE:
    LD      HL, VRAM_NAMETABLE : CALL VDP_SETW
    LD      HL, MAZE
    LD      BC, 32*21
.lp:
    LD      A, (HL) : OUT (VDP_DATA), A : INC HL
    DEC     BC : LD A, B : OR C : JR NZ, .lp
    RET


; =============================================================================
; FIND_PORTALS — scan the maze data and find the portal rows
; Looks for rows where column 0 OR column 31 is open (=0)
; Stores PORTAL_Y_MIN and PORTAL_Y_MAX in RAM
; =============================================================================
FIND_PORTALS:
    LD      HL, MAZE
    LD      B, 21               ; 24 rows
    LD      C, 0                ; row counter
    LD      A, 0xFF
    LD      (PORTAL_Y_MIN), A   ; not found yet
    XOR     A
    LD      (PORTAL_Y_MAX), A

.row_loop:
    ; Check column 0 (first byte on the row)
    LD      A, (HL)
    OR      A                   ; 0 = open
    JR      NZ, .check_col31

    ; Left edge open — this is a portal row
    JR      .portal_row

.check_col31:
    ; Check column 31 (last byte on the row = HL+31)
    PUSH    HL
    LD      DE, 31
    ADD     HL, DE
    LD      A, (HL)
    POP     HL
    OR      A
    JR      NZ, .not_portal

.portal_row:
    ; Compute Y pixels: row * 8
    LD      A, C
    RLCA : RLCA : RLCA          ; * 8

    ; Update PORTAL_Y_MIN if not yet set
    PUSH    AF
    LD      A, (PORTAL_Y_MIN)
    CP      0xFF
    POP     AF
    JR      NZ, .update_max     ; min already set → update max only
    LD      (PORTAL_Y_MIN), A   ; store min

.update_max:
    ; Max = this row + 7 (row's lowest pixel)
    ADD     A, 7
    LD      (PORTAL_Y_MAX), A

.not_portal:
    ; Next row
    LD      DE, 32
    ADD     HL, DE
    INC     C
    DJNZ    .row_loop

    ; If no portals were found, set a safe default
    LD      A, (PORTAL_Y_MIN)
    CP      0xFF
    JR      NZ, .done
    LD      A, 80  : LD (PORTAL_Y_MIN), A
    LD      A, 111 : LD (PORTAL_Y_MAX), A
.done:
    RET

; INIT_MAZE — load all patterns and draw the level
INIT_MAZE:
    LD      HL, 0x0000 : CALL LOAD_PATTERNS
    LD      HL, 0x0800 : CALL LOAD_PATTERNS
    LD      HL, 0x1000 : CALL LOAD_PATTERNS
    LD      HL, 0x2000 : CALL LOAD_COLORS
    LD      HL, 0x2800 : CALL LOAD_COLORS
    LD      HL, 0x3000 : CALL LOAD_COLORS
    CALL    DRAW_MAZE
    RET

; INIT_NAVMAP — precompute junction points into the NAVMAP table
; Called once at startup, after INIT_MAZE.
; Each (column, row) gets a 4-bit direction map stored:
;   Bit 0=RIGHT, 1=LEFT, 2=UP, 3=DOWN (0=not a valid spot)
; The 2x2 tile block must be free, and the relevant neighboring tile must be free.
INIT_NAVMAP:
    ; Clear NAVMAP
    XOR     A
    LD      HL, NAVMAP
    LD      (HL), A
    LD      DE, NAVMAP + 1
    LD      BC, 32*21 - 1
    LDIR

    ; IX = pointer into the MAZE table (current cell)
    ; IY = pointer into the NAVMAP table (current cell)
    ; D  = rows remaining (23=row0 … 1=row22)
    ; E  = columns remaining (31=col0 … 1=col30)
    LD      IX, MAZE
    LD      IY, NAVMAP
    LD      D, 20
.nv_row:
    LD      E, 31
.nv_col:
    ; Check the 2x2 block: all four tiles must be free
    LD      A, (IX+0)  : OR A : JR NZ, .nv_skip
    LD      A, (IX+1)  : OR A : JR NZ, .nv_skip
    LD      A, (IX+32) : OR A : JR NZ, .nv_skip
    LD      A, (IX+33) : OR A : JR NZ, .nv_skip

    ; Compute the direction bitmap in register B
    LD      B, 0

    ; RIGHT: col+2 <= 31 (E >= 2) and both tiles free
    LD      A, E : CP 2 : JR C, .nv_nr
    LD      A, (IX+2)  : OR A : JR NZ, .nv_nr
    LD      A, (IX+34) : OR A : JR NZ, .nv_nr
    SET     0, B
.nv_nr:
    ; LEFT: col > 0 (E < 31) and both tiles free
    LD      A, E : CP 31 : JR Z, .nv_nl
    LD      A, (IX-1)  : OR A : JR NZ, .nv_nl
    LD      A, (IX+31) : OR A : JR NZ, .nv_nl
    SET     1, B
.nv_nl:
    ; UP: row > 0 (D < 20) and both tiles free
    LD      A, D : CP 20 : JR Z, .nv_nu
    LD      A, (IX-32) : OR A : JR NZ, .nv_nu
    LD      A, (IX-31) : OR A : JR NZ, .nv_nu
    SET     2, B
.nv_nu:
    ; DOWN: row < 19 (D > 1) and both tiles free
    LD      A, D : CP 1 : JR Z, .nv_nd
    LD      A, (IX+64) : OR A : JR NZ, .nv_nd
    LD      A, (IX+65) : OR A : JR NZ, .nv_nd
    SET     3, B
.nv_nd:
    LD      (IY+0), B
.nv_skip:
    INC     IX
    INC     IY
    DEC     E : JR NZ, .nv_col
    ; Skip column 31 (move to the start of the next row)
    INC     IX
    INC     IY
    DEC     D : JR NZ, .nv_row
    RET
