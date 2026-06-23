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

- **16×16 spritet** — 2-frame kävelyanimaatio neljään suuntaan, pysähtyy kun pelaaja seisoo
- **Leveät käytävät** — labyrintti suunniteltu 16px leveillä käytävillä 16×16 spriteille
- **Kaksi pelaajaa** — P1 näppäimistö + joystick 1, P2 joystick 2
- **Törmäystarkistus** — pikselitarkka seinäkolliisio 16×16 sprite-alueelle (4 kulmapistettä)
- **Snap-to-grid** — automaattinen kohdistus 8px-ruudukkoon risteyksessä käännettäessä
- **Portaalit** — vasemman ja oikean reunan aukot teleporttaavat toiselle puolelle
- **Worrit-viholliset** — satunnaissuuntainen AI, välttelee takaisin kääntymistä
- **Ammukset** — yksi ammus per pelaaja, seinätarkistus keskipisteellä, tappaa Worritin
- **PSG-ääniefektit** — ammuksen ääni (kanava A) ja räjähdys (kanava B)
- **Pelaajan kuolema** — vihollisen kosketus tappaa, vilkkumisanimaatio, respawn aloituspaikassa
- **3 elämää** per pelaaja, peli loppuu kun elämät = 0
- **Aaltojärjestelmä** — uusi aalto syntyy kun kaikki viholliset tuhottu, 1.5s viive välissä
- **Vaikeustason nousu** — vihollisten määrä kasvaa: 3 → 4 → 5 → 6 (max)
- **HUD** — pisteet (BCD, 100 per tappo), elämät ja värikoodatut pelaajaikonit alarivillä

## Tiedostorakenne

| Tiedosto       | Sisältö                                           |
|----------------|---------------------------------------------------|
| `main.asm`     | ROM-header, INIT, MAINLOOP, WAIT_VBLANK, aaltologiikka |
| `constants.asm`| EQU-vakiot, RAM-osoitteet (0xC000+)                |
| `vdp.asm`      | VDP-apurutiinit, Screen 2 init (16×16 sprite-moodi) |
| `maze.asm`     | Kenttädata (leveät käytävät), IS_WALL, DRAW_MAZE   |
| `input.asm`    | Näppäimistö- ja joystick-luku (PSG R14/R15)        |
| `player.asm`   | 16×16 spritet, animaatio, liikkuminen, portaalit, kuolema |
| `enemy.asm`    | Worrit AI, LFSR-satunnaisluku, spawn, aaltotarkistus |
| `bullet.asm`   | Ammukset, törmäys vihollisiin, pisteytys           |
| `sound.asm`    | PSG AY-3-8910 ääniefektit                          |
| `hud.asm`      | Numerotileet, pisteet, elämänäyttö                  |

## Tekniset yksityiskohdat

### Sprite pattern layout (VRAM 0x3800+)

| Offset  | Pattern # | Sisältö                    |
|---------|-----------|----------------------------|
| 0–31    | 0         | Pelaaja oikea frame 1      |
| 32–63   | 4         | Pelaaja oikea frame 2      |
| 64–95   | 8         | Pelaaja vasen frame 1      |
| 96–127  | 12        | Pelaaja vasen frame 2      |
| 128–159 | 16        | Pelaaja alas frame 1       |
| 160–191 | 20        | Pelaaja alas frame 2       |
| 192–223 | 24        | Pelaaja ylös frame 1       |
| 224–255 | 28        | Pelaaja ylös frame 2       |
| 256–287 | 32        | Worrit                     |
| 288–319 | 36        | Ammus                      |

### RAM-kartta (0xC000+)

| Osoite      | Käyttö                          |
|-------------|---------------------------------|
| C000–C007   | Pelaajien X, Y, suunta, input   |
| C008–C00B   | Elämät ja kuolinajastimet       |
| C00C        | Frame-laskuri (animaatio)       |
| C00D        | Kentän numero (LEVEL)           |
| C00E        | Aaltojen välinen viive          |
| C010–C03F   | Viholliset (6 × 8 tavua)       |
| C040–C041   | LFSR-siemen                     |
| C050–C05F   | Ammukset (2 × 8 tavua)         |
| C060–C063   | Ääniefektien laskurit           |
| C070–C073   | Pisteet (BCD)                   |

### Opitut MSX/TMS9918A-gotchat

1. **ROM on kirjoitussuojattu** — kaikki muuttuva data EQU-osoitteina RAM:iin (0xC000+)
2. **Sprite Y=0xD0 on stop-merkki** — piilottaa kaikki myöhemmät spritet, käytä 0xD8
3. **Sprite Y-offset** — TMS9918A piirtää spriten 1px alemmaksi kuin attribute tablen Y-arvo
4. **16×16 spritet** — VDP R#1 bitti 1, pattern-numerot 4:n monikertoja, 32 tavua/pattern
5. **IS_WALL tuhoaa rekisterit** — PUSH/POP kaikille (HL, DE, BC)
6. **PSG R7 bitti 6 = 0** — portti A input (joystick), pohja-arvo 0xBF
7. **C-BIOS sotkee PSG:n** — DI + VDP-statuksen pollaus HALT:in sijaan
8. **DJNZ max 128 tavua** — pitkissä silmukoissa DEC B / JP NZ
9. **16×16 törmäystarkistus** — kaikki 4 kulmaa (+15 eikä +7), ammukselle keskipiste (+8)

### Työkalut

- **Assembler:** sjasmplus v1.20.3
- **Emulaattori:** openMSX 20.0 + C-BIOS MSX1
- **BIOS:** C-BIOS (MSX BIOS -korvike)

## TODO

- [ ] Lisää vihollistyyppejä (Garwor, Thorwar, Worluk, Wizard)
- [ ] Game over -ruutu
- [ ] Otsikkoruutu
- [ ] Useampia kenttälayouteja
- [ ] Vihollisten nopeuden kasvu tasojen myötä
