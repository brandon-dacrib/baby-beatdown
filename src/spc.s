; spc.s: SPC700 command server for Baby Beatdown (wla-spc700). Lives at $0200..$02FF in SPC RAM.
; The main CPU runs the sequencer; this loop only turns commands into DSP register writes.
; Protocol: CPU writes p1,p2,p3 to ports 1..3, then the command byte to port 0 (bits 7-6 op, bits 5-3 a
; sequence number so repeated commands differ, bits 2-0 voice); the server echoes the byte on port 0 when done.
;   op 00: set volume      p1 = left, p2 = right
;   op 01: note on         p1 = sample, p2 = pitch low, p3 = pitch high (ADSR from the table at $0340)
;   op 10: note off (release)
; Sample directory at $0300 (DIR = $03), ADSR table at $0340 (2 bytes per sample), BRR data after.
.MEMORYMAP
 SLOTSIZE $10000
 DEFAULTSLOT 0
 SLOT 0 $0000
.ENDME
.ROMBANKMAP
 BANKSTOTAL 1
 BANKSIZE $10000
 BANKS 1
.ENDRO
.BANK 0 SLOT 0
.ORG $0200

.DEFINE LAST  $00
.DEFINE DSPA  $F2
.DEFINE DSPD  $F3
.DEFINE PORT0 $F4
.DEFINE PORT1 $F5
.DEFINE PORT2 $F6
.DEFINE PORT3 $F7
.DEFINE ADSR  $0340

start:
  mov x,#$EF
  mov sp,x
  mov $F1,#$30          ; clear ports 0/1, timers off
  mov DSPA,#$6C
  mov DSPD,#$20         ; FLG: not muted, echo write off, noise clock 0
  mov DSPA,#$0C
  mov DSPD,#$7F         ; MVOL L
  mov DSPA,#$1C
  mov DSPD,#$7F         ; MVOL R
  mov DSPA,#$2C
  mov DSPD,#$00         ; EVOL L
  mov DSPA,#$3C
  mov DSPD,#$00         ; EVOL R
  mov DSPA,#$5D
  mov DSPD,#$03         ; DIR = $0300
  mov DSPA,#$4D
  mov DSPD,#$00         ; EON
  mov DSPA,#$3D
  mov DSPD,#$00         ; NON
  mov DSPA,#$2D
  mov DSPD,#$00         ; PMON
  mov DSPA,#$5C
  mov DSPD,#$00         ; KOFF
  mov DSPA,#$4C
  mov DSPD,#$00         ; KON
  mov a,#$00
  mov LAST,a
  mov PORT0,#$00
loop:
  mov a,PORT0
  cmp a,LAST
  beq loop
  mov LAST,a
  mov y,a
  and a,#$07
  xcn a                 ; voice * 16 = DSP voice register base
  mov x,a
  mov a,y
  and a,#$C0
  beq setvol
  cmp a,#$40
  beq noteon
  cmp a,#$80
  beq noteoff
  bra ack
setvol:
  mov a,x
  mov DSPA,a
  mov DSPD,PORT1        ; VOL L
  mov a,x
  or a,#$01
  mov DSPA,a
  mov DSPD,PORT2        ; VOL R
  bra ack
noteon:
  mov a,x
  or a,#$04
  mov DSPA,a
  mov DSPD,PORT1        ; SRCN
  mov a,x
  or a,#$02
  mov DSPA,a
  mov DSPD,PORT2        ; pitch low
  mov a,x
  or a,#$03
  mov DSPA,a
  mov DSPD,PORT3        ; pitch high
  mov a,PORT1
  asl a
  mov y,a
  mov a,!$0340+y
  push a
  mov a,x
  or a,#$05
  mov DSPA,a
  pop a
  mov DSPD,a            ; ADSR1
  mov a,PORT1
  asl a
  inc a
  mov y,a
  mov a,!$0340+y
  push a
  mov a,x
  or a,#$06
  mov DSPA,a
  pop a
  mov DSPD,a            ; ADSR2
  mov a,LAST
  and a,#$07
  mov y,a
  mov a,!bits+y
  mov DSPA,#$5C
  mov DSPD,#$00         ; clear KOFF so the voice can restart
  mov DSPA,#$4C
  mov DSPD,a            ; KON
  bra ack
noteoff:
  mov a,LAST
  and a,#$07
  mov y,a
  mov a,!bits+y
  mov DSPA,#$5C
  mov DSPD,a            ; KOFF
ack:
  mov a,LAST
  mov PORT0,a
  jmp !loop
bits:
  .db $01, $02, $04, $08, $10, $20, $40, $80
