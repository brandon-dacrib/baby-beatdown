# Baby Beatdown

A Street Fighter II-style SNES fighting game for the [ppu.toys](https://ppu.toys) Studio (emulated SNES PPU +
S-DSP, written in Lua). Eight baby fighters, each an animal (plus one human and one insect) with its own body,
martial art, stage, song, voice, ending and select-screen portrait.

Public repo: https://github.com/brandon-dacrib/baby-beatdown

## Where things are

| path | purpose |
|------|---------|
| `toy/` | the 83 Lua files that ARE the game, plus `sources/` (font and stage sheets, 9 songs). Authoritative copy of the Studio toy. |
| `00_LOAD_ORDER.md` | how to restore the toy into a fresh Studio tab (34 numbered steps) and the Studio quirks learned the hard way. |
| `STYLES.md` | who fights how: styles, move lists, supers, projectiles, reactions, celebrations, arcade ladder, hands. |
| `tools/` | Python painters: `scenes.py` + `quantize.py` (stage backgrounds), `select_bg.py`, `faces.py` (portraits), `paintlib.py`. |
| `legacy/` | first-generation sprite generators; unused. |
| `render/` | PNG renders of the painted stages (ignored by git; regenerate with the tools). |

## The roster

| # | baby | species | style | stage (song) |
|---|------|---------|-------|--------------|
| 1 | Brandon | human (Louisiana Creole) | boxing / Jeet Kune Do | bayou (bayou) |
| 2 | Arlo | terrier puppy | capoeira | backyard (backyard) |
| 3 | Dawn | kitten | kung fu | NYC rooftop (rooftop, hip hop) |
| 4 | Chris | piglet | sumo | farm (farm) |
| 5 | Isaac | duckling | taekwondo | pond (pond) |
| 6 | Teddy | bear cub | wrestling | cave (cave) |
| 7 | Pip | bunny | muay thai | garden (garden) |
| 8 | Blue | bug | karate | leaf (leaf) |

(The nursery song plays on the title and select screens; stage N belongs to character N.)

## Status (2026-10-24)

Done and verified in the Studio (`check` 40 s clean, demo matches and screenshots):

- title screen with attract demo, player select with big RLE-encoded portraits (also shown in demo mode)
- painted parallax stages with ambient life (wind, candles, birds, spectators, barrel, beach ball)
- CPS-1 look: coloured outlines, cel bands, species hands and feet that follow the forearm/shin,
  translucent character-shaped shadows, sole contact lines and landing dust
- per-character martial arts with organic combos, projectiles that clash mid-air, Teddy's bear hug
- three hit reactions, expressions, voices, unique final-blow sounds, celebrations
- 7-fight arcade ladder for a human player with a fireworks ending per character
- per-stage music, SF2-style HUD with a readable font on every stage

Not yet done or unverified:

- 2-player mode (deferred by request; one controller only)
- the hip-hop rooftop track and the character voices have not been heard by a person yet
- Teddy and Pip are placeholder names
- no SNES cartridge export: `snes_check` rejects the toy for structural reasons (function overrides, record
  tables, strings, run-time sprite rendering, 242 KB WRAM). `PORT.md` groups the ~420 findings by cause and
  lays out the rebuild; it is a second toy, not an edit of this one

## Working rules

- Save every file to `toy/` as it is written to the Studio; keep both identical; delete temporary zz_* files.
- Commit and push to GitHub at the end of every work block.
- If the Studio tab is lost (refresh, sign-in, browser close), restore from `00_LOAD_ORDER.md`.
  If the MCP server drops: `claude mcp remove ppu-studio`, `claude mcp add --transport http ppu-studio <url>`, then `/mcp` reconnect.


**Cart status 2026-10-25:** the SF2T-format cart build exports a real ROM: `dist/baby-beatdown.sfc` (12 poses per fighter, 30 Hz, 0 errors). See PORT.md.

**Native build 2026-10-29 (current):** the cartridge is now built locally in 65816 assembly (`make` ->
`dist/baby-beatdown.sfc`, 2 MB, 60 Hz, all 56 poses of all 8 characters, title screen, player select, all
eight painted stages with sky gradients, water shimmer, crowds, birds, shadows and hit sparks, round flow and
an attract demo, two-player mode, meter supers and projectiles, chain combos, sweeps, breakable props, a
break-the-crib bonus stage, character bios with win and lose lines, music and sound effects through an SPC700 driver) and verified headless in Mesen2. See
`NATIVE.md`. The ppu.toys cart dialect (`cart/`) and its PORT.md notes are kept for history only.

**Cart status 2026-10-28:** first emulator play found a range-contract crash, half-speed logic, no sound and a flat backdrop. Source fixed and audited (`tools/check_ranges.lua`), painted stage 1 added (`tools/cartstage.py`), audio code added but unverified; the ROM in `dist/` predates these fixes until the Studio re-exports it. See the end of PORT.md.
