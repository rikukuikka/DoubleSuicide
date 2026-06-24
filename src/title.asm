; =============================================================================
; title.asm — Otsikkoruutu ja pelimoodin valinta
; =============================================================================
;
; Tile-indeksit: 0=tyhjä, 2-11=numerot, 12=kursori, 14-39=kirjaimet A-Z

; Muistissa oleva valinta (0=1P, 1=2P)
TITLE_SEL   EQU 0xC07A

; =============================================================================
; TITLE_SCREEN — näytä otsikkoruutu, odota valinta
; Ulostulo: GAME_MODE = 1 tai 2
; =============================================================================
TITLE_SCREEN:
    ; Tyhjennä ruutu
    LD      HL, VRAM_NAMETABLE
    LD      BC, 32*24
    LD      A, 0
    CALL    VDP_FILL

    ; Piirrä otsikko "WIZARD OF WOR" riville 4, sarakkeesta 9
    LD      HL, VRAM_NAMETABLE + 4*32 + 9
    CALL    VDP_SETW
    LD      HL, TXT_TITLE
    CALL    WRITE_TEXT

    ; Piirrä "1 PLAYER" riville 10, sarakkeesta 12
    LD      HL, VRAM_NAMETABLE + 10*32 + 12
    CALL    VDP_SETW
    LD      HL, TXT_1P
    CALL    WRITE_TEXT

    ; Piirrä "2 PLAYERS" riville 12, sarakkeesta 12
    LD      HL, VRAM_NAMETABLE + 12*32 + 12
    CALL    VDP_SETW
    LD      HL, TXT_2P
    CALL    WRITE_TEXT

    ; Valinta oletuksena 1P
    XOR     A : LD (TITLE_SEL), A

.input_loop:
    CALL    WAIT_VBLANK
    LD      A, (FRAME_CTR) : INC A : LD (FRAME_CTR), A
    CALL    UPDATE_SOUND         ; musiikki soi taustalla
    CALL    READ_INPUTS

    ; Ylös/alas vaihtaa valintaa
    LD      A, (P1_INPUT)
    LD      B, A
    AND     IN_UP
    JR      Z, .no_up
    XOR     A : LD (TITLE_SEL), A        ; 0 = 1 PLAYER
.no_up:
    LD      A, B
    AND     IN_DOWN
    JR      Z, .no_down
    LD      A, 1 : LD (TITLE_SEL), A     ; 1 = 2 PLAYERS
.no_down:

    ; Piirrä kursori (vilkkuva neliö)
    ; Tyhjennä molemmat kursoripaikat ensin
    LD      HL, VRAM_NAMETABLE + 10*32 + 10 : CALL VDP_SETW
    XOR     A : OUT (VDP_DATA), A
    LD      HL, VRAM_NAMETABLE + 12*32 + 10 : CALL VDP_SETW
    XOR     A : OUT (VDP_DATA), A

    ; Vilkuta kursori (näkyvissä 75% ajasta)
    LD      A, (FRAME_CTR) : AND 0x10 : JR NZ, .no_cursor

    ; Piirrä kursori valitulle riville
    LD      A, (TITLE_SEL)
    OR      A
    JR      NZ, .cursor_2p
    LD      HL, VRAM_NAMETABLE + 10*32 + 10 : CALL VDP_SETW
    JR      .draw_cursor
.cursor_2p:
    LD      HL, VRAM_NAMETABLE + 12*32 + 10 : CALL VDP_SETW
.draw_cursor:
    LD      A, 12 : OUT (VDP_DATA), A    ; syaani neliö
.no_cursor:

    ; Tulipainike = vahvista valinta
    LD      A, B
    AND     IN_FIRE
    JR      Z, .input_loop

    ; Odota että painike vapautetaan (ei jää pohjaan)
.wait_release:
    CALL    WAIT_VBLANK
    CALL    READ_INPUTS
    LD      A, (P1_INPUT) : AND IN_FIRE : JR NZ, .wait_release

    ; Aseta GAME_MODE
    LD      A, (TITLE_SEL)
    INC     A                   ; 0→1, 1→2
    LD      (GAME_MODE), A
    RET

; =============================================================================
; WRITE_TEXT — kirjoita merkkijono VRAM:iin (VDP-osoite asetettu)
; HL = merkkijonon osoite (0-terminoitu ASCII)
; =============================================================================
WRITE_TEXT:
    LD      A, (HL) : INC HL
    OR      A : RET Z           ; 0 = loppu
    CP      ' '
    JR      Z, .space
    CP      '0' : JR C, .space
    CP      '9'+1 : JR C, .digit
    CP      'A' : JR C, .space
    CP      'Z'+1 : JR NC, .space
    ; Kirjain A-Z → tile 14-39
    SUB     'A' - 14
    OUT     (VDP_DATA), A
    JR      WRITE_TEXT
.digit:
    ; Numero 0-9 → tile 2-11
    SUB     '0' - 2
    OUT     (VDP_DATA), A
    JR      WRITE_TEXT
.space:
    XOR     A
    OUT     (VDP_DATA), A
    JR      WRITE_TEXT

; =============================================================================
; Tekstit
; =============================================================================
TXT_TITLE:  DB "DOUBLE SUICIDE", 0
TXT_1P:     DB "1 PLAYER", 0
TXT_2P:     DB "2 PLAYERS", 0
