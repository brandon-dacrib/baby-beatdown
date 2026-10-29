# Baby Beatdown: the manual

A Street Fighter II style fighting game for the Super Nintendo, written in 65816 assembly with an SPC700
sound driver. The ROM is `dist/baby-beatdown.sfc` (2 MB, LoROM, 60 Hz). It runs in any accurate SNES
emulator (developed and tested on Mesen2) and on real hardware through a flash cartridge.

## Controls

| button | action |
|---|---|
| D-pad left / right | walk; hold away from the opponent to block |
| D-pad up | jump (with left or right for a diagonal) |
| D-pad down | crouch; hold down and press left or right to block low |
| Y or X | punch |
| B | kick |
| A | super move (needs a full meter) |
| forward + punch / kick | the baby's signature strike |
| down + kick | low kick: sweeps knock the opponent down |
| down + punch | low punch, or the crouch shot for the four babies who have one |
| Start on pad 1 | start, one player versus the CPU |
| Start on pad 2 | join as player two |
| Select on the title | go straight to the bonus stage |

## Fighting

- **Rounds**: best of three, 99 seconds each. A knockout or the higher health at time up wins the round.
- **Blocking**: hold away from the opponent. Standing blocks cannot stop low kicks; crouching blocks cannot
  stop high attacks.
- **Combos**: once a hit lands, press punch or kick again to flow into the next move of the baby's chain. The
  hit counter shows on your side of the screen. Chains are listed per baby below.
- **Sweeps** knock the other baby down. They cannot be hit while on the floor and get up on their own.
- **Super meter**: fills when you land hits, a little when you take them, and when you smash a prop. At full
  (six cells) press A. Five babies throw a projectile, three rush.
- **Props**: every stage has two breakable objects. Attacks and projectiles burst them and feed the meter.
- **Projectiles** hit the body, can be blocked, and one crouch shot can be in flight at a time.

## The babies

| baby | style | punches | kicks | forward + P / K | low P / K | super |
|---|---|---|---|---|---|---|
| Brandon | boxing / JKD | jab, cross, hook, straight, uppercut | side kick, kick, front kick | chain punch / side kick | uppercut / sweep | DIAPER DUMP (projectile) |
| Arlo | capoeira | back fist, elbow, palm thrust | crescent, meia lua, front, high kick | elbow / meia lua kick | back fist / sweep | BOTTLE BASH (rush) |
| Dawn | kung fu | chain punch, tiger claw, back fist, straight | crescent, front, side kick | tiger claw / flying kick | tiger claw / sweep | RATTLE RAMPAGE (3-hit rush) |
| Chris | sumo | palm thrust, haymaker, belly bump | stomp, knee, front kick | belly bump / stomp | palm / stomp | BINKY BLAST (projectile) |
| Isaac | taekwondo | jab, back fist | axe, side, crescent, front, roundhouse | back fist / flying kick | jab / sweep | BUBBLE BURP (wobbling projectile) |
| Teddy | wrestling | haymaker, lariat, headbutt | knee, stomp, kick | lariat / knee | haymaker / stomp | TANTRUM TOSS (ground projectile) |
| Pip | muay thai | elbow, jab, uppercut | knee, flying knee, front, roundhouse | elbow / flying knee | uppercut / sweep | TEETHING CHOMP (hopping rush) |
| Blue | karate | straight, back fist, tiger claw | front, side, roundhouse | straight / side kick | straight / sweep | SPIT-UP SPRAY (short projectile) |

Crouch shots (down + punch): Brandon's binky, Dawn's yarn ball, Isaac's bubble, Blue's spit glob.

Combo chains (press punch again, or kick again, after a hit lands):

| baby | punch chain | kick chain |
|---|---|---|
| Brandon | jab, cross, uppercut | kick, cross, uppercut |
| Arlo | jab, cross, high kick | kick, sweep, uppercut |
| Dawn | jab, jab, jab, cross | high kick, sweep |
| Chris | cross, uppercut | kick, kick |
| Isaac | jab, jab, high kick | kick, high kick, high kick |
| Teddy | cross, cross, uppercut | kick, sweep |
| Pip | jab, uppercut | kick, kick, kick, high kick |
| Blue | jab, jab, jab, jab, jab | sweep, sweep, kick |

## Modes

- **One player**: pick a baby on the map of the United States; the CPU picks its own and you fight on its
  home stage. Win the match and you get the bonus stage.
- **Two players**: press Start on the second controller at the title. Each pad picks on the select screen,
  the fight is on the second player's stage.
- **Bonus stage**: fifty seconds to break the crib. Its health bar is the opponent's bar. PERFECT if it
  collapses in time.
- **Attract mode**: leave the title alone and the game plays itself, select screen included. Any button
  returns to the title.

## Building from source

Needs Homebrew `cc65` (ca65 / ld65), `wla-dx` (wla-spc700 / wlalink), and Python 3 with numpy and pillow
in `.venv`. Then:

```
make
```

`make` regenerates the data (stages, sprites, portraits, effects, audio) from `tools/` and links
`dist/baby-beatdown.sfc`. The paintings come from `tools/scenes2.py` and `tools/select_bg.py`; the fighter
poses are in `render/poses_orig` with a detail pass in `tools/sprite_detail.py`. `NATIVE.md` documents the
engine layout. `tools/emu_test.py` drives Mesen2 headless for screenshots and state dumps.
