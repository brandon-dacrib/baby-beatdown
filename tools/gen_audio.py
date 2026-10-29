#!/usr/bin/env python3
"""gen_audio.py: synthesize the instruments, BRR-encode them, and convert the ppu.toys songs into the cart's
60 Hz event streams.

  gen/spc_samples.bin  sample directory (32 entries x 4 bytes, at SPC $0300) + ADSR table (32 x 2, at $0380) + BRR data
                       (loaded to SPC RAM at $0300 by the boot upload, right after the driver)
  gen/audio.inc        SAMPLE_* ids, PITCH_TAB (pitch words per midi note 24..107 for a 32 kHz loop of 128
                       samples), SFX_* macros' data, and SONG_<name>: [delta frames][cmd][p1][p2][p3]... 0xFF = loop
Instruments are approximations of the Studio's built-in sounds (piano, bass, pluck, lead, strings, organ,
flute, bell, kick, snare, hat, ohat, tom, crash, clap). SPC voices 0..5 play music, 6..7 sound effects."""
import json, math, os, struct, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(root, "gen")
RATE = 32000
LOOP = 128                               # looped waveform length (8 BRR blocks); base pitch = 32000/128 = 250 Hz
BASE_MIDI = 69 + 12 * math.log2(250.0 / 440.0)   # 59.21

# ---------------------------------------------------------------- waveforms
def harmonic(amps, n=LOOP, phase=0.0, shape=None):
    out = []
    for i in range(n):
        t = i / n
        v = sum(a * math.sin(2 * math.pi * (k + 1) * t + phase) for k, a in enumerate(amps))
        out.append(v)
    m = max(abs(x) for x in out) or 1
    return [x / m for x in out]

def noise(n, seed=1):
    out = []; s = seed
    for _ in range(n):
        s = (s * 1103515245 + 12345) & 0x7FFFFFFF
        out.append((s / 0x3FFFFFFF) - 1.0)
    return out

def env(n, attack, decay):
    return [min(1.0, i / max(1, attack)) * math.exp(-i / decay) for i in range(n)]

def oneshot_kick(n=3200):
    out = []; ph = 0.0
    for i in range(n):
        f = 50 + 150 * math.exp(-i / 500)
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * math.exp(-i / 1200))
    return out

def oneshot_tom(n=4000):
    out = []; ph = 0.0
    for i in range(n):
        f = 110 + 90 * math.exp(-i / 900)
        ph += 2 * math.pi * f / RATE
        out.append((math.sin(ph) * 0.9 + 0.1 * math.sin(2 * ph)) * math.exp(-i / 1500))
    return out

def oneshot_snare(n=4800):
    nz = noise(n, 7); ph = 0.0; out = []
    for i in range(n):
        ph += 2 * math.pi * 180 / RATE
        out.append(0.55 * nz[i] * math.exp(-i / 1100) + 0.45 * math.sin(ph) * math.exp(-i / 500))
    return out

def oneshot_hat(n=1600, decay=350, seed=3):
    nz = noise(n, seed); out = []; prev = 0.0
    for i in range(n):
        hp = nz[i] - prev; prev = nz[i]          # crude high-pass
        out.append(hp * 0.7 * math.exp(-i / decay))
    return out

def oneshot_crash(n=14000):
    return oneshot_hat(n, 5000, 11)

def oneshot_thump(n=2600):
    out = []; ph = 0.0
    for i in range(n):
        f = 70 + 60 * math.exp(-i / 250)
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * math.exp(-i / 700) * 0.9 + 0.1 * math.sin(3 * ph) * math.exp(-i / 200))
    return out

def oneshot_slam(n=9000):
    nz = noise(n, 13); out = []; ph = 0.0
    for i in range(n):
        f = 45 + 70 * math.exp(-i / 400)
        ph += 2 * math.pi * f / RATE
        out.append(0.8 * math.sin(ph) * math.exp(-i / 2200) + 0.35 * nz[i] * math.exp(-i / 500))
    return out

def oneshot_clap(n=4000):
    nz = noise(n, 5); out = []
    for i in range(n):
        e = sum(math.exp(-((i - d) if i >= d else 1e9) / 300) for d in (0, 320, 640, 960))
        out.append(nz[i] * min(1.0, e) * 0.8)
    return out

INSTR = [  # name, waveform, looped, adsr (ar, dr, sl, sr) ; ar 0-15 (15 fastest), dr 0-7, sl 0-7, sr 0-31
    ("piano",   harmonic([1.0, 0.6, 0.35, 0.2, 0.12, 0.08]), True,  (15, 2, 4, 14)),
    ("bass",    harmonic([1.0, 0.5, 0.25, 0.12, 0.06]), True,       (15, 4, 6, 12)),
    ("pluck",   harmonic([1.0, 0.4, 0.5, 0.1, 0.2]), True,          (15, 1, 2, 16)),
    ("lead",    harmonic([1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14]), True, (14, 7, 6, 8)),
    ("strings", harmonic([1.0, 0.7, 0.5, 0.35, 0.25, 0.18, 0.12, 0.09]), True, (9, 7, 7, 6)),
    ("organ",   harmonic([1.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0.4, 0.3]), True, (15, 7, 7, 10)),
    ("flute",   harmonic([1.0, 0.15, 0.05]), True,                  (10, 7, 7, 8)),
    ("bell",    harmonic([1.0, 0.0, 0.0, 0.5, 0.0, 0.3, 0.0, 0.0, 0.2]), True, (15, 3, 3, 12)),
    ("kick",    oneshot_kick(), False,                              (15, 7, 7, 0)),
    ("snare",   oneshot_snare(), False,                             (15, 7, 7, 0)),
    ("hat",     oneshot_hat(), False,                               (15, 7, 7, 0)),
    ("ohat",    oneshot_hat(4800, 1400, 9), False,                  (15, 7, 7, 0)),
    ("tom",     oneshot_tom(), False,                               (15, 7, 7, 0)),
    ("crash",   oneshot_crash(), False,                             (15, 7, 7, 0)),
    ("clap",    oneshot_clap(), False,                              (15, 7, 7, 0)),
    ("thump",   oneshot_thump(), False,                             (15, 7, 7, 0)),
    ("guitar",  harmonic([1.0, 0.8, 0.55, 0.4, 0.3, 0.2, 0.15, 0.1], phase=0.3), True, (15, 2, 3, 13)),
    ("brass",   harmonic([1.0, 0.9, 0.75, 0.6, 0.5, 0.4, 0.33, 0.28, 0.24]), True, (10, 6, 6, 9)),
    ("vibes",   harmonic([1.0, 0.0, 0.0, 0.35, 0.0, 0.0, 0.0, 0.12]), True, (15, 3, 2, 12)),
    ("conga",   oneshot_tom(2600), False,                           (15, 7, 7, 0)),
    ("shaker",  oneshot_hat(1200, 220, 17), False,                  (15, 7, 7, 0)),
    ("slam",    oneshot_slam(), False,                              (15, 7, 7, 0)),
]
INSTR_ID = {n: i for i, (n, *_r) in enumerate(INSTR)}

# ---------------------------------------------------------------- BRR encoder
def brr_encode(samples, looped):
    """samples: floats -1..1. Returns bytes. Length padded to a multiple of 16."""
    pcm = [max(-32768, min(32767, int(round(s * 30000)))) for s in samples]
    while len(pcm) % 16: pcm.append(0)
    out = bytearray(); p1 = p2 = 0
    nblk = len(pcm) // 16
    for b in range(nblk):
        blk = pcm[b * 16:(b + 1) * 16]
        best = None
        for filt in range(4) if b > 0 else range(1):
            for shift in range(13):
                err = 0; l1, l2 = p1, p2; nib = []
                for s in blk:
                    if filt == 0: pred = 0
                    elif filt == 1: pred = l1 * 15 // 16
                    elif filt == 2: pred = l1 * 61 // 32 - l2 * 15 // 16
                    else: pred = l1 * 115 // 64 - l2 * 13 // 16
                    d = (s - pred)
                    q = int(round(d / (1 << shift))) if shift < 12 else 0
                    q = max(-8, min(7, q))
                    rec = pred + (q << shift)
                    rec = max(-32768, min(32767, rec))
                    err += (rec - s) ** 2
                    l2, l1 = l1, rec
                    nib.append(q & 15)
                    if err > (best[0] if best else 1e30): break
                if best is None or err < best[0]:
                    best = (err, filt, shift, nib, l1, l2)
        err, filt, shift, nib, p1, p2 = best
        hdr = (shift << 4) | (filt << 2)
        if b == nblk - 1: hdr |= 1 | (2 if looped else 0)
        out.append(hdr)
        for i in range(0, 16, 2): out.append((nib[i] << 4) | nib[i + 1])
    return bytes(out)

# ---------------------------------------------------------------- build the sample block (SPC $0300..)
DIR_ADDR = 0x0300
dir_bytes = bytearray(); adsr_bytes = bytearray(); data = bytearray()
base = DIR_ADDR + 32 * 4 + 32 * 2          # samples start after the directory (32 entries) and the ADSR table ($0380)
for name, wave, looped, (ar, dr, sl, sr) in INSTR:
    brr = brr_encode(wave, looped)
    start = base + len(data)
    loop = start if looped else start + len(brr) - 9
    dir_bytes += struct.pack("<HH", start, loop)
    adsr_bytes += bytes((0x80 | (dr << 4) | ar, (sl << 5) | sr))
    data += brr
while len(dir_bytes) < 128: dir_bytes += struct.pack("<HH", base, base)
while len(adsr_bytes) < 64: adsr_bytes += b"\x8F\x00"
blob = bytes(dir_bytes) + bytes(adsr_bytes) + bytes(data)
open(os.path.join(OUT, "spc_samples.bin"), "wb").write(blob)
print(f"samples: {len(INSTR)} instruments, {len(data)} bytes BRR, block {len(blob)} bytes at SPC ${DIR_ADDR:04X}")

# ---------------------------------------------------------------- songs -> 60 Hz event streams
def pitch_for(midi):
    return max(1, min(0x3FFF, int(round(4096 * 2 ** ((midi - BASE_MIDI) / 12)))))
DRUMS = {"kick", "snare", "hat", "ohat", "tom", "crash", "clap", "thump", "slam", "conga", "shaker"}
def convert_song(j):
    tempo = j["tempo"]; rows = j["rows"]
    fpt = 3600.0 / (tempo * 48)        # frames per tick (48 ticks per beat: kick 0/96, snare 48/144, hats every 24)
    swing = j.get("swing") or 0
    events = []                        # (frame, order, cmd, p1, p2, p3)
    arrangement = j.get("arrangement") or [0]
    t0 = 0
    voice_free = [0] * 6               # frame at which each music voice is free
    for pi in arrangement:
        pat = j["patterns"][pi]
        for n in sorted(pat["notes"], key=lambda n: n["at"]):
            row = rows[n["row"]]; snd = row["sound"]
            if snd not in INSTR_ID: continue
            at = n["at"]
            if swing and (at % 48) == 24: at += int(24 * swing / 100 * 0.5)
            f_on = int(round((t0 + at) * fpt)); f_off = int(round((t0 + at + n["len"]) * fpt))
            if f_off <= f_on: f_off = f_on + 1
            # pick the voice free the earliest
            v = min(range(6), key=lambda k: voice_free[k])
            voice_free[v] = f_off
            vol = max(1, min(127, row.get("vol", 100))) // 2
            if snd in DRUMS: midi = row.get("note", 60)
            else: midi = row.get("note", 60) + (n.get("transpose", 0))
            p = pitch_for(midi) if snd not in DRUMS else int(4096 * 2 ** ((midi - 60) / 12))
            events.append((f_on, 0, 0x00 | v, vol, vol, 0))              # volume
            events.append((f_on, 1, 0x40 | v, INSTR_ID[snd], p & 255, p >> 8))   # note on
            if snd not in DRUMS: events.append((f_off, 2, 0x80 | v, 0, 0, 0))  # note off
        t0 += pat["length"]
    total = int(round(t0 * fpt))
    events.sort()
    out = bytearray(); last = 0
    for f, _o, cmd, p1, p2, p3 in events:
        if f >= total: break
        d = f - last
        while d > 254: out += bytes((254, 0xFF, 0, 0, 0)); d -= 254   # cmd $FF = no-op wait
        out += bytes((d, cmd, p1, p2, p3)); last = f
    d = total - last
    while d > 254: out += bytes((254, 0xFF, 0, 0, 0)); d -= 254
    out += bytes((d, 0xFE, 0, 0, 0))   # loop marker
    return bytes(out), total
inc = ["; audio.inc: generated by tools/gen_audio.py"]
for n, i in INSTR_ID.items(): inc.append(f"SMP_{n.upper()} = {i}")
inc.append("SPC_SAMPLES_ADDR = $%04X" % DIR_ADDR)
inc.append("PITCH_TAB:   ; midi 24..107 -> DSP pitch for the 128-sample loops")
inc.append("  .word " + ", ".join(str(pitch_for(m)) for m in range(24, 108)))
songs = sys.argv[1:] or ["bayou", "backyard", "rooftop", "farm", "pond", "cave", "garden", "leaf", "nursery"]
inc.append('.segment "SONGS"')
for name in songs:
    j = json.load(open(os.path.join(root, f"data/songs/{name}.json")))
    stream, total = convert_song(j)
    inc.append(f"SONG_{name.upper()}:")
    for i in range(0, len(stream), 40):
        inc.append("  .byte " + ", ".join(str(b) for b in stream[i:i + 40]))
    print(f"song {name}: {len(stream)} bytes, {total} frames ({total/60:.1f} s) per loop")
inc.append('.segment "RODATA"')
inc.append("SONG_TAB:\n  .word " + ", ".join(f".loword(SONG_{n.upper()})" for n in songs))
inc.append("SONG_BANK:\n  .byte " + ", ".join(f"^SONG_{n.upper()}" for n in songs))
inc.append("SEL_PITCH:\n  .word %d, %d, %d" % (pitch_for(72), pitch_for(76), pitch_for(79)))   # C5 E5 G5
open(os.path.join(OUT, "audio.inc"), "w").write("\n".join(inc) + "\n")
