; Background music for Double Suicide, AKG (Arkos Tracker 2 "generic") format.
; The original sawtooth/triangle-buzzer march, transcribed note for note from the
; old hand-written player: one line = one 60 Hz tick (speed 1), the tune plays
; on channel 3 (PSG channel C) only, so channels A and B stay free for the
; sound effects.
; Replace this file with a song exported from Arkos Tracker (AKG format, see
; README "Music and sound effects"), keeping the Music_Start label.

Music_Start:
    db "AT20"
    dw Music_ArpeggioTable      ; The address of the Arpeggio table.
    dw Music_PitchTable         ; The address of the Pitch table.
    dw Music_InstrumentTable    ; The address of the Instrument table.
    dw Music_EffectBlockTable   ; The address of the Effect Block table.

; The addresses of each Subsong:
    dw Music_Subsong0_Start

Music_ArpeggioTable:
Music_PitchTable:

Music_InstrumentTable:
    dw Music_EmptyInstrument
    dw Music_Instrument1

Music_EmptyInstrument:
    db 0                        ; The speed (>0, 0 for 256).
Music_EmptyInstrument_Loop:
    db 0                        ; No Soft no Hard. Volume: 0. Noise? false.
    db 6                        ; Loop to silence.

; Instrument 1: "buzzer". Hardware envelope only (tone and noise off, R13 = 14,
; repeating triangle), retriggered on every note. The hardware arpeggio of +48
; (4 octaves) makes the envelope period the note's tone period / 16, exactly
; what the old player wrote to R11/R12, so the track notes are the real notes.
Music_Instrument1:
    db 1                        ; The speed (>0, 0 for 256).
    db %01101011                ; Hard only. Envelope: 14. Retrig. Not simple.
    db %01000000                ; Hardware arpeggio, no noise.
    db 48                       ; Hardware arpeggio: +48.
Music_Instrument1_Loop:
    db %01100011                ; Hard only. Envelope: 14. Not simple.
    db %01000000                ; Hardware arpeggio, no noise.
    db 48                       ; Hardware arpeggio: +48.
    db 7                        ; Loop.
    dw Music_Instrument1_Loop

Music_EffectBlockTable:

; Subsong 0
; ----------------------
Music_Subsong0_Start:
    db 2                        ; ReplayFrequency (unused by the player: Play is called at 60 Hz).
    db 0                        ; Digichannel (0-2).
    db 1                        ; PSG count (>0).
    db 0                        ; Loop start index (>=0).
    db 3                        ; End index (>=0).
    db 1                        ; Initial speed (>=0): one line per tick.
    db 48                       ; Base note index (>=0).

Music_Subsong0_Linker:
Music_Subsong0_Linker_Loop:
; Position 0
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_Track0
    dw Music_Subsong0_LinkerBlock0
; Position 1
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_Track1
    dw Music_Subsong0_LinkerBlock1
; Position 2
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_Track2
    dw Music_Subsong0_LinkerBlock2
; Position 3
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_TrackEmpty
    dw Music_Subsong0_Track3
    dw Music_Subsong0_LinkerBlock3

    dw 0                        ; Loop.
    dw Music_Subsong0_Linker_Loop

Music_Subsong0_LinkerBlock0:
    db 116                       ; Height.
    db 0                        ; Transposition 0.
    db 0                        ; Transposition 1.
    db 0                        ; Transposition 2.
    dw Music_Subsong0_SpeedTrack0   ; SpeedTrack address.
    dw Music_Subsong0_EventTrack0   ; EventTrack address.

Music_Subsong0_LinkerBlock1:
    db 126                       ; Height.
    db 0                        ; Transposition 0.
    db 0                        ; Transposition 1.
    db 0                        ; Transposition 2.
    dw Music_Subsong0_SpeedTrack0   ; SpeedTrack address.
    dw Music_Subsong0_EventTrack0   ; EventTrack address.

Music_Subsong0_LinkerBlock2:
    db 126                       ; Height.
    db 0                        ; Transposition 0.
    db 0                        ; Transposition 1.
    db 0                        ; Transposition 2.
    dw Music_Subsong0_SpeedTrack0   ; SpeedTrack address.
    dw Music_Subsong0_EventTrack0   ; EventTrack address.

Music_Subsong0_LinkerBlock3:
    db 85                       ; Height.
    db 0                        ; Transposition 0.
    db 0                        ; Transposition 1.
    db 0                        ; Transposition 2.
    dw Music_Subsong0_SpeedTrack0   ; SpeedTrack address.
    dw Music_Subsong0_EventTrack0   ; EventTrack address.

Music_Subsong0_TrackEmpty:
    db 61, 127                  ; Waits for 128 lines.

Music_Subsong0_Track0:
    db 128, 1                 ; C4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 135, 1                 ; G4, instrument 1.
    db 254                      ; Waits for 5 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 61, 9                   ; Waits for 10 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.

Music_Subsong0_Track1:
    db 128, 1                 ; C4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 135, 1                 ; G4, instrument 1.
    db 254                      ; Waits for 5 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 61, 9                   ; Waits for 10 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 61, 21                   ; Waits for 22 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 126                      ; Waits for 3 lines.
    db 128, 1                 ; C4, instrument 1.
    db 61, 21                   ; Waits for 22 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 126                      ; Waits for 3 lines.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.

Music_Subsong0_Track2:
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.

Music_Subsong0_Track3:
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 132, 1                 ; E4, instrument 1.
    db 61, 11                   ; Waits for 12 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 131, 1                 ; D#4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 130, 1                 ; D4, instrument 1.
    db 190                      ; Waits for 4 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 60                       ; Waits for 1 line.
    db 128, 1                 ; C4, instrument 1.
    db 61, 21                   ; Waits for 22 lines.
    db 128, 0                 ; Rest (instrument 0).
    db 190                      ; Waits for 4 lines.

; The speed tracks
Music_Subsong0_SpeedTrack0:
    db 255                      ; Wait for 128 lines.

; The event tracks
Music_Subsong0_EventTrack0:
    db 255                      ; Wait for 128 lines.
