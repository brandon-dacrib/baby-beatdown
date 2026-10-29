; screens.s: title, player select, fight flow (rounds, callouts, match end, attract demo), stage loading,
; HDMA sky gradient + per-scanline scroll bands, ambient sprites (birds, butterflies, crowd, candles),
; palette cycling, shadows, hit sparks, text. Included from main.s inside the CODE segment.
; Convention: procedures are entered and left with A/X/Y 16-bit.

MODE_TITLE  = 0
MODE_SELECT = 1
MODE_FIGHT  = 2
RS_INTRO = 0
RS_FIGHT = 1
RS_END   = 2
RS_MATCH = 3
PAL5 = (5 << 10) | (1 << 13)        ; yellow text
PAL6 = (6 << 10) | (1 << 13)        ; red text
PAL7 = (7 << 10) | (1 << 13)        ; white text
BTN_ANY = $F0C0                     ; B Y Select Start A X
GRID_X = 112
GRID_Y = 112

; glyph ids in string constants from here on
.repeat 26, i
  .charmap 65 + i, 1 + i
.endrepeat
.repeat 10, i
  .charmap 48 + i, 27 + i
.endrepeat
.charmap 33, 37                     ; !
.charmap 46, 38                     ; .
.charmap 45, 39                     ; -
.charmap 58, 40                     ; :
.charmap 32, 0                      ; space

.macro TEXT str, col, row, pal
  lda #.loword(str)
  sta ptr0
  lda #pal
  sta tmp4
  ldx #(row) * 64 + (col) * 2
  jsr text_at
.endmacro
.macro CLEAR_ROW row
  ldx #(row) * 64
  jsr clear_row
.endmacro

; ------------------------------------------------------------------ text
; glyph string at ptr0 ($FF terminated) -> bg3_shadow + X, palette word tmp4
.proc text_at
  ldy #0
@l:
  a8
  lda (ptr0),y
  cmp #$FF
  beq @done
  a16
  and #$00FF
  ora tmp4
  sta bg3_shadow,x
  inx
  inx
  iny
  bra @l
@done:
  a16
  rts
.endproc

; 8 glyphs at ptr0 (a name: 0 = blank) -> bg3_shadow + X, palette tmp4
.proc text_name
  ldy #0
@l:
  a8
  lda (ptr0),y
  a16
  and #$00FF
  ora tmp4
  sta bg3_shadow,x
  inx
  inx
  iny
  cpy #8
  bne @l
  rts
.endproc

; A = character 1..8 -> ptr0 = its name
.proc name_ptr
  dec a
  asl a
  asl a
  asl a
  clc
  adc #.loword(CH_NAME)
  sta ptr0
  rts
.endproc

.proc clear_row                     ; X = byte offset of the row
  lda #0
  ldy #32
: sta bg3_shadow,x
  inx
  inx
  dey
  bne :-
  rts
.endproc

.proc clear_bg3
  ldx #0
  lda #0
: sta bg3_shadow,x
  inx
  inx
  cpx #1792
  bne :-
  rts
.endproc

; A = 0..99 -> two digit glyphs at bg3_shadow + X, palette tmp4
.proc text_num2
  sta tmp0
  lda #10
  sta tmp1
  phx
  jsr div_small
  plx
  clc
  adc #27
  ora tmp4
  sta bg3_shadow,x
  lda tmp2
  clc
  adc #27
  ora tmp4
  sta bg3_shadow+2,x
  rts
.endproc

; ------------------------------------------------------------------ frames and fades
.proc wait_frame
: lda nmi_flag
  beq :-
  stz nmi_flag
  jmp song_tick
.endproc

.proc fade_out                      ; 15 -> forced blank over 32 frames, music keeps playing
  lda #15
  sta fade_v
@l:
  jsr wait_frame
  jsr wait_frame
  a8
  lda fade_v
  sta INIDISP
  a16
  dec fade_v
  bpl @l
  a8
  lda #$80
  sta INIDISP
  stz HDMAEN                ; no HDMA, no NMI while palettes and VRAM are loaded (both move PPU addresses)
  lda #$01
  sta NMITIMEN
  a16
  rts
.endproc

.proc fade_in
  stz fade_v
  a8
  lda #$0E
  sta HDMAEN                ; sky gradient (1, 3) + scroll bands (2)
  lda #$81
  sta NMITIMEN              ; NMI + auto joypad
  a16
  stz nmi_flag
@l:
  jsr wait_frame
  jsr wait_frame
  a8
  lda fade_v
  sta INIDISP
  a16
  inc fade_v
  lda fade_v
  cmp #16
  bne @l
  rts
.endproc

.proc any_button
  lda pad_new
  and #BTN_ANY
  rts
.endproc

.proc clear_inputs
  ldx #0
: stz in_left,x
  stz in_right,x
  stz in_up,x
  stz in_down,x
  stz in_punch,x
  stz in_kick,x
  stz in_super,x
  inx
  inx
  cpx #4
  bne :-
  rts
.endproc

; ------------------------------------------------------------------ stage loading (forced blank)
; A = stage 1..9: BG1 tiles/map/palettes, sky HDMA table, ambient config
.proc load_stage
  sta stage
  asl a
  asl a
  asl a
  tax                       ; *8
  ldy stage
  a8
  lda STAGE_BANK,y
  sta dma_bank
  a16
  phx
  lda STAGE_TAB+2,x
  tay
  lda STAGE_TAB,x
  tax
  lda #VRAM_BG1_TILES
  jsr dma_vram
  plx
  phx
  lda STAGE_TAB+4,x
  tax
  ldy #1792
  lda #VRAM_BG1_MAP
  jsr dma_vram
  plx
  lda STAGE_TAB+6,x
  sta ptr0
  lda dma_bank
  and #$00FF
  sta ptr0+2
  ; six palettes of 15 colours -> cgram slot*16+1
  ldy #0
  ldx #0
@slot:
  a8
  lda stage_pal_slots,x
  asl a
  asl a
  asl a
  asl a
  inc a
  sta CGADD
  lda #15
  sta tmp3
@col:
  lda [ptr0],y
  sta CGDATA
  iny
  lda [ptr0],y
  sta CGDATA
  iny
  dec tmp3
  bne @col
  a16
  inx
  cpx #6
  bne @slot
  ; sky gradient tables for HDMA channels 1 and 3
  lda stage
  asl a
  tax
  lda SKYRG_TAB,x
  sta A1T1L
  lda SKYB_TAB,x
  sta A1T3L
  lda AMB_TAB,x
  sta amb_ptr
  ; offsets into the ambient record
  ldy #1
  lda (amb_ptr),y
  and #$00FF
  sta tmp0
  asl a
  adc tmp0
  asl a                     ; nbands*6
  clc
  adc #2
  sta amb_cyc               ; cycle index, speed, 16 colours
  clc
  adc #34
  sta amb_flk               ; flicker index, base, dark
  clc
  adc #5
  sta amb_crowd             ; n, xy pairs
  tay
  lda (amb_ptr),y
  and #$00FF
  asl a
  sec
  adc amb_crowd
  sta amb_cand              ; n, xy pairs
  jsr reset_ambient
  ; neutral scroll table until the first frame builds one: 112 + 112 lines of 0, end
  a8
  lda #112
  sta hofs_a
  stz hofs_a+1
  stz hofs_a+2
  sta hofs_a+3
  stz hofs_a+4
  stz hofs_a+5
  stz hofs_a+6
  a16
  lda #.loword(hofs_a)
  sta hofs_next
  stz hofs_flip
  rts
.endproc

; wipe the BG2 map to the blank tile
.proc clear_bg2
  lda #VRAM_BG2_MAP
  sta VMADDL
  ldx #1024
  lda #BLANK2
: sta VMDATAL
  dex
  bne :-
  rts
.endproc

; stage song A = 0..8 (8 = nursery): silence the music voices and restart the sequencer
.proc play_song
  pha
  ldx #0
@off:
  a8
  txa
  ora #$80
  sta snd_cmd
  jsr spc_cmd
  a16
  inx
  cpx #6
  bne @off
  pla
  asl a
  tax
  lda SONG_TAB,x
  sta sng
  txa
  lsr a
  tax
  a8
  lda SONG_BANK,x
  sta sng+2
  a16
  lda sng
  sta sng_base
  lda [sng]
  and #$00FF
  sta song_wait
  rts
.endproc

; ------------------------------------------------------------------ title
.proc go_title
  jsr fade_out
  jsr hide_all
  stz demo
  stz two_p
  lda #MODE_TITLE
  sta mode
  stz mtimer
  stz sel_t                 ; attract timer (survives the stage re-rolls)
  jsr title_setup
  jmp fade_in
.endproc

.proc pick_pair                     ; fchar = a, fchar+2 = b != a
  jsr rnd8
  and #7
  inc a
  sta fchar
  jsr rnd8
  and #7
  inc a
  cmp fchar
  bne :+
  and #7
  inc a
: sta fchar+2
  rts
.endproc

.proc title_setup
  jsr pick_pair
  jsr rnd8
  and #7
  inc a
  jsr load_stage
  lda stage
  dec a
  jsr play_song
  jsr fighters_reset
  lda #1088
  sta fx
  lda #3008
  sta fx+2
  jsr restore_obj_pals
  ; logo on BG2 rows 3..5, columns 3..28 (palette 2)
  jsr clear_bg2
  ldy #0
  lda #VRAM_BG2_MAP + 3 * 32 + 3
  sta tmp0
@row:
  lda tmp0
  sta VMADDL
  ldx #26
@tile:
  tya
  clc
  adc #LOGO_TILE | (2 << 10) | (1 << 13)
  sta VMDATAL
  iny
  dex
  bne @tile
  lda tmp0
  clc
  adc #32
  sta tmp0
  cpy #78
  bne @row
  jsr clear_bg3
  TEXT s_tagline, 5, 7, PAL7
  TEXT s_onep, 2, 25, PAL5
  a8
  lda #$17                  ; BG1 + BG2 + BG3 + OBJ
  sta TM
  a16
  rts
.endproc

.proc title_frame
  inc mtimer
  inc sel_t
  jsr clear_inputs
  lda mtimer
  sta tmp0
  lda #60
  sta tmp1
  jsr div_small
  lda tmp2
  cmp #40
  bcs @off
  TEXT s_push, 11, 10, PAL5
  bra @blink_done
@off:
  CLEAR_ROW 10
@blink_done:
  lda mtimer
  sta tmp0
  lda #240
  sta tmp1
  jsr div_small
  lda tmp2
  cmp #90
  bne :+
  inc in_punch
: cmp #170
  bne :+
  inc in_kick+2
: ldx #0
  jsr update_fighter
  ldx #2
  jsr update_fighter
  lda #1088                 ; the demo pair pose in place (lunges would walk them into each other)
  sta fx
  lda #3008
  sta fx+2
  stz fvx
  stz fvx+2
  jsr draw_fighters
  jsr draw_shadows
  lda pad2_new
  and #$1000                ; Start on pad 2: two players
  beq :+
  lda #1
  sta two_p
  jsr sfx_select_c
  jmp go_select
: jsr any_button
  beq :+
  stz two_p
  jsr sfx_select_c
  jmp go_select
: lda mtimer
  cmp #420
  bne :+
  jsr fade_out
  jsr title_setup
  jsr fade_in
  lda #1
  sta mtimer
: lda sel_t
  cmp #900
  bne :+
  jmp start_demo
: rts
.endproc

; ------------------------------------------------------------------ player select
.proc go_select
  jsr fade_out
  jsr hide_all
  lda #MODE_SELECT
  sta mode
  stz mtimer
  lda #1
  sta sel_cur
  stz sel_cpu
  lda two_p
  beq :+
  lda #2
  sta sel_cpu               ; 2P: the second cursor
: stz sel_t
  stz sel_ok1
  stz sel_ok2
  lda #9
  jsr load_stage
  lda #8
  jsr play_song
  ; icons -> OBJ rows 0..7 (icon i: tile (i/4)*64 + (i%4)*4), palettes -> OBJ palettes 0..7
  ldx #0
@icon:
  stx tmp3
  a8
  lda ICON_BANK,x
  sta dma_bank
  a16
  txa
  asl a
  tay
  lda ICON_TAB,y
  sta tmp0                  ; source
  txa
  and #3
  asl a
  asl a                     ; (i%4)*4 tiles
  sta tmp1
  txa
  and #4                    ; (i/4)*4 -> rows 4.. = 64 tiles
  asl a
  asl a
  asl a
  asl a
  clc
  adc tmp1
  asl a
  asl a
  asl a
  asl a                     ; tile * 16 words
  clc
  adc #VRAM_OBJ
  sta tmp1
  ldy #4
@irow:
  phy
  lda tmp1
  ldx tmp0
  ldy #128
  jsr dma_vram
  lda tmp1
  clc
  adc #256
  sta tmp1
  lda tmp0
  clc
  adc #128
  sta tmp0
  ply
  dey
  bne @irow
  ; palette
  lda tmp3
  asl a
  asl a
  asl a
  asl a
  clc
  adc #129
  a8
  sta CGADD
  a16
  lda tmp3
  asl a
  asl a
  asl a
  asl a
  sec
  sbc tmp3
  asl a                     ; i*30
  tay
  ldx #15
@pc:
  a8
  lda FACE_PALS,y
  sta CGDATA
  lda FACE_PALS+1,y
  sta CGDATA
  a16
  iny
  iny
  dex
  bne @pc
  ldx tmp3
  inx
  cpx #8
  beq :+
  brl @icon
:
  ; BG2 map: portrait at rows 15..26, columns 1..12
  jsr clear_bg2
  ldy #0
  lda #VRAM_BG2_MAP + 15 * 32 + 1
  sta tmp0
@prow:
  lda tmp0
  sta VMADDL
  ldx #12
@pt:
  tya
  clc
  adc #FACE_TILE
  sta VMDATAL
  iny
  dex
  bne @pt
  lda tmp0
  clc
  adc #32
  sta tmp0
  cpy #144
  bne @prow
  stz face_shown
  jsr show_face
  ; the first portrait is uploaded now (forced blank) rather than through the NMI queue
: lda face_up
  beq :+
  jsr nmi_face_half
  bra :-
: jsr clear_bg3
  a8
  lda #$17
  sta TM
  a16
  jmp fade_in
.endproc

; portrait of sel_cur: palette request + two-frame tile upload through the NMI
.proc show_face
  lda sel_cur
  cmp face_shown
  bne :+
  rts
: sta face_shown
  dec a
  sta tmp0
  asl a
  asl a
  asl a
  asl a
  sec
  sbc tmp0
  asl a                     ; (c-1)*30
  clc
  adc #.loword(FACE_PALS)
  sta pal_ptr
  lda #1
  sta pal_idx               ; cgram 1..15 (BG palette 0)
  lda #2
  sta face_up
  rts
.endproc

; called from the NMI (or under forced blank): upload half of the portrait (72 tiles = 2304 bytes)
.proc nmi_face_half
  lda face_up
  beq @done
  ldx face_shown
  dex
  a8
  lda FACE_BANK,x
  sta A1B0
  lda #$01
  sta DMAP0
  lda #$18
  sta BBAD0
  a16
  txa
  asl a
  tax
  lda FACE_TAB,x
  sta nmi_t1
  lda #VRAM_BG2_TILES + FACE_TILE * 16
  sta nmi_t0
  lda face_up
  cmp #1
  bne :+
  lda nmi_t1
  clc
  adc #2304
  sta nmi_t1
  lda nmi_t0
  clc
  adc #1152
  sta nmi_t0
: lda nmi_t0
  sta VMADDL
  lda nmi_t1
  sta A1T0L
  lda #2304
  sta DAS0L
  a8
  lda #1
  sta MDMAEN
  a16
  dec face_up
@done:
  rts
.endproc

.proc sfx_select_c
  lda SEL_PITCH
  sta sfx_pitch
  lda #SMP_PLUCK
  jmp sfx_play
.endproc
.proc sfx_select_e
  lda SEL_PITCH+2
  sta sfx_pitch
  lda #SMP_PLUCK
  jmp sfx_play
.endproc
.proc sfx_select_g
  lda SEL_PITCH+4
  sta sfx_pitch
  lda #SMP_PLUCK
  jmp sfx_play
.endproc

; cursor cell -> tmp0 = column, tmp1 = row (BG3 map) for character A (1..8)
.proc cell_pos
  dec a
  sta tmp2
  and #3
  asl a
  asl a
  clc
  adc #GRID_X / 8
  sta tmp0
  lda tmp2
  and #4
  clc
  adc #GRID_Y / 8
  sta tmp1
  rts
.endproc

; bracket of tile 49 around the 4x4 cell at tmp0/tmp1, palette word tmp4
.proc bracket
  lda tmp1
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a                     ; row*64
  sta tmp2
  lda tmp0
  asl a
  clc
  adc tmp2
  tax
  lda #49
  ora tmp4
  sta bg3_shadow,x
  ora #$4000
  sta bg3_shadow+6,x
  eor #$C000
  sta bg3_shadow+192,x
  ora #$4000
  sta bg3_shadow+198,x
  rts
.endproc

.proc select_frame
  inc mtimer
  jsr clear_inputs
  lda mtimer
  cmp #12
  bcc @draw                 ; input lockout: the press that opened this screen must not pick
  lda two_p
  bne @two
  lda sel_cpu
  bne @waiting
  jsr p1_moves
  jsr any_button
  beq @draw
  jsr rnd8
  and #7
  inc a
  sta sel_cpu
  stz sel_t
  jsr sfx_select_g
  bra @draw
@waiting:
  inc sel_t
  lda sel_t
  cmp #110
  bcc @draw
  jmp start_match
@two:
  lda sel_ok1
  bne :+
  jsr p1_moves
  jsr any_button
  beq :+
  inc sel_ok1
  jsr sfx_select_g
: lda sel_ok2
  bne :+
  jsr p2_moves
  lda pad2_new
  and #BTN_ANY
  beq :+
  inc sel_ok2
  jsr sfx_select_g
: lda sel_ok1
  beq @draw
  lda sel_ok2
  beq @draw
  inc sel_t
  lda sel_t
  cmp #60
  bcc @draw
  jmp start_match
@draw:
  lda sel_cpu
  ldy two_p
  beq :+
  lda sel_ok1
: sta p1_done
  jsr show_face
  jsr clear_bg3
  TEXT s_pselect, 9, 1, PAL7
  lda sel_cur
  jsr cell_pos
  lda #PAL5
  sta tmp4
  jsr bracket
  ; "1P" above the cursor, blinking until the pick
  lda mtimer
  and #16
  beq @one_p
  lda p1_done
  beq @no_1p
@one_p:
  lda tmp1
  dec a
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a
  sta tmp2
  lda tmp0
  inc a
  asl a
  clc
  adc tmp2
  tax
  lda #.loword(s_1p)
  sta ptr0
  jsr text_at
@no_1p:
  TEXT s_1p, 1, 13, PAL5
  lda sel_cur
  jsr name_ptr
  ldx #14 * 64 + 2
  lda #PAL5
  sta tmp4
  jsr text_name
  lda sel_cur
  lda #PAL5
  sta tmp4
  lda sel_cur
  jsr loc_label
  lda sel_cpu
  bne :+
  jmp @icons
: ; CPU / 2P pick in red
  lda #PAL6
  sta tmp4
  lda sel_cpu
  jsr cell_pos
  jsr bracket
  lda tmp1
  dec a
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a
  sta tmp2
  lda tmp0
  asl a
  clc
  adc tmp2
  tax
  lda #.loword(s_cpu)
  ldy two_p
  beq :+
  lda #.loword(s_2p)
: sta ptr0
  jsr text_at
  lda sel_cpu
  jsr loc_label
  lda two_p
  bne :+
  TEXT s_vscpu, 12, 23, PAL6
  bra @vs_done
: TEXT s_vs2p, 12, 23, PAL6
@vs_done:
  lda sel_cpu
  jsr name_ptr
  ldx #23 * 64 + 19 * 2
  jsr text_name
  TEXT s_stage, 12, 24, PAL5
  lda sel_cpu
  dec a
  asl a
  asl a
  asl a
  clc
  adc #.loword(STAGE_NAME)
  sta ptr0
  ldx #24 * 64 + 18 * 2
  lda #PAL5
  sta tmp4
  jsr text_name
@icons:
  ; icons: OAM 4..11, 32x32, palette i, the cursor's bobbing
  ldx #0
@ic:
  stx tmp3
  txa
  and #3
  asl a
  asl a
  asl a
  asl a
  asl a                     ; (i%4)*32
  clc
  adc #GRID_X
  sta oa_x
  txa
  and #4
  asl a
  asl a
  asl a                     ; (i/4)*32
  clc
  adc #GRID_Y
  sta oa_y
  txa
  inc a
  cmp sel_cur
  bne :+
  lda p1_done
  bne :+
  lda mtimer
  and #8
  beq :+
  dec oa_y
: txa
  and #3
  asl a
  asl a                     ; (i%4)*4
  sta tmp2
  txa
  and #4
  asl a
  asl a
  asl a
  asl a                     ; (i/4)*64
  clc
  adc tmp2
  sta oa_tile
  txa
  asl a
  ora #$20                  ; priority 2, palette i
  sta oa_attr
  stz oa_large
  txa
  clc
  adc #4
  tay
  jsr oam_set
  ldx tmp3
  inx
  cpx #8
  bne @ic
  rts
.endproc

.proc p1_moves
  lda sel_cur
  sta cur_tmp
  lda pad_new
  sta cur_pad
  jsr cursor_moves
  lda cur_tmp
  sta sel_cur
  rts
.endproc
.proc p2_moves
  lda sel_cpu
  sta cur_tmp
  lda pad2_new
  sta cur_pad
  jsr cursor_moves
  lda cur_tmp
  sta sel_cpu
  rts
.endproc
; cur_tmp moved by the new presses in cur_pad
.proc cursor_moves
  lda cur_pad
  bit #$0200                ; left
  beq :+
  lda #$FFFF
  jsr move_cursor_x
: lda cur_pad
  bit #$0100                ; right
  beq :+
  lda #1
  jsr move_cursor_x
: lda cur_pad
  bit #$0C00                ; up / down
  beq :+
  lda cur_tmp
  cmp #5
  bcs @up
  clc
  adc #4
  bra @set
@up:
  sec
  sbc #4
@set:
  sta cur_tmp
  jsr sfx_select_e
: rts
.endproc
; A = +1 / -1: move cur_tmp within its row of four
.proc move_cursor_x
  sta tmp2
  lda cur_tmp
  dec a
  and #4
  sta tmp3                  ; row base
  lda cur_tmp
  dec a
  and #3
  clc
  adc tmp2
  and #3
  clc
  adc tmp3
  inc a
  sta cur_tmp
  jmp sfx_select_e
.endproc

; stage label of character A lit in palette tmp4
.proc loc_label
  tax
  dex
  lda SEL_LOC_ROW,x
  and #$00FF
  asl a
  asl a
  asl a
  asl a
  asl a
  asl a
  sta tmp2
  lda SEL_LOC_COL,x
  and #$00FF
  asl a
  clc
  adc tmp2
  sta tmp2
  txa
  asl a
  asl a
  asl a
  clc
  adc #.loword(STAGE_NAME)
  sta ptr0
  ldx tmp2
  jmp text_name
.endproc

; ------------------------------------------------------------------ fight
; OBJ palettes 0/1 = fighters, 2 = effects, 4 = shadow (black, blended)
.proc restore_obj_pals
  ldx #0
  jsr set_char_pal
  ldx #2
  jsr set_char_pal
  a8
  lda #128 + 2 * 16 + 1
  sta CGADD
  a16
  ldx #0
: a8
  lda FX_PAL,x
  sta CGDATA
  lda FX_PAL+1,x
  sta CGDATA
  a16
  inx
  inx
  cpx #30
  bne :-
  a8
  lda #128 + 4 * 16 + 1
  sta CGADD
  stz CGDATA
  stz CGDATA
  a16
  rts
.endproc

; both fighters: full health, idle, facing each other at the round start positions
.proc fighters_reset
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
  stz sec_ctr
  stz ai_t
  stz ai_plan
  stz spk_t
  stz spk_t+2
  stz pj_on
  stz pj_on+2
  stz callout_t
  rts
@one:
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
  stz fhitdone,x
  lda #$FFFF
  sta fshown,x
  lda #SC_IDLE
  jmp set_script
.endproc

.proc start_match
  jsr fade_out
  lda sel_cur
  sta fchar
  lda sel_cpu
  sta fchar+2
  jmp begin_fight
.endproc

.proc start_demo
  jsr fade_out
  jsr pick_pair
  lda #1
  sta demo
  jmp begin_fight
.endproc

; fchar set: load the CPU's stage, first round
.proc begin_fight
  jsr hide_all
  lda #MODE_FIGHT
  sta mode
  lda fchar+2
  jsr load_stage
  lda stage
  dec a
  jsr play_song
  jsr restore_obj_pals
  lda #1
  sta round_num
  stz fwins
  stz fwins+2
  jsr fighters_reset
  jsr clear_bg3
  jsr hud_names
  lda #RS_INTRO
  sta round_st
  stz round_t
  jsr clear_bg2
  a8
  lda #$15                  ; BG1 + BG3 + OBJ
  sta TM
  a16
  jmp fade_in
.endproc

.proc reset_round
  jsr fighters_reset
  lda #RS_INTRO
  sta round_st
  stz round_t
  CLEAR_ROW 10
  rts
.endproc

; A = winner (0 / 2 / $FFFF draw), tmp3 = message string
.proc fight_over
  sta winner
  bmi :+
  tax
  inc fwins,x
: lda #RS_END
  sta round_st
  stz round_t
  lda tmp3
  sta msg_ptr
  rts
.endproc

.proc fight_frame
  inc round_t
  lda demo
  beq @nodemo
  jsr any_button
  beq :+
  jmp go_title
: lda frame_ctr
  and #32
  bne :+
  TEXT s_demo, 7, 25, PAL5
  bra @nodemo
: CLEAR_ROW 25
@nodemo:
  lda round_st
  cmp #RS_FIGHT
  beq @live
  cmp #RS_INTRO
  beq @intro
  cmp #RS_END
  bne :+
  brl @end
:
  brl @match
@intro:
  jsr clear_inputs
  lda round_t
  cmp #1
  bne :+
  TEXT s_round, 12, 10, PAL5
  lda round_num
  clc
  adc #27
  ora #PAL5
  sta bg3_shadow + 10 * 64 + 18 * 2
: lda round_t
  cmp #70
  bne :+
  CLEAR_ROW 10
  TEXT s_fight, 13, 10, PAL6
: lda round_t
  cmp #110
  beq :+
  brl @update
:
  CLEAR_ROW 10
  lda #RS_FIGHT
  sta round_st
  stz round_t
  bra @update
@live:
  lda demo
  beq :+
  ldx #0
  jsr cpu_input
  jsr cpu_special
: lda two_p
  beq @cpu2
  ldx #2
  lda pad2_now
  sta tmp0
  lda pad2_new
  sta tmp1
  jsr decode_pad
  bra @in_done
@cpu2:
  ldx #2
  jsr cpu_input
  ldx #2
  jsr cpu_special
@in_done:
  jsr tick_clock
  jsr @update
  ; outcome
  lda fhp+2
  bne :+
  lda #.loword(s_ko)
  sta tmp3
  lda #0
  jmp fight_over
: lda fhp
  bne :+
  lda #.loword(s_ko)
  sta tmp3
  lda #2
  jmp fight_over
: lda clock
  bne @ret
  lda #.loword(s_timeup)
  sta tmp3
  lda fhp
  cmp fhp+2
  beq @draw
  bcc @p2
  lda #0
  jmp fight_over
@p2:
  lda #2
  jmp fight_over
@draw:
  lda #.loword(s_draw)
  sta tmp3
  lda #$FFFF
  jmp fight_over
@ret:
  rts
@update:
  ldx #0
  jsr update_fighter
  ldx #2
  jsr update_fighter
  jsr separate
  jsr update_projectiles
  jsr draw_fighters
  jsr draw_shadows
  jsr draw_sparks
  jsr draw_projectiles
  lda callout_t
  beq :+
  dec callout_t
  bne :+
  CLEAR_ROW 8
: jmp draw_hud
@end:
  jsr clear_inputs
  lda round_t
  cmp #1
  bne :+
  lda msg_ptr
  sta ptr0
  lda #PAL6
  sta tmp4
  ldx #10 * 64 + 13 * 2
  jsr text_at
: lda round_t
  cmp #60
  bne :+
  CLEAR_ROW 10
  lda winner
  bmi :+
  tax
  lda fstate,x
  cmp #ST_KO
  beq @nowin
  lda #ST_WIN
  sta fstate,x
  stz fvx,x
  lda #SC_WIN
  jsr set_script
@nowin:
  lda winner
  tax
  lda fchar,x
  jsr name_ptr
  lda #PAL5
  sta tmp4
  ldx #10 * 64 + 10 * 2
  jsr text_name
  TEXT s_wins, 18, 10, PAL5
: lda round_t
  cmp #150
  beq :+
  brl @update
:
  CLEAR_ROW 10
  lda winner
  bmi @next
  tax
  lda fwins,x
  cmp #2
  bcc @next
  lda #RS_MATCH
  sta round_st
  stz round_t
  lda winner
  tax
  lda fchar,x
  jsr name_ptr
  lda #PAL5
  sta tmp4
  ldx #10 * 64 + 4 * 2
  jsr text_name
  TEXT s_winsmatch, 12, 10, PAL5
  lda two_p
  beq :+
  brl @update
: lda winner
  bne :+
  TEXT s_naptime, 5, 12, PAL7
  brl @update
: TEXT s_waaah, 7, 12, PAL7
  brl @update
@next:
  inc round_num
  jsr reset_round
  brl @update
@match:
  jsr clear_inputs
  lda round_t
  cmp #600
  bcs @to_title
  cmp #120
  bcs :+
  brl @update
:
  jsr any_button
  bne :+
  brl @update
:
@to_title:
  jmp go_title
.endproc

; ------------------------------------------------------------------ OAM helper
; Y = sprite, oa_x (9-bit), oa_y, oa_tile, oa_attr, oa_large
.proc oam_set
  tya
  asl a
  asl a
  tax
  a8
  lda oa_x
  sta oam_shadow,x
  lda oa_y
  sta oam_shadow+1,x
  lda oa_tile
  sta oam_shadow+2,x
  lda oa_tile+1
  and #1
  ora oa_attr               ; tile bit 8 = attribute bit 0
  sta oam_shadow+3,x
  a16
  tya
  lsr a
  lsr a
  tax                       ; hi-table byte
  tya
  and #3
  asl a
  tay                       ; bit position
  lda oa_x
  xba
  and #1
  sta oa_t0
  lda oa_large
  beq :+
  lda #2
  ora oa_t0
  sta oa_t0
: lda #3
  jsr @shift
  eor #$FFFF
  and #$00FF
  sta oa_t1
  lda oa_t0
  jsr @shift
  sta oa_t0
  a8
  lda oam_shadow+512,x
  and oa_t1
  ora oa_t0
  sta oam_shadow+512,x
  a16
  rts
@shift:
  cpy #0
  beq @s0
  phy
: asl a
  dey
  bne :-
  ply
@s0:
  rts
.endproc

.proc hide_sprite                   ; Y = sprite
  lda #$0100
  sta oa_x
  lda #224
  sta oa_y
  stz oa_tile
  stz oa_attr
  stz oa_large
  jmp oam_set
.endproc

; ------------------------------------------------------------------ sparks and shadows
; spawn at bx/by (attack box centre, by = height above the feet), A = cell (SPARK0 or BSPARK)
.proc spawn_spark
  sta tmp0
  lda spk_next
  eor #2
  sta spk_next
  tax
  lda bx
  sec
  sbc #16
  sta spk_x,x
  lda #FLOOR - 16
  sec
  sbc by
  sta spk_y,x
  lda #12
  sta spk_t,x
  lda tmp0
  sta spk_cell,x
  rts
.endproc

.proc draw_sparks
  ldx #0
@s:
  lda spk_t,x
  beq @hide
  dec a
  sta spk_t,x
  lda spk_cell,x
  cmp #FX_SPARK0
  bne @cell                 ; the block flash (SPARK1) stays put
  lda #12
  sec
  sbc spk_t,x
  lsr a
  lsr a
  lsr a
  clc
  adc #FX_SPARK0
@cell:
  jsr fx_tile
  sta oa_tile
  lda spk_x,x
  sta oa_x
  lda spk_y,x
  sta oa_y
  lda #$34                  ; priority 3, palette 2
  sta oa_attr
  stz oa_large
  txa
  lsr a
  clc
  adc #4
  tay
  phx
  jsr oam_set
  plx
  bra @next
@hide:
  txa
  lsr a
  clc
  adc #4
  tay
  phx
  jsr hide_sprite
  plx
@next:
  inx
  inx
  cpx #4
  bne @s
  rts
.endproc

; A = fx cell -> A = OBJ tile number (rows 8.., 4 cells per 4-row group); only tmp2 is used
.proc fx_tile
  sta tmp2
  and #3
  asl a
  asl a
  pha
  lda tmp2
  and #$FFFC
  asl a
  asl a
  asl a
  asl a                     ; (k/4)*64
  sta tmp2
  pla
  clc
  adc tmp2
  clc
  adc #128
  rts
.endproc

; shadows under both fighters: OAM 2/3, palette 4 (blended with the floor)
.proc draw_shadows
  ldx #0
@s:
  lda fx,x
  asr4
  sec
  sbc #16
  sta oa_x
  lda #FLOOR - 29
  sta oa_y
  lda #FX_SHADOW
  jsr fx_tile
  sta oa_tile
  lda #$28
  sta oa_attr
  stz oa_large
  txa
  lsr a
  clc
  adc #2
  tay
  phx
  jsr oam_set
  plx
  inx
  inx
  cpx #4
  bne @s
  rts
.endproc

; ------------------------------------------------------------------ ambient sprites, palette cycle, scroll bands
.proc reset_ambient
  stz bird_on
  stz bird_t
  ldy #0
  lda (amb_ptr),y
  and #$0006
  lsr a
  sta bf_n
  lda #40 * 16
  sta bf_x
  lda #110 * 16
  sta bf_x+2
  lda #80 * 16
  sta bf_y
  lda #100 * 16
  sta bf_y+2
  stz bf_t
  lda #37
  sta bf_t+2
  stz cyc_idx
  stz flk_idx
  rts
.endproc

.proc update_ambient
  lda #12
  sta amb_oam
  ; ---- birds
  ldy #0
  lda (amb_ptr),y
  and #$0001
  bne :+
  brl @no_birds
:
  lda bird_on
  beq :+
  brl @fly
:
  jsr rnd8
  cmp #2
  bcc :+
  brl @no_birds
:
  ; spawn three
  lda #1
  sta bird_on
  stz bird_t
  jsr rnd8
  and #31
  clc
  adc #20
  asl a
  asl a
  asl a
  asl a
  sta tmp0                  ; y0 * 16
  jsr rnd8
  and #7
  clc
  adc #13
  sta bird_vx               ; 13..20 sixteenths per frame
  jsr rnd8
  and #1
  sta tmp1                  ; 1 = enters from the left
  ldx #0
  stz tmp2                  ; i * 18 px
@sp:
  lda tmp1
  beq @from_right
  lda #($10000 - 20 * 16)
  sec
  sbc tmp2
  bra @sx
@from_right:
  lda #276 * 16
  clc
  adc tmp2
@sx:
  sta bird_x,x
  lda tmp0
  sta bird_y,x
  txa
  and #2
  beq :+
  lda bird_y,x
  clc
  adc #8 * 16
  sta bird_y,x
: lda tmp2
  clc
  adc #18 * 16
  sta tmp2
  inx
  inx
  cpx #6
  bne @sp
  lda tmp1
  bne @fly
  lda bird_vx
  neg16
  sta bird_vx
@fly:
  inc bird_t
  lda bird_t
  cmp #420
  bcc :+
  stz bird_on
  brl @no_birds
: ldx #0
@b:
  lda bird_x,x
  clc
  adc bird_vx
  sta bird_x,x
  asr4
  sec
  sbc #16
  sta oa_x
  ; bob: sine(frame*3 + i*8) >> 6
  lda frame_ctr
  sta tmp0
  asl a
  clc
  adc tmp0
  sta tmp0
  txa
  asl a
  asl a
  clc
  adc tmp0
  and #63
  tay
  ldsby SINE64
  asr4
  asr1
  asr1
  sta tmp1
  lda bird_y,x
  asr4
  clc
  adc tmp1
  sec
  sbc #16
  sta oa_y
  lda frame_ctr
  lsr a
  lsr a
  lsr a
  and #1
  clc
  adc #FX_BIRD0
  jsr fx_tile
  sta oa_tile
  lda #$24                  ; priority 2, palette 2
  sta oa_attr
  stz oa_large
  ldy amb_oam
  inc amb_oam
  phx
  jsr oam_set
  plx
  inx
  inx
  cpx #6
  beq :+
  brl @b
:
@no_birds:
  ; ---- butterflies
  ldx #0
@bf:
  txa
  lsr a
  cmp bf_n
  bcc :+
  brl @bf_done
:
  inc bf_t,x
  lda bf_t,x
  lsr a
  and #63
  tay
  ldsby SINE64
  sta tmp3                  ; for the flip
  asr4
  clc
  adc bf_x,x
  cmp #8 * 16
  bcs :+
  lda #8 * 16
: cmp #232 * 16
  bcc :+
  lda #232 * 16
: sta bf_x,x
  lda bf_t,x
  asl a
  clc
  adc #16
  and #63
  tay
  ldsby SINE64
  asr4
  asr1
  clc
  adc bf_y,x
  cmp #50 * 16
  bcs :+
  lda #50 * 16
: cmp #150 * 16
  bcc :+
  lda #150 * 16
: sta bf_y,x
  asr4
  sec
  sbc #16
  sta oa_y
  lda bf_x,x
  asr4
  sec
  sbc #16
  sta oa_x
  lda bf_t,x
  lsr a
  lsr a
  lsr a
  and #1
  clc
  adc #FX_BFLY0
  jsr fx_tile
  sta oa_tile
  lda #$24
  ldy tmp3
  bpl :+
  ora #$40
: sta oa_attr
  stz oa_large
  ldy amb_oam
  inc amb_oam
  phx
  jsr oam_set
  plx
  inx
  inx
  brl @bf
@bf_done:
  ; ---- crowd babies
  ldy amb_crowd
  lda (amb_ptr),y
  and #$00FF
  sta tmp3
  beq @no_crowd
  stz tmp1                  ; i
@cr:
  iny
  lda (amb_ptr),y
  and #$00FF
  sec
  sbc #8
  sta oa_x
  iny
  lda (amb_ptr),y
  and #$00FF
  sec
  sbc #15
  sta oa_y
  ; cell: type (i%3)*2, +1 (cheering) when ((f>>4) + i*3) & 3 == 0
  phy
  ldy tmp1
  ldby CROWD_TYPE
  sta tmp2
  lda tmp1
  asl a
  adc tmp1                  ; i*3
  sta tmp0
  lda frame_ctr
  lsr a
  lsr a
  lsr a
  lsr a
  clc
  adc tmp0
  and #3
  bne :+
  inc tmp2
: lda tmp2
  jsr fx_tile
  sta oa_tile
  lda tmp1
  and #1
  beq :+
  lda #$40
: ora #$24
  sta oa_attr
  stz oa_large
  ldy amb_oam
  inc amb_oam
  jsr oam_set
  ply
  inc tmp1
  lda tmp1
  cmp tmp3
  bne @cr
@no_crowd:
  ; ---- candles
  ldy amb_cand
  lda (amb_ptr),y
  and #$00FF
  sta tmp3
  beq @no_cand
  stz tmp1
@cd:
  iny
  lda (amb_ptr),y
  and #$00FF
  sec
  sbc #8
  sta oa_x
  iny
  lda (amb_ptr),y
  and #$00FF
  sec
  sbc #16
  sta oa_y
  phy
  lda tmp1
  asl a
  sta tmp0
  lda frame_ctr
  lsr a
  lsr a
  clc
  adc tmp0
  and #3
  bne @steady
  lda #$40                  ; the flame flickers by mirroring
  bra @attr
@steady:
  lda #0
@attr:
  ora #$24
  sta oa_attr
  lda #FX_CANDLE0
  jsr fx_tile
  sta oa_tile
  stz oa_large
  ldy amb_oam
  inc amb_oam
  jsr oam_set
  ply
  inc tmp1
  lda tmp1
  cmp tmp3
  bne @cd
@no_cand:
  ; hide the rest of 12..27
  ldy amb_oam
@hide:
  cpy #28
  bcs @hidden
  phy
  jsr hide_sprite
  ply
  iny
  bra @hide
@hidden:
  ; ---- palette cycle: colour k = (frame * speed) >> 3 & 15
  ldy amb_cyc
  lda (amb_ptr),y
  and #$00FF
  sta cyc_idx
  beq @no_cyc
  iny
  lda (amb_ptr),y
  and #$00FF
  sta tmp0
  lda frame_ctr
  jsr mul_small             ; A = frame * tmp0
  lsr a
  lsr a
  lsr a
  and #15
  asl a
  sta tmp0
  tya
  clc
  adc tmp0
  inc a
  tay
  lda (amb_ptr),y
  sta cyc_val
@no_cyc:
  ; ---- flicker
  ldy amb_flk
  lda (amb_ptr),y
  and #$00FF
  sta flk_idx
  beq @no_flk
  jsr rnd8
  cmp #20
  bcs :+
  iny
  iny
: iny
  lda (amb_ptr),y
  sta flk_val
@no_flk:
  jmp build_hofs
.endproc

; A = A * tmp0 (unsigned 8x8 via the hardware multiplier)
.proc mul_small
  a8
  sta WRMPYA
  lda tmp0
  sta WRMPYB
  nop
  nop
  nop
  nop
  a16
  lda RDMPYL
  rts
.endproc

; per-scanline BG1 horizontal scroll table (HDMA channel 2, mode 2): rebuilt every frame into the
; buffer the PPU is not reading; the NMI points the channel at hofs_next.
; band: y0, lines, kind (0 sine, 1 drift), amp shift, y step, speed (sine: phase per frame; drift: shift)
.proc build_hofs
  lda hofs_flip
  eor #1
  sta hofs_flip
  ldx #0
  lda hofs_flip
  beq :+
  ldx #1024
: txa
  clc
  adc #.loword(hofs_a)
  sta hofs_next
  stz tmp3                  ; current line
  ldy #1
  lda (amb_ptr),y
  and #$00FF
  sta tmp4                  ; bands left
  ldy #2
@band:
  lda tmp4
  bne :+
  brl @tail
:
  dec tmp4
  lda (amb_ptr),y
  and #$00FF
  sec
  sbc tmp3
  jsr hofs_gap
  lda (amb_ptr),y
  and #$00FF
  sta tmp3
  iny
  lda (amb_ptr),y
  and #$00FF
  sta hb_cnt
  iny
  lda (amb_ptr),y
  and #$00FF
  sta hb_kind
  iny
  lda (amb_ptr),y
  and #$00FF
  sta hb_amp
  iny
  lda (amb_ptr),y
  and #$00FF
  sta hb_ystep
  iny
  lda (amb_ptr),y
  and #$00FF
  sta hb_speed
  iny
  phy
  lda hb_speed
  sta tmp0
  lda frame_ctr
  and #$00FF
  jsr mul_small
  sta hb_phase
  lda hb_cnt
  ora #$80
  a8
  sta hofs_a,x
  a16
  inx
  stz hb_i
@line:
  lda hb_kind
  bne @drift
  lda hb_ystep
  sta tmp0
  lda hb_i
  jsr mul_small
  clc
  adc hb_phase
  and #63
  tay
  ldsby SINE64
  ldy hb_amp
  beq @store
: asr1
  dey
  bne :-
  bra @store
@drift:
  lda frame_ctr
  ldy hb_speed
  beq @store
: lsr a
  dey
  bne :-
@store:
  and #$03FF
  a8
  sta hofs_a,x
  xba
  sta hofs_a+1,x
  a16
  inx
  inx
  inc hb_i
  lda hb_i
  cmp hb_cnt
  bne @line
  lda tmp3
  clc
  adc hb_cnt
  sta tmp3
  ply
  brl @band
@tail:
  lda #224
  sec
  sbc tmp3
  jsr hofs_gap
  a8
  stz hofs_a,x
  a16
  rts
.endproc

; A = lines of zero scroll to emit at hofs_a + X (entries of at most 127 lines)
.proc hofs_gap
@l:
  cmp #0
  beq @done
  cmp #128
  bcc @one
  pha
  lda #127
  jsr @emit
  pla
  sec
  sbc #127
  bra @l
@one:
  jsr @emit
@done:
  rts
@emit:
  a8
  sta hofs_a,x
  stz hofs_a+1,x
  stz hofs_a+2,x
  a16
  inx
  inx
  inx
  rts
.endproc

.proc hide_all
  ldy #0
: phy
  jsr hide_sprite
  ply
  iny
  cpy #128
  bne :-
  rts
.endproc

CROWD_TYPE: .byte 0, 2, 0, 2, 0, 2, 0, 2
SINE64:
  .byte 0, 12, 25, 37, 49, 60, 71, 81, 90, 98, 106, 112, 117, 122, 125, 126, 127, 126, 125, 122, 117, 112, 106, 98, 90, 81, 71, 60, 49, 37, 25, 12, 0, 244, 231, 219, 207, 196, 185, 175, 166, 158, 150, 144, 139, 134, 131, 130, 129, 130, 131, 134, 139, 144, 150, 158, 166, 175, 185, 196, 207, 219, 231, 244
s_tagline:  .byte "8 BABIES. 1 NAP TIME.", $FF
s_push:     .byte "PUSH START", $FF
s_onep:     .byte "PAD 1 VS CPU   PAD 2 FOR 2P", $FF
s_2p:       .byte "2P", $FF
s_vs2p:     .byte "VS 2P  ", $FF
s_pselect:  .byte "PLAYER SELECT", $FF
s_1p:       .byte "1P", $FF
s_cpu:      .byte "CPU", $FF
s_vscpu:    .byte "VS CPU ", $FF
s_stage:    .byte "STAGE ", $FF
s_round:    .byte "ROUND", $FF
s_fight:    .byte "FIGHT!", $FF
s_ko:       .byte "K.O.", $FF
s_timeup:   .byte "TIME UP", $FF
s_draw:     .byte "DRAW", $FF
s_wins:     .byte "WINS", $FF
s_winsmatch: .byte "WINS THE MATCH", $FF
s_naptime:  .byte "NAP TIME FOR THE CPU!", $FF
s_waaah:    .byte "WAAAH! TRY AGAIN!", $FF
s_demo:     .byte "DEMO - PUSH START", $FF
