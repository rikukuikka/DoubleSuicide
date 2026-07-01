; =============================================================================
; vdp.asm — VDP (TMS9918A) apurutiinit
; =============================================================================

; VDP_SETW — aseta VRAM kirjoitusosoite HL:stä
VDP_SETW:
    LD      A, L : OUT (VDP_REG), A
    LD      A, H : OR 0x40 : OUT (VDP_REG), A
    RET

; HIDE_SPRITE — piilota yksi sprite; HL = VRAM sprite attribute address
HIDE_SPRITE:
    CALL    VDP_SETW
    LD      A, 0xD8 : OUT (VDP_DATA), A
    XOR     A : OUT (VDP_DATA), A : OUT (VDP_DATA), A : OUT (VDP_DATA), A
    RET

; VDP_FILL — täytä BC tavua arvolla A osoitteesta HL
VDP_FILL:
    LD      D, A
    CALL    VDP_SETW
.lp:
    LD      A, D : OUT (VDP_DATA), A
    DEC     BC : LD A, B : OR C : JR NZ, .lp
    RET

; VDP_INIT_SCREEN2 — alusta Screen 2 moodi
VDP_INIT_SCREEN2:
    LD      A, 0x02 : OUT (VDP_REG), A : LD A, 0x80 : OUT (VDP_REG), A
    LD      A, 0xE2 : OUT (VDP_REG), A : LD A, 0x81 : OUT (VDP_REG), A  ; 0xE2 = 16x16 sprites
    LD      A, 0x06 : OUT (VDP_REG), A : LD A, 0x82 : OUT (VDP_REG), A
    LD      A, 0xFF : OUT (VDP_REG), A : LD A, 0x83 : OUT (VDP_REG), A
    LD      A, 0x03 : OUT (VDP_REG), A : LD A, 0x84 : OUT (VDP_REG), A
    LD      A, 0x36 : OUT (VDP_REG), A : LD A, 0x85 : OUT (VDP_REG), A
    LD      A, 0x07 : OUT (VDP_REG), A : LD A, 0x86 : OUT (VDP_REG), A
    LD      A, 0x01 : OUT (VDP_REG), A : LD A, 0x87 : OUT (VDP_REG), A
    RET
