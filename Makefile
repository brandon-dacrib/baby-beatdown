# Baby Beatdown native SNES build: ca65/ld65 (brew install cc65), data from tools/gen_asm.py
PY = .venv/bin/python
ROM = dist/baby-beatdown.sfc
GEN = gen/data.inc gen/sprites.bin gen/screens.inc gen/font.bin gen/audio.inc build/spc.bin

all: $(ROM)

render/poses/char1.json: tools/sprite_detail.py render/poses_orig/char1.json
	$(PY) tools/sprite_detail.py

render/stage1.png: tools/scenes2.py tools/paintlib.py
	cd tools && ../$(PY) scenes2.py

render/stage9.png: tools/select_bg.py tools/paintlib.py data/font.json
	cd tools && ../$(PY) select_bg.py

gen/data.inc gen/font.bin gen/char1.bin: tools/gen_asm.py data/gamedata.json render/poses/char1.json data/font.json
	$(PY) tools/gen_asm.py

gen/screens.inc: tools/gen_screens.py tools/faces.py tools/quantize.py render/stage1.png render/stage9.png
	$(PY) tools/gen_screens.py

gen/sprites.bin: gen/char1.bin
	cat gen/char1.bin gen/char2.bin gen/char3.bin gen/char4.bin gen/char5.bin gen/char6.bin gen/char7.bin gen/char8.bin > $@

data/songs/bayou.json: tools/compose.py
	$(PY) tools/compose.py

gen/audio.inc gen/spc_samples.bin: tools/gen_audio.py data/songs/bayou.json
	$(PY) tools/gen_audio.py

build/spc.bin: src/spc.s
	mkdir -p build
	wla-spc700 -o build/spc.o src/spc.s
	printf '[objects]\nbuild/spc.o\n' > build/spc.link
	wlalink -b build/spc.link $@

build/main.o: src/main.s src/screens.s src/snes.inc $(GEN)
	mkdir -p build
	ca65 --cpu 65816 -I src -o $@ src/main.s

$(ROM): build/main.o src/lorom.cfg
	ld65 -C src/lorom.cfg -o $@ -m build/map.txt build/main.o
	python3 tools/fixsum.py $@

VERSION := $(shell cat VERSION)
# a release package: the ROM, the docs, the box art and the license
package: $(ROM)
	rm -rf build/pkg && mkdir -p build/pkg/baby-beatdown-v$(VERSION)
	cp $(ROM) README.md LICENSE NATIVE.md build/pkg/baby-beatdown-v$(VERSION)/
	cp -r docs art build/pkg/baby-beatdown-v$(VERSION)/
	cd build/pkg && zip -qr ../baby-beatdown-v$(VERSION).zip baby-beatdown-v$(VERSION)
	@echo build/baby-beatdown-v$(VERSION).zip

clean:
	rm -rf build $(ROM)
.PHONY: all clean package
