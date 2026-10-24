# Baby Beatdown — who fights how

Controls: Y/X punch, B kick, A super (full meter), forward+punch / forward+kick = the style's signature,
down+kick = low, down+punch = low punch or projectile. A landed hit can be chained into any other move
of the style (up to 5 hits); the buttons cycle through the list, never repeating the last move.

| Baby | Style | Punches | Kicks | Forward+P | Forward+K | Low | Projectile / grab | Super |
|---|---|---|---|---|---|---|---|---|
| Brandon (human) | Boxing / Jeet Kune Do | jab, cross, hook, straight, uppercut | side kick, kick, front kick | straight blast (3-hit chain) | side kick | sweep | BINKY SHOT (down+P) | DIAPER DUMP |
| Arlo (puppy) | Capoeira | back fist, elbow, palm | crescent, meia lua de compasso, front kick, high kick | elbow | meia lua (spins) | sweep | — | BOTTLE BASH |
| Dawn (kitten) | Kung Fu | chain punches, tiger claw, back fist, straight | crescent (crane), front kick, side kick | tiger claw (overhead) | flying kick | sweep | YARN BALL (down+P) | RATTLE RAMPAGE |
| Chris (piglet) | Sumo | palm thrust, haymaker (harite), belly bump | stomp, knee, front kick | belly bump | stomp (shockwave, low) | stomp | — | BINKY BLAST |
| Isaac (duck) | Taekwondo | jab, back fist | axe kick, side kick, crescent (spinning), front kick, roundhouse | back fist (spins) | flying side kick | sweep | BUBBLE (down+P) | BUBBLE BURP |
| Teddy (bear) | Wrestling | haymaker, lariat, headbutt | knee, stomp, kick | lariat | knee | stomp | BEAR HUG: punch inside hugging range (3 squeezes, toss) | TANTRUM TOSS |
| Pip (bunny) | Muay Thai | elbow, jab, uppercut | knee, flying knee, teep (front kick), roundhouse | elbow | flying knee | sweep | — | TEETHING CHOMP |
| Blue (bug) | Karate (Shotokan) | reverse punch, back fist (uraken), knife hand | front kick, side kick, roundhouse | reverse punch | side kick | sweep | SPIT GLOB (down+P) | SPIT-UP SPRAY |

Hit reactions: head snap (high hits), gut fold (mid), leg buckle (low), each with a recoil frame.
Voices: each baby has a phrase on specials, a wail with its own impact sound on the final blow, a cheer on a win.
Celebrations: Brandon pumps and jumps, Arlo sits and hops, Dawn grooms, Chris does sumo stomps, Isaac flaps,
Teddy flexes, Pip bounces, Blue bows and spins.
Projectiles cancel each other mid-air ("CLASH!"). A beach ball lives in the Yard, Farm and Garden stages.

## Arcade ladder and endings (arcade.lua)
A human match starts a 7-fight ladder against every other baby on their own stage ("MATCH n OF 7").
Lose once and it is back to the title. Beat all seven and the champion gets a big win sequence on their
home stage: fireworks, confetti, their celebration moves and voice, a four-line story (ENDING table in
arcade.lua), then THE END. Any button or ~20 s returns to the title.

## Hands
cps.lua orients every hand along its forearm: bent arms (guard, chamber) are closed fists with the knuckles
on the leading side, extended arms open into the species' fingers, claws, trotter, wingtip or pincer.
Lifted feet point along the shin. Arlo is a terrier (terrier.lua: pricked tan-lined ears, crown tufts,
bushy brows, beard; portrait in tools/faces.py).
