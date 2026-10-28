# Baby Beatdown native SNES build: ca65/ld65 (brew install cc65), data from tools/gen_asm.py
PY = .venv/bin/python
ROM = dist/baby-beatdown.sfc
GEN = gen/data.inc gen/sprites.bin gen/stage1.bin gen/font.bin gen/audio.inc build/spc.bin

all: $(ROM)

gen/data.inc gen/stage1.bin gen/font.bin gen/char1.bin: tools/gen_asm.py cart/gamedata.json render/poses/char1.json toy/sources/font.json
	$(PY) tools/gen_asm.py 1

gen/sprites.bin: gen/char1.bin
	cat gen/char1.bin gen/char2.bin gen/char3.bin gen/char4.bin gen/char5.bin gen/char6.bin gen/char7.bin gen/char8.bin > $@

gen/audio.inc gen/spc_samples.bin: tools/gen_audio.py toy/sources/songs/bayou.json
	$(PY) tools/gen_audio.py bayou

build/spc.bin: src/spc.s
	mkdir -p build
	wla-spc700 -o build/spc.o src/spc.s
	printf '[objects]\nbuild/spc.o\n' > build/spc.link
	wlalink -b build/spc.link $@

build/main.o: src/main.s src/snes.inc $(GEN)
	mkdir -p build
	ca65 --cpu 65816 -I src -o $@ src/main.s

$(ROM): build/main.o src/lorom.cfg
	ld65 -C src/lorom.cfg -o $@ -m build/map.txt build/main.o
	python3 tools/fixsum.py $@

clean:
	rm -rf build $(ROM)
.PHONY: all clean
