#!/usr/bin/env python3
"""compose.py: writes the nine songs (data/songs/*.json) from short musical descriptions.

Each song names a style for the drums and bass, a chord progression, a melody and a counter line written as
"note:beats" strings. Ticks: 48 per beat, 4/4 bars of 192. Six music voices: drums use two (kick/snare share
one, hats the other), bass one, chords two, melody one; the counter line replaces one chord voice."""
import json, os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(root, "data", "songs")
BEAT, BAR = 48, 192
NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
def midi(name):
    n = NAMES[name[0]]; i = 1
    if name[i] in "#b": n += 1 if name[i] == "#" else -1; i += 1
    return 12 * (int(name[i:]) + 1) + n
CHORDS = {"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "maj7": (0, 4, 7, 11), "sus": (0, 5, 7), "dim": (0, 3, 6), "6": (0, 4, 7, 9), "m6": (0, 3, 7, 9), "9": (0, 4, 7, 10, 14)}
def chord(sym):
    root = sym.rstrip("m7ajsdi69"); q = sym[len(root):]
    if root.endswith("b") or root.endswith("#"): pass
    return midi(root + "4"), CHORDS[q]

class Song:
    def __init__(self, tempo, swing=0):
        self.tempo, self.swing = tempo, swing
        self.rows, self.rowidx, self.notes, self.length = [], {}, [], 0
    def row(self, sound, note, vol):
        k = (sound, note, vol)
        if k not in self.rowidx:
            self.rowidx[k] = len(self.rows); self.rows.append({"sound": sound, "note": note, "vol": vol})
        return self.rowidx[k]
    def hit(self, at, sound, note, vol, length):
        self.notes.append({"at": int(at), "row": self.row(sound, note, vol), "len": max(1, int(length))})
        self.length = max(self.length, int(at) + int(length))
    def line(self, text, sound, vol, start=0, octave=0, legato=0.9):
        """"C5:1 E5:0.5 -:0.5 ..." (- = rest) from tick start; returns the end tick"""
        t = start
        for tok in text.split():
            n, b = tok.split(":"); d = float(b) * BEAT
            if n != "-": self.hit(t, sound, midi(n) + 12 * octave, vol, d * legato)
            t += d
        return t
    def drums(self, style, bars, start=0):
        for b in range(bars):
            t0 = start + b * BAR
            if style == "funk":
                for k in (0, 0.75, 2, 2.5): self.hit(t0 + k * BEAT, "kick", 59, 110, 6)
                for k in (1, 3): self.hit(t0 + k * BEAT, "snare", 60, 95, 6); self.hit(t0 + k * BEAT, "clap", 60, 60, 6)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "hat" if k % 2 == 0 else "ohat", 60, 45 if k % 2 == 0 else 35, 4)
            elif style == "rock":
                for k in (0, 2, 2.5): self.hit(t0 + k * BEAT, "kick", 59, 110, 6)
                for k in (1, 3): self.hit(t0 + k * BEAT, "snare", 60, 100, 6)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "hat", 60, 55 if k % 2 == 0 else 35, 4)
                if b % 4 == 3: self.hit(t0 + 3.5 * BEAT, "tom", 55, 80, 6)
            elif style == "hiphop":
                for k in (0, 1.75, 2.5): self.hit(t0 + k * BEAT, "kick", 57, 115, 8)
                for k in (1, 3): self.hit(t0 + k * BEAT, "snare", 58, 100, 8)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "hat", 60, 50 if k % 2 == 0 else 30, 3)
                self.hit(t0 + 3.5 * BEAT, "ohat", 60, 35, 6)
            elif style == "country":
                for k in (0, 2): self.hit(t0 + k * BEAT, "kick", 59, 105, 6)
                for k in (1, 3): self.hit(t0 + k * BEAT, "snare", 60, 85, 6)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "shaker", 60, 45, 3)
            elif style == "waltz":
                self.hit(t0, "kick", 58, 95, 6)
                for k in (1, 2): self.hit(t0 + k * BEAT, "hat", 60, 40, 4)
            elif style == "cave":
                self.hit(t0, "thump", 55, 110, 8); self.hit(t0 + 2 * BEAT, "thump", 55, 90, 8)
                for k in (1, 3): self.hit(t0 + k * BEAT, "tom", 52, 70, 6)
                for k in range(4): self.hit(t0 + k * BEAT + BEAT / 2, "shaker", 60, 30, 3)
            elif style == "soul":
                for k in (0, 2.5): self.hit(t0 + k * BEAT, "kick", 59, 105, 6)
                for k in (1, 3): self.hit(t0 + k * BEAT, "snare", 60, 90, 6); self.hit(t0 + k * BEAT, "clap", 60, 50, 6)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "hat", 60, 45 if k % 2 == 0 else 30, 4)
            elif style == "latin":
                for k in (0, 1.5, 2.5): self.hit(t0 + k * BEAT, "kick", 59, 105, 6)
                for k in (0.5, 1, 2, 3, 3.5): self.hit(t0 + k * BEAT, "conga", 64 if k in (1, 3) else 60, 75, 5)
                for k in range(8): self.hit(t0 + k * BEAT / 2, "shaker", 60, 45, 3)
                if b % 2 == 1: self.hit(t0 + 3 * BEAT, "clap", 60, 70, 6)
            elif style == "lullaby":
                self.hit(t0, "hat", 60, 25, 4); self.hit(t0 + 2 * BEAT, "hat", 60, 20, 4)
    def bass(self, style, prog, sound="bass", vol=110, start=0):
        """prog: list of (chord symbol, bars)"""
        t = start
        for sym, bars in prog:
            root, iv = chord(sym); r = root - 24 + (12 if root - 24 < 36 else 0)
            fifth = r + 7; octv = r + 12; third = r + iv[1]
            for b in range(bars):
                t0 = t + b * BAR
                if style == "funk":
                    for k, n in ((0, r), (0.75, r), (1.5, octv), (2, r), (2.75, fifth), (3.25, r), (3.75, r + 10 if "7" in sym else octv)):
                        self.hit(t0 + k * BEAT, sound, n, vol, 10)
                elif style == "rock":
                    for k in range(8): self.hit(t0 + k * BEAT / 2, sound, r if k < 6 else fifth, vol, 18)
                elif style == "hiphop":
                    for k, n in ((0, r), (1.75, r), (2.5, fifth), (3.5, r)): self.hit(t0 + k * BEAT, sound, n, vol, 30)
                elif style == "country":
                    for k, n in ((0, r), (1, fifth), (2, r), (3, fifth if b % 2 == 0 else third)): self.hit(t0 + k * BEAT, sound, n, vol, 20)
                elif style == "waltz":
                    self.hit(t0, sound, r, vol, 40); self.hit(t0 + 2 * BEAT, sound, fifth, vol - 20, 20)
                elif style == "cave":
                    self.hit(t0, sound, r, vol, 80); self.hit(t0 + 3 * BEAT, sound, r + 10 if "7" in sym else fifth, vol - 10, 20)
                elif style == "soul":
                    for k, n in ((0, r), (1, third), (2, fifth), (2.5, octv), (3, fifth), (3.5, third)): self.hit(t0 + k * BEAT, sound, n, vol, 16)
                elif style == "latin":
                    for k, n in ((0, r), (1.5, fifth), (2.5, octv), (3.5, fifth)): self.hit(t0 + k * BEAT, sound, n, vol, 22)
                elif style == "lullaby":
                    self.hit(t0, sound, r, vol - 30, 90); self.hit(t0 + 2 * BEAT, sound, fifth, vol - 40, 40)
            t += bars * BAR
        return t
    def chords(self, style, prog, sound="piano", vol=70, start=0, voices=2):
        t = start
        for sym, bars in prog:
            root, iv = chord(sym)
            tones = [root + i for i in iv][: voices + 1]
            for b in range(bars):
                t0 = t + b * BAR
                if style == "stabs":
                    for k in (0.5, 2, 3.5):
                        for n in tones[:voices]: self.hit(t0 + k * BEAT, sound, n, vol, 14)
                elif style == "pad":
                    for n in tones[:voices]: self.hit(t0, sound, n, vol, BAR - 6)
                elif style == "arp":
                    seq = (tones + tones[:1])[:4]
                    for k in range(8): self.hit(t0 + k * BEAT / 2, sound, seq[k % len(seq)] + (12 if k >= 4 else 0), vol, 20)
                elif style == "strum":
                    for k in (0, 1, 1.5, 2.5, 3):
                        for n in tones[:voices]: self.hit(t0 + k * BEAT, sound, n, vol - (10 if k % 1 else 0), 18)
                elif style == "waltz":
                    for k in (1, 2):
                        for n in tones[:voices]: self.hit(t0 + k * BEAT, sound, n, vol, 20)
            t += bars * BAR
    def save(self, name):
        self.length = ((self.length + BAR - 1) // BAR) * BAR          # loop on a bar line
        # how many music voices the player needs at once (the game has six; drums share by sample)
        ev = sorted((n["at"], 1, n["len"]) for n in self.notes)
        free = [0] * 6; worst = 0
        for at, _, ln in ev:
            v = min(range(6), key=lambda k: free[k]); worst = max(worst, 1 if free[v] <= at else 0)
            free[v] = at + ln
        stolen = sum(1 for at, _, ln in ev if False)
        pats = [{"length": self.length, "notes": sorted(self.notes, key=lambda n: n["at"])}]
        json.dump({"tempo": self.tempo, "swing": self.swing, "rows": self.rows, "patterns": pats, "arrangement": [0], "loopStart": 0},
                  open(os.path.join(OUT, name + ".json"), "w"), separators=(",", ":"))
        # count notes that would be cut short because all six voices are busy
        free = [0] * 6; cut = 0
        for at, _, ln in ev:
            v = min(range(6), key=lambda k: free[k])
            if free[v] > at: cut += 1
            free[v] = at + ln
        print(f"{name}: {self.length // BAR} bars, {len(self.notes)} notes, tempo {self.tempo}, voice steals {cut}")

# ------------------------------------------------------------ 1 Los Angeles: West Coast funk at sunset
s = Song(104, swing=30)
prog = [("Dm7", 2), ("G7", 2), ("Dm7", 2), ("Bb", 1), ("A7", 1)]
s.drums("funk", 8); s.bass("funk", prog); s.chords("stabs", prog, "organ", 55)
s.line("A4:0.5 C5:0.5 D5:1 F5:0.5 D5:0.5 C5:1 A4:0.5 C5:0.5 D5:2 -:1 F5:0.5 G5:0.5 A5:1 G5:0.5 F5:0.5 D5:1 C5:0.5 D5:0.5 F5:1 D5:1 -:1 "
       "D5:0.5 F5:0.5 A5:1 G5:0.5 F5:0.5 D5:1 C5:0.5 A4:0.5 C5:2 -:1 Bb4:0.5 D5:0.5 F5:1 E5:0.5 D5:0.5 C#5:1 E5:0.5 A5:0.5 A5:1.5 -:0.5 -:1", "lead", 72)
s.line("-:8 F5:0.5 -:0.5 A5:0.5 -:0.5 F5:1 -:2 D5:0.5 -:0.5 F5:0.5 -:0.5 G5:1 -:2 -:16", "guitar", 50, octave=0)
s.save("bayou")
# ------------------------------------------------------------ 2 Ohio backyard: sunny pop rock
s = Song(132)
prog = [("C", 1), ("G", 1), ("Am", 1), ("F", 1), ("C", 1), ("G", 1), ("F", 1), ("G", 1)]
s.drums("rock", 8); s.bass("rock", prog); s.chords("strum", prog, "guitar", 48)
s.line("E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 E5:1 D5:0.5 E5:0.5 G5:1 E5:0.5 D5:0.5 C5:2 -:1 E5:0.5 G5:0.5 A5:1 G5:0.5 E5:0.5 D5:1 C5:0.5 D5:0.5 E5:2 -:0.5 "
       "C5:0.5 E5:0.5 G5:0.5 C6:1 B5:0.5 A5:0.5 G5:1 E5:0.5 G5:0.5 A5:1 G5:0.5 F5:0.5 E5:2 -:1 F5:0.5 A5:0.5 C6:1 A5:0.5 G5:0.5 E5:1 F5:0.5 G5:0.5 G5:2 -:1", "lead", 70)
s.save("backyard")
# ------------------------------------------------------------ 3 New York rooftop: night hip hop with jazz chords
s = Song(92, swing=50)
prog = [("Am7", 2), ("Dm7", 2), ("Fmaj7", 2), ("E7", 2)]
s.drums("hiphop", 8); s.bass("hiphop", prog); s.chords("pad", prog, "piano", 50, voices=3)
s.line("E5:1 -:0.5 G5:0.5 A5:1 -:0.5 G5:0.5 E5:1 D5:0.5 C5:0.5 D5:1 -:1 A4:0.5 C5:0.5 D5:1 F5:0.5 E5:0.5 D5:1 C5:1 -:1 "
       "A4:0.5 C5:0.5 E5:1 -:0.5 G5:0.5 A5:1 G5:0.5 E5:0.5 C5:1 -:1 B4:0.5 D5:0.5 E5:1 G#5:0.5 B5:0.5 E5:1 D5:0.5 B4:0.5 E5:2 -:1", "vibes", 68)
s.save("rooftop")
# ------------------------------------------------------------ 4 Iowa farm: barn-dance country
s = Song(140)
prog = [("G", 2), ("C", 1), ("G", 1), ("D", 2), ("G", 2)]
s.drums("country", 8); s.bass("country", prog); s.chords("strum", prog, "pluck", 45)
s.line("D5:0.5 G5:0.5 B5:0.5 D6:0.5 B5:0.5 G5:0.5 A5:0.5 B5:0.5 C6:0.5 E6:0.5 C6:0.5 A5:0.5 B5:1 G5:0.5 D5:0.5 "
       "A5:0.5 F#5:0.5 D5:0.5 F#5:0.5 A5:0.5 C6:0.5 A5:0.5 F#5:0.5 G5:1 B5:0.5 D6:0.5 G5:2 "
       "G5:0.5 A5:0.5 B5:0.5 G5:0.5 E6:0.5 D6:0.5 B5:0.5 G5:0.5 C6:0.5 E6:0.5 G6:0.5 E6:0.5 C6:1 A5:0.5 C6:0.5 "
       "D6:0.5 C6:0.5 A5:0.5 F#5:0.5 D5:0.5 F#5:0.5 A5:0.5 C6:0.5 B5:0.5 G5:0.5 D5:0.5 B4:0.5 G5:2", "strings", 66)
s.save("farm")
# ------------------------------------------------------------ 5 Minnesota lake: a gentle folk waltz (3/4 feel inside 4/4 bars: use 3-beat pulse)
s = Song(126)
prog = [("D", 2), ("Bm", 2), ("G", 2), ("A", 2)]
s.drums("waltz", 8); s.bass("waltz", prog); s.chords("waltz", prog, "pluck", 45)
s.line("F#5:1 A5:1 D6:2 -:0.5 C#6:0.5 B5:1 A5:1 F#5:2 -:1 D5:1 E5:1 F#5:2 -:0.5 E5:0.5 D5:1 B4:1 D5:2 -:1 "
       "G5:1 B5:1 D6:2 -:0.5 E6:0.5 D6:1 B5:1 G5:2 -:1 A5:1 C#6:1 E6:2 -:0.5 D6:0.5 C#6:1 B5:1 A5:2 -:1", "flute", 62)
s.line("-:16 D5:1 F#5:1 A5:2 -:4 B4:1 D5:1 F#5:2 -:4 -:16", "strings", 40)
s.save("pond")
# ------------------------------------------------------------ 6 Kentucky cave: mountain minor, slow and deep
s = Song(96)
prog = [("Em", 2), ("Em", 2), ("C", 2), ("B7", 2)]
s.drums("cave", 8); s.bass("cave", prog); s.chords("pad", prog, "organ", 40, voices=3)
s.line("E5:1.5 G5:0.5 B5:1 A5:0.5 G5:0.5 E5:2 -:1 G5:0.5 A5:0.5 B5:1 D6:1 B5:1 A5:0.5 G5:0.5 E5:2 -:1 "
       "C5:1 E5:1 G5:1.5 A5:0.5 G5:2 -:1 B4:0.5 D#5:0.5 F#5:1 A5:1 F#5:1 D#5:0.5 B4:0.5 E5:2 -:1", "pluck", 62)
s.save("cave")
# ------------------------------------------------------------ 7 Georgia garden: southern soul with gospel organ
s = Song(112, swing=20)
prog = [("Bb", 2), ("Eb", 2), ("Bb", 1), ("Gm", 1), ("Eb", 1), ("F7", 1)]
s.drums("soul", 8); s.bass("soul", prog); s.chords("stabs", prog, "organ", 50)
s.line("D5:0.5 F5:0.5 Bb5:1 A5:0.5 F5:0.5 D5:1 F5:0.5 G5:0.5 F5:2 -:1 Eb5:0.5 G5:0.5 Bb5:1 G5:0.5 F5:0.5 Eb5:1 D5:0.5 Eb5:0.5 F5:2 -:1 "
       "F5:0.5 Bb5:0.5 D6:1 C6:0.5 Bb5:0.5 A5:1 Bb5:0.5 G5:0.5 D5:2 -:1 Eb5:0.5 G5:0.5 Bb5:1 A5:0.5 G5:0.5 F5:1 Eb5:0.5 D5:0.5 Bb4:2 -:1", "brass", 60)
s.save("garden")
# ------------------------------------------------------------ 8 Florida everglades: Miami latin
s = Song(124)
prog = [("Am", 1), ("Dm", 1), ("E7", 1), ("Am", 1), ("F", 1), ("G", 1), ("C", 1), ("E7", 1)]
s.drums("latin", 8); s.bass("latin", prog); s.chords("stabs", prog, "piano", 52)
s.line("E5:0.5 A5:0.5 C6:0.5 B5:0.5 A5:1 E5:1 F5:0.5 A5:0.5 D6:0.5 C6:0.5 A5:1 F5:1 G#5:0.5 B5:0.5 E6:0.5 D6:0.5 B5:1 G#5:1 A5:2 -:2 "
       "C6:0.5 A5:0.5 F5:0.5 A5:0.5 C6:1 A5:1 B5:0.5 G5:0.5 D5:0.5 G5:0.5 B5:1 G5:1 C6:0.5 E6:0.5 G5:0.5 C6:0.5 E6:1 D6:0.5 B5:0.5 G#5:2 E5:1 -:1", "lead", 70)
s.save("leaf")
# ------------------------------------------------------------ title / select: a music-box lullaby
s = Song(100)
prog = [("C", 2), ("Am", 2), ("F", 2), ("G", 2), ("C", 2), ("Am", 2), ("F", 1), ("G", 1), ("C", 2)]
s.drums("lullaby", 16); s.bass("lullaby", prog); s.chords("arp", prog, "bell", 38)
s.line("E5:1 G5:1 C6:2 B5:1 A5:1 G5:2 A5:1 C6:1 F5:2 G5:1 F5:1 E5:2 E5:1 G5:1 C6:2 B5:1 A5:1 G5:2 A5:1 G5:1 F5:1 E5:1 D5:2 C5:2 "
       "-:8 -:8 -:8 -:8", "vibes", 55)
s.save("nursery")
