
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        PLAYER.ASM                                          *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Protracker MOD player.                              *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Initialize main variables.


mod_init:	xor	a
	ld	(mod_enable),a	; **STOP PLAYBACK**
	ld	(mod_counter),a	; Set to mod_speed-1 for fun!

	ld	(mod_pbreakpos),a
	ld	(mod_posjumpflag),a
	ld	(mod_pbreakflag),a

	ld	(mod_pattdelaytime),a
	ld	(mod_pattdelaytime2),a

	ld	a,6
	ld	(mod_speed),a
	ld	a,125
	ld	(mod_bpm),a

	ld	hl,0
	ld	(mod_ctc2_tick+1),hl	; Reset counter

	ld	hl,mod_audchan1temp
	ld	de,4			; Four channels

mod_clear:	ld	b,n_dmabit	; Clear upto n_dmabit

mod_clear2:	ld	(hl),d		; 0
	inc	l
	djnz	mod_clear2
	add	hl,64-n_dmabit	; Skip to next channel
	dec	e
	jr	nz,mod_clear

	jp	mod_set_song_start


; --------------------------------------------------------------------------


; **DISABLE INTERRUPTS IF CALLED DIRECT WHILE MOD PLAYING**


; Set MOD pattern/song variables.


mod_set_song_start:	xor	a		; Song position = 0


; >  A = Song position


mod_set_song_row:	ld	b,0		; ROW/DIVISION/LINE


; >  A = Song position
; >  B = Row (0..63)

; <  A = Corrupt
; <  B = As entry
; <  C = Pattern number


mod_set_song_position:	ld	(mod_songpos),a	; Set song position

	ld	hl,mod_row
	ld	(hl),b

mod_song_position:	ld	hl,mod_sequence
	add	hl,a
	ld	c,(hl)		; Get pattern number

	ld	(mod_position),bc	; **ATOMIC**

	ld	a,c
	and	00000111b
	add	a,a
	add	a,a		; * 1024
	ld	(mod_ptr+1),a	; WORD (set MSB)

	ld	a,c
	and	00111000b
	rrca
	rrca
	rrca
	add	a,BANK8K_PATTERNS
	ld	(mod_bank),a
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Trigger MOD sample **VALID MOD MUST BE LOADED**


; > HL = Pointer to AUDxPER
; >  A = Sample number 0..31

; <  A = Sample default volume


mod_trigger_period:	ld	e,(hl)	; AUDxPER
	inc	l
	ld	d,(hl)
	inc	l


; > HL = Pointer to AUDxRES
; > DE = Amiga period
; >  A = Sample number 0..31

; <  A = Sample default volume


mod_trigger_sample:	ex	de,hl	; DE = AUDxRES
	add	hl,hl
	set	7,h	; MM4 32768 ($8000)
	di
	nextreg	MM4,BANK8K_PERIOD
	ld	c,(hl)	; Translate Amiga to Next period
	inc	l	; using word entries from a table
	ld	b,(hl)	; Amiga period to 16-bit counter
	ei

	ex	de,hl	; HL = AUDxRES
	ld	e,a
	ld	d,AUDX_listlen	; Index instrument data
	mul	d,e
	add	de,mod_instruments+AUDX_vol

	ld	a,(de)	; AUDxVOL (default sample volume)
	inc	de

	di
	ld	(hl),c	; AUDxRES (set 16-bit period)
	inc	l
	ld	(hl),b
	inc	l
	ld	(hl),0	; AUDxCNT (reset 16-bit counter)
	inc	l
	ld	(hl),0
	inc	l
	ex	de,hl
	ldi		; AUDxLPL
	ldi
	ldi		; AUDxLPH
	ldi		; AUDxLOP
	ldi
	ldi		; AUDxLCL
	ldi
	ldi		; AUDxLCH
	ldi		; AUDxLEN
	ldi
	ei
	ret		;  A = Default volume for sample


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **IM2 CTC2 INTERRUPT**


; Interrupt MOD player @ fixed rate (default is (125 BPM) (SPEED 6) for 50Hz)

; Auto-adjusts CIA emulation by monitoring mod_bpm variable.


mod_ctc2:	ei			; Allow CTC0/CTC1 ints
	push	af
	push	bc
	push	hl

	ld	hl,(mod_bpm)	; Emulate CIA timer
	add	hl,hl
	add	hl,hl

mod_ctc2_tick:	ld	bc,0
	add	hl,bc		; Add BPM * 4
	ld	(mod_ctc2_tick+1),hl

mod_ctc2_constant:	ld	bc,4375		; **MAGIC**
	
	xor	a
	sbc	hl,bc		; 16-bit compare
	jp	c,mod_ctc2_out	; LOWER

	ld	hl,(mod_ctc2_tick+1)
	xor	a		; Adjust overflow
	sbc	hl,bc
	ld	(mod_ctc2_tick+1),hl

;	------------

;;;	nextreg	FALLBACK,128	; Raster timing RED

	ld	a,(mod_enable)	; PLAY/STOP ?
	and	a
	jr	z,mod_ctc2_out

	push	de		; **SAVE REGISTERS**
	push	ix

	ld	hl,mod_speed	; Process TICK SPEED
	ld	a,(mod_counter)
	inc	a
	ld	(mod_counter),a
	cp	(hl)
	jp	c,mod_tick_n

	xor	a
	ld	(mod_volumeflags),a

	ld	(mod_counter),a		 ; TICK = 0

;	------------

	ld	a,(mod_pattdelaytime2)   ; Delayed?
	and	a
	jp	z,mod_tick_0	; Play NOTE if 0 delay

	ld	hl,mod_tick_n_normal_tab ; Switch to N
	ld	(mod_normal_commands+1),hl
	ld	hl,mod_tick_0_extend_tab
	ld	(mod_extend_commands+1),hl

	call	mod_nonewallchannels
	jp	mod_dskip

;	------------

mod_ctc2_out:	pop	hl
	pop	bc
	pop	af
	reti


; --------------------------------------------------------------------------


; Called on any tick to process effects using current control table group.


mod_nonewallchannels:	ld	ix,mod_audchan1temp
	call	mod_normal_commands	; mt_checkefx

	ld	ix,mod_audchan2temp
	call	mod_normal_commands	; mt_checkefx

	ld	ix,mod_audchan3temp
	call	mod_normal_commands	; mt_checkefx

	ld	ix,mod_audchan4temp
	jp	mod_normal_commands	; mt_checkefx


; --------------------------------------------------------------------------


; Called on ticks 1..31 (process effects).


mod_tick_n:	xor	a
	ld	(mod_volumeflags),a

	ld	hl,mod_tick_n_normal_tab  ; Control flow
	ld	(mod_normal_commands+1),hl; table select
	ld	hl,mod_tick_n_extend_tab  ; for TICK 1..31
	ld	(mod_extend_commands+1),hl

	call	mod_nonewallchannels
	jp	mod_nonewpositionyet ; Song position check


; --------------------------------------------------------------------------


; Called on tick 0 (get new note and process effects).


mod_tick_0:	ld	hl,mod_tick_0_normal_tab
	ld	(mod_normal_commands+1),hl
	ld	hl,mod_tick_0_extend_tab
	ld	(mod_extend_commands+1),hl

	ld	a,(mod_row)	; ROW/DIVISION/LINE (0..63)
	ld	b,a
	ld	a,(mod_songpos)
	call	mod_song_position

	xor	a
	ld	(mod_dmacontemp),a

;	------------

	if	0

	ld	hl,(mod_audchan1temp+0)	; **OBSOLETE**
	ld	a,l
	or	h
	ld	hl,(mod_audchan1temp+2)
	or	l
	or	h
	jr	nz,.plvskip_1
	ld	hl,AUD0PER
	ld	de,(mod_audchan1temp+n_period)
	call	mod_set_period_hl		; AUD0PER
.plvskip_1:
	ld	hl,(mod_audchan2temp+0)
	ld	a,l
	or	h
	ld	hl,(mod_audchan2temp+2)
	or	l
	or	h
	jr	nz,.plvskip_2
	ld	hl,AUD1PER
	ld	de,(mod_audchan2temp+n_period)
	call	mod_set_period_hl		; AUD1PER
.plvskip_2:
	ld	hl,(mod_audchan3temp+0)
	ld	a,l
	or	h
	ld	hl,(mod_audchan3temp+2)
	or	l
	or	h
	jr	nz,.plvskip_3
	ld	hl,AUD2PER
	ld	de,(mod_audchan3temp+n_period)
	call	mod_set_period_hl		; AUD2PER
.plvskip_3:
	ld	hl,(mod_audchan4temp+0)
	ld	a,l
	or	h
	ld	hl,(mod_audchan4temp+2)
	or	l
	or	h
	jr	nz,.plvskip_4
	ld	hl,AUD3PER
	ld	de,(mod_audchan4temp+n_period)
	call	mod_set_period_hl		; AUD3PER
.plvskip_4:
	endif

;	------------

	ld	hl,(mod_ptr)	; Source pattern
	ld	a,(mod_row)
	ld	e,a
	ld	d,16
	mul	d,e
	add	hl,de
	set	7,h		; MM4 (32768)

	ld	a,(mod_bank)
	ld	de,mod_audchan1temp ; Shadow ROW (n_note)

	di
	nextreg	MM4,a

	ldi				; BYTE1 n_note
	ldi				; BYTE2
	ldi				; BYTE3 n_cmd
	ldi				; BYTE4 n_cmdlo

	ld	de,mod_audchan2temp

	ldi
	ldi
	ldi
	ldi

	ld	de,mod_audchan3temp

	ldi
	ldi
	ldi
	ldi

	ld	de,mod_audchan4temp

	ldi
	ldi
	ldi
	ldi
	ei

;	------------

	ld	ix,mod_audchan1temp
	call	mod_playvoice

	ld	ix,mod_audchan2temp
	call	mod_playvoice

	ld	ix,mod_audchan3temp
	call	mod_playvoice

	ld	ix,mod_audchan4temp
	call	mod_playvoice


; Play new notes using the retrigger logic.


mod_setdma:	ld	a,(mod_dmacontemp) ; xxxx3210 (See AUD3EN)

	ld	hl,mod_audchan4temp+n_loopstart
	ld	de,AUD3LPL
	test	AUD3EN
	call	nz,mod_doretrig2

	ld	hl,mod_audchan3temp+n_loopstart
	ld	de,AUD2LPL
	test	AUD2EN
	call	nz,mod_doretrig2

	ld	hl,mod_audchan2temp+n_loopstart
	ld	de,AUD1LPL
	test	AUD1EN
	call	nz,mod_doretrig2

	ld	hl,mod_audchan1temp+n_loopstart
	ld	de,AUD0LPL
	test	AUD0EN
	call	nz,mod_doretrig2

;	------------
;	------------
;	------------

mod_dskip:	ld	hl,mod_row		; Next ROW
	inc	(hl)

	ld	a,(mod_pattdelaytime)
	and	a
	jr	z,mod_dskpc
	ld	(mod_pattdelaytime2),a
	xor	a
	ld	(mod_pattdelaytime),a

mod_dskpc:	ld	a,(mod_pattdelaytime2)
	and	a
	jr	z,mod_dskpa
	dec	a
	ld	(mod_pattdelaytime2),a
	jr	z,mod_dskpa
	ld	hl,mod_row
	dec	(hl)			; Previous ROW

mod_dskpa:	ld	a,(mod_pbreakflag)
	and	a
	jr	z,mod_nnpysk

	ld	a,(mod_pbreakpos)
	ld	(mod_row),a
	xor	a
	ld	(mod_pbreakpos),a
	ld	(mod_pbreakflag),a

;	------------

mod_nnpysk:	ld	a,(mod_row)
	cp	64
	jr	c,mod_nonewpositionyet	; LOWER

;	------------

mod_nextposition:	ld	a,(mod_pbreakpos)
	ld	(mod_row),a

	xor	a
	ld	(mod_pbreakpos),a
	ld	(mod_posjumpflag),a	; Clear jump flag

	ld	a,(mod_songpos)
	inc	a
	and	127
	ld	(mod_songpos),a

	ld	hl,mod_songlength
	cp	(hl)
	jr	c,mod_nonewpositionyet	; LOWER
	xor	a
	ld	(mod_songpos),a

;	------------

mod_nonewpositionyet:	ld	a,(mod_posjumpflag)
	and	a
	jr	nz,mod_nextposition

;	------------
;	------------
;	------------

	ld	a,(mod_volumeflags)
	and	a
	jr	nz,mod_ignorevolumes	; FAST or SLOW ?

	ld	a,(mod_audchan1temp+n_volume)
	ld	(AUD0VOL),a
	ld	a,(mod_audchan2temp+n_volume)
	ld	(AUD1VOL),a
	ld	a,(mod_audchan3temp+n_volume)
	ld	(AUD2VOL),a
mod_ctc2_vol4:	ld	a,(mod_audchan4temp+n_volume)
	ld	(AUD3VOL),a

;	------------

mod_ctc2_exit:	pop	ix		; **RESTORE REGISTERS**
	pop	de
	pop	hl
	pop	bc
	pop	af

;;;	nextreg	FALLBACK,0	; Raster timing BLACK

	reti


; --------------------------------------------------------------------------


; Check volume flags to ignore Paula channels set by effects (slower code).


mod_ignorevolumes:	ld	b,a
	bit	0,b		; AUD0EN
	jr	nz,.aud0
	ld	a,(mod_audchan1temp+n_volume)
	ld	(AUD0VOL),a
.aud0:
	bit	1,b		; AUD1EN
	jr	nz,.aud1
	ld	a,(mod_audchan2temp+n_volume)
	ld	(AUD1VOL),a
.aud1:
	bit	2,b		; AUD2EN
	jr	nz,.aud2
	ld	a,(mod_audchan3temp+n_volume)
	ld	(AUD2VOL),a
.aud2:
	bit	3,b		; AUD3EN
	jr	nz,mod_ctc2_exit

	jr	mod_ctc2_vol4


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; > IX = Audio channel x temp (see n_note)

; < IX = As entry


mod_playvoice:	ld	a,(ix+n_cmd)
	and	11110000b
	swapnib
	ld	b,a
	ld	a,(ix+n_note)
	and	00010000b
	or	b
	jp	z,mod_setregisters ; No instrument?

	ld	e,a		; A = instrument 0..31
	ld	d,AUDX_listlen	; Index instrument data
	mul	d,e
	add	de,mod_instruments
	ex	de,hl

	ld	e,(hl)
	ld	(ix+n_finetune),e
	inc	hl
	ld	d,(hl)		; AUDxVOL
	ld	(ix+n_volume),d	; Set default volume
	inc	hl

	ld	d,96		; Four octaves (4*2*12)
	mul	d,e		; Select mod_ftune0 table
	add	de,32768+4096		; MM4 36864 ($9000)
	ld	(ix+n_peroffset+0),e
	ld	(ix+n_peroffset+1),d

;	------------

	ld	e,(ix+n_retrigger)	; n_loopstart
	ld	d,PAGE_PAULA

	ldi		; AUDX_lpl
	ldi
	ldi		; AUDX_lph
	ldi		; AUDX_lop
	ldi
	ldi		; AUDX_lcl
	ldi
	ldi		; AUDX_lch
	ldi		; AUDX_len
	ldi

;	------------
;	------------
;	------------

mod_setregisters:	ld	a,(ix+n_note+0)		; No note?
	and	00001111b
	or	(ix+n_note+1)
	jp	z,mod_normal_commands	; mt_checkmoreefx

	ld	c,(ix+n_cmdlo)
	ld	a,c
	and	11110000b
	cp	$5			; Finetune
	ld	a,(ix+n_cmd)
	jr	nz,.no_e5x

	and	00001111b
	cp	$E
	jr	nz,.no_e5x2

	ld	a,c
	and	00001111b
	call	mod_setfinetune		; Run $E5x
	jr	mod_setperiod

.no_e5x:	and	00001111b

.no_e5x2:	cp	$3			; Portamento
	jp	z,mod_settoneporta
	cp	$5			; +Volslide
	jp	z,mod_settoneporta

	cp	$9			; CMD $9xx offset
	ld	a,c
	call	z,mod_sampleoffset	; Run $9xx

;	------------
;	------------
;	------------

mod_setperiod:	ld	a,(ix+n_note+0)		; **ENDIAN**
	and	00001111b
	or	10000000b		; MM4 32768
	ld	d,a
	ld	e,(ix+n_note+1)		; DE 32768..36863

	ld	l,(ix+n_peroffset+0)	; HL = 36864 +
	ld	h,(ix+n_peroffset+1)	; 96 * FINETUNE

	di
	nextreg	MM4,BANK8K_FINETUNE
	ld	a,(de)			; Note index
	add	hl,a			; Transpose period
	ld	c,(hl)
	inc	l
	ld	b,(hl)			; BC = period
	ei
	ld	(ix+n_period+0),c
	ld	(ix+n_period+1),b


	ld	a,(ix+n_cmdlo)
	and	11110000b
	cp	$D			; Notedelay
	jr	nz,.no_edx
	ld	a,(ix+n_cmd)
	and	00001111b
	cp	$E
	jr	nz,.no_edx

	ld	a,(ix+n_cmdlo)
	and	00001111b
	jp	mod_notedelay		; edx (note delay)
.no_edx:
;	------------

	bit	2,(ix+n_vibratocontrol)	; See WAVEFORM_RESET
	jr	nz,mod_vibnoc
	ld	(ix+n_vibratopos),0	; Reset position
mod_vibnoc:
	bit	2,(ix+n_tremolocontrol)	; See WAVEFORM_RESET
	jr	nz,mod_trenoc
	ld	(ix+n_tremolopos),0	; Reset position
mod_trenoc:

	ld	a,(mod_dmacontemp)
	or	(ix+n_dmabit)
	ld	(mod_dmacontemp),a	; Set DMA bit

	call	mod_pernop		; AUDxPER

	jp	mod_normal_commands	; mt_checkmoreefx


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Set channel period if changed.


; **MULTIPLE ENTRY POINTS**


; > IX = Audio channel x temp (see n_note)


mod_pernop:	ld	e,(ix+n_period+0)
	ld	d,(ix+n_period+1)


; > IX = Audio channel x temp (see n_note)
; > DE = Period


mod_set_period_ix:	ld	l,(ix+n_paula_per)	; AUDxPER
	ld	h,PAGE_PAULA


; > IX = Audio channel x temp (see n_note)
; > HL = AUDxPER
; > DE = Period

; < IX = As entry


mod_set_period_hl:	ld	c,(hl)			; Current LSB
	ld	(hl),e
	inc	l
	ld	a,(hl)			; Current MSB
	ld	(hl),d
	inc	l

	cp	d		; Don't update unless
	jr	nz,.set		; there is change as
	ld	a,e		; you may hear glitches
	cp	c		; and pitch distortion
	ret	z		; due to counter reset

.set:	ex	de,hl
	add	hl,hl
	set	7,h	; MM4 32768 ($8000)
	di
	nextreg	MM4,BANK8K_PERIOD
	ld	c,(hl)	; Translate Amiga to Next period
	inc	l	; using WORD entries from a table
	ld	b,(hl)	; Amiga period to 16-bit counter
	ex	de,hl
	ld	(hl),c	; AUDxRES
	inc	l
	ld	(hl),b
	inc	l
	ld	(hl),0	; AUDxCNT
	inc	l
	ld	(hl),0
	ei
	ret
	

; --------------------------------------------------------------------------


; > IX = Audio channel x temp (see n_note)


mod_settoneporta:	ld	a,(ix+n_note+0)		; **ENDIAN**
	and	00001111b
	or	10000000b		; MM4 32768
	ld	d,a
	ld	e,(ix+n_note+1)		; DE 32768..36863

	ld	l,(ix+n_peroffset+0)	; HL = 36864 +
	ld	h,(ix+n_peroffset+1)	; 96 * FINETUNE

	di
	nextreg	MM4,BANK8K_FINETUNE
	ld	a,(de)			; Note index
	add	hl,a			; Transpose period
	ld	e,(hl)
	inc	l
	ld	d,(hl)			; DE = period
	ei

	ld	(ix+n_wantedperiod+0),e
	ld	(ix+n_wantedperiod+1),d

	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)

	xor	a
	ld	(ix+n_toneportdirec),a
	sbc	hl,de
	jr	z,mod_cleartoneporta
	ret	nc
	ld	(ix+n_toneportdirec),1
	ret	

mod_cleartoneporta:	ld	(ix+n_wantedperiod+0),a
	ld	(ix+n_wantedperiod+1),a
	ret	


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **MOD COMMANDS AND EFFECTS**


mod_arptab	db	0,1,2,0,1,2,0,1
	db	2,0,1,2,0,1,2,0
	db	1,2,0,1,2,0,1,2
	db	0,1,2,0,1,2,0,1


; --------------------------------------------------------------------------


; CMD $0xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_arpeggio:	ld	c,a

	ld	a,(mod_counter)		; TICK
	and	31
	ld	hl,mod_arptab
	add	hl,a			; HL 0 1 2 0 1 2

	ld	a,c

	bit	1,(hl)			; 10b TICK 2
	jr	nz,mod_arpeggiofind

	swapnib				; yx
	
	bit	0,(hl)			; 01b TICK 1
	jr	nz,mod_arpeggiofind	; 00b TICK 0

	ld	e,(ix+n_period+0)
	ld	d,(ix+n_period+1)
	jp	mod_set_period_ix	; AUDxPER

;	------------

mod_arpeggiofind:	ld	e,(ix+n_peroffset+0)	; HL = 36864 +
	ld	d,(ix+n_peroffset+1)	; 96 * FINETUNE
	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)
	set	7,h			; DE 32768..36863

	and	00001111b		; y
	add	a,a			; * 2 WORD index

	di
	nextreg	MM4,BANK8K_FINETUNE
	add	a,(hl)			; Note index
	ex	de,hl

	add	hl,a			; Transpose period
	ld	e,(hl)
	inc	l
	ld	d,(hl)			; DE = period
	ei
	jp	mod_set_period_ix	; AUDxPER


; --------------------------------------------------------------------------


; CMD $1xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_portaup:


; --------------------------------------------------------------------------


; CMD $E1x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_fineportaup:	ld	c,a

	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)
	xor	a
	ld	b,a
	sbc	hl,bc
	ld	d,h
	ld	e,l
	ld	bc,113
	xor	a
	sbc	hl,bc
	jp	p,mod_portauskip

	ld	d,b
	ld	e,c
mod_portauskip:	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d
	jp	mod_set_period_ix	 ; AUDxPER


; --------------------------------------------------------------------------


; CMD $2xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_portadown:


; --------------------------------------------------------------------------


; CMD $E2x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0

 
mod_fineportadown:	ld	c,a	

	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)
	ld	b,0
	add	hl,bc
	ld	d,h
	ld	e,l
	ld	bc,856
	xor	a
	sbc	hl,bc
	jp	m,mod_portadskip

	ld	d,b
	ld	e,c
mod_portadskip:	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d
	jp	mod_set_period_ix	 ; AUDxPER


; --------------------------------------------------------------------------


; CMD $3xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_toneportamento:	and	a
	jr	z,mod_toneportnochange
	ld	(ix+n_toneportspeed),a
	ld	(ix+n_cmdlo),0

mod_toneportnochange:	ld	a,(ix+n_wantedperiod+0)
	or	(ix+n_wantedperiod+1)
	ret	z
	ld	e,(ix+n_toneportspeed)
	bit	0,(ix+n_toneportdirec)
	jr	nz,mod_toneportaup

mod_toneportadown:	ld	d,0
	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)
	add	hl,de
	ex	de,hl
	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d

	ld	l,(ix+n_wantedperiod+0)
	ld	h,(ix+n_wantedperiod+1)
	xor	a
	sbc	hl,de		
	jp	p,mod_toneportasetper

	add	hl,de
	ex	de,hl
	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d
	ld	(ix+n_wantedperiod+0),a
	ld	(ix+n_wantedperiod+1),a
	jp	mod_toneportasetper

;	------------

mod_toneportaup:	xor	a
	ld	d,a
	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)
	sbc	hl,de
	ex	de,hl
	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d

	ld	l,(ix+n_wantedperiod+0)
	ld	h,(ix+n_wantedperiod+1)
	xor	a
	sbc	hl,de
	jp	m,mod_toneportasetper

	add	hl,de
	ex	de,hl
	ld	(ix+n_period+0),e
	ld	(ix+n_period+1),d
	ld	(ix+n_wantedperiod+0),a
	ld	(ix+n_wantedperiod+1),a

;	------------

mod_toneportasetper:	bit	0,(ix+n_glissfunk)	; ON/OFF ?
	jp	z,mod_set_period_ix	; AUDxPER

	ld	a,(ix+n_note+0)		; **ENDIAN**
	and	00001111b
	or	10000000b		; MM4 32768
	ld	d,a
	ld	e,(ix+n_note+1)		; DE 32768..36863

	ld	l,(ix+n_peroffset+0)	; HL = 36864 +
	ld	h,(ix+n_peroffset+1)	; 96 * FINETUNE

	di
	nextreg	MM4,BANK8K_FINETUNE
	ld	a,(de)			; Note index
	add	hl,a			; Transpose period
	ld	e,(hl)
	inc	l
	ld	d,(hl)			; DE = period
	ei
	jp	mod_set_period_ix	; AUDxPER


; --------------------------------------------------------------------------


; **RANDOM WAVEFORM NOT SUPPORTED**


; CMD $4xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_vibrato:	and	a
	jr	z,mod_vibrato2

	ld	c,(ix+n_vibratocmd)
	and	00001111b
	jr	z,mod_vibskip
	ld	b,a
	ld	a,c
	and	11110000b
	or	b
	ld	c,a

mod_vibskip:	ld	a,(ix+n_cmdlo)
	and	11110000b
	jr	z,mod_vibskip2
	ld	b,a
	ld	a,c
	and	00001111b
	or	b
	ld	c,a

mod_vibskip2:	ld	(ix+n_vibratocmd),c

;	------------

mod_vibrato2:	ld	hl,mod_vibratotable
	ld	a,(ix+n_vibratopos)
	rrca
	rrca
	and	31
	add	hl,a
	ld	d,(hl)			; Read from table

	add	a,a
	add	a,a
	add	a,a
	ld	e,a

	ld	a,(ix+n_vibratocontrol)	; See WAVEFORM_SINE
	and	3
	jr	z,mod_vib_set		; 0 SINE WAVE
	dec	a
	jr	z,mod_vib_rampdown	; 1 RAMP DOWN

	ld	d,255			; 2 SQUAREWAVE
	jr	mod_vib_set

;	------------

mod_vib_rampdown:	ld	d,e
	bit	7,(ix+n_vibratopos)
	jr	z,mod_vib_set		; POSITIVE

	dec	a			; A = 255
	sub	d
	ld	d,a

;	------------

mod_vib_set:	ld	a,(ix+n_vibratocmd)
	and	00001111b
	ld	e,a
	mul	d,e
	ld	b,7
	bsrl	de,b
	ld	l,(ix+n_period+0)
	ld	h,(ix+n_period+1)

	bit	7,(ix+n_vibratopos)
	jr	nz,mod_vibratoneg

	add	hl,de
	jr	mod_vibrato3

mod_vibratoneg:	xor	a
	sbc	hl,de

mod_vibrato3:	ex	de,hl
	call	mod_set_period_ix	; AUDxPER

	ld	a,(ix+n_vibratocmd)
	rrca
	rrca
	and	00111100b
	add	a,(ix+n_vibratopos)	
	ld	(ix+n_vibratopos),a
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **RANDOM WAVEFORM NOT SUPPORTED**


; CMD $7xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_tremolo:	and	a
	jr	z,mod_tremolo2

	ld	c,(ix+n_tremolocmd)
	and	00001111b
	jr	z,mod_treskip
	ld	b,a
	ld	a,c
	and	11110000b
	or	b
	ld	c,a

mod_treskip:	ld	a,(ix+n_cmdlo)
	and	11110000b
	jr	z,mod_treskip2
	ld	b,a
	ld	a,c
	and	00001111b
	or	b
	ld	c,a

mod_treskip2:	ld	(ix+n_tremolocmd),c

mod_tremolo2:	ld	hl,mod_vibratotable
	ld	a,(ix+n_tremolopos)
	rrca
	rrca
	and	31
	add	hl,a
	ld	d,(hl)			; Read from table

	add	a,a
	add	a,a
	add	a,a
	ld	e,a

	ld	a,(ix+n_tremolocontrol)	; See WAVEFORM_SINE
	and	3
	jr	z,mod_tre_set		; 0 SINE WAVE
	dec	a
	jr	z,mod_tre_rampdown	; 1 RAMP DOWN

	ld	d,255			; 2 SQUAREWAVE
	jr	mod_tre_set

;	------------

mod_tre_rampdown:	ld	d,e
	bit	7,(ix+n_vibratopos)
	jr	z,mod_tre_set		; POSITIVE

	dec	a			; A = 255
	sub	d
	ld	d,a

;	------------

mod_tre_set:	ld	a,(ix+n_tremolocmd)
	and	00001111b
	ld	e,a
	mul	d,e
	ld	b,6
	bsrl	de,b

	ld	a,(ix+n_volume)
	bit	7,(ix+n_tremolopos)
	jr	nz,mod_tremoloneg	; NEGATIVE
	add	a,e
	jr	mod_tremolo3

;	------------

mod_tremoloneg:	sub	e
mod_tremolo3:	jp	p,mod_tremoloskip	; POSITIVE
	xor	a

mod_tremoloskip:	cp	64+1
	jr	c,mod_tremolook		; LOWER
	ld	a,64

mod_tremolook:	ld	l,(ix+n_paula_vol)
	ld	h,PAGE_PAULA
	ld	(hl),a			; AUDxVOL

	ld	a,(mod_volumeflags)	; Set volume
	or	(ix+n_dmabit)		; ignore flag
	ld	(mod_volumeflags),a	; using DMA bit

;	------------

	ld	a,(ix+n_tremolocmd)
	rrca
	rrca
	and	00111100b
	add	a,(ix+n_tremolopos)
	ld	(ix+n_tremolopos),a
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; CMD $5xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_toneplusvolslide:	call	mod_toneportnochange

	jr	mod_volumeslide2


; --------------------------------------------------------------------------


; CMD $6xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_vibratoplusvolslide:	call	mod_vibrato2

mod_volumeslide2:	ld	a,(ix+n_cmdlo)


; --------------------------------------------------------------------------


; CMD $Axx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_volumeslide:	swapnib
	and	00001111b
	jr	nz,mod_volumefineup

	ld	a,(ix+n_cmdlo)
	and	00001111b


; --------------------------------------------------------------------------


; CMD $EBx


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_volumefinedown:	ld	c,a
	ld	a,(ix+n_volume)
	sub	c
	jp	p,mod_vsdskip	; POSITIVE
	xor	a
mod_vsdskip:	ld	(ix+n_volume),a
	ret


; --------------------------------------------------------------------------


; CMD $EAx


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_volumefineup:	add	a,(ix+n_volume)


; --------------------------------------------------------------------------


; CMD $Cxx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_volumechange:	cp	64
	jp	m,mod_vsuskip	; NEGATIVE
	ld	a,64
mod_vsuskip:	ld	(ix+n_volume),a
	ret


; --------------------------------------------------------------------------


; **LENGTH OVERFLOW UNTESTED**


; CMD $9xx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_sampleoffset:	and	a
	jr	z,mod_sononew
	ld	(ix+n_sampleoffset),a	; Update

mod_sononew:	ld	a,(ix+n_cmd)		; Clear 9xx to
	and	11110000b		; fix bug where
	ld	(ix+n_cmd),a		; player logic
	xor	a			; calls the
	ld	(ix+n_cmdlo),a		; command twice

	ld	c,a
	ld	b,(ix+n_sampleoffset)

	ld	l,(ix+n_length+0)
	ld	h,(ix+n_length+1)
	sbc	hl,bc
	jr	c,mod_sofskip		; Overflow?

	ld	l,(ix+n_offset)		; n_start+1
	ld	h,PAGE_PAULA

	ld	a,(hl)			; AUDxLCL+1
	add	a,b
	ld	(hl),a			; AUDxLCH
	inc	hl
	ld	a,(hl)
	adc	a,c			; C = 0
	ld	(hl),a
	inc	l
	inc	l
	ld	a,(hl)			; AUDxLEN+1
	sub	b
	ld	(hl),a
	ret

;	------------

mod_sofskip:	ld	hl,mod_instruments+AUDX_lcl ; Sample #0
	ld	d,PAGE_PAULA
	ld	e,(ix+n_offset)		; n_start+1
	dec	e			; n_start

	ldi		; AUDX_lcl
	ldi
	ldi		; AUDX_lch
	ldi		; AUDX_len
	ldi
	ret


; --------------------------------------------------------------------------


; CMD $Bxx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_positionjump:	dec	a
	ld	(mod_songpos),a

mod_pj2:	xor	a
	ld	(mod_pbreakpos),a
	inc	a
	ld	(mod_posjumpflag),a
	ret


; --------------------------------------------------------------------------


; CMD $Dxx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_patternbreak:	ld	c,a
	and	11110000b
	swapnib
	ld	e,a
	ld	d,10
	mul	d,e

	ld	a,c
	and	00001111b
	add	a,e
	cp	64		; HIGHER OR SAME
	jr	nc,mod_pj2

	ld	(mod_pbreakpos),a
	ld	a,1
	ld	(mod_posjumpflag),a
	ret


; --------------------------------------------------------------------------


; CMD $Fxx


; > IX = Audio channel x temp (see n_note)
; >  A = 8-bit X parameter (n_cmdlo)


mod_setspeed:	cp	32
	jr	nc,settempo	; HIGHER OR SAME

	ld	(mod_speed),a
	xor	a
	ld	(mod_counter),a
	ret

settempo:	ld	(mod_bpm),a
	ld	hl,0
	ld	(mod_ctc2_tick+1),hl	; Reset counter
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; CMD $E3x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_setglisscontrol:	jr	z,.set
	ld	a,GLISSANDO_ON	; $1..$F changed to = 1
.set:	ld	(ix+n_glissfunk),a
	ret


; --------------------------------------------------------------------------


; CMD $E4x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_setvibratocontrol:	ld	(ix+n_vibratocontrol),a
	ret


; --------------------------------------------------------------------------


; CMD $E5x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_setfinetune:	ld	(ix+n_finetune),a

	ld	e,a
	ld	d,96		; Four octaves (4*2*12)
	mul	d,e		; Select mod_ftune0 table

	add	de,32768+4096		; MM4 36864 ($9000)
	ld	(ix+n_peroffset+0),e
	ld	(ix+n_peroffset+1),d
	ret


; --------------------------------------------------------------------------


; CMD $E6x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_jumploop:	jr	z,mod_setloop

	ld	c,(ix+n_loopcount)
	inc	c
	dec	c
	jr	z,mod_jumpcnt
	dec	(ix+n_loopcount)
	ret	z

mod_jmploop:	ld	a,(ix+n_pattpos)
	ld	(mod_pbreakpos),a
	ld	a,1
	ld	(mod_pbreakflag),a
	ret

mod_jumpcnt:	ld	(ix+n_loopcount),a
	jr	mod_jmploop

mod_setloop:	ld	a,(mod_row)	
	and	63
	ld	(ix+n_pattpos),a
	ret


; --------------------------------------------------------------------------


; CMD $E7x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_settremolocontrol:	ld	(ix+n_tremolocontrol),a
	ret


; --------------------------------------------------------------------------


; CMD $E9x


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_retrignote:	ret	z
	ld	e,a

	ld	a,(mod_counter)
	and	a
	jr	nz,mod_rtnskp

	ld	a,(ix+n_note+0)
	and	00001111b
	or	(ix+n_note+1)
	ret	nz		; Ignore if note

	ld	a,(mod_counter)

mod_rtnskp:	and	31
	ld	d,0
	ld	b,5
	bsla	de,b
	add	de,32768+4096+1536	; mod_retrigtab
	add	de,a
	di
	nextreg	MM4,BANK8K_FINETUNE
	ld	a,(de)
	ei
	and	a
	ret	nz

;	------------

mod_doretrig:	ld	l,(ix+n_retrigger)	; n_start
	ld	h,PAGE_PAULA
	ld	e,(ix+n_paula_lpl)	; AUDxLPL
	ld	d,h

mod_doretrig2:	di
	ldi				; AUDxLPL
	ldi
	ldi				; AUDxLPH
	ldi				; AUDxLOP
	ldi

	ldi				; AUDxLCL
	ldi
	ldi				; AUDxLCH
	ldi				; AUDxLEN
	ldi
	ei
	ret


; --------------------------------------------------------------------------


; CMD $ECx


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_notecut:	ld	hl,mod_counter
	cp	(hl)
	ret	nz		; TICK match ?

	ld	(ix+n_volume),0
	ret


; --------------------------------------------------------------------------


; CMD $EDx


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_notedelay:	ld	hl,mod_counter
	cp	(hl)
	ret	nz		; TICK match X ?

	ld	a,(ix+n_note+0)
	and	00001111b
	or	(ix+n_note+1)
	ret	z		; If no note?

	jr	mod_doretrig	; Trigger sample


; --------------------------------------------------------------------------


; CMD $EEx


; > IX = Audio channel x temp (see n_note)
; >  A = 4-bit X parameter (n_cmdlo)
; > ZF = Set if A = 0


mod_patterndelay:	ld	c,a

	ld	a,(mod_pattdelaytime2)
	and	a
	ret	nz

	ld	a,c
	inc	a
	ld	(mod_pattdelaytime),a
	ret


; --------------------------------------------------------------------------


; 32 BYTES.


mod_vibratotable	db  	  0, 24, 49, 74, 97,120,141,161
	db	180,197,212,224,235,244,250,253
	db	255,253,250,244,235,224,212,197
	db	180,161,141,120, 97, 74, 49, 24


; --------------------------------------------------------------------------


; Control flow jump table routines to process effects for current tick.


mod_normal_commands:	ld	hl,mod_tick_0_normal_tab ; **PATCHED**

	ld	a,(ix+n_cmd)
	and	00001111b
	ld	c,a
	or	(ix+n_cmdlo)
	jp	z,mod_pernop
	ld	a,c

	add	a,a
	add	hl,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(ix+n_cmdlo)	; Pass X to function
	jp	(hl)	


mod_extend_commands:	ld	hl,mod_tick_0_extend_tab ; **PATCHED**

	ld	a,(ix+n_cmdlo)
	ld	c,a
	swapnib
	and	00001111b
	add	a,a
	add	hl,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a

	ld	a,c
	and	00001111b	; Pass X / ZF to function
	jp	(hl)	


; --------------------------------------------------------------------------


mod_ret:	ret


; --------------------------------------------------------------------------


; Command/effect control flow tables - selected from mod_counter (0..31)


; 0 is tick 0
; N is tick 1..31


mod_tick_0_normal_tab

 dw mod_pernop	; -N  0xy (arpeggio)
 dw mod_pernop	; -N  1xx (portamento up)
 dw mod_pernop	; -N  2xx (portamento down)
 dw mod_pernop	; -N  3xx (tone portamento)
 dw mod_pernop	; -N  4xy (vibrato)
 dw mod_pernop	; -N  5xy (tone portamento + vol slide)
 dw mod_pernop	; -N  6xy (vibrato + vol slide)
 dw mod_tremolo	; 0N  7xy (tremolo)
 dw mod_pernop	; --  8-- NOT USED
 dw mod_sampleoffset	; 0-  9xx (set sample offset)
 dw mod_pernop	; -N  axy (volume slide)
 dw mod_positionjump	; 0-  bxx (position jump)
 dw mod_volumechange	; 0-  cxx (set volume)
 dw mod_patternbreak	; 0-  dxx (pattern break)
 dw mod_extend_commands	; 0N  exy (extended commands)
 dw mod_setspeed	; 0-  fxx (set speed)

mod_tick_n_normal_tab

 dw mod_arpeggio	; -N  0xy (arpeggio)
 dw mod_portaup	; -N  1xx (portamento up)
 dw mod_portadown	; -N  2xx (portamento down)
 dw mod_toneportamento	; -N  3xx (tone portamento)
 dw mod_vibrato	; -N  4xy (vibrato)
 dw mod_toneplusvolslide	; -N  5xy (tone portamento + vol slide)
 dw mod_vibratoplusvolslide; -N  6xy (vibrato + vol slide)
 dw mod_tremolo	; 0N  7xy (tremolo)
 dw mod_pernop	; --  8-- NOT USED
 dw mod_pernop	; 0-  9xx (set sample offset)
 dw mod_volumeslide	; -N  axy (volume slide)
 dw mod_pernop	; 0-  bxx (position jump)
 dw mod_pernop	; 0-  cxx (set volume)
 dw mod_pernop	; 0-  dxx (pattern break)
 dw mod_extend_commands	; 0N  exy (extended commands)
 dw mod_pernop	; 0-  fxx (set speed)


; --------------------------------------------------------------------------


mod_tick_0_extend_tab

 dw mod_ret     	; --  e0- NOT USED
 dw mod_fineportaup	; 0-  e1x (fine portamento up)
 dw mod_fineportadown	; 0-  e2x (fine portamento down)
 dw mod_setglisscontrol	; 0-  e3x (glissando control)
 dw mod_setvibratocontrol	; 0-  e4x (vibrato control)
 dw mod_setfinetune	; 0-  e5x (set finetune)
 dw mod_jumploop	; 0-  e6x (pattern loop)
 dw mod_settremolocontrol	; 0-  e7x (tremolo control)
 dw mod_ret	; --  e8- NOT USED
 dw mod_ret	; -N  e9x (retrig note)
 dw mod_volumefineup	; 0-  eax (fine volume slide up)
 dw mod_volumefinedown	; 0-  ebx (fine volume slide down)
 dw mod_ret	; -N  ecx (note cut)
 dw mod_ret	; -N  edx (note delay)
 dw mod_patterndelay	; 0-  eex (pattern delay)
 dw mod_ret	; --  ef- NOT USED

mod_tick_n_extend_tab

 dw mod_ret     	; --  e0- NOT USED
 dw mod_ret	; 0-  e1x (fine portamento up)
 dw mod_ret	; 0-  e2x (fine portamento down)
 dw mod_ret	; 0-  e3x (glissando control)
 dw mod_ret	; 0-  e4x (vibrato control)
 dw mod_ret	; 0-  e5x (set finetune)
 dw mod_ret	; 0-  e6x (pattern loop)
 dw mod_ret	; 0-  e7x (tremolo control)
 dw mod_ret	; --  e8- NOT USED
 dw mod_retrignote	; -N  e9x (retrig note)
 dw mod_ret	; 0-  eax (fine volume slide up)
 dw mod_ret	; 0-  ebx (fine volume slide down)
 dw mod_notecut	; -N  ecx (note cut)
 dw mod_notedelay	; -N  edx (note delay)
 dw mod_ret	; 0-  eex (pattern delay)
 dw mod_ret	; --  ef- NOT USED


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Next variables and data.


mod_patterns	db	0	; Pattern count (set by loader)

mod_bpm	dw	125	; Default for 50Hz
mod_speed	db	6	; Default for 50Hz
mod_counter	db	0	; TICK/COUNT for SPEED and effects

mod_songpos	db	0	; Song position in pattern table

mod_bank	db	BANK8K_PATTERNS
mod_ptr	dw	0

mod_position	db	0	; PATTERN  (0..63) **ATOMIC** WORD
	db	0	; DIVISION (0..63) **ATOMIC** WORD

mod_row	db	0	; ROW/DIVISION (0..63)

mod_pbreakpos	db	0
mod_posjumpflag	db	0
mod_pbreakflag	db	0

mod_pattdelaytime	db	0	; CMD $EE delay
mod_pattdelaytime2	db	0

mod_dmacontemp	db	0	; Fake DMACON for MOD internal use

mod_volumeflags	db	0	; **NEW**

mod_enable	db	0	; MOD playback (0 = STOP)


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; ZX Spectrum Next modified copy of mod_samples.


mod_instruments	ds	AUDX_listlen*32		; One extra sample


; --------------------------------------------------------------------------


; Amiga MOD cached data.


; Header/samples/song local cache (1084 BYTES)


mod_header	ds	20	; Name
mod_samples	ds	930	; Instrument info (30*31)
mod_songlength	ds	1	; Pattern sequence count
mod_127	ds	1	; Repeat song position / stop
mod_sequence	ds	128	; Pattern table (patterns 0..63)
mod_mk	ds	4	; M.K. signature


; --------------------------------------------------------------------------

