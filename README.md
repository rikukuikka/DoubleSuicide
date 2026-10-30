# Double Suicide — MSX1

A Wizard of Wor clone for MSX1 in Z80 assembly.

## Building

```bash
sjasmplus --raw=build/DoubleSuicide.rom src/main.asm
```

## Running

```bash
openmsx -machine C-BIOS_MSX1 -cart build/DoubleSuicide.rom -joytype1 keys
```

## Controls

| Action | P1 (keyboard) | P1 (joystick 1) | P2 (joystick 2) |
|----------|------------------|-----------------|-----------------|
| Up     | up arrow       | up            | up            |
| Down     | down arrow      | down            | down            |
| Left    | left arrow      | left           | left            |
| Right    | right arrow      | right            | right            |
| Fire     | space       | fire            | fire            |

## Implemented features

- **Title screen** — its own logo, 1P / 2P selection with a cursor, Commando font
- **16x16 sprites** — 2-frame walking animation in four directions, stops when the player stands still
- **Wide corridors** — the maze is designed with 16px-wide corridors for 16x16 sprites
- **Two players** — P1 keyboard + joystick 1, P2 joystick 2; single- and two-player modes
- **Collision detection** — pixel-accurate wall collision for the 16x16 sprite area (4 corner points)
- **Snap-to-grid** — automatic alignment to the 8px grid when turning at a junction
- **Portals** — openings on the left and right edges teleport to the opposite side
- **Robot enemies** — 4-directional sprites, random-direction AI (25% chance to consider turning at a junction, otherwise keeps going straight), avoids turning back; base movement speed set by the round system
- **Tank enemy** — chases the nearest living player (dx/dy comparison for direction choice), fires in both directions when on the same row/column along its movement axis
- **Ghost enemy** — chases the player like the tank but at twice the Robot/Tank base speed, never fires; **only visible when a living player is on the same row or column** (otherwise hidden), 2-frame walking animation
- **Wizard boss** — appears every 6th level (the boss row in `WAVE_TABLE`) in place of the normal enemy mix; a two-layer 16x16 sprite (color 9 highlight drawn over a color 13 body), wanders like the Robot, teleports to a random NAVMAP point roughly every 3 seconds, and fires its own bullet at whichever player is in line. Defeating it starts a new, faster round and resets the level counter back to 1
- **Round/difficulty system** — every time the Wizard is defeated, a round counter advances and all enemy/bullet speeds are recalculated from one tunable table (`BASE_X2_TABLE` in `enemy.asm`): round 1 starts at half a pixel/frame, round 2 at 1px/frame, round 3+ caps at 2px/frame. The Ghost and Wizard always move at twice the Robot/Tank speed. Fractional speeds are handled with a half-pixel accumulator (`GET_MOVE_DELTA`) so all positions stay whole-pixel
- **Enemy shooting** — the Robot/Tank/Wizard fire when in line with a player (50% probability per roll), only in the direction they're moving toward; each roll (hit or miss) starts a 10-frame cooldown before the enemy can roll again, so they don't fire nonstop; odd-indexed enemies fire at P1, even-indexed at P2 (all fire at P1 in single-player mode; the Wizard always prefers P1 if alive)
- **Hitboxes** — tuned smaller than the 16x16 sprite for fairer collisions: bullets are treated as a 4x4 box and players/enemies as a 6x6 box, both centered on the sprite
- **NAVMAP-based spawning** — enemies spawn at precomputed junction points (no more roll-and-check-for-a-wall), at least 50px from players and 16px from each other; 64 attempts + a guaranteed-to-work NAVMAP scan as a fallback
- **WAVE_TABLE** — each level's enemy counts (robots/tanks/ghosts) or the boss flag are defined in one easily editable table in `enemy.asm`; the last row repeats for all later non-boss levels
- **Radar** — a 32x24px area in the middle of the HUD, where each playfield tile maps to one pixel; enemy positions shown as sprites in the color matching their type (Robot yellow, Tank cyan, Ghost white, Wizard magenta — shown on the radar even while hidden on the field), a blue border made of fixed nametable tiles
- **Bullets** — one bullet per player, wall check at the center point, kills any enemy including the Wizard
- **Enemy bullets** — speed derives from the current round (Robot/Tank bullets match the round's base-x2 value, the Wizard's are one step faster), don't cross into the HUD area
- **Explosions** — 2-frame animation when an enemy is destroyed
- **Music and sound effects** — Arkos Tracker 3 AKG player (ROM version, converted to sjasmplus), played at 60 Hz on both PAL and NTSC; the current song is the original buzzer march on channel C, the shot effect plays on channel A and the explosion/death effect on channel B (see [Music and sound effects](#music-and-sound-effects))
- **Player death** — enemy touch or a bullet kills, blinking animation, respawns at the starting position
- **3 lives** per player, the game ends when lives = 0
- **Game over screen** — a 144x52 px image loaded into bank 1, shown once all players have died; releasing the fire button returns to the title screen
- **Wave system** — a new wave spawns once all enemies are destroyed, with a 1.5s delay in between
- **HUD** — score (BCD, 100 per kill), lives, color-coded player icons and the radar on the bottom row

## File structure

| File        | Contents                                                       |
|-----------------|---------------------------------------------------------------|
| `main.asm`      | ROM header, INIT, ENABLE_PAGE2, MAINLOOP, WAIT_VBLANK, wave logic |
| `constants.asm` | EQU constants, RAM addresses (0xC000+)                           |
| `vdp.asm`       | VDP helper routines, Screen 2 init (16x16 sprite mode)           |
| `maze.asm`      | Level data (wide corridors), IS_WALL, DRAW_MAZE, INIT_NAVMAP |
| `input.asm`     | Keyboard and joystick reading (PSG R14/R15)                   |
| `player.asm`    | 16x16 sprites, animation, movement, portals, death      |
| `enemy.asm`     | Robot/Tank/Ghost AI, shooting, round/speed system, LFSR random numbers, NAVMAP spawning, WAVE_TABLE, radar drawing, explosions |
| `bullet.asm`    | Player bullets, collision with enemies, scoring              |
| `boss.asm`      | Wizard boss: sprites, movement, teleport, shooting, its own bullet |
| `sound.asm`     | Sound interface (INIT_SOUND, UPDATE_SOUND, SFX_*, STOP_SOUND), includes the Arkos player (the song and effects are included by `main.asm`, in page 2) |
| `hud.asm`       | Digit tiles, score, lives display, radar border tiles         |
| `title.asm`     | Title screen, logo, 1P/2P selection                             |
| `gameover.asm`  | Game over screen, CHECK_GAME_OVER, image tile data (bank 1)     |
| `arkos/`        | Arkos Tracker 3 AKG player + sound effect player, **generated** by `make arkos` from `third_party/arkos/` — don't edit |
| `music/`        | `song.asm` (AKG song), `sfx.asm` (sound effects) and their Player Configuration files |

Outside `src/`: `third_party/arkos/` holds the original (RASM syntax) player
sources from the [Arkos Tracker 3 repository](https://bitbucket.org/JulienNevo/arkostracker3)
(`hardware/cpc/playerAkg/sources`, MIT license), and `tools/rasm2sjasm.py`
converts them (and exported Player Configuration files) to sjasmplus syntax.

## Music and sound effects

Music and effects are played by the Arkos Tracker 3 "AKG" (generic) player,
built as a **ROM player** (`PLY_AKG_Rom`: no self-modifying code, variables
in `ARKOS_BUFFER`) for MSX (`PLY_AKG_HARDWARE_MSX`: PSG ports 0xA0/0xA1, R7
bit 7 = 1 and bit 6 = 0 are kept so the joysticks keep working), with sound
effects enabled. `UPDATE_SOUND` calls `PLY_AKG_Play` once per logic tick,
which is 60 Hz on both NTSC and PAL (`GAME_TICK_COUNT`).

The player runs with interrupts disabled (it reads data through SP), which the
game already does. It clobbers every register, so `UPDATE_SOUND` is only
called between the other updates; the `SFX_*` wrappers preserve BC, DE and HL
because they're called from inside the game's loops.

### Replacing the song

1. In Arkos Tracker, set the song's replay rate to **60 Hz** (one `Play` per
   tick; at 50 Hz it would play 20 % too fast).
2. **File > Export > Export to AKG (generic)** (not AKM/AKY: the game uses
   the AKG player), with these settings:
   - Export as: **Source** (not Binary), *Export to several files* off.
   - **Generate a configuration file for players (as source)**: on.
   - Source profile: **Z80** (the exported song assembles in sjasmplus as-is).
   - Source labels prefix: **`Music_`**, so the song starts with the
     `Music_Start` label that `INIT_SOUND` uses.
   - *Encode to address*: off (sjasmplus places the data).
   - Sample export: irrelevant, the PSG doesn't play samples.
3. Replace `src/music/song.asm` with the exported song, and convert the
   exported player configuration (its `PLY_CFG_... = 1` lines are indented,
   which sjasmplus doesn't accept) over the old one:
   ```bash
   python3 tools/rasm2sjasm.py MySong_playerconfig.asm src/music/song_playerconfig.asm
   ```
   Without a configuration file the player still works, it's just bigger and
   slower (the full player is ~3.5 KB and takes up to ~1000 instructions per
   tick on busy songs; configured for the current song it is ~1.6 KB and
   ~430 instructions).
4. `make`, and check the `ROM end / free` line. The song and the effects are
   placed in page 2 (from 0x8000), after the code.

The music may use all three channels; a sound effect overrides the music on
its channel while it plays.

### Replacing the sound effects

1. In Arkos Tracker each sound effect is an instrument. **File > Export >
   Export sound effects (AKX)** lists them with an *Exported?* checkbox and
   the *Output index* each one gets. The game plays these indexes
   (`SFX_NUM_*` in `sound.asm`):

   | Output index | Effect | Played by | Channel |
   |---|---|---|---|
   | 01 | Shot (`SFX_NUM_SHOOT`) | `SFX_SHOOT` | A |
   | 02 | Explosion / death (`SFX_NUM_EXPLOSION`) | `SFX_ENEMY_DIE` | B |

   **Export at least two effects**: the player doesn't check the index, so
   playing an effect missing from the table reads garbage (wrong sound or a
   crash). The *Found note* column is the note the effect is exported at.
2. Same settings as for the song: **Source**, **Generate a configuration
   file for players** on, profile **Z80**, *Encode to address* off. Leave the
   labels prefix empty or use `SoundEffects`, then check that the table at the
   top of the exported file is labelled exactly `SoundEffects` (rename it if
   not): `INIT_SOUND` uses that label.
3. Replace `src/music/sfx.asm` with the exported file and convert its player
   configuration:
   ```bash
   python3 tools/rasm2sjasm.py MyEffects_playerconfig.asm src/music/sfx_playerconfig.asm
   ```
4. `make`. To add more effects, give them a new `SFX_NUM_*` and a wrapper
   like `SFX_SHOOT` in `sound.asm` (choose the channel in C: 0 = A, 1 = B,
   2 = C).

### Updating the player

Copy `PlayerAkg.asm` and `PlayerAkg_SoundEffects.asm` from the Arkos Tracker
sources (`hardware/cpc/playerAkg/sources`) to `third_party/arkos/` and run
`make arkos` to regenerate `src/arkos/`.

## Technical details

### Sprite pattern layout (VRAM 0x3800+)

The VDP is in 16x16 sprite mode (R#1 SIZE bit) — **every sprite always
reserves 4 consecutive pattern numbers** (32 bytes), even if only one
8x8 quadrant is actually drawn. All the pattern bases below are
therefore multiples of 4.

| Pattern # | Contents                              |
|-----------|---------------------------------------|
| 0-31      | Player: 4 directions x 2 frames         |
| 32-47     | Robot: right(32) / left(36) / down(40) / up(44) |
| 48-51     | Horizontal bullet (right/left, `BULLET_DIR_PAT` — also used for enemy bullets) |
| 52-55     | Vertical bullet (up/down, `BULLET_DIR_PAT`)         |
| 56-59     | Explosion frame 1                      |
| 60-63     | Explosion frame 2                      |
| 64-71     | Tank: horizontal(64) / vertical(68)         |
| 72-75     | Radar dot (only quadrant 72 in use, the rest blank due to the reservation) |
| 76-107    | Ghost: 4 directions x 2 frames (`GHOST_DIR_PAT` table in `enemy.asm`) |
| 108-171   | Wizard: 16 groups (4 directions x 2 frames x 2 color layers) (`WIZARD_DIR_PAT` table in `boss.asm`) |

### Sprite attribute table (32 sprites, VRAM 0x1B00+)

| Sprite # | Contents                        |
|----------|--------------------------------|
| 0-1      | Players (P1, P2)              |
| 2-7      | Enemies (Robot/Tank/Ghost/Wizard slot, ENEMIES table) — the Wizard itself is drawn separately via 26-28 |
| 8-9      | Player bullets              |
| 10-11    | Explosions                    |
| 12-17    | Enemy bullets           |
| 18-19    | Tank bullets            |
| 20-25    | Radar dots (1 per ENEMIES slot) |
| 26-28    | Wizard: front layer + back layer + its own bullet |
| 29-31    | Free                        |

### RAM map (0xC000+)

| Address        | Constant            | Use                                |
|---------------|------------------|---------------------------------------|
| C000-C005     | P1_X … P2_DIR    | Player X, Y, direction                |
| C006-C007     | P1_INPUT, P2_INPUT | Input state per frame            |
| C008-C00B     | P1_LIVES … P2_DEAD_TMR | Lives and death timers       |
| C00C          | GAME_MODE        | 1 = single player, 2 = two players         |
| C00D          | FRAME_CTR        | Frame counter for animations           |
| C00E          | LEVEL            | Level number (1+)                    |
| C00F          | WAVE_TIMER       | Delay between waves                |
| C010-C03F     | ENEMIES          | 6 enemies x 8 bytes (Robot/Tank/Ghost/Wizard, type in IX+3, speed in IX+5, shoot cooldown in IX+7) |
| C040-C041     | RAND_SEED        | 16-bit LFSR seed                    |
| C050-C05F     | BULLETS          | 2 player bullets x 8 bytes         |
| C060          | MUSIC_ON         | 1 = UPDATE_SOUND plays the Arkos player, 0 = stopped (game over) |
| C061-C062     | —                | Free (old sound effect counters)       |
| C070-C073     | P1_SCORE_H … P2_SCORE_L | Player scores (BCD)            |
| C074-C079     | —                | Free (old background music state)     |
| C07A-C07F     | EXPLOSIONS       | 2 explosions x 3 bytes               |
| C080          | HUD_DIRTY        | 1 = DRAW_HUD must run             |
| C081-C098     | ENEMY_BULLETS    | 6 enemy bullets x 4 bytes       |
| C099-C0A0     | TANK_BULLETS     | 2 tank bullets x 4 bytes            |
| C0A1          | BOSS_ACTIVE      | 1 = the Wizard's boss level is running |
| C0A2-C0A5     | WIZARD_BULLET    | X, Y, direction, active                |
| C0A6          | WIZARD_TELEPORT_TIMER | Frames left until the next teleport |
| C0A7          | ROUND            | Round number (1, 2, 3…), drives the speed table |
| C0A8-C0AC     | CUR_RT_SPEED_X2 … CUR_WIZARD_BULLET_SPEED | Current round's speeds, recomputed by `APPLY_ROUND_SPEEDS` |
| C0AD          | MOVE_DELTA       | This frame's pixel count, from the half-pixel accumulator |
| C0AE          | TITLE_SEL        | Title screen mode selection (0=1P, 1=2P), used only before GAME_MODE is set |
| C0AF-C0B0     | PAL_ACTIVE, PAL_TICK_ACC | PAL detection and the extra-tick accumulator |
| C100-C3FF     | NAVMAP           | Junction point direction bitmap (768 bytes) |
| C400-C5FF     | ARKOS_BUFFER     | Arkos ROM player variables (`PLY_AKG_ROM_Buffer`); the current song uses 126 bytes, the full player with sound effects at most 273; `sound.asm` ASSERTs it fits |

### MSX/TMS9918A gotchas learned along the way

1. **ROM is write-protected** — all mutable data lives at EQU addresses in RAM (0xC000+)
2. **Sprite Y=0xD0 is a stop marker** — it hides all later sprites, use 0xD8
3. **Sprite Y offset** — the TMS9918A draws a sprite 1px lower than the attribute table's Y value
4. **16x16 sprites** — VDP R#1 bit 1, pattern numbers are multiples of 4, 32 bytes/pattern
5. **IS_WALL clobbers registers** — PUSH/POP for all of them (HL, DE, BC)
6. **PSG R7 bit 6 = 0** — port A input (joystick), base value 0xBF
7. **C-BIOS interferes with the PSG** — DI + polling the VDP status instead of HALT
8. **DJNZ max 128 bytes** — use DEC B / JP NZ in long loops
9. **16x16 collision detection** — all 4 corners (+15, not +7), center point (+8) for the bullet
10. **VDP writes right after vblank** — all DRAW_* calls at the start of MAINLOOP before any updates; otherwise writes can land during active scanning and corrupt the picture
11. **16x16 mode ALWAYS reserves 4 patterns per sprite** — even for a single quadrant "dot"; if the next loaded sprite starts at the wrong (non-4-aligned) offset, its data leaks into the previous sprite's invisible quadrants and shows up on top of them
12. **Don't touch a DJNZ loop's counter register from a subroutine** — if a loop keeps its counter in B (or a constant value in DE, e.g. an `ADD IX,DE` step), any subroutine called from inside the loop that uses the same register as scratch without PUSH/POP will scramble the loop — DJNZ repeats the wrong number of times and a pointer (e.g. IX) runs off the end of the array. Use C or another register verified to be free
13. **Z80 has no direct 16-bit-address arithmetic** — `SUB (nn)` / `ADD A,(nn)` don't exist (only `LD A,(nn)` does); sjasmplus silently accepts the syntax and truncates the address into an 8-bit immediate instead of erroring. Load the value into `A` via `LD A,(nn)` first, move it to a scratch register, then use that register in the arithmetic op
14. **LFSR correctness needs care** — combining the feedback bit with `OR` without clearing the target bit first silently collapses the period (22 states instead of the theoretical 65535), and even a mathematically correct maximal-length LFSR produces strongly correlated *adjacent* outputs, so two back-to-back rolls (e.g. spawn column then row) only cover a small fraction of combinations. Advancing a full byte per `RAND` call instead of one bit fixes both the period and the correlation
15. **A 32 KB cartridge must select its own slot for page 2** — the ROM spans 0x4000-0xBFFF, but the BIOS only selects the cartridge's slot for page 1 (0x4000-0x7FFF); page 2 still shows RAM until `ENABLE_PAGE2` (first thing in INIT) copies page 1's primary/secondary slot to page 2 via `RSLREG`/`EXPTBL`/`SLTTBL`/`ENASLT`. Everything INIT runs before that, and ENABLE_PAGE2 itself, must stay in page 1 (an ASSERT checks it)
16. **sjasmplus is not RASM** — the Arkos sources rely on RASM features: `IFDEF` testing symbols set with `name = 1` (sjasmplus `IFDEF` only sees `DEFINE`s; use `IF exist name`), indented `name = value` (sjasmplus wants it in column 0), macros/REPEAT with `{param}` in label names, case-insensitive labels, trailing commas in `dw` lists. `tools/rasm2sjasm.py` handles all of these

### Tools

- **Assembler:** sjasmplus v1.20.3
- **Emulator:** openMSX 20.0 + C-BIOS MSX1
- **BIOS:** C-BIOS (MSX BIOS replacement)
- **Music:** Arkos Tracker 3 (AKG player)

## TODO

- [x] Add enemy types — Tank, Ghost, and the Wizard boss all added
- [x] Enemy speed increase across levels — a round system now scales Robot/Tank/Ghost/Wizard and bullet speeds after each Wizard kill
- [ ] More level layouts
