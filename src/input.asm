; =============================================================================
; input.asm — Keyboard and joystick reading
; =============================================================================
;
; Joystick port 1: PSG register 14
;   bit0=up bit1=down bit2=left bit3=right bit4=fire
;
; Keyboard row 8 (tested):
;   bit5=up bit6=down bit4=left bit7=right bit0=space

READ_INPUTS:
    ; --- P1: joystick port 1 ---
    LD      A, 15 : OUT (PSG_REG), A : IN A, (PSG_READ) : AND PSG_P1 : OUT (PSG_REG15), A
    LD      A, 14 : OUT (PSG_REG), A : IN A, (PSG_READ) : CPL : LD B, A

    ; --- P1: keyboard row 8 ---
    LD      A, 8 : OUT (PPI_ROW), A : IN A, (PPI_COL) : CPL : LD E, A
    LD      A, E : AND 0x20 : JR Z, .nku : LD A, B : OR IN_UP    : LD B, A
.nku:
    LD      A, E : AND 0x40 : JR Z, .nkd : LD A, B : OR IN_DOWN  : LD B, A
.nkd:
    LD      A, E : AND 0x10 : JR Z, .nkl : LD A, B : OR IN_LEFT  : LD B, A
.nkl:
    LD      A, E : AND 0x80 : JR Z, .nkr : LD A, B : OR IN_RIGHT : LD B, A
.nkr:
    LD      A, E : AND 0x01 : JR Z, .nkf : LD A, B : OR IN_FIRE  : LD B, A
.nkf:
    LD      A, B : LD (P1_INPUT), A

    ; --- P2: joystick port 2 ---
    LD      A, 15 : OUT (PSG_REG), A : IN A, (PSG_READ) : OR PSG_P2 : OUT (PSG_REG15), A
    LD      A, 14 : OUT (PSG_REG), A : IN A, (PSG_READ) : CPL : LD B, A
    LD      A, B : LD (P2_INPUT), A
    RET
