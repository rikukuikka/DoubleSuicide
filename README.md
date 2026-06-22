# Wizard of Wor — MSX1

Wizard of Wor -klooni MSX1:lle Z80-assemblyllä.

## Rakentaminen

```bash
sjasmplus --raw=build/wow.rom src/main.asm
```

## Ajaminen

```bash
openmsx -machine C-BIOS_MSX1 -cart build/wow.rom -joytype1 keys
```

## Ohjaus

| Toiminto | P1 (näppäimistö) | P1 (joystick 1) | P2 (joystick 2) |
|----------|------------------|-----------------|-----------------|
| Ylös     | nuoli ylös       | ylös            | ylös            |
| Alas     | nuoli alas       | alas            | alas            |
| Vasen    | nuoli vasen      | vasen           | vasen           |
| Oikea    | nuoli oikea      | oikea           | oikea           |
| Ammu     | välilyönti       | tuli            | tuli            |

## Toteutetut ominaisuudet

- **Labyrintti** — Screen 2 (TMS9918A), 32×24 tiilikartta sinisillä seinillä
- **Kaksi pelaajaa** — P1 näppäimistö + joystick 1, P2 joystick 2
- **Törmäystarkistus** — pikselitarkka seinäkolliisio kahdella kulmapisteellä
- **Snap-to-grid** — automaattinen kohdistus 8px-ruudukkoon risteyksessä käännettäessä (4px toleranssi)
- **Portaalit** — vasemman ja oikean reunan aukot teleporttaavat pelaajan toiselle puolelle
- **Worrit-viholliset** — 3 kpl, satunnaissuuntainen AI (16-bit LFSR), vaihtaa suuntaa seinään törmätessä
- **Ammukset** — yksi ammus per pelaaja, liikkuu 4px/frame, tappaa Worritin osumalla
- **PSG-ääniefektit** — ammuksen ääni (kanava A, laskeva sävel) ja räjähdys (kanava B, kohina)
- **Pelaajan kuolema** — Worritin kosketus tappaa, 1s vilkkumisanimaatio, respawn aloituspaikassa
- **3 elämää** per pelaaja, peli loppuu kun elämät = 0
- **HUD** — pisteet (BCD, 100 per tappo) ja elämät alareunan rivillä, värikoodatut pelaajaikonit

## Tiedostorakenne

| Tiedosto       | Sisältö                                      |
|----------------|----------------------------------------------|
| `main.asm`     | ROM-header, INIT, MAINLOOP, WAIT_VBLANK      |
| `constants.asm`| EQU-vakiot, RAM-osoitteet (0xC000+)           |
| `vdp.asm`      | VDP-apurutiinit (SETW, FILL, Screen 2 init)  |
| `maze.asm`     | Kenttädata, IS_WALL, DRAW_MAZE, FIND_PORTALS |
| `input.asm`    | Näppäimistö- ja joystick-luku (PSG R14/R15)   |
| `player.asm`   | Sprite-data, liikkuminen, portaalit, kuolema  |
| `enemy.asm`    | Worrit AI, LFSR-satunnaisluku, spawn          |
| `bullet.asm`   | Ammukset, törmäys vihollisiin, pisteytys      |
| `sound.asm`    | PSG AY-3-8910 ääniefektit                     |
| `hud.asm`      | Numerotileet, pisteet, elämänäyttö             |

## Tekniset yksityiskohdat

### RAM-kartta (0xC000+)

| Osoite      | Käyttö                          |
|-------------|---------------------------------|
| C000–C007   | Pelaajien X, Y, suunta, input   |
| C008–C00B   | Elämät ja kuolinajastimet       |
| C010–C03F   | Viholliset (6 × 8 tavua)       |
| C040–C041   | LFSR-siemen                     |
| C050–C05F   | Ammukset (2 × 8 tavua)         |
| C060–C063   | Ääniefektien laskurit           |
| C070–C073   | Pisteet (BCD)                   |

### Opitut MSX-gotchat

1. **ROM on kirjoitussuojattu** — kaikki muuttuva data EQU-osoitteina RAM:iin (0xC000+), ei DB:llä ROM:iin
2. **TMS9918A Y=0xD0 on sprite stop** — piilottaa kaikki myöhemmät spritet, käytä 0xD8
3. **IS_WALL tuhoaa rekisterit** — PUSH/POP kaikille (HL, DE, BC)
4. **PSG R7 bitti 6 = 0** — portti A täytyy olla input (joystick), pohja-arvo 0xBF ei 0xFF
5. **C-BIOS sotkee PSG:n** — DI + VDP-statuksen pollaus HALT:in sijaan estää keskeytyksen

### Työkalut

- **Assembler:** sjasmplus v1.20.3
- **Emulaattori:** openMSX 20.0 + C-BIOS MSX1
- **BIOS:** C-BIOS (MSX BIOS -korvike)

## TODO

- [ ] Uusi kenttä kun kaikki viholliset tuhottu
- [ ] Lisää vihollistyyppejä (Garwor, Thorwar, Worluk, Wizard)
- [ ] Game over -ruutu
- [ ] Otsikkoruutu
- [ ] Kentän progressio ja vaikeustason nousu
