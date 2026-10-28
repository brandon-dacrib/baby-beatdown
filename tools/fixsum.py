#!/usr/bin/env python3
"""fixsum.py rom.sfc: write the SNES header checksum/complement (LoROM header at $7FC0, power-of-two ROM)."""
import sys
p = sys.argv[1]; d = bytearray(open(p, "rb").read())
d[0x7FDC:0x7FE0] = b"\xFF\xFF\x00\x00"
s = sum(d) & 0xFFFF
d[0x7FDC:0x7FDE] = (s ^ 0xFFFF).to_bytes(2, "little"); d[0x7FDE:0x7FE0] = s.to_bytes(2, "little")
open(p, "wb").write(d); print(f"{p}: {len(d)} bytes, checksum {s:04X}")
