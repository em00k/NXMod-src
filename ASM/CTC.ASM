
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        CTC.ASM                                             *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: CTC routines.                                       *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; **ONLY NEED TO DO THIS AT STARTUP**


; Initialize timer for Paula/CIA emulation, configuring for VGA/HDMI.

;  VGA 28Mhz /  16 (prescaler) = 1750000 / CTC0 56 = 31250Hz (DAC OUTPUT)
;  VGA 28Mhz / 256 (prescaler) =  109375 / CTC1 35 =  3125Hz (SAMPLE SCALER)
;  VGA 28Mhz / 256 (prescaler) =  109375 / CTC2 NN = VARIABLE (MOD PLAY)


; **STATIC TIME CONSTANTS - CHANGE PERIOD TABLE TO COMPENSATE VIDEO TIMING**


; > DE = Pointer to LINE interrupt routine (-1 = use Paula)
; > BC = Line number

; <  A = Timing mode (0 VGA / 7 HDMI)


ctc_init:	di

	ld	a,i		; Patch IM2 vector table
	ld	h,a
	ld	l,0

	inc	de		; Valid address?
	ld	a,e
	or	d
	dec	de
	jr	nz,.valid_line

	ld	de,paula_line	; Use internal LINE
	ld	(paula_frame),a

.valid_line:	ld	(hl),e		; Set LINE interrupt
	inc	l
	ld	(hl),d

	xor	a
	ld	(DMACON),a	; Disable DAC
	call	paula_enable	; Disable CTC

	ld	a,b
	and	00000001b
	or	00000110b	; ULA off / LINE interrupt ON
	nextreg	INTMSB,a
	ld	a,c
	nextreg	INTLSB,a	; IM2 on line BC

	ld	bc,SELECT	 ; Read timing register
	ld	a,INTCTL
	out	(c),a
	inc	b
	in	a,(c)
	and	00001000b	 ; Preserve stackless mode
	or	00000001b	 ; Vector 0x00, IM2 ON
	out	(c),a
	dec	b

	nextreg INTEN0,00000010b ; Interrupt enable LINE
	nextreg INTEN1,00000011b ; CTC channel 0 zc/to
	nextreg INTEN2,00000000b ; Interrupters

	nextreg INTST0,11111111b ; 
	nextreg INTST1,11111111b ; Set status bits to clear
	nextreg INTST2,11111111b ; 

	nextreg INTDM0,00000010b ; LINE can break over DMA
	nextreg INTDM1,00000111b ; CTC can break over DMA
	nextreg INTDM2,00000000b ; Dont care

	ld	a,TIMING
	out	(c),a
	inc	b
	in	a,(c)
	and	7

	ld	d,a	; Configure CTC channels 0,1 and 2

	ld	hl,.timing_tab
	add	hl,a
	add	a,a
	add	hl,a		; * 3

; Bit 7: I Interrupt (disabled / enabled)
; Bit 6: M Mode (timer / counter)
; Bit 5: P Prescaler (16 / 256)
; Bit 4: E Edge select (falling / rising)
; Bit 3: T Trigger (constant load / CLK pulse)
; Bit 2: C Time constant (no constant / follows)
; Bit 1: R Reset (continued / software reset)
; Bit 0: V Control (vector / control word)

	ld	bc,CTC0		; Channel 0 port
;                                    IMPETCRV	; Bits 7-0
	ld	a,10000101b	; / 16
	out	(c),a		; Control word
	ld	a,56
	out	(c),a		; Time constant

	ld	bc,CTC1		; Channel 1 port
;                                    IMPETCRV	; Bits 7-0
	ld	a,10100101b	; / 256
	out	(c),a		; Control word
	ld	a,35
	out	(c),a		; Time constant

	ld	bc,CTC2		; Channel 2 port
;                                    IMPETCRV	; Bits 7-0
	ld	a,10100101b	; / 256
	out	(c),a		; Control word
	ld	a,(hl)
	outinb			; Time constant
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(mod_ctc2_constant+1),bc

	ld	a,d		; Return A
	ei
	ret


; --------------------------------------------------------------------------


; 50Hz playback, CTC2 table for all video timing modes.


.timing_tab	db	250	; 0 28000000 50Hz
	dw	4375	;   4375	  6.0

	db	244	; 1 28571429 50Hz
	dw	4574	;   4574.062842	  6.000082433

	db	244	; 2 29464286 50Hz
	dw	4717	;   4717.002732	  6.000003475

	db	234	; 3 30000000 50Hz
	dw	5008	;   5008.012831	  6.00001436

	db	211	; 4 31000000 50Hz
	dw	5739	;   5739.040284	  6.000042116

	db	250	; 5 32000000 50Hz
	dw	5000	;   5000	  6.0

	db	254	; 6 33000000 50Hz
	dw	5075	;   5075.049213	  6.000058182

	db	255	; 7 27000000 50Hz
	dw	4136	;   4136.029412	  6.000042667


; --------------------------------------------------------------------------
;
;
; The math!
;
;
; The Amiga CIA decrements a 16-bit counter at 1/10 its clock rate (7Mhz).
; Protracker is able to set accurate bpm based tempos using the CIA.
;
; Protracker uses a bpm of 125 * 4 for the vblank legacy speed tempo, as
; 50Hz * 60 / 500 = 6. The CIA interrupt routine has a simple counter that
; increaments each tick and resets to 0 when it matches the speed parameter.
;
;
; The ZX Spectrum Next CTC timer is limited to an 8-bit counter and fixed
; pre-scaler of 256 or 16. A transparent software solution is used to provide
; accurate bpm tempos for each of the eight video mode clock frequencies.
;
;
;
; Here's how...
;
;
; 28000000 / 256 = 109375 CTC : CTC / 250 = 437.5 HZ : HZ * 60 = 26250 TICKS.
;
; TICKS / 6 = 4375 MAGIC! We use this 'magic' number to divide down ctc2 to
; provide the bpm tempo (see mod_ctc2).
;
;
; We divide the bpm tempo down further to create the speed logic for the
; original Protracker vblank based tempo; 50Hz vblank * 60 seconds = 3000.
;
; 3000 / 125 * 4 default tempo (quarter notes) = 6 ticks default speed.
;
;
; RULE #1; Change mod_bpm and keep mod_speed = 6 for correct 'bpm' tempos.
;
; RULE #2; Change mod_speed and keep mod_bpm = 125 for correct 'speed' tempos.
;
;
; Maths examples...
;
; ( ( 28000000Hz / 256 scaler) / 250 constant ) = 437.5Hz ctc2 timer rate;
;
; 437.5Hz ctc2 / 50Hz vblank rate = 8.75 (ctc2 bpm divider).
; 
;
; 125 bpm * 4 quarter notes = 500 : 4375 'magic' number / 500 notes = 8.75 :)
;
;
; Here are the time constants and magic numbers for each video mode. A high
; constant is used to keep the ctc2 rate as low as possible with a balanced
; rounding error;
;
;
; 6562500 (ctc)	60*109375           28Mhz (VGA0)
; 250 (constant)	PERFECT 6.0
; 4375 (magic)	4375
;
; 6696428	60*111607.14        28.5Mhz
; 244	CLOSE   6.000082433
; 4574	4574.062842
;
; 6905692	60*115094.87        29.5Mhz
; 244	CLOSE   6.000003475
; 4717	4717.002732
;
; 7031250	60*117187.50        30Mhz
; 234	CLOSE   6.00001436
; 5008	5008.012831
;
; 7265625	60*121093.75        31Mhz
; 211	CLOSE   6.000042116
; 5739	5739.040284
;
; 7500000	60*125000           32Mhz
; 250	PERFECT 6.0
; 5000	5000
;
; 7734375	60*128906.25        33Mhz (VGA6)
; 254	CLOSE   6.000058182
; 5075	5075.049213
;
; 6328125	60*105468.75        27Mhz (HDMI)
; 255	CLOSE   6.000042667
; 4136	4136.029412
;
;
; Example bpm rounding error for HDMI;
;
;
; 27Mhz / 256 scaler = 105468.75 * 60 = 6328125.
;
; 6328125 / 255 constant / 6 speed = 4136.029412 'magic' number.
;
; 6328125 / 255 constant = 24816.17647 / 4136 (integer) = 6.000042667
;
; A speed of 6 ticks will be slightly above 6;
;
; 6 / 6.000042667 = 0.999992888 * 125 = 124.9991111 (close enough !!!)
;
;
; ZX Spectrum Next tempo drift should be less than the Amiga CIA in theory.
;
;
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Load period table for video timing detected during startup.


; **ONLY NEED TO DO THIS AT STARTUP**


; > IX = Filename for period table (see ntsc_filename)
; >  A = BANK8K for 8K table


load_period_tab:	nextreg	MM0,255		; Restore ROM
	nextreg	MM1,255

	ld	(.bank8k+3),a	; NEXTREG N,N

	ld	b,1		; Read mode; Existing file
	ld	a,"*"		; Use default drive
	rst	08h
	db	f_open		; Open file
	jp	c,file_err
	ld	(file_handle),a	; Store file handle

.bank8k:	nextreg	MM2,0		; Bank8k for period

	ld	ix,16384	; MM2 16384 ($4000)
	ld	bc,8192		; 8K table
	ld	a,(file_handle)
	rst	08h
	db	f_read		; Load period table
	jp	c,file_err

	ld	a,(file_handle)
	rst	08h
	db	f_close		; Close file
	ret


; --------------------------------------------------------------------------


; Next VGA/HDMI timing and Amiga NTSC period table filenames.


; **PROTRACKER PERIODS ARE BASED ON THE NTSC CLOCK**


ntsc_filename	db	'NTSC\16BIT_0.8K',0	; NTSC = 3579545


; --------------------------------------------------------------------------

