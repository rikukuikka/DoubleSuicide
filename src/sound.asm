; =============================================================================
; sound.asm — music and sound effects through the Arkos Tracker 2 AKG player
; =============================================================================
;
; The player (src/arkos/PlayerAkg.asm, converted from the original RASM source
; by tools/rasm2sjasm.py) is assembled as a ROM player: no self-modifying
; code, all of its variables live in a RAM buffer at ARKOS_BUFFER.
;
; UPDATE_SOUND is called once per logic tick (GAME_TICK, title screen), i.e.
; at 60 Hz on both NTSC and PAL thanks to GAME_TICK_COUNT, so songs must be
; made for a 60 Hz replay rate.
;
; Channels: the music may use all three; a sound effect replaces the music on
; its channel while it plays. SFX_SHOOT plays on channel A, SFX_ENEMY_DIE on
; channel B; the current song only uses channel C.
;
; R7: PLY_AKG_HARDWARE_MSX makes the player keep R7 bit 7 = 1 (port B
; output) and bit 6 = 0 (port A input, joystick) — see README gotcha 6.
;
; The player uses the stack pointer to read data and the alternate registers,
; so it must run with interrupts disabled (the game never enables them).
; PLY_AKG_Play clobbers every register, including IX, IY and the shadow set.

; Effect numbers in music/sfx.asm (the first one is 1)
SFX_NUM_SHOOT       EQU 1
SFX_NUM_EXPLOSION   EQU 2

; =============================================================================
; INIT_SOUND — silence the PSG, start the music from the beginning
; =============================================================================
INIT_SOUND:
    LD      A, 7      : OUT (PSG_REG), A
    LD      A, 0xBF   : OUT (PSG_REG15), A
    ; Channels A, B, C silent
    LD      A, 8      : OUT (PSG_REG), A
    XOR     A         : OUT (PSG_REG15), A
    LD      A, 9      : OUT (PSG_REG), A
    XOR     A         : OUT (PSG_REG15), A
    LD      A, 10     : OUT (PSG_REG), A
    XOR     A         : OUT (PSG_REG15), A

    LD      HL, Music_Start
    XOR     A                     ; subsong 0
    CALL    PLY_AKG_Init
    LD      HL, SoundEffects
    CALL    PLY_AKG_InitSoundEffects
    LD      A, 1 : LD (MUSIC_ON), A
    RET

; =============================================================================
; STOP_SOUND — silence everything; UPDATE_SOUND does nothing until INIT_SOUND
; =============================================================================
STOP_SOUND:
    XOR     A : LD (MUSIC_ON), A
    JP      PLY_AKG_Stop          ; all volumes 0, R7 = 0xBF

; =============================================================================
; SFX_SHOOT — channel A
; Preserves BC, DE, HL (called from inside the callers' loops).
; =============================================================================
SFX_SHOOT:
    PUSH    BC : PUSH DE : PUSH HL
    LD      A, SFX_NUM_SHOOT
    LD      C, 0                  ; channel A
    JR      SFX_PLAY

; =============================================================================
; SFX_ENEMY_DIE — channel B (also used for the player's death)
; Preserves BC, DE, HL (called from inside the callers' loops).
; =============================================================================
SFX_ENEMY_DIE:
    PUSH    BC : PUSH DE : PUSH HL
    LD      A, SFX_NUM_EXPLOSION
    LD      C, 1                  ; channel B
SFX_PLAY:
    LD      B, 0                  ; inverted volume: 0 = full
    CALL    PLY_AKG_PlaySoundEffect   ; clobbers AF, AF', BC, DE, HL
    POP     HL : POP DE : POP BC
    RET

; =============================================================================
; UPDATE_SOUND — play one 60 Hz tick of music + sound effects
; =============================================================================
UPDATE_SOUND:
    LD      A, (MUSIC_ON)
    OR      A
    RET     Z
    JP      PLY_AKG_Play

; =============================================================================
; The player, the music and the sound effects. The Player Configuration files
; must come BEFORE the player: they leave out the code the songs don't need.
; =============================================================================
    INCLUDE "src/music/song_playerconfig.asm"
    INCLUDE "src/music/sfx_playerconfig.asm"

PLY_AKG_HARDWARE_MSX = 1          ; PSG at ports 0xA0/0xA1, R7 bits 7/6 kept as 1/0
PLY_AKG_Rom = 1                   ; no self-modifying code, variables in RAM
PLY_AKG_ROM_Buffer = ARKOS_BUFFER
PLY_AKG_MANAGE_SOUND_EFFECTS = 1
    INCLUDE "src/arkos/PlayerAkg.asm"
    ASSERT PLY_AKG_ROM_BufferSize <= ARKOS_BUFFER_SIZE

; The song (Music_Start) and the effects (SoundEffects) are included by
; main.asm, in page 2.
