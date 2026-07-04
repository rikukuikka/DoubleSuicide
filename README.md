# Double Suicide — MSX1

Wizard of Wor -klooni MSX1:lle Z80-assemblyllä.

## Rakentaminen

```bash
sjasmplus --raw=build/DoubleSuicide.rom src/main.asm
```

## Ajaminen

```bash
openmsx -machine C-BIOS_MSX1 -cart build/DoubleSuicide.rom -joytype1 keys
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

- **Otsikkoruutu** — oma logo, 1P / 2P -valinta kursorilla, Commando-fontti
- **16×16 spritet** — 2-frame kävelyanimaatio neljään suuntaan, pysähtyy kun pelaaja seisoo
- **Leveät käytävät** — labyrintti suunniteltu 16px leveillä käytävillä 16×16 spriteille
- **Kaksi pelaajaa** — P1 näppäimistö + joystick 1, P2 joystick 2; yksin- ja kaksinpeli
- **Törmäystarkistus** — pikselitarkka seinäkollisio 16×16 sprite-alueelle (4 kulmapistettä)
- **Snap-to-grid** — automaattinen kohdistus 8px-ruudukkoon risteyksessä käännettäessä
- **Portaalit** — vasemman ja oikean reunan aukot teleporttaavat toiselle puolelle
- **Worrit-viholliset** — 4-suuntaiset spritet, satunnaissuuntainen AI, välttelee takaisin kääntymistä; liikkuvat nopeudella 1 (pelaaja nopeudella 2)
- **Vihollisten ampuminen** — Worrit ampuu kun on samalla rivillä tai sarakkeella kuin pelaaja (50% todennäköisyys), vain suuntaan jota kohti liikkuu; parittomat viholliset ampuvat P1:tä, parilliset P2:ta (yksinpelissä kaikki P1:tä)
- **Ammukset** — yksi ammus per pelaaja, seinätarkistus keskipisteellä, tappaa Worritin
- **Vihollisten ammukset** — puolet hitaampia kuin pelaajan, eivät ylitä HUD-aluetta
- **Räjähdykset** — 2-frame animaatio kun Worrit tuhoutuu
- **PSG-ääni** — kanava A: ampuminen, kanava B: räjähdys, kanava C: taustamusiikki (sahalaita-envelope)
- **Pelaajan kuolema** — vihollisen kosketus tai ammus tappaa, vilkkumisanimaatio, respawn aloituspaikassa
- **3 elämää** per pelaaja, peli loppuu kun elämät = 0
- **Aaltojärjestelmä** — uusi aalto syntyy kun kaikki viholliset tuhottu, 1.5s viive välissä
- **Vaikeustason nousu** — vihollisten määrä kasvaa: 3 → 4 → 5 → 6 (max)
- **HUD** — pisteet (BCD, 100 per tappo), elämät ja värikoodatut pelaajaikonit alarivillä

## Tiedostorakenne

| Tiedosto        | Sisältö                                                       |
|-----------------|---------------------------------------------------------------|
| `main.asm`      | ROM-header, INIT, MAINLOOP, WAIT_VBLANK, aaltologiikka        |
| `constants.asm` | EQU-vakiot, RAM-osoitteet (0xC000+)                           |
| `vdp.asm`       | VDP-apurutiinit, Screen 2 init (16×16 sprite-moodi)           |
| `maze.asm`      | Kenttädata (leveät käytävät), IS_WALL, DRAW_MAZE, INIT_NAVMAP |
| `input.asm`     | Näppäimistö- ja joystick-luku (PSG R14/R15)                   |
| `player.asm`    | 16×16 spritet, animaatio, liikkuminen, portaalit, kuolema      |
| `enemy.asm`     | Worrit AI, ampuminen, LFSR-satunnaisluku, spawn, räjähdykset   |
| `bullet.asm`    | Pelaajan ammukset, törmäys vihollisiin, pisteytys              |
| `sound.asm`     | PSG AY-3-8910 taustamusiikki + ääniefektit                    |
| `hud.asm`       | Numerotileet, pisteet, elämänäyttö                            |
| `title.asm`     | Otsikkoruutu, logo, 1P/2P-valinta                             |

## Tekniset yksityiskohdat

### Sprite pattern layout (VRAM 0x3800+)

| Offset    | Pattern # | Sisältö                    |
|-----------|-----------|----------------------------|
| 0–255     | 0–28      | Pelaaja: 4 suuntaa × 2 framea |
| 256–287   | 32        | Worrit oikea               |
| 288–319   | 36        | Worrit vasen               |
| 320–351   | 40        | Worrit alas                |
| 352–383   | 44        | Worrit ylös                |
| 384–415   | 48        | Ammus (pelaaja)            |
| 416–447   | 52        | Räjähdys frame 1           |
| 448–479   | 56        | Räjähdys frame 2           |

### RAM-kartta (0xC000+)

| Osoite        | Vakio            | Käyttö                                |
|---------------|------------------|---------------------------------------|
| C000–C005     | P1_X … P2_DIR    | Pelaajien X, Y, suunta                |
| C006–C007     | P1_INPUT, P2_INPUT | Syötteiden tila per frame            |
| C008–C00B     | P1_LIVES … P2_DEAD_TMR | Elämät ja kuolinajastimet       |
| C00C          | GAME_MODE        | 1 = yksinpeli, 2 = kaksinpeli         |
| C00D          | FRAME_CTR        | Frame-laskuri animaatioille           |
| C00E          | LEVEL            | Kentän numero (1+)                    |
| C00F          | WAVE_TIMER       | Aaltojen välinen viive                |
| C010–C03F     | ENEMIES          | 6 vihollista × 8 tavua               |
| C040–C041     | RAND_SEED        | 16-bit LFSR-siemen                    |
| C050–C05F     | BULLETS          | 2 pelaajan ammusta × 8 tavua         |
| C060–C062     | SFX_A_CTR …      | Ääniefektien laskurit                 |
| C074–C079     | BGM_PTR …        | Taustamusiikin tila (ptr, loop, timer, active) |
| C07A–C07F     | EXPLOSIONS       | 2 räjähdystä × 3 tavua               |
| C080          | HUD_DIRTY        | 1 = DRAW_HUD täytyy ajaa             |
| C081–C098     | ENEMY_BULLETS    | 6 vihollisen ammusta × 4 tavua       |
| C100–C3FF     | NAVMAP           | Risteyspisteiden suuntabittikartta (768 tavua) |

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
10. **VDP-kirjoitukset heti vblankin jälkeen** — kaikki DRAW_* -kutsut MAINLOOP:in alussa ennen päivityksiä; muuten kirjoitukset voivat osua aktiiviseen skannaukseen ja korruptoida kuvan

### Työkalut

- **Assembler:** sjasmplus v1.20.3
- **Emulaattori:** openMSX 20.0 + C-BIOS MSX1
- **BIOS:** C-BIOS (MSX BIOS -korvike)

## TODO

- [ ] Lisää vihollistyyppejä (Garwor, Thorwar, Worluk, Wizard)
- [ ] Game over -ruutu
- [ ] Useampia kenttälayouteja
- [ ] Vihollisten nopeuden kasvu tasojen myötä
