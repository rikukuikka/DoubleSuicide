; Sound effects for Double Suicide, Arkos Tracker 2 sound effect format (AKG
; player, PLY_AKG_MANAGE_SOUND_EFFECTS). Transcribed from the old hand-written
; effects; each cell lasts one 60 Hz tick (speed 0).
; Replace with sound effects exported from Arkos Tracker, keeping the
; SoundEffects label and the effect numbers SFX_NUM_* in sound.asm.

; The sound effects, starting at 1.
SoundEffects:
    dw SoundEffects_Shoot          ; Sound effect 1 (SFX_NUM_SHOOT).
    dw SoundEffects_Explosion      ; Sound effect 2 (SFX_NUM_EXPLOSION).

; Sound effect 1: shot. Tone, volume 13, period rising 62 -> 182 (pitch falls).
SoundEffects_Shoot:
    db 0                           ; Speed.
    db 53                          ; Soft only. Volume: 13.
    dw 62                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 74                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 86                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 98                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 110                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 122                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 134                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 146                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 158                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 170                         ; Software period.
    db 53                          ; Soft only. Volume: 13.
    dw 182                         ; Software period.
    db 4                           ; End of the sound effect.

; Sound effect 2: explosion / death. Noise period 7, volume fading 15 -> 1.
SoundEffects_Explosion:
    db 0                           ; Speed.
    db 248                         ; No Soft no Hard. Volume: 15. Noise.
    db 7                           ; Noise: 7.
    db 240                         ; No Soft no Hard. Volume: 14. Noise.
    db 7                           ; Noise: 7.
    db 232                         ; No Soft no Hard. Volume: 13. Noise.
    db 7                           ; Noise: 7.
    db 224                         ; No Soft no Hard. Volume: 12. Noise.
    db 7                           ; Noise: 7.
    db 216                         ; No Soft no Hard. Volume: 11. Noise.
    db 7                           ; Noise: 7.
    db 208                         ; No Soft no Hard. Volume: 10. Noise.
    db 7                           ; Noise: 7.
    db 200                         ; No Soft no Hard. Volume: 9. Noise.
    db 7                           ; Noise: 7.
    db 192                         ; No Soft no Hard. Volume: 8. Noise.
    db 7                           ; Noise: 7.
    db 184                         ; No Soft no Hard. Volume: 7. Noise.
    db 7                           ; Noise: 7.
    db 176                         ; No Soft no Hard. Volume: 6. Noise.
    db 7                           ; Noise: 7.
    db 168                         ; No Soft no Hard. Volume: 5. Noise.
    db 7                           ; Noise: 7.
    db 160                         ; No Soft no Hard. Volume: 4. Noise.
    db 7                           ; Noise: 7.
    db 152                         ; No Soft no Hard. Volume: 3. Noise.
    db 7                           ; Noise: 7.
    db 144                         ; No Soft no Hard. Volume: 2. Noise.
    db 7                           ; Noise: 7.
    db 136                         ; No Soft no Hard. Volume: 1. Noise.
    db 7                           ; Noise: 7.
    db 4                           ; End of the sound effect.
