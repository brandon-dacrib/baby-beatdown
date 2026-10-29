; Baby Beatdown is free software, released under the GNU GPL v3 or later (see LICENSE).
; specials.s: meter supers (A with a full meter: a projectile or a rush per character), crouch-punch shots for
; four babies, the two projectile slots, and the super-name callout. Included from main.s (CODE segment).
; Projectile slot X (0/2) belongs to fighter X; positions are 1/16 px like the fighters, pj_y is the screen y
; of the 16x16 centre in pixels.

; X = fighter with a full meter and the super button: start the super
.proc start_super
  stz fmeter,x
  lda #ST_SUPER
  sta fstate,x
  stz ftimer,x
  stz fhitdone,x
  stz fvx,x
  ldy fchar,x
  dey
  ldby SUP_SCRIPT
  jsr set_script
  lda fchar,x
  sta callout_char
  lda #60
  sta callout_t
  jsr draw_callout
  lda #SMP_BELL
  jmp sfx_play
.endproc

; the super's name on row 8 (centred per SUP_NAMECOL)
.proc draw_callout
  phx
  lda callout_char
  dec a
  tay
  ldby SUP_NAMECOL
  asl a
  clc
  adc #8 * 64
  tax
  lda callout_char
  dec a
  asl a
  asl a
  asl a
  asl a                     ; *16
  clc
  adc #.loword(SUP_NAME)
  sta ptr0
  lda #PAL6
  sta tmp4
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
  cpy #16
  bne @l
  plx
  rts
.endproc

; ST_SUPER per frame (X = fighter, att/def set by update_fighter)
.proc super_state
  lda ftimer,x
  inc a
  sta ftimer,x
  lda fchar,x
  dec a
  sta sp_ch
  tay
  ldby SUP_KIND
  bne @rush
  ; projectile super: fire at frame 18, idle at 36
  lda ftimer,x
  cmp #18
  bne :+
  jsr fire_super
: lda ftimer,x
  cmp #36
  bcs :+
  brl @phys
:
  brl @idle
@rush:
  lda ftimer,x
  cmp #12
  bcs :+
  brl @phys
:
  ldy sp_ch
  ldby SUP_SPEED
  ldy fface,x
  bpl :+
  neg16
: sta fvx,x
  lda ftimer,x
  cmp #12
  bne :+
  ldy sp_ch
  ldby SUP_FLAGS
  and #2
  beq :+
  lda #$FFB0                ; hop: -5 px/frame
  sta fvy,x
: lda ftimer,x
  and #$0007                ; hit test on frames 16, 24, 32 (every 8 from 12: 16 = 12+4 ... use low bits)
  bne @nohit
  ldy sp_ch
  ldby SUP_HITS
  cmp fhitdone,x
  beq @nohit
  bcc @nohit
  ldy def
  lda fstate,y
  cmp #ST_KO
  beq @nohit
  cmp #ST_DOWN
  beq @nohit
  lda #ABOX_RUSH
  jsr hit_box
  ldx att
  cmp #0
  beq @nohit
  sta h_slot
  inc fhitdone,x
  ldy sp_ch
  ldby SUP_DMG
  sta h_dmg
  lda #24
  sta h_stun
  stz h_low
  stz h_high
  stz h_sweep
  jsr take_hit
  ldx att
@nohit:
  lda ftimer,x
  cmp #36
  bcc @phys
@idle:
  stz fstate,x
  stz fvx,x
  lda #SC_IDLE
  jsr set_script
@phys:
  jmp physics
.endproc

; X = fighter: launch its super projectile
.proc fire_super
  ldy sp_ch
  ldby SUP_SPEED
  sta pj_speed
  ldby SUP_DMG
  sta pj_dmg
  ldby SUP_DY
  sta pj_dy
  ldby SUP_FLAGS
  and #1
  sta pj_wob
  lda sp_ch
  asl a
  tay
  lda SUP_LIFE,y
  sta pj_life
  lda sp_ch
  clc
  adc #FX_PROJ0
  sta pj_cellv
  lda #24
  sta pj_xoff
  jmp fire_proj
.endproc

; called from the attack state every frame (X = fighter, tmp3 = move): the shoot move fires at its startup frame
.proc shoot_check
  lda fmove,x
  cmp #MV_SHOOT
  bne @no
  lda ftimer,x
  cmp #8
  bne @no
  lda fchar,x
  dec a
  tay
  ldby SPC_CELL
  dec a
  clc
  adc #FX_SPC0
  sta pj_cellv
  ldby SPC_SPEED
  sta pj_speed
  ldby SPC_DMG
  sta pj_dmg
  ldby SPC_WOBBLE
  sta pj_wob
  lda #300
  sta pj_life
  lda #32
  sta pj_dy
  lda #22
  sta pj_xoff
  jsr fire_proj
  jsr sfx_select_g
@no:
  rts
.endproc

; X = fighter: start projectile slot X from pj_cellv/speed/dmg/dy/wob/life/xoff
.proc fire_proj
  lda #1
  sta pj_on,x
  stz pj_t,x
  lda pj_cellv
  sta pj_cell,x
  lda pj_dmg
  sta pj_dmgv,x
  lda pj_life
  sta pj_lifev,x
  lda pj_wob
  sta pj_wobv,x
  lda pj_xoff
  asl a
  asl a
  asl a
  asl a
  ldy fface,x
  bpl :+
  neg16
: clc
  adc fx,x
  sta pj_x,x
  lda pj_speed
  ldy fface,x
  bpl :+
  neg16
: sta pj_vx,x
  lda fy,x
  asr4
  clc
  adc #FLOOR - 64
  clc
  adc pj_dy
  sta pj_y,x
  rts
.endproc

; both slots: move, wobble, expire, hit the other fighter's body
.proc update_projectiles
  ldx #0
@slot:
  lda pj_on,x
  bne :+
  brl @next
:
  inc pj_t,x
  lda pj_x,x
  clc
  adc pj_vx,x
  sta pj_x,x
  lda pj_wobv,x
  beq @nowob
  lda pj_t,x
  sta tmp0
  asl a
  asl a
  asl a
  clc
  adc tmp0
  clc
  adc tmp0
  clc
  adc tmp0                  ; t*11
  and #63
  tay
  ldsby SINE64
  asr4
  asr1
  asr1
  clc
  adc pj_y,x
  sta pj_y,x
@nowob:
  lda pj_t,x
  cmp pj_lifev,x
  bcc :+
  brl @kill
:
  lda pj_x,x
  asr4
  sta tmp0                  ; px (world)
  sec
  sbc cam
  clc
  adc #16
  cmp #290                  ; on screen: px - cam in -16..273
  bcc :+
  brl @kill
:  jsr objects_projectile
  beq :+
  brl @kill
:
  ; target body box
  txa
  eor #2
  tay
  lda fstate,y
  cmp #ST_KO
  beq :+
  cmp #ST_DOWN
  bne :++
: brl @next
:
  lda fboxset,y
  phy
  tay
  ldby BS_BODY
  tay
  ldby HBOX_HW
  clc
  adc #6
  sta tmp1                  ; half width + projectile half size
  ldby HBOX_HH
  clc
  adc #6
  sta tmp2
  ldby HBOX_CY
  sta tmp3
  ply
  lda fx,y
  asr4
  sec
  sbc tmp0
  bpl :+
  neg16
: cmp tmp1
  bcs @next                 ; too far horizontally
  lda fy,y
  asr4
  clc
  adc #FLOOR
  sec
  sbc tmp3                  ; body centre screen y
  sec
  sbc pj_y,x
  bpl :+
  neg16
: cmp tmp2
  bcs @next
  ; hit: attacker = owner X, defender = Y
  stx att
  sty def
  lda pj_dmgv,x
  sta h_dmg
  lda #26
  sta h_stun
  stz h_low
  stz h_high
  stz h_sweep
  lda #2
  sta h_slot
  lda tmp0
  sta bx
  lda #FLOOR
  sec
  sbc pj_y,x
  sta by
  phx
  jsr take_hit
  plx
@kill:
  stz pj_on,x
@next:
  inx
  inx
  cpx #4
  beq :+
  brl @slot
:
  rts
.endproc

; OAM 6/7
.proc draw_projectiles
  ldx #0
@slot:
  txa
  lsr a
  clc
  adc #6
  tay
  lda pj_on,x
  beq @hide
  lda pj_x,x
  asr4
  sec
  sbc cam
  sec
  sbc #16
  and #$01FF
  sta oa_x
  lda pj_y,x
  sec
  sbc #16
  sta oa_y
  lda pj_cell,x
  jsr fx_tile
  sta oa_tile
  lda #$24
  ldy pj_vx,x
  bpl :+
  ora #$40
: sta oa_attr
  stz oa_large
  txa
  lsr a
  clc
  adc #6
  tay
  phx
  jsr oam_set
  plx
  bra @next
@hide:
  phx
  jsr hide_sprite
  plx
@next:
  inx
  inx
  cpx #4
  bne @slot
  rts
.endproc

; CPU (X = fighter): throw the crouch shot from range now and then
.proc cpu_special
  lda fstate,x
  cmp #ST_ATTACK
  bne @not_chain
  lda fhitdone,x
  beq @not_chain
  phx
  jsr rnd8
  plx
  cmp #90
  bcs @not_chain
  inc in_punch,x            ; chain after a landed hit
@not_chain:
  lda fchar,x
  dec a
  tay
  ldby SPC_CELL
  beq @no
  lda pj_on,x
  bne @no
  lda fstate,x
  cmp #ST_CROUCH + 1
  bcs @no
  txa
  eor #2
  tay
  lda fx,y
  sec
  sbc fx,x
  bpl :+
  neg16
: cmp #90 * 16
  bcc @no
  phx
  jsr rnd8
  plx
  cmp #8
  bcs @no
  inc in_down,x
  inc in_punch,x
@no:
  rts
.endproc

; ST_DOWN: fly back, hit the floor, lie for a while, get up (X = fighter)
.proc down_state
  jsr physics
  lda fy,x
  bmi @ret                  ; still in the air
  jsr decay_vx
  inc ftimer,x
  lda ftimer,x
  cmp #36
  bne :+
  lda #SC_GETUP
  jsr set_script
: lda ftimer,x
  cmp #50
  bcc @ret
  stz fstate,x
  stz fvx,x
  lda #SC_IDLE
  jmp set_script
@ret:
  rts
.endproc

; in the attack state (X = fighter): after a landed hit, punch / kick starts the next chain move
.proc combo_check
  lda fhitdone,x
  beq @no
  lda fstate,x
  cmp #ST_ATTACK
  bne @no
  ldy fmove,x
  ldby M_FLAGS
  and #$0004                ; air moves do not chain
  bne @no
  ldby M_STARTUP
  cmp ftimer,x
  bcs @no                   ; only once the move is past its startup
  lda in_punch,x
  bne @punch
  lda in_kick,x
  beq @no
  lda fchar,x
  dec a
  asl a
  adc fchar,x
  dec a                     ; (char-1)*3
  asl a                     ; *6
  clc
  adc fcombo,x
  tay
  ldby CH_CHAIN_K
  bra @go
@punch:
  lda fchar,x
  dec a
  asl a
  adc fchar,x
  dec a
  asl a
  clc
  adc fcombo,x
  tay
  ldby CH_CHAIN_P
@go:
  beq @no                   ; end of the chain
  sta tmp0
  lda fcombo,x
  inc a
  sta tmp1
  lda tmp0
  jsr start_move
  lda tmp1
  sta fcombo,x
  stz in_punch,x
  stz in_kick,x
@no:
  rts
.endproc

; "N HIT COMBO" on row 6, on the attacker's side
.proc draw_combo
  ldx #6 * 64 + 2 * 2
  lda combo_side
  beq :+
  ldx #6 * 64 + 19 * 2
: lda combo_n
  clc
  adc #27                   ; digit glyph (combos stay below 10)
  ora #PAL6
  sta bg3_shadow,x
  inx
  inx
  inx
  inx
  lda #.loword(s_hitcombo)
  sta ptr0
  lda #PAL6
  sta tmp4
  jmp text_at
.endproc
s_hitcombo: .byte "HIT COMBO", $FF

; ---------------------------------------------------------------- breakable stage props (OAM 8/9)
.proc objects_reset
  ldx #0
: lda #1
  sta ob_on,x
  stz ob_t,x
  inx
  inx
  cpx #4
  bne :-
  lda #40
  sta ob_x
  lda #344
  sta ob_x+2
  lda stage
  dec a
  tay
  ldby STAGE_OBJ
  clc
  adc #FX_BARREL
  sta ob_cell
  rts
.endproc

; X = attacker in an active attack: burst any standing object under its attack box
.proc objects_check
  phx
  stx ob_att
  ldy fmove,x
  ldby M_BOX
  beq @done
  jsr attack_box
  ldx #0
@o:
  lda ob_on,x
  cmp #1
  bne @next
  lda ob_x,x
  sec
  sbc bx
  bpl :+
  neg16
: sec
  sbc bw
  bmi @ydist
  cmp #12
  bcs @next
@ydist:
  lda #16                   ; the prop's centre is 16 px above the floor
  sec
  sbc by
  bpl :+
  neg16
: sec
  sbc bh
  bmi @hit
  cmp #14
  bcs @next
@hit:
  jsr object_burst
  ldy ob_att
  lda fmeter,y
  clc
  adc #12
  cmp #METER_MAX
  bcc :+
  lda #METER_MAX
: sta fmeter,y
@next:
  inx
  inx
  cpx #4
  bne @o
@done:
  plx
  rts
.endproc

; X = object slot: start its burst
.proc object_burst
  lda #2
  sta ob_on,x
  lda #14
  sta ob_t,x
  lda ob_x,x
  sta bx
  lda #16
  sta by
  lda #FX_SPARK0
  jsr spawn_spark
  lda #SMP_CRASH
  jsr sfx_play
  lda #SMP_TOM
  jmp sfx_play
.endproc

; projectile at tmp0 (world px) / pj_y,x: returns A = 1 if it broke an object (X preserved)
.proc objects_projectile
  phx
  ldy #0
@o:
  lda ob_on,y
  cmp #1
  bne @next
  lda ob_x,y
  sec
  sbc tmp0
  bpl :+
  neg16
: cmp #22
  bcs @next
  lda #FLOOR - 16
  sec
  sbc pj_y,x
  bpl :+
  neg16
: cmp #20
  bcs @next
  tya
  tax
  jsr object_burst
  plx
  lda #1
  rts
@next:
  iny
  iny
  cpy #4
  bne @o
  plx
  lda #0
  rts
.endproc

.proc draw_objects
  ldx #0
@o:
  txa
  lsr a
  clc
  adc #8
  tay
  lda ob_on,x
  beq @hide
  cmp #2
  bne @show
  dec ob_t,x
  bne @hide                 ; bursting: the spark shows, the prop is gone
  stz ob_on,x
  bra @hide
@show:
  lda ob_x,x
  sec
  sbc cam
  sec
  sbc #16
  and #$01FF
  sta oa_x
  lda #FLOOR - 32
  sta oa_y
  lda ob_cell
  jsr fx_tile
  sta oa_tile
  lda #$24
  sta oa_attr
  stz oa_large
  phx
  jsr oam_set
  plx
  bra @next
@hide:
  phx
  jsr hide_sprite
  plx
@next:
  inx
  inx
  cpx #4
  bne @o
  rts
.endproc
