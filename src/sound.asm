; =============================================================================
; sound.asm — VERSION: SAWTOOTH BUZZER (hardware envelope)
; Channel C plays through the envelope generator at the note frequency
; → a genuine sawtooth waveform instead of a square wave!
; R13 values: 0x08=sawtooth, 0x0E=triangle, 0x0C=inverted sawtooth
; =============================================================================
;
; R7 mixer bits 7,6 always: bit7=1 (port B out), bit6=0 (port A in)
; Channels: A = shooting, B = explosion, C = background music
;
; R7 values (0b10xxxxx):
;   Silent:       0b10111111 = 0xBF
;   A tone:       0b10111110 = 0xBE
;   B noise:      0b10101111 = 0xAF
;   A+B:          0b10101110 = 0xAE
;   C tone:       0b10111011 = 0xBB
;   A+C:          0b10111010 = 0xBA
;   B+C:          0b10101011 = 0xAB
;   A+B+C:        0b10101010 = 0xAA

PSG_REG_W   EQU 0xA0
PSG_DAT_W   EQU 0xA1

; SFX RAM
SFX_A_CTR   EQU 0xC060
SFX_A_FREQ  EQU 0xC061
SFX_B_CTR   EQU 0xC062

; BGM RAM
BGM_PTR     EQU 0xC074      ; current position in the song (2 bytes)
BGM_START   EQU 0xC076      ; song start, for looping (2 bytes)
BGM_TIMER   EQU 0xC078      ; counter to the next note
BGM_ACTIVE  EQU 0xC079      ; 1 = music is playing

; =============================================================================
; INIT_SOUND
; =============================================================================
INIT_SOUND:
    LD      A, 7      : OUT (PSG_REG_W), A
    LD      A, 0xBF   : OUT (PSG_DAT_W), A
    ; Channels A, B, C silent
    LD      A, 8      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    LD      A, 9      : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    LD      A, 10     : OUT (PSG_REG_W), A
    XOR     A         : OUT (PSG_DAT_W), A
    ; SFX reset
    XOR     A
    LD      (SFX_A_CTR), A
    LD      (SFX_B_CTR), A
    ; BGM setup
    CALL    BGM_INIT
    RET

; =============================================================================
; SFX_SHOOT — channel A
; =============================================================================
SFX_SHOOT:
    LD      A, 12 : LD (SFX_A_CTR), A
    LD      A, 50 : LD (SFX_A_FREQ), A
    RET

; =============================================================================
; SFX_ENEMY_DIE — channel B
; =============================================================================
SFX_ENEMY_DIE:
    LD      A, 16 : LD (SFX_B_CTR), A
    RET

; =============================================================================
; BGM_INIT — start the background music
; =============================================================================
BGM_INIT:
    LD      HL, SONG_DATA
    LD      (BGM_START), HL
    LD      (BGM_PTR), HL
    XOR     A
    LD      (BGM_TIMER), A
    LD      A, 1
    LD      (BGM_ACTIVE), A
    RET

; =============================================================================
; BGM_UPDATE — update the background music (channel C)
; =============================================================================
BGM_UPDATE:
    LD      A, (BGM_ACTIVE)
    OR      A
    RET     Z

    ; Counter > 0 → wait
    LD      A, (BGM_TIMER)
    OR      A
    JR      Z, .next_note
    DEC     A
    LD      (BGM_TIMER), A
    RET

.next_note:
    LD      HL, (BGM_PTR)
    LD      A, (HL) : INC HL    ; duration
    LD      E, (HL) : INC HL    ; frequency fine
    LD      D, (HL) : INC HL    ; frequency coarse

    OR      A                   ; duration = 0 = command?
    JR      Z, .restart

    LD      (BGM_TIMER), A
    LD      (BGM_PTR), HL

    ; Rest? (frequency = 0)
    LD      A, E : OR D
    JR      Z, .mute

    ; SAWTOOTH BUZZER: the envelope repeats at the note frequency
    ; Envelope period = tone period / 16 → same pitch
    SRL     D : RR E
    SRL     D : RR E
    SRL     D : RR E
    SRL     D : RR E
    LD      A, 11 : OUT (PSG_REG_W), A
    LD      A, E  : OUT (PSG_DAT_W), A    ; envelope fine
    LD      A, 12 : OUT (PSG_REG_W), A
    LD      A, D  : OUT (PSG_DAT_W), A    ; envelope coarse
    ; Channel C into envelope mode (R10 bit 4 = 1)
    LD      A, 10 : OUT (PSG_REG_W), A
    LD      A, 0x10 : OUT (PSG_DAT_W), A
    ; Envelope shape: 0x08 = repeating sawtooth
    ; Also try: 0x0E = repeating triangle, 0x0C = inverted sawtooth
    LD      A, 13 : OUT (PSG_REG_W), A
    LD      A, 0x0E : OUT (PSG_DAT_W), A
    RET

.mute:
    LD      A, 10 : OUT (PSG_REG_W), A
    XOR     A     : OUT (PSG_DAT_W), A    ; channel C silent
    RET

.restart:
    LD      HL, (BGM_START)
    LD      (BGM_PTR), HL
    XOR     A
    LD      (BGM_TIMER), A
    JR      .next_note

; =============================================================================
; UPDATE_SOUND — SFX + mixer, call once per frame
; =============================================================================
UPDATE_SOUND:
    CALL    BGM_UPDATE

    ; --- Channel A: shooting ---
    LD      A, (SFX_A_CTR)
    OR      A
    JR      Z, .a_off
    DEC     A : LD (SFX_A_CTR), A
    LD      A, (SFX_A_FREQ)
    ADD     A, 12 : LD (SFX_A_FREQ), A
    LD      A, 0  : OUT (PSG_REG_W), A
    LD      A, (SFX_A_FREQ) : OUT (PSG_DAT_W), A
    LD      A, 1  : OUT (PSG_REG_W), A
    XOR     A     : OUT (PSG_DAT_W), A
    LD      A, 8  : OUT (PSG_REG_W), A
    LD      A, 13 : OUT (PSG_DAT_W), A
    JR      .b_part
.a_off:
    LD      A, 8 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A

.b_part:
    ; --- Channel B: explosion ---
    LD      A, (SFX_B_CTR)
    OR      A
    JR      Z, .b_off
    DEC     A : LD (SFX_B_CTR), A
    LD      A, 6 : OUT (PSG_REG_W), A
    LD      A, 7 : OUT (PSG_DAT_W), A
    LD      A, 9 : OUT (PSG_REG_W), A
    LD      A, (SFX_B_CTR) : OUT (PSG_DAT_W), A
    JR      .mixer
.b_off:
    LD      A, 9 : OUT (PSG_REG_W), A
    XOR     A    : OUT (PSG_DAT_W), A

.mixer:
    ; R7: combine SFX A, B and BGM C
    ; Start from silent: 0b10111111
    LD      D, 0xBF

    LD      A, (SFX_A_CTR) : OR A : JR Z, .no_a
    RES     0, D            ; A tone on (bit 0 = 0)
.no_a:
    LD      A, (SFX_B_CTR) : OR A : JR Z, .no_b
    RES     4, D            ; B noise on (bit 4 = 0)
.no_b:
    ; Buzzer mode: channel C's tone mixer stays OFF (bit 2 = 1).
    ; The sound comes purely from envelope amplitude modulation —
    ; this is the classic 'buzzer bass' technique.
    LD      A, 7 : OUT (PSG_REG_W), A
    LD      A, D : OUT (PSG_DAT_W), A
    RET

; =============================================================================
; Song data — a looping dungeon march in E minor
; Format: 3 bytes per note (duration in frames, freq_lo, freq_hi)
; Duration 0 = restart
; Frequency 0,0 = rest (mute)
;
; Notes (PSG period):
;   C3=0x0357 D3=762 (0x02FA) D#3=0x02CF  E3=679 (0x02A7)  F3=641 (0x0281)
;   G3=571 (0x023B)  A3=508 (0x01FC)  Bb3=480 (0x01E0)
;   B3=453 (0x01C5)
; CGD#DD#DD#DD#DD#
; =============================================================================
SONG_DATA:
    ; --- Phrase 1 ---
    DB 12, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 5, 0x1D, 0x01    ; G4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 10, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 12, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 12, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 12, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00

    ; --- Phrase 2 ---
    DB 12, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 5, 0x1D, 0x01    ; G4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 10, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 12, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 22, 0x7D, 0x01    ; D4
    DB 3,  0x00, 0x00
    DB 22, 0xAC, 0x01    ; C4
    DB 3,  0x00, 0x00    ; rest

    ; --- Phrase 3 ---
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0xAC, 0x01    ; C4
    DB 1,  0x00, 0x00    ; rest
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 12, 0x53, 0x01    ; E4
    DB 1,  0x00, 0x00
    DB 4, 0x68, 0x01    ; D#4
    DB 1,  0x00, 0x00
    DB 4, 0x7D, 0x01    ; D4
    DB 1,  0x00, 0x00
    DB 22, 0xAC, 0x01    ; C4
    DB 4,  0x00, 0x00    ; rest


    ; --- Loop ---
    DB 0, 0, 0
