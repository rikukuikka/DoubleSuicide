# Wizard of Wor — MSX1 Assembly

Wizard of Wor -kloonin MSX1 assembler-toteutus.

## Tiedostorakenne

```
src/
  main.asm      — ROM-header ja pääsilmukka
  vdp.asm       — TMS9918A apurutiinit
  patterns.asm  — Ruututyyppien patternit ja värit
  maze.asm      — Labyrinttidata ja piirtorutiinit
build/
  wow.rom       — Käännetty ROM (generoituu make-komennolla)
```

## Kehitysympäristö

### Tarvittavat ohjelmat

1. **sjasmplus** — assembler
   - https://github.com/z00m128/sjasmplus
   - Linux: `git clone && make && sudo make install`
   - Windows: lataa binary GitHubista

2. **openMSX** — emulaattori
   - https://openmsx.org/
   - Linux: `sudo apt install openmsx`
   - Windows/Mac: installer sivustolta

3. **C-BIOS** — ilmainen MSX BIOS
   - https://cbios.sourceforge.net/
   - tai openMSX lataa sen automaattisesti

### Kääntäminen

```bash
make
```

### Ajaminen emulaattorissa

```bash
make run
```

### Manuaalinen ajo

```bash
sjasmplus --raw=build/wow.rom src/main.asm
openmsx -machine C-BIOS_MSX1 -cart build/wow.rom
```

## Tekninen toteutus

### VDP Screen 2 -moodi
- 256×192 pikseliä
- 32×24 ruudukkoa (8×8 pikseliä/ruutu)
- Jokaisella 8 rivillä oma värimääritys
- Pattern Table: 0x0000 (3 x 256 x 8 tavua)
- Name Table:    0x1800 (32 x 24 = 768 tavua)
- Color Table:   0x2000 (3 x 256 x 8 tavua)

### Labyrintti
- 32×24 ruudukkoa
- Vasen ja oikea reuna auki riveillä 10–13 (viholliset tulevat sisään)
- `GET_MAZE_TILE` — hae ruudun tyyppi koordinaateilla

## Seuraavat askeleet

- [ ] Pelaajan sprite ja liikkuminen
- [ ] Näppäimistön luku (PSG I/O portit)
- [ ] Törmäystarkistus labyrinttiin
- [ ] Viholliset ja tekoäly
- [ ] Ääniefektit (PSG AY-3-8910)
- [ ] Pisteet ja HUD
- [ ] Kaksinpeli
