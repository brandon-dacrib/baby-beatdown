; BABY BEATDOWN - native SNES build (65816, ca65). LoROM/FastROM, Mode 1.
; Engine ported from cart/main.lua (SF2 Turbo formats: 4-byte keyframes, box sets, centre/half-extent boxes).
; Fighters are two 64x64 OBJs whose tiles are streamed from ROM by DMA in NMI when the pose changes (2 KB each).
; Units: positions/velocities in 1/16 px. Facing: 1 right, -1 (=$FFFF) left. Fighter index X = 0 or 2.
.p816
.include "snes.inc"

; ------------------------------------------------------------------ constants
FLOOR     = 176
HP_MAX    = 96
METER_MAX = 96
ST_IDLE = 0
ST_WALK = 1
ST_CROUCH = 2
ST_JUMP = 3
ST_ATTACK = 4
ST_HIT = 5
ST_BLOCK = 6
ST_KO = 7
ST_SUPER = 8
ST_WIN = 9
X_MIN = 256
X_MAX = 3840
VRAM_BG1_TILES = $0000
VRAM_FONT      = $3000
VRAM_BG3_MAP   = $3C00
VRAM_BG1_MAP   = $4000
VRAM_OBJ       = $6000
HUD_PAL_WORD   = (5 << 10) | (1 << 13)    ; BG3 palette 5, priority 1
SKY_COLOUR     = 12959                     ; rgb(252,162,100) in BGR555
POSES_PER_CHAR = 56

; ------------------------------------------------------------------ variables
.segment "ZEROPAGE"
fx:       .res 4
fy:       .res 4
fvx:      .res 4
fvy:      .res 4
fface:    .res 4
fchar:    .res 4
fhp:      .res 4
fmeter:   .res 4
fstate:   .res 4
ftimer:   .res 4
fmove:    .res 4
fhitdone: .res 4
flast:    .res 4
fflash:   .res 4
fwins:    .res 4
fscript:  .res 4
fkey:     .res 4
fhold:    .res 4
fcell:    .res 4
fshown:   .res 4
fboxset:  .res 4
factive:  .res 4
in_left:  .res 4
in_right: .res 4
in_up:    .res 4
in_down:  .res 4
in_punch: .res 4
in_kick:  .res 4
in_super: .res 4
spr_addr: .res 4        ; ROM address (within bank) of the shown pose block
spr_bank: .res 4        ; ROM bank of the shown pose block
pad_now:  .res 2
pad_prev: .res 2
frame_ctr:.res 2
clock:    .res 2
rng:      .res 2
ai_t:     .res 2
ai_plan:  .res 2
att:      .res 2        ; attacker index (0/2)
def:      .res 2        ; defender index (0/2)
bx:       .res 2
by:       .res 2
bw:       .res 2
bh:       .res 2
ox:       .res 2
oy:       .res 2
ow:       .res 2
oh:       .res 2
h_dmg:    .res 2
h_stun:   .res 2
h_slot:   .res 2
h_low:    .res 2
h_high:   .res 2
tmp0:     .res 2
tmp1:     .res 2
tmp2:     .res 2
tmp3:     .res 2
tmp4:     .res 2
nmi_flag: .res 2
dirty:    .res 4        ; per fighter: 1 = pose tiles must be uploaded
sec_ctr:  .res 2
nmi_t0:   .res 2
nmi_t1:   .res 2
rng_t0:   .res 2
rng_t1:   .res 2
snd_seq:  .res 1
snd_cmd:  .res 1
snd_p1:   .res 1
snd_p2:   .res 1
snd_p3:   .res 1
snd_pad:  .res 1
song_ptr: .res 2
song_base:.res 2
song_wait:.res 2
sfx_voice:.res 2
sfx_sample:.res 2

.segment "BSS"
oam_shadow: .res 544
hud_shadow: .res 192    ; BG3 rows 1..3

; ------------------------------------------------------------------ ROM data
.segment "RODATA"
.include "../gen/data.inc"
stage_tiles: .incbin "../gen/stage1.bin"
stage_tiles_end:
stage_map:   .incbin "../gen/stage1.map"
stage_pal:   .incbin "../gen/stage1.pal"
font_tiles:  .incbin "../gen/font.bin"
font_tiles_end:
char_pals:
  .incbin "../gen/char1.pal"
  .incbin "../gen/char2.pal"
  .incbin "../gen/char3.pal"
  .incbin "../gen/char4.pal"
  .incbin "../gen/char5.pal"
  .incbin "../gen/char6.pal"
  .incbin "../gen/char7.pal"
  .incbin "../gen/char8.pal"
stage_pal_slots: .byte 0, 3, 4, 5, 6, 7
.include "../gen/audio.inc"
.segment "AUDIO"            ; bank $9D: SPC driver + samples (read with long addressing)
spc_driver:  .incbin "../build/spc.bin"
spc_driver_end:
spc_samples: .incbin "../gen/spc_samples.bin"
spc_samples_end:
.segment "RODATA"

; sprite data: 448 poses x 2048 bytes in banks $81.. (16 poses per 32 KB bank), see Makefile / lorom.cfg
.macro SPRBANK n
  .segment .sprintf("SPR%02d", n)
  .incbin "../gen/sprites.bin", n * 32768, 32768
.endmacro
.repeat 28, i
  SPRBANK i
.endrepeat

; ------------------------------------------------------------------ reset
.segment "CODE"
reset:
  sei
  clc
  xce
  ai16
  ldx #$1FFF
  txs
  lda #0
  tcd
  a8
  lda #$80
  pha
  plb                       ; data bank $80: ROM tables, and the $2100/$4200 registers + WRAM mirrors
  lda #$80
  sta INIDISP               ; forced blank
  lda #1
  sta MEMSEL                ; FastROM
  stz NMITIMEN
  ; clear PPU registers
  stz OBSEL
  stz BGMODE
  stz MOSAIC
  stz BG1HOFS
  stz BG1HOFS
  stz BG1VOFS
  stz BG1VOFS
  stz BG3HOFS
  stz BG3HOFS
  stz BG3VOFS
  stz BG3VOFS
  stz W12SEL
  stz W34SEL
  stz WOBJSEL
  stz TMW
  stz TSW
  stz CGWSEL
  stz CGADSUB
  lda #$E0
  sta COLDATA
  stz SETINI
  ; clear zero page + BSS
  ai16
  ldx #0
  lda #0
: sta $0000,x
  inx
  inx
  cpx #$1000
  bne :-
  jsr init_video
  jsr spc_upload
  jsr init_game
  lda #.loword(SONG_BAYOU)
  jsr song_start
  a8
  lda #$81
  sta NMITIMEN              ; NMI + auto joypad
  lda #$0F
  sta INIDISP               ; screen on
  ai16
main_loop:
: lda nmi_flag
  beq :-
  stz nmi_flag
  jsr read_pads
  ldx #2
  jsr cpu_input
  ldx #0
  jsr update_fighter
  ldx #2
  jsr update_fighter
  jsr separate
  inc frame_ctr
  jsr tick_clock
  jsr check_round
  jsr draw_fighters
  jsr draw_hud
  jsr song_tick
  jmp main_loop

; the clock: one unit per 60 frames
tick_clock:
  lda sec_ctr
  inc a
  cmp #60
  bcc :+
  lda clock
  beq @z
  dec clock
@z:
  lda #0
: sta sec_ctr
  rts

; after a KO rests for 120 frames: score and reset the round
check_round:
  ldx #0
  jsr @chk
  ldx #2
@chk:
  lda fstate,x
  cmp #ST_KO
  bne @no
  lda ftimer,x
  cmp #120
  bcc @no
  jmp round_reset
@no:
  rts

round_reset:
  ldx #0
  jsr @one
  ldx #2
  jsr @one
  lda #1024
  sta fx
  lda #2816
  sta fx+2
  lda #1
  sta fface
  lda #$FFFF
  sta fface+2
  lda #99
  sta clock
  stz ai_t
  stz ai_plan
  rts
@one:
  lda fstate,x
  cmp #ST_KO
  bne @skip
  txa
  eor #2
  tay                       ; Y = winner
  lda fwins,y
  cmp #2
  bcs @clear
  inc a
  sta fwins,y
  bra @skip
@clear:
  stz fwins
  stz fwins+2
@skip:
  lda #HP_MAX
  sta fhp,x
  stz fmeter,x
  stz fy,x
  stz fvx,x
  stz fvy,x
  stz fstate,x
  stz ftimer,x
  stz fmove,x
  stz fflash,x
  stz flast,x
  lda #SC_IDLE
  jmp set_script

; ------------------------------------------------------------------ video init (forced blank)
.proc init_video
  a8
  lda #$09
  sta BGMODE                ; mode 1, BG3 priority
  lda #(VRAM_BG1_MAP >> 10) << 2
  sta BG1SC
  lda #(VRAM_BG3_MAP >> 10) << 2
  sta BG3SC
  lda #(VRAM_BG1_TILES >> 12)
  sta BG12NBA
  lda #(VRAM_FONT >> 12)
  sta BG34NBA
  lda #$43                  ; OBJ 8x8 / 64x64, name base $6000
  sta OBSEL
  lda #$15                  ; BG1 + BG3 + OBJ
  sta TM
  lda #$80
  sta VMAIN
  ai16
  ; stage tiles -> $0000
  lda #VRAM_BG1_TILES
  ldx #.loword(stage_tiles)
  ldy #stage_tiles_end - stage_tiles
  jsr dma_vram
  lda #VRAM_BG1_MAP
  ldx #.loword(stage_map)
  ldy #1792
  jsr dma_vram
  lda #VRAM_FONT
  ldx #.loword(font_tiles)
  ldy #font_tiles_end - font_tiles
  jsr dma_vram
  ; BG3 map: clear to 0
  lda #VRAM_BG3_MAP
  sta VMADDL
  ldx #1024
  lda #0
: sta VMDATAL
  dex
  bne :-
  ; palettes
  a8
  stz CGADD
  lda #<SKY_COLOUR
  sta CGDATA
  lda #>SKY_COLOUR
  sta CGDATA
  ; stage palettes: slots 0,3,4,5,6,7 -> cgram slot*16+1..15
  ldx #0
@pal_slot:
  a8
  lda stage_pal_slots,x
  asl a
  asl a
  asl a
  asl a
  inc a
  sta CGADD
  phx
  txa
  ai16
  and #$00FF
  sta tmp0
  asl a                     ; *2
  asl a                     ; *4
  asl a                     ; *8
  asl a                     ; *16
  sec
  sbc tmp0                  ; *15
  asl a                     ; *30 bytes per palette
  tax
  ldy #15
@pal_col:
  a8
  lda stage_pal,x
  sta CGDATA
  lda stage_pal+1,x
  sta CGDATA
  inx
  inx
  dey
  bne @pal_col
  ai16
  plx
  inx
  cpx #6
  bne @pal_slot
  ; HUD palette 5 (cgram 20..23): transparent, dark, yellow, white
  a8
  lda #21
  sta CGADD
  lda #<3138
  sta CGDATA
  lda #>3138
  sta CGDATA
  lda #<9119
  sta CGDATA
  lda #>9119
  sta CGDATA
  lda #$FF
  sta CGDATA
  lda #$7F
  sta CGDATA
  ai16
  ; OAM shadow: everything off screen
  ldx #0
  lda #$F0F0
: sta oam_shadow,x
  inx
  inx
  cpx #512
  bne :-
  lda #$0A                  ; sprites 0 and 1 large
  sta oam_shadow+512
  rts
.endproc

; DMA A = VRAM word address, X = source (bank $80), Y = byte count
.proc dma_vram
  sta VMADDL
  a8
  lda #$01
  sta DMAP0                 ; 2 registers write once, A -> B
  lda #$18
  sta BBAD0
  stx A1T0L
  lda #$80
  sta A1B0
  sty DAS0L
  lda #1
  sta MDMAEN
  ai16
  rts
.endproc

; ------------------------------------------------------------------ game init
.proc init_game
  lda #1024
  sta fx
  lda #2816
  sta fx+2
  lda #1
  sta fface
  lda #$FFFF
  sta fface+2
  lda #1
  sta fchar
  lda #2
  sta fchar+2
  lda #HP_MAX
  sta fhp
  sta fhp+2
  lda #1
  sta fboxset
  sta fboxset+2
  lda #$FFFF
  sta fshown
  sta fshown+2
  lda #99
  sta clock
  lda #12345
  sta rng
  ; OBJ palettes for the two characters
  ldx #0
  jsr set_char_pal
  ldx #2
  jsr set_char_pal
  ldx #0
  lda #SC_IDLE
  jsr set_script
  ldx #2
  lda #SC_IDLE
  jsr set_script
  jsr hud_names
  rts
.endproc

; OBJ palette for fighter X (0/2): cgram 128 + slot*16 + 1..15 from char_pals[(char-1)*30]
.proc set_char_pal
  lda fchar,x
  dec a
  sta tmp0
  asl a
  asl a
  asl a
  asl a
  sec
  sbc tmp0
  asl a                     ; (char-1)*30
  tay
  txa
  asl a
  asl a
  asl a                     ; slot*16 (X=2 -> 16)
  clc
  adc #129
  a8
  sta CGADD
  ldx #15
: lda char_pals,y
  sta CGDATA
  lda char_pals+1,y
  sta CGDATA
  iny
  iny
  dex
  bne :-
  ai16
  rts
.endproc

; ------------------------------------------------------------------ NMI: OAM, HUD rows, pose tiles
nmi:
  ai16
  pha
  phx
  phy
  phb
  a8
  lda #$80
  pha
  plb
  lda RDNMI
  ; OAM
  stz OAMADDL
  stz OAMADDH
  stz DMAP0                 ; 1 register, A -> B
  lda #$04
  sta BBAD0
  ldx #.loword(oam_shadow)
  stx A1T0L
  lda #$80
  sta A1B0
  ldx #544
  stx DAS0L
  lda #1
  sta MDMAEN
  ; HUD rows 1..3 of the BG3 map
  lda #$80
  sta VMAIN
  ldx #VRAM_BG3_MAP + 32
  stx VMADDL
  lda #$01
  sta DMAP0
  lda #$18
  sta BBAD0
  ldx #.loword(hud_shadow)
  stx A1T0L
  ldx #192
  stx DAS0L
  lda #1
  sta MDMAEN
  ; pose tiles: 8 rows of 256 bytes, ONE fighter per frame (two overrun the vertical blank; SF2T budgets the same way)
  ai16
  ldx #0
  lda dirty
  bne :+
  ldx #2
: jsr nmi_upload
  lda #1
  sta nmi_flag
  ai16
  plb
  ply
  plx
  pla
  rti

; X = fighter: if dirty, DMA its pose block (8 x 256 bytes) to its OBJ columns
.proc nmi_upload
  lda dirty,x
  beq @done
  stz dirty,x
  txa
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a                     ; X=2 -> 128 words (columns 8..15)
  clc
  adc #VRAM_OBJ
  sta nmi_t0                  ; VRAM word address of row 0
  lda spr_addr,x
  sta nmi_t1
  a8
  lda spr_bank,x
  sta A1B0
  lda #$01
  sta DMAP0
  lda #$18
  sta BBAD0
  a16
  ldy #8
@row:
  lda nmi_t0
  sta VMADDL
  lda nmi_t1
  sta A1T0L
  lda #256
  sta DAS0L
  a8
  lda #1
  sta MDMAEN
  a16
  lda nmi_t0
  clc
  adc #256
  sta nmi_t0
  lda nmi_t1
  clc
  adc #256
  sta nmi_t1
  dey
  bne @row
@done:
  rts
.endproc

; ------------------------------------------------------------------ input
; P1 pad -> in_* [0]; new presses via pad_prev
.proc read_pads
  lda pad_now
  sta pad_prev
  a8
: lda HVBJOY
  and #1
  bne :-                    ; auto joypad read in progress
  a16
  lda JOY1L
  sta pad_now
  stz in_left
  stz in_right
  stz in_up
  stz in_down
  stz in_punch
  stz in_kick
  stz in_super
  lda pad_now
  bit #$0200
  beq :+
  inc in_left
: bit #$0100
  beq :+
  inc in_right
: bit #$0800
  beq :+
  inc in_up
: bit #$0400
  beq :+
  inc in_down
: lda pad_prev
  eor #$FFFF
  and pad_now               ; newly pressed
  sta tmp0
  bit #$4040                ; Y or X
  beq :+
  inc in_punch
: lda tmp0
  bit #$8000                ; B
  beq :+
  inc in_kick
: lda tmp0
  bit #$0080                ; A
  beq :+
  inc in_super
: rts
.endproc

; CPU brain for fighter X (opponent = X^2)
.proc cpu_input
  stz in_left,x
  stz in_right,x
  stz in_up,x
  stz in_down,x
  stz in_punch,x
  stz in_kick,x
  stz in_super,x
  txa
  eor #2
  tay
  lda fx,y
  sec
  sbc fx,x
  bpl :+
  neg16
: asr4
  sta tmp2                  ; d (px)
  lda ai_t
  beq @plan
  dec ai_t
  brl @act
@plan:
  phx
  phy
  jsr rnd8
  ply
  plx
  sta tmp3                  ; r
  lda fmeter,x
  cmp #METER_MAX
  bcc @not_super
  lda tmp2
  cmp #150
  bcs @not_super
  lda tmp3
  cmp #100
  bcs @not_super
  lda #8
  sta ai_plan
  lda #4
  sta ai_t
  brl @act
@not_super:
  lda fstate,y
  cmp #ST_ATTACK
  bne @not_def
  lda tmp2
  cmp #60
  bcs @not_def
  lda tmp3
  cmp #100
  bcs @not_def
  lda #2
  sta ai_plan
  lda #18
  sta ai_t
  brl @act
@not_def:
  lda tmp2
  cmp #45
  bcc @close
  lda tmp3
  cmp #160
  bcs @f2
  lda #1
  sta ai_plan
  phx
  phy
  jsr rnd8
  ply
  plx
  and #15
  clc
  adc #10
  sta ai_t
  brl @act
@f2:
  cmp #190
  bcs @f3
  lda tmp2
  cmp #91
  bcc @f3
  lda #5
  sta ai_plan
  lda #10
  sta ai_t
  brl @act
@f3:
  lda tmp3
  cmp #220
  bcs @f4
  lda #7
  sta ai_plan
  lda #12
  sta ai_t
  brl @act
@f4:
  stz ai_plan
  lda #10
  sta ai_t
  brl @act
@close:
  lda tmp3
  cmp #80
  bcs @c2
  lda #3
  sta ai_plan
  lda #8
  sta ai_t
  brl @act
@c2:
  cmp #150
  bcs @c3
  lda #4
  sta ai_plan
  lda #10
  sta ai_t
  brl @act
@c3:
  cmp #180
  bcs @c4
  lda #6
  sta ai_plan
  lda #10
  sta ai_t
  brl @act
@c4:
  cmp #210
  bcs @c5
  lda #2
  sta ai_plan
  lda #14
  sta ai_t
  brl @act
@c5:
  cmp #230
  bcs @c6
  lda #9
  sta ai_plan
  lda #12
  sta ai_t
  brl @act
@c6:
  stz ai_plan
  lda #8
  sta ai_t
@act:
  ; fwd_right = fx[y] > fx[x]
  lda fx,y
  cmp fx,x
  beq @fr0
  bcs @fr1
@fr0:
  stz tmp3
  bra @sel
@fr1:
  lda #1
  sta tmp3
@sel:
  lda ai_plan
  cmp #1
  bne @p2
@walk_fwd:
  lda tmp3
  beq :+
  inc in_right,x
  rts
: inc in_left,x
  rts
@p2:
  cmp #2
  beq @back
  cmp #9
  bne @p5
@back:
  lda tmp3
  beq :+
  inc in_left,x
  rts
: inc in_right,x
  rts
@p5:
  cmp #5
  bne @p10
  inc in_up,x
  lda #10
  sta ai_plan
  bra @walk_fwd
@p10:
  cmp #10
  bne @p3
  lda fy,x
  clc
  adc #320
  bpl @r                    ; fy >= -320: not high enough yet
  lda tmp2
  cmp #60
  bcs @r
  inc in_kick,x
@r:
  rts
@p3:
  cmp #3
  bne @p4
  lda ai_t
  cmp #7
  bne @r
  inc in_punch,x
  rts
@p4:
  cmp #4
  bne @p6
  lda ai_t
  cmp #9
  bne @r
  inc in_kick,x
  rts
@p6:
  cmp #6
  bne @p7
  inc in_down,x
  lda ai_t
  cmp #9
  bne @r
  inc in_kick,x
  rts
@p7:
  cmp #7
  bne @p8
  inc in_down,x
  rts
@p8:
  cmp #8
  bne @r
  lda ai_t
  cmp #3
  bne @r
  inc in_super,x
  rts
.endproc

; A = rnd8 (0..255); clobbers nothing else
.proc rnd8
  lda rng
  asl a
  sta rng_t0                  ; 2r
  asl a
  asl a
  sta rng_t1                  ; 8r
  asl a
  asl a
  asl a                     ; 64r
  clc
  adc rng_t1
  clc
  adc rng_t0
  clc
  adc rng
  clc
  adc #74
  sta rng
  and #$00FF
  rts
.endproc

; A = A mod tmp0 (both small positive), via the hardware divider
.proc mod_small
  a8
  sta WRDIVL
  xba
  sta WRDIVH
  lda tmp0
  sta WRDIVB
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  a16
  lda RDMPYL
  rts
.endproc

; ------------------------------------------------------------------ script interpreter
; A = script id, X = fighter
.proc set_script
  sta fscript,x
  tay
  ldby SCRIPT_START
  sta fkey,x
  ; fall through
.endproc
.proc load_key
  lda fkey,x
  asl a
  asl a
  tay
  ldby SCRIPT_DATA
  sta fhold,x
  ldby SCRIPT_DATA+2
  sta fcell,x
  ldby SCRIPT_DATA+3
  sta fboxset,x
  ldby SCRIPT_DATA+1
  and #$0002
  beq :+
  lda #1
: sta factive,x
  lda fscript,x
  cmp #SC_IDLE
  bne @done
  ldy #SC_IDLE
  ldby SCRIPT_START
  inc a
  cmp fkey,x
  bne @done
  ldy fchar,x
  dey
  ldby CH_IDLE2
  sta fcell,x
@done:
  rts
.endproc

.proc step_script
  lda fhold,x
  cmp #2
  bcc @adv
  dec a
  sta fhold,x
  rts
@adv:
  lda fkey,x
  asl a
  asl a
  tay
  ldby SCRIPT_DATA+1
  bit #$0080
  beq @next
  bit #$0001
  beq @end
  lda fscript,x
  tay
  ldby SCRIPT_START
  sta fkey,x
  jmp load_key
@next:
  inc fkey,x
  jmp load_key
@end:
  rts
.endproc

; ------------------------------------------------------------------ boxes
; attacker att vs defender def: A = hurt slot hit (1 head, 2 body, 3 legs) or 0
.proc hit_test
  ldx att
  ldy fmove,x
  ldby M_BOX
  bne :+
  rts
: sta tmp3                  ; b
  tay
  ldsby ABOX_CX
  ldy fface,x
  cpy #1
  beq :+
  neg16
: sta tmp0
  lda fx,x
  asr4
  clc
  adc tmp0
  sta bx
  ldy tmp3
  ldsby ABOX_CY
  sta tmp0
  lda fy,x
  asr4
  neg16
  clc
  adc tmp0
  sta by
  ldby ABOX_HW
  sta bw
  ldby ABOX_HH
  sta bh
  ldx def
  lda fboxset,x
  tay
  ldby BS_HEAD
  sta tmp0
  lda #1
  sta tmp1
  jsr hurt_slot
  bne @hit
  ldy fboxset,x
  ldby BS_BODY
  sta tmp0
  lda #2
  sta tmp1
  jsr hurt_slot
  bne @hit
  ldy fboxset,x
  ldby BS_LEGS
  sta tmp0
  lda #3
  sta tmp1
  jsr hurt_slot
  bne @hit
  lda #0
@hit:
  rts
.endproc

; X = defender, tmp0 = hurt box index (0 = none), tmp1 = slot id. A = slot if overlap else 0
.proc hurt_slot
  lda tmp0
  bne :+
  rts
: tay
  ldby HBOX_CX                 ; always 0 in the data, but keep the facing flip for completeness
  ldy fface,x
  cpy #1
  beq :+
  neg16
: sta tmp2
  lda fx,x
  asr4
  clc
  adc tmp2
  sta ox
  ldy tmp0
  ldby HBOX_CY
  sta tmp2
  lda fy,x
  asr4
  neg16
  clc
  adc tmp2
  sta oy
  ldby HBOX_HW
  sta ow
  ldby HBOX_HH
  sta oh
  ; overlap test
  lda bx
  sec
  sbc ox
  bpl :+
  neg16
: sta tmp2
  lda bw
  clc
  adc ow
  cmp tmp2
  bcc @no                   ; bw+ow < dx
  lda by
  sec
  sbc oy
  bpl :+
  neg16
: sta tmp2
  lda bh
  clc
  adc oh
  cmp tmp2
  bcc @no
  lda tmp1
  rts
@no:
  lda #0
  rts
.endproc

; push boxes keep the fighters apart
.proc separate
  lda fstate
  cmp #ST_KO
  beq @ret0
  lda fstate+2
  cmp #ST_KO
  beq @ret0
  ldy fboxset
  ldby BS_PUSH
  beq @ret0
  sta tmp0                  ; p1
  ldy fboxset+2
  ldby BS_PUSH
  bne @go
@ret0:
  rts
@go:
  sta tmp1                  ; p2
  lda fx+2
  sec
  sbc fx
  sta tmp2                  ; dx
  bpl :+
  neg16
: sta tmp3                  ; ax
  ldy tmp0
  ldby PBOX_HW
  sta tmp4
  ldy tmp1
  ldby PBOX_HW
  clc
  adc tmp4
  asl a
  asl a
  asl a
  asl a
  sta tmp4                  ; s = (hw1+hw2)*16
  ; dy check
  lda fy+2
  sec
  sbc fy
  bpl :+
  neg16
: pha
  ldy tmp0
  ldby PBOX_HH
  sta tmp0
  ldy tmp1
  ldby PBOX_HH
  clc
  adc tmp0
  asl a
  asl a
  asl a
  asl a
  sta tmp0
  pla
  cmp tmp0
  beq :+
  bcs @clamp                ; dy > hh sum: no push
: lda tmp3
  cmp tmp4
  bcs @clamp                ; ax >= s
  lda tmp4
  sec
  sbc tmp3
  lsr a                     ; push = (s - ax) / 2
  sta tmp0
  lda tmp2
  bmi @left
  lda fx
  sec
  sbc tmp0
  sta fx
  lda fx+2
  clc
  adc tmp0
  sta fx+2
  bra @clamp
@left:
  lda fx
  clc
  adc tmp0
  sta fx
  lda fx+2
  sec
  sbc tmp0
  sta fx+2
@clamp:
  ldx #0
  jsr clamp_x
  ldx #2
  jsr clamp_x
@ret:
  rts
.endproc

.proc clamp_x
  lda fx,x
  cmp #X_MIN
  bpl :+                    ; signed compare: fx - 256 >= 0
  lda #X_MIN
  sta fx,x
  rts
: cmp #X_MAX+1
  bmi :+
  lda #X_MAX
  sta fx,x
: rts
.endproc

; ------------------------------------------------------------------ fighter logic
; X = fighter, A = move id
.proc start_move
  sta fmove,x
  sta flast,x
  lda #ST_ATTACK
  sta fstate,x
  stz ftimer,x
  stz fhitdone,x
  stz fvx,x
  ldy fmove,x
  ldsby M_HOP
  beq :+
  sta fvy,x
: ldy fmove,x
  ldby M_SCRIPT
  jsr set_script
  lda #SMP_HAT
  jmp sfx_play
.endproc

; X = fighter, A = kind (1 punch, 2 kick). Returns A = move id
.proc pick_move
  sta tmp1                  ; kind
  lda fchar,x
  dec a
  tay
  cmp #0
  lda tmp1
  cmp #2
  beq @k
  ldby CH_NPUNCHES
  bra :+
@k:
  ldby CH_NKICKS
: sta tmp0                  ; n
  phx
  phy
  jsr rnd8
  jsr mod_small
  ply
  plx
  inc a
  sta tmp2                  ; k (1..n)
  jsr @lookup
  cmp flast,x
  bne @ok
  lda tmp2
  cmp tmp0
  bcc :+
  lda #0
: inc a
  sta tmp2
  jsr @lookup
@ok:
  rts
@lookup:
  ; index = (char-1)*5 + k - 1
  lda fchar,x
  dec a
  sta tmp3
  asl a
  asl a
  clc
  adc tmp3
  clc
  adc tmp2
  dec a
  tay
  lda tmp1
  cmp #2
  beq @kk
  ldby CH_PUNCHES
  rts
@kk:
  ldby CH_KICKS
  rts
.endproc

; A = 1 if fighter X holds back
.proc holding_back
  lda fface,x
  cmp #1
  bne :+
  lda in_left,x
  rts
: lda in_right,x
  rts
.endproc

; att/def set, h_dmg h_stun h_slot h_low h_high set. Returns with X = def.
.proc take_hit
  ldx def
  lda fstate,x
  cmp #ST_CROUCH+1
  bcs @no_block             ; not idle/walk/crouch
  jsr holding_back
  beq @no_block
  lda fstate,x
  cmp #ST_CROUCH
  beq @crouching
  lda h_low
  bne @no_block             ; standing cannot block a low
  bra @block
@crouching:
  lda h_high
  bne @no_block             ; crouching cannot block a high
@block:
  lda #ST_BLOCK
  sta fstate,x
  lda #12
  sta ftimer,x
  lda fface,x
  asl a
  asl a
  asl a
  asl a
  asl a                     ; face*32
  neg16
  sta fvx,x
  lda fmeter,x
  clc
  adc #3
  cmp #METER_MAX
  bcc :+
  lda #METER_MAX
: sta fmeter,x
  lda #SC_BLOCK
  jsr set_script
  lda #SMP_TOM
  jmp sfx_play
@no_block:
  lda fhp,x
  sec
  sbc h_dmg
  bcs :+
  lda #0
: sta fhp,x
  lda #ST_HIT
  sta fstate,x
  lda h_stun
  sta ftimer,x
  lda fface,x
  bmi @hl
  lda #$FFD8                ; -40
  bra :+
@hl:
  lda #40
: sta fvx,x
  lda fy,x
  bpl :+
  lda #$FFD0                ; -48
  sta fvy,x
: lda #6
  sta fflash,x
  lda #SMP_SNARE
  jsr sfx_play
  ldy att
  lda fmeter,y
  clc
  adc #12
  cmp #METER_MAX
  bcc :+
  lda #METER_MAX
: sta fmeter,y
  lda fmeter,x
  clc
  adc #6
  cmp #METER_MAX
  bcc :+
  lda #METER_MAX
: sta fmeter,x
  lda h_slot
  cmp #1
  bne :+
  lda #SC_HEADSNAP
  bra @scr
: cmp #3
  bne :+
  lda #SC_STAGGER
  bra @scr
: lda #SC_GUT
@scr:
  jsr set_script
  lda fhp,x
  bne @done
  lda #ST_KO
  sta fstate,x
  stz ftimer,x
  lda #$FFB0                ; -80
  sta fvy,x
  lda fface,x
  bmi :+
  lda #$FFD0                ; -48
  bra @kv
: lda #48
@kv:
  sta fvx,x
  lda #SC_KO
  jsr set_script
  lda #SMP_CRASH
  jsr sfx_play
@done:
  rts
.endproc

.proc physics
  lda fx,x
  clc
  adc fvx,x
  sta fx,x
  lda fy,x
  bmi @air
  lda fvy,x
  beq @ground
@air:
  ldy fchar,x
  dey
  ldby CH_GRAV
  clc
  adc fvy,x
  cmp #256
  bmi :+                    ; signed < 256
  lda #255
: sta fvy,x
  clc
  adc fy,x
  bmi @still_air
  stz fy,x
  stz fvy,x
  lda fstate,x
  cmp #ST_JUMP
  beq @land
  cmp #ST_ATTACK
  bne @ground
  ldy fmove,x
  ldby M_FLAGS
  and #$0004
  beq @ground
@land:
  stz fstate,x
  stz fvx,x
  lda #SC_IDLE
  jsr set_script
  bra @ground
@still_air:
  sta fy,x
@ground:
  jmp clamp_x
.endproc

; fvx = fvx * 13 / 16 (arithmetic)
.proc decay_vx
  lda fvx,x
  sta tmp0
  asl a
  asl a
  sta tmp1                  ; 4v
  asl a                     ; 8v
  clc
  adc tmp1
  clc
  adc tmp0                  ; 13v
  asr4
  sta fvx,x
  rts
.endproc

; X = fighter (0/2); opponent = X ^ 2
.proc update_fighter
  stx att
  txa
  eor #2
  sta def
  lda fflash,x
  beq :+
  dec fflash,x
: jsr step_script
  lda fstate,x
  cmp #ST_KO
  bne @not_ko
  jsr physics
  lda fy,x
  bmi @ret
  jsr decay_vx
  lda ftimer,x
  cmp #255
  bcs @ret
  inc ftimer,x
@ret:
  rts
@not_ko:
  cmp #ST_WIN
  bne :+
  brl @ret
: cmp #ST_HIT
  beq @stunned
  cmp #ST_BLOCK
  beq @stunned
  cmp #ST_ATTACK
  beq @attack
  cmp #ST_JUMP
  bne :+
  brl @jump
: jmp grounded
@stunned:
  lda ftimer,x
  beq :+
  dec ftimer,x
: jsr physics
  jsr decay_vx
  lda ftimer,x
  bne @ret_b
  lda fy,x
  bmi @ret_b
  stz fstate,x
  stz fvx,x
  lda #SC_IDLE
  jmp set_script
@ret_b:
  rts
@attack:
  ldy fmove,x
  sty tmp3                  ; m
  lda ftimer,x
  cmp #255
  bcs :+
  inc a
  sta ftimer,x
: ldby M_LUNGE
  beq @nolunge
  sta tmp2
  ldby M_STARTUP
  sta tmp1
  ldby M_ACTIVE
  clc
  adc tmp1
  cmp ftimer,x
  bcc @nolunge              ; timer > startup+active
  lda fface,x
  bmi :+
  lda tmp2
  bra @setvx
: lda tmp2
  neg16
@setvx:
  sta fvx,x
  bra @airvx
@nolunge:
  stz fvx,x
@airvx:
  ldy tmp3
  ldby M_FLAGS
  and #$0004
  beq :+
  lda fface,x
  bmi @airl
  lda #36
  bra @airs
@airl:
  lda #$FFDC                ; -36
@airs:
  sta fvx,x
: jsr physics
  ; hit check
  lda factive,x
  bne :+
  brl @endcheck
: ldy tmp3
  ldby M_HITS
  cmp fhitdone,x
  beq @skipchk
  bcs :+
@skipchk:
  brl @endcheck
: ldy def
  lda fstate,y
  cmp #ST_KO
  bne :+
  brl @endcheck
: jsr hit_test
  ldx att
  cmp #0
  bne :+
  brl @endcheck
:
  sta h_slot
  inc fhitdone,x
  ldy tmp3
  ldby M_DMG
  sta tmp0
  ldby M_FLAGS
  and #$0010
  beq @kmul
  ldy fchar,x
  dey
  ldby CH_PMUL
  bra @mul
@kmul:
  ldy fchar,x
  dey
  ldby CH_KMUL
@mul:
  sta tmp1
  jsr mul16                 ; tmp0 * tmp1 -> A
  asr4
  sta h_dmg
  ldy tmp3
  ldby M_STUN
  sta h_stun
  ldby M_FLAGS
  and #$0001
  sta h_low
  ldby M_FLAGS
  and #$0002
  lsr a
  sta h_high
  jsr take_hit
  ldx att
  stz factive,x
@endcheck:
  ldx att
  lda fstate,x
  cmp #ST_ATTACK
  bne @ret2
  ldy tmp3
  ldby M_FLAGS
  and #$0004
  bne @ret2                 ; air moves end on landing
  ldby M_STARTUP
  sta tmp0
  ldby M_ACTIVE
  clc
  adc tmp0
  sta tmp0
  ldby M_RECOVER
  clc
  adc tmp0
  cmp ftimer,x
  beq @endmove
  bcs @ret2                 ; total > timer: still going
@endmove:
  stz fstate,x
  stz fvx,x
  lda #SC_IDLE
  jmp set_script
@ret2:
  rts
@jump:
  jsr physics
  lda fstate,x
  cmp #ST_JUMP
  bne @ret2                 ; landed this step
  lda in_punch,x
  beq :+
  lda #MV_JPUNCH
  jmp start_move
: lda in_kick,x
  beq @ret2
  lda #MV_JKICK
  jmp start_move
.endproc

; grounded: face the opponent, read the inputs
.proc grounded
  ldy def
  lda fx,y
  cmp fx,x
  beq @fl
  bcc @fl
  lda #1
  bra :+
@fl:
  lda #$FFFF
: sta fface,x
  stz fvx,x
  ; fwd = in_right if facing right else in_left
  lda fface,x
  bmi :+
  lda in_right,x
  bra @fwd
: lda in_left,x
@fwd:
  sta tmp2
  ldy fchar,x
  dey
  sty tmp1                  ; char-1
  lda fstate,x
  sta tmp3                  ; st
  lda in_super,x
  beq @n1
  lda fmeter,x
  cmp #METER_MAX
  bcc @n1
  stz fmeter,x
  lda #ST_SUPER
  sta fstate,x
  stz ftimer,x
  stz fhitdone,x
  lda #SC_SUPER
  jmp set_script
@n1:
  lda in_kick,x
  beq @n2
  lda in_down,x
  beq @n2
  ldy tmp1
  ldby CH_LOWK
  jmp start_move
@n2:
  lda in_punch,x
  beq @n3
  lda in_down,x
  beq @n3
  ldy tmp1
  ldby CH_LOWP
  jmp start_move
@n3:
  lda in_punch,x
  beq @n4
  lda tmp2
  beq @n4
  ldy tmp1
  ldby CH_FWDP
  jmp start_move
@n4:
  lda in_kick,x
  beq @n5
  lda tmp2
  beq @n5
  ldy tmp1
  ldby CH_FWDK
  jmp start_move
@n5:
  lda in_punch,x
  beq @n6
  lda #1
  jsr pick_move
  jmp start_move
@n6:
  lda in_kick,x
  beq @n7
  lda #2
  jsr pick_move
  jmp start_move
@n7:
  lda in_up,x
  beq @n8
  lda #ST_JUMP
  sta fstate,x
  ldy tmp1
  tya
  asl a
  tay
  lda CH_JUMP,y
  sta fvy,x
  lda in_left,x
  beq :+
  lda #$FFDA                ; -38
  sta fvx,x
  bra @j
: lda in_right,x
  beq @j
  lda #38
  sta fvx,x
@j:
  lda #SC_JUMP
  jsr set_script
  jmp physics
@n8:
  lda in_down,x
  beq @n9
  lda tmp3
  cmp #ST_CROUCH
  beq :+
  lda #SC_CROUCH
  jsr set_script
: lda #ST_CROUCH
  sta fstate,x
  rts
@n9:
  lda in_left,x
  ora in_right,x
  beq @idle
  lda tmp3
  cmp #ST_WALK
  beq :+
  lda #SC_WALK
  jsr set_script
: lda #ST_WALK
  sta fstate,x
  ; dir
  lda in_left,x
  beq @dr
  lda #$FFFF
  bra @dir
@dr:
  lda #1
@dir:
  sta tmp2                  ; dir
  cmp fface,x
  beq @fwdwalk
  ldy tmp1
  ldby CH_WALKBACK
  bra @spd
@fwdwalk:
  ldy tmp1
  ldby CH_WALK
@spd:
  ldy tmp2
  cpy #1
  beq :+
  neg16
: sta fvx,x
  jmp physics
@idle:
  lda tmp3
  cmp #ST_IDLE
  beq :+
  lda #SC_IDLE
  jsr set_script
: stz fstate,x
  rts
.endproc

; A = tmp0 * tmp1 (unsigned, small)
.proc mul16
  lda #0
  ldy #8
@l:
  lsr tmp1
  bcc :+
  clc
  adc tmp0
: asl tmp0
  dey
  bne @l
  rts
.endproc

; ------------------------------------------------------------------ drawing
.proc draw_fighters
  ldx #0
  jsr @one
  ldx #2
@one:
  lda fcell,x
  cmp fshown,x
  beq @same
  sta fshown,x
  ; pose block address: gp = (char-1)*56 + cell ; bank = $81 + gp>>4 ; addr = $8000 + (gp&15)<<11
  lda fchar,x
  dec a
  sta tmp0
  asl a
  asl a
  asl a                     ; *8
  sta tmp1
  asl a
  asl a                     ; *32
  clc
  adc tmp1                  ; *40
  clc
  adc tmp1                  ; *48
  clc
  adc tmp1                  ; *56
  clc
  adc fcell,x
  sta tmp1                  ; gp
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc #$81
  sta spr_bank,x
  lda tmp1
  and #15
  xba                       ; <<8
  asl a
  asl a
  asl a                     ; <<11
  ora #$8000
  sta spr_addr,x
  lda #1
  sta dirty,x
@same:
  ; OAM entry X/2: x = fx>>4 - 32, y = FLOOR + fy>>4 - 64
  lda fx,x
  asr4
  sec
  sbc #32
  sta tmp0
  lda fy,x
  asr4
  clc
  adc #FLOOR-64
  sta tmp1
  lda fflash,x
  and #1
  beq :+
  lda #240
  sta tmp1                  ; hidden on odd flash frames
: txa
  asl a                     ; X=2 -> OAM entry 1 -> byte offset 4
  tay
  a8
  lda tmp0
  sta oam_shadow,y
  lda tmp1
  sta oam_shadow+1,y
  txa
  asl a
  asl a                     ; tile 0 / 8
  sta oam_shadow+2,y
  txa                       ; X=2 -> $02: palette 1 (OAM byte 3 = vhoopppN, palette in bits 1..3)
  ora #$20                  ; priority 2
  ldy fface,x
  cpy #1
  beq :+
  ora #$40                  ; h-flip
: sta tmp2
  txa
  asl a
  tay
  lda tmp2
  sta oam_shadow+3,y
  ; hi table bits: x bit 8 (bit 0 for sprite 0, bit 2 for sprite 1); size bits 1 and 3 stay set
  lda tmp0+1
  and #1                    ; 1 if x negative (bit 8 of the 9-bit x)
  sta tmp2
  lda #$FE
  cpx #2
  bne :+
  asl tmp2
  asl tmp2
  lda #$FB
: and oam_shadow+512
  ora tmp2
  ora #$0A
  sta oam_shadow+512
  a16
  rts
.endproc

; glyphs: A=1..Z=26, 0..9 = 27..36, 43 health full, 44 empty, 45 meter full, 46 empty
.proc draw_hud
  ; row 1 (shadow bytes 0..63): P1 health at columns 1..12 (i -> col 12-i), P2 at 19..30
  lda fhp
  clc
  adc #7
  lsr a
  lsr a
  lsr a
  sta tmp0                  ; h1 cells
  lda fhp+2
  clc
  adc #7
  lsr a
  lsr a
  lsr a
  sta tmp1
  ldy #0
@hp:
  lda #44
  cpy tmp0
  bcs :+
  lda #43
: ora #HUD_PAL_WORD
  sta tmp2
  tya
  eor #$FFFF
  inc a
  clc
  adc #12                   ; col 12 - i
  asl a
  tax
  lda tmp2
  sta hud_shadow,x
  lda #44
  cpy tmp1
  bcs :+
  lda #43
: ora #HUD_PAL_WORD
  sta tmp2
  tya
  clc
  adc #19
  asl a
  tax
  lda tmp2
  sta hud_shadow,x
  iny
  cpy #12
  bne @hp
  ; row 3 (bytes 128..191): meter, 6 cells each
  lda fmeter
  lsr a
  lsr a
  lsr a
  lsr a
  sta tmp0
  lda fmeter+2
  lsr a
  lsr a
  lsr a
  lsr a
  sta tmp1
  ldy #0
@mt:
  lda #46
  cpy tmp0
  bcs :+
  lda #45
: ora #HUD_PAL_WORD
  sta tmp2
  tya
  eor #$FFFF
  inc a
  clc
  adc #12
  asl a
  tax
  lda tmp2
  sta hud_shadow+128,x
  lda #46
  cpy tmp1
  bcs :+
  lda #45
: ora #HUD_PAL_WORD
  sta tmp2
  tya
  clc
  adc #19
  asl a
  tax
  lda tmp2
  sta hud_shadow+128,x
  iny
  cpy #6
  bne @mt
  ; clock at row 2 columns 15,16
  lda clock
  sta tmp0
  lda #10
  sta tmp1
  jsr div_small             ; A = quotient, tmp2 = remainder
  clc
  adc #27
  ora #HUD_PAL_WORD
  sta hud_shadow+64+30
  lda tmp2
  clc
  adc #27
  ora #HUD_PAL_WORD
  sta hud_shadow+64+32
  rts
.endproc

; tmp0 / tmp1 -> A quotient, tmp2 remainder (hardware divider)
.proc div_small
  a8
  lda tmp0
  sta WRDIVL
  lda tmp0+1
  sta WRDIVH
  lda tmp1
  sta WRDIVB
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  a16
  lda RDMPYL
  sta tmp2
  lda RDDIVL
  rts
.endproc

; names on row 2: P1 columns 2..9, P2 columns 24..31
.proc hud_names
  lda fchar
  dec a
  asl a
  asl a
  asl a
  tay                       ; (char-1)*8
  ldx #0
: ldby CH_NAME
  ora #HUD_PAL_WORD
  sta hud_shadow+64+4,x
  iny
  inx
  inx
  cpx #16
  bne :-
  lda fchar+2
  dec a
  asl a
  asl a
  asl a
  tay
  ldx #0
: ldby CH_NAME
  ora #HUD_PAL_WORD
  sta hud_shadow+64+48,x
  iny
  inx
  inx
  cpx #16
  bne :-
  rts
.endproc

; ------------------------------------------------------------------ audio: SPC upload, commands, sequencer, sfx
; Upload the driver ($0200) and the sample block ($0300..) through the IPL ROM, then run the driver.
.proc spc_upload
  a8
: lda APUIO0
  cmp #$AA
  bne :-
  lda APUIO1
  cmp #$BB
  bne :-
  ldx #$0200
  stx APUIO2
  lda #1
  sta APUIO1
  lda #$CC
  sta APUIO0
: cmp APUIO0
  bne :-
  ldx #0
  ldy #0
@b1:
  lda f:spc_driver,x
  sta APUIO1
  tya
  sta APUIO0
: cmp APUIO0
  bne :-
  iny
  inx
  cpx #spc_driver_end - spc_driver
  bne @b1
  ; second block
  ldx #SPC_SAMPLES_ADDR
  stx APUIO2
  lda #1
  sta APUIO1
  tya
  inc a
  sta APUIO0
: cmp APUIO0
  bne :-
  ldx #0
  ldy #0
@b2:
  lda f:spc_samples,x
  sta APUIO1
  tya
  sta APUIO0
: cmp APUIO0
  bne :-
  iny
  inx
  cpx #spc_samples_end - spc_samples
  bne @b2
  ; run
  ldx #$0200
  stx APUIO2
  stz APUIO1
  tya
  inc a
  sta APUIO0
: cmp APUIO0
  bne :-
  ai16
  stz snd_seq
  rts
.endproc

; send snd_cmd (op | voice) with snd_p1..3; waits for the echo (bounded)
.proc spc_cmd
  a8
  lda snd_seq
  clc
  adc #8
  and #$38
  sta snd_seq
  ora snd_cmd
  sta snd_cmd
  lda snd_p1
  sta APUIO1
  lda snd_p2
  sta APUIO2
  lda snd_p3
  sta APUIO3
  lda snd_cmd
  sta APUIO0
  ldy #4000
: cmp APUIO0
  beq @ok
  dey
  bne :-
@ok:
  a16
  rts
.endproc

; A = song address (bank $80)
.proc song_start
  sta song_ptr
  sta song_base
  lda (song_ptr)
  and #$00FF
  sta song_wait
  rts
.endproc

.proc song_tick
  lda song_wait
  beq @run
  dec song_wait
  rts
@run:
  a8
  ldy #1
  lda (song_ptr),y
  cmp #$FE
  beq @loop
  cmp #$FF
  beq @next
  sta snd_cmd
  iny
  lda (song_ptr),y
  sta snd_p1
  iny
  lda (song_ptr),y
  sta snd_p2
  iny
  lda (song_ptr),y
  sta snd_p3
  jsr spc_cmd
  a8
@next:
  a16
  lda song_ptr
  clc
  adc #5
  sta song_ptr
  bra @wait
@loop:
  a16
  lda song_base
  sta song_ptr
@wait:
  lda (song_ptr)
  and #$00FF
  sta song_wait
  bne @done
  bra @run
@done:
  rts
.endproc

; A = sample id; alternates voices 6 and 7; preserves X and Y
.proc sfx_play
  phx
  phy
  sta sfx_sample
  lda sfx_voice
  eor #1
  sta sfx_voice
  ora #6
  sta tmp0
  a8
  lda tmp0
  sta snd_cmd               ; op 00: volume
  lda #60
  sta snd_p1
  sta snd_p2
  jsr spc_cmd
  a8
  lda tmp0
  ora #$40
  sta snd_cmd               ; op 01: note on
  lda sfx_sample
  sta snd_p1
  stz snd_p2
  lda #$10
  sta snd_p3                ; pitch $1000 = native rate
  jsr spc_cmd
  ply
  plx
  rts
.endproc

irq:
  rti

; ------------------------------------------------------------------ header + vectors
.segment "HEADER"
  .byte "BABY BEATDOWN        "   ; 21 bytes
  .byte $30                       ; LoROM, FastROM
  .byte $00                       ; ROM only
  .byte $0A                       ; 1 MB
  .byte $07                       ; 128 KB SRAM (used only as the test-runner screenshot channel)
  .byte $01                       ; NTSC
  .byte $33
  .byte $00                       ; version
  .word $0000                     ; checksum complement (patched by tools/fixsum.py)
  .word $0000                     ; checksum

.segment "VECTORS"
  ; native: (2 unused) COP BRK ABORT NMI (unused) IRQ
  .word 0, 0, .loword(irq), .loword(irq), .loword(irq), .loword(nmi), .loword(irq), .loword(irq)
  ; emulation: (2 unused) COP (unused) ABORT NMI RESET IRQ/BRK
  .word 0, 0, .loword(irq), .loword(irq), .loword(irq), .loword(nmi), .loword(reset), .loword(irq)
