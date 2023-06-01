
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        PAULA.ASM                                           *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Paula/CIA software emulation.                       *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; The Amiga 'Paula' sound chip/DMA is emulated in software using two CTC
; timers. A fast 31Khz is used to supply the four DACs with samples. A slower
; 3125Hz timer is used to frequency and volume scale packets of ten samples.
; Double buffering keeps audio dropouts to a minimum. The register driven
; real-time audio engine has an ultra low latency of 0.32ms.


; --------------------------------------------------------------------------


; LINE interrupt vsync.


paula_vsync:	ld	hl,paula_frame
	ld	a,(hl)

.vsync:	cp	(hl)	; Wait for LINE to change variable
	jr	z,.vsync
	ret


; --------------------------------------------------------------------------


; Update CTC vectors and DMACON register.


; >  A = DMA (CTC) enable (see DMAEN)


paula_enable:	di

	ld	(DMACON+1),a	; Update

	ld	a,$FD		; Set LD HL,NN to LD IY,NN
	ld	(paula_timer_sync),a
	ld	iy,PAGE_DACA*256; Reset floating vector

	ld	a,i		; Patch IM2 vector table
	ld	h,a
	ld	l,6		; CTC0

	ld	a,(DMACON+1)
	test	DMAEN
	jr	z,.disable

.enable:	call	paula_set_vectors
	ei
	ret

.disable:	call	paula_reset_vectors
	ei
	ret


; --------------------------------------------------------------------------


paula_reset_vectors:	ld	de,paula_reti
	call	paula_set_vector
	call	paula_set_vector
	jr	paula_set_vector


paula_set_vectors:	ld	de,paula_ctc0
	call	paula_set_vector

	ld	de,paula_ctc1
	call	paula_set_vector

	ld	de,mod_ctc2


; > HL = IM2 vector
; > DE = Interrupt routine

; < HL = Updated
; < DE = As entry


paula_set_vector:	ld	(hl),e		; Patch IM2 vector table
	inc	l
	ld	(hl),d
	inc	l
	ret


; --------------------------------------------------------------------------


; **DUMMY CTC INTERRUPT**


paula_reti:	ei
	reti


; --------------------------------------------------------------------------


; **IM2 LINE INTERRUPT**


; Interrupt mode 2 LINE routine.


paula_line:	ei
	push	af

	db	62		; LD A,N
paula_frame	db	0
	inc	a
	ld	(paula_frame),a

	pop	af
	reti


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **IM2 CTC0 INTERRUPT**


paula_ctc0:	jp	(iy)	; IY = floating vector


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **IM2 CTC1 INTERRUPT**


; 3125Hz CTC1 sample scaler for four channel, ten sample buffering.


; This CTC1 timer routine should always be in sync with the 31K CTC0 IY DAC
; buffer write, so that CTC0 swaps buffers A/B as this slower timer triggers.
;
; Why? To give this bulky code as many Ts as possible to fill the DAC buffer
; in time for the next CTC0 buffer swap. If CTC1 lags behind, you will hear
; audio drop-outs and gargling as we will updating the live output buffer.
;
; There are around five scanlines (3125Hz) to complete this task.
;
; The timer sync logic is simple; this code is patched by paula_enable for a
; one-shot reset of the IY vector when this timer kicks in. This code then
; replaces the patch with a NOP. The sync must be carried out each time the
; CTC vectors are changed (DMAEN bit of DMACON register).


paula_ctc1:	push	af
	push	bc
	push	de
	push	hl
	exx
	push	bc
	push	hl

;	------------

	xor	a	; Code patched by paula_enable
paula_timer_sync:	nop
	ld	hl,PAGE_DACA*256; LD IY,NN / NOP:LD HL,NN

	ld	(paula_timer_sync),a ; Patch code to NOP

	ei		; Allow CTC0 DAC 31250Hz timer

;	------------
;	------------
;	------------

	ld	a,(DMACON)
	test	AUD0EN
	jr	nz,paula_dma_0

	ld	hl,paula_cache_a_0+1
	ld	de,paula_cache_b_0+1
	call	paula_reset_dac

;	ld	hl,(AUD0LPL)	; Reset loop **WIP**
;	ld	(AUD0LCL),hl
;	ld	a,(AUD0LPH)
;	ld	(AUD0LCH),a
;	ld	hl,(AUD0LOP)
;	ld	(AUD0LEN),hl

	jp	paula_off_0

;	------------

paula_dma_0:	ld	hl,(AUD0CNT)	; Period 16bit count
	ld	bc,(AUD0RES)	; Period 16bit reset
	ld	a,(AUD0VOL)	; Volume (amplitude)
	test	64
	jp	z,paula_amp_0	; Scale amplitude? (0..63)

;	<--D---><--E---><--L--->
;	000mmmmmmmmooooooooooooo; MMU : OFFSET

paula_64_0:	ld	de,(AUD0LCL+1)	; **FIXED AMPLITUDE**
	ld	a,b
	ld	b,5
	bsrl	de,b		; 21-bit address to bank8k
	ld	b,a
	ld	a,e
	nextreg	MM2,a		; Use address 16384..24575
	inc	a
	nextreg	MM3,a		; Handle bank8k overflow

	ld	de,(AUD0LCL)
	ld	a,d
	and	00011111b	; Bank8k offset (0..8191)
	or	01000000b
	ld	d,a	

	push	de		; Remember sample pointer

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA	; CTC0 buffer A/B
	ld	a,(de)		; Pre-fetch sample
	jp	z,.half		; Which buffer half?

;	------------

	ld	(paula_cache_a_0+1),a	; Buffer A
	add	hl,bc
	jr	nc,.no_0
	inc	de
	ld	a,(de)		; Next sample
.no_0:
	ld	(paula_cache_a_0+25),a
	add	hl,bc
	jr	nc,.no_1
	inc	de
	ld	a,(de)
.no_1:
	ld	(paula_cache_a_0+49),a
	add	hl,bc
	jr	nc,.no_2
	inc	de
	ld	a,(de)
.no_2:
	ld	(paula_cache_a_0+73),a
	add	hl,bc
	jr	nc,.no_3
	inc	de
	ld	a,(de)
.no_3:
	ld	(paula_cache_a_0+97),a
	add	hl,bc
	jr	nc,.no_4
	inc	de
	ld	a,(de)
.no_4:
	ld	(paula_cache_a_0+121),a
	add	hl,bc
	jr	nc,.no_5
	inc	de
	ld	a,(de)
.no_5:
	ld	(paula_cache_a_0+145),a
	add	hl,bc
	jr	nc,.no_6
	inc	de
	ld	a,(de)
.no_6:
	ld	(paula_cache_a_0+169),a
	add	hl,bc
	jr	nc,.no_7
	inc	de
	ld	a,(de)
.no_7:
	ld	(paula_cache_a_0+193),a
	add	hl,bc
	jr	nc,.no_8
	inc	de
	ld	a,(de)
.no_8:
	ld	(paula_cache_a_0+217),a
	add	hl,bc
	jr	nc,.next	; Was .no_9
	inc	de
.no_9:	jr	.next

;	------------

.half:	ld	(paula_cache_b_0+1),a	; Buffer B
	add	hl,bc
	jr	nc,.no_10
	inc	de
	ld	a,(de)
.no_10:
	ld	(paula_cache_b_0+25),a
	add	hl,bc
	jr	nc,.no_11
	inc	de
	ld	a,(de)
.no_11:
	ld	(paula_cache_b_0+49),a
	add	hl,bc
	jr	nc,.no_12
	inc	de
	ld	a,(de)
.no_12:
	ld	(paula_cache_b_0+73),a
	add	hl,bc
	jr	nc,.no_13
	inc	de
	ld	a,(de)
.no_13:
	ld	(paula_cache_b_0+97),a
	add	hl,bc
	jr	nc,.no_14
	inc	de
	ld	a,(de)
.no_14:
	ld	(paula_cache_b_0+121),a
	add	hl,bc
	jr	nc,.no_15
	inc	de
	ld	a,(de)
.no_15:
	ld	(paula_cache_b_0+145),a
	add	hl,bc
	jr	nc,.no_16
	inc	de
	ld	a,(de)
.no_16:
	ld	(paula_cache_b_0+169),a
	add	hl,bc
	jr	nc,.no_17
	inc	de
	ld	a,(de)
.no_17:
	ld	(paula_cache_b_0+193),a
	add	hl,bc
	jr	nc,.no_18
	inc	de
	ld	a,(de)
.no_18:
	ld	(paula_cache_b_0+217),a
	add	hl,bc
	jr	nc,.next	; Was .no_19
	inc	de
.no_19:
;	------------

.next:	ld	(AUD0CNT),hl	; Store period 8.8 count

	push	de		; Swap DE to shadow regs
	exx
	pop	hl		; Was DE

	jp	paula_next_0	; Jump to loop processor

;	------------
;	------------
;	------------

;	<--D---><--E---><--L--->
;	000mmmmmmmmooooooooooooo; MMU : OFFSET

paula_amp_0:	exx			; **AMPLITUDE SCALER**
	ld	de,(AUD0LCL+1)
	ld	b,5
	bsrl	de,b		; 21-bit address to bank8k

	ld	b,a
	and	00100000b	; 0/32
	rlca
	rlca
	rlca
	add	a,BANK8K_VOLUME
	nextreg	MM4,a		; 32768
	res	5,b
	set	7,b		; B = volume table MSB

	ld	a,e
	nextreg	MM2,a		; Use address 16383..24575
	inc	a
	nextreg	MM3,a		; Handle bank8k wrap

	ld	hl,(AUD0LCL)
	ld	a,h
	and	00011111b	; 8K
	or	01000000b
	ld	h,a	

	push	hl

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA

	ld	c,(hl)		; Pre-fetch sample
	ld	a,(bc)		; Volume scale (C = LSB)
	exx

	jp	z,.half		; Which buffer half?

;	------------

	ld	(paula_cache_a_0+1),a	; Buffer A
	add	hl,bc
	jr	nc,.no_0
	exx
	inc	hl
	ld	c,(hl)		; Next sample
	ld	a,(bc)		; Volume scale
	exx
.no_0:
	ld	(paula_cache_a_0+25),a
	add	hl,bc
	jr	nc,.no_1
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_1:
	ld	(paula_cache_a_0+49),a
	add	hl,bc
	jr	nc,.no_2
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_2:
	ld	(paula_cache_a_0+73),a
	add	hl,bc
	jr	nc,.no_3
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_3:
	ld	(paula_cache_a_0+97),a
	add	hl,bc
	jr	nc,.no_4
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_4:
	ld	(paula_cache_a_0+121),a
	add	hl,bc
	jr	nc,.no_5
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_5:
	ld	(paula_cache_a_0+145),a
	add	hl,bc
	jr	nc,.no_6
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_6:
	ld	(paula_cache_a_0+169),a
	add	hl,bc
	jr	nc,.no_7
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_7:
	ld	(paula_cache_a_0+193),a
	add	hl,bc
	jr	nc,.no_8
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_8:
	ld	(paula_cache_a_0+217),a
	add	hl,bc
	jr	nc,.next	; Was .no_9
	exx
	inc	hl
	exx
.no_9:	jr	.next

;	------------
;	------------
;	------------

.half:	ld	(paula_cache_b_0+1),a	; Buffer B
	add	hl,bc
	jr	nc,.no_10
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_10:
	ld	(paula_cache_b_0+25),a
	add	hl,bc
	jr	nc,.no_11
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_11:
	ld	(paula_cache_b_0+49),a
	add	hl,bc
	jr	nc,.no_12
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_12:
	ld	(paula_cache_b_0+73),a
	add	hl,bc
	jr	nc,.no_13
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_13:
	ld	(paula_cache_b_0+97),a
	add	hl,bc
	jr	nc,.no_14
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_14:
	ld	(paula_cache_b_0+121),a
	add	hl,bc
	jr	nc,.no_15
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_15:
	ld	(paula_cache_b_0+145),a
	add	hl,bc
	jr	nc,.no_16
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_16:
	ld	(paula_cache_b_0+169),a
	add	hl,bc
	jr	nc,.no_17
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_17:
	ld	(paula_cache_b_0+193),a
	add	hl,bc
	jr	nc,.no_18
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_18:
	ld	(paula_cache_b_0+217),a
	add	hl,bc
	jr	nc,.next	; Was .no_19
	exx
	inc	hl
	exx
.no_19:
;	------------

.next:	ld	(AUD0CNT),hl

	exx	; Update sample pointer, counter and loop

paula_next_0:	pop	de		; Was HL
	xor	a
	sbc	hl,de
	ex	de,hl		; DE = samples fetched

	ld	hl,(AUD0LCL)
	add	hl,de		; Update 21-bit ptr (2MB)
	ld	(AUD0LCL),hl
	ld	a,(AUD0LCH)
	adc	a,0
	ld	(AUD0LCH),a

	ld	hl,(AUD0LEN)	; Sample length (64K)
	xor	a
	sbc	hl,de
	jr	c,.loop
	jr	nz,.no_loop

.loop:	ld	a,h		; 16-bit negate
	cpl
	ld	b,a
	ld	a,l
	cpl
	ld	c,a
	inc	bc		; BC = zero or positive
	ex	de,hl		; DE = zero or negative

	ld	hl,(AUD0LPL)
	add	hl,bc		; Adjust sample overshoot
	ld	(AUD0LCL),hl
	ld	a,(AUD0LPH)
	adc	a,0
	ld	(AUD0LCH),a

	ld	hl,(AUD0LOP)
	add	hl,de		; Adjust sample overshoot

.no_loop:	ld	(AUD0LEN),hl
	exx

;	------------
;	------------
;	------------
;	------------
;	------------
;	------------
;	------------

paula_off_0:	ld	a,(DMACON)
	test	AUD1EN
	jr	nz,paula_dma_1

	ld	hl,paula_cache_a_1+1
	ld	de,paula_cache_b_1+1
	call	paula_reset_dac

;	ld	hl,(AUD1LPL)	; Reset loop **WIP**
;	ld	(AUD1LCL),hl
;	ld	a,(AUD1LPH)
;	ld	(AUD1LCH),a
;	ld	hl,(AUD1LOP)
;	ld	(AUD1LEN),hl

	jp	paula_off_1

;	------------

paula_dma_1:	ld	hl,(AUD1CNT)
	ld	bc,(AUD1RES)
	ld	a,(AUD1VOL)
	test	64
	jp	z,paula_amp_1

paula_64_1:	ld	de,(AUD1LCL+1)
	ld	a,b
	ld	b,5
	bsrl	de,b
	ld	b,a
	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	de,(AUD1LCL)
	ld	a,d
	and	00011111b
	or	01000000b
	ld	d,a	

	push	de

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA
	ld	a,(de)
	jp	z,.half

;	------------

	ld	(paula_cache_a_1+1),a
	add	hl,bc
	jr	nc,.no_0
	inc	de
	ld	a,(de)
.no_0:
	ld	(paula_cache_a_1+25),a
	add	hl,bc
	jr	nc,.no_1
	inc	de
	ld	a,(de)
.no_1:
	ld	(paula_cache_a_1+49),a
	add	hl,bc
	jr	nc,.no_2
	inc	de
	ld	a,(de)
.no_2:
	ld	(paula_cache_a_1+73),a
	add	hl,bc
	jr	nc,.no_3
	inc	de
	ld	a,(de)
.no_3:
	ld	(paula_cache_a_1+97),a
	add	hl,bc
	jr	nc,.no_4
	inc	de
	ld	a,(de)
.no_4:
	ld	(paula_cache_a_1+121),a
	add	hl,bc
	jr	nc,.no_5
	inc	de
	ld	a,(de)
.no_5:
	ld	(paula_cache_a_1+145),a
	add	hl,bc
	jr	nc,.no_6
	inc	de
	ld	a,(de)
.no_6:
	ld	(paula_cache_a_1+169),a
	add	hl,bc
	jr	nc,.no_7
	inc	de
	ld	a,(de)
.no_7:
	ld	(paula_cache_a_1+193),a
	add	hl,bc
	jr	nc,.no_8
	inc	de
	ld	a,(de)
.no_8:
	ld	(paula_cache_a_1+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_9:	jr	.next

;	------------

.half:	ld	(paula_cache_b_1+1),a
	add	hl,bc
	jr	nc,.no_10
	inc	de
	ld	a,(de)
.no_10:
	ld	(paula_cache_b_1+25),a
	add	hl,bc
	jr	nc,.no_11
	inc	de
	ld	a,(de)
.no_11:
	ld	(paula_cache_b_1+49),a
	add	hl,bc
	jr	nc,.no_12
	inc	de
	ld	a,(de)
.no_12:
	ld	(paula_cache_b_1+73),a
	add	hl,bc
	jr	nc,.no_13
	inc	de
	ld	a,(de)
.no_13:
	ld	(paula_cache_b_1+97),a
	add	hl,bc
	jr	nc,.no_14
	inc	de
	ld	a,(de)
.no_14:
	ld	(paula_cache_b_1+121),a
	add	hl,bc
	jr	nc,.no_15
	inc	de
	ld	a,(de)
.no_15:
	ld	(paula_cache_b_1+145),a
	add	hl,bc
	jr	nc,.no_16
	inc	de
	ld	a,(de)
.no_16:
	ld	(paula_cache_b_1+169),a
	add	hl,bc
	jr	nc,.no_17
	inc	de
	ld	a,(de)
.no_17:
	ld	(paula_cache_b_1+193),a
	add	hl,bc
	jr	nc,.no_18
	inc	de
	ld	a,(de)
.no_18:
	ld	(paula_cache_b_1+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_19:
;	------------

.next:	ld	(AUD1CNT),hl

	push	de
	exx
	pop	hl

	jp	paula_next_1

;	------------
;	------------
;	------------

paula_amp_1:	exx
	ld	de,(AUD1LCL+1)
	ld	b,5
	bsrl	de,b

	ld	b,a
	and	00100000b
	rlca
	rlca
	rlca
	add	a,BANK8K_VOLUME
	nextreg	MM4,a
	res	5,b
	set	7,b

	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	hl,(AUD1LCL)
	ld	a,h
	and	00011111b
	or	01000000b
	ld	h,a	

	push	hl

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA

	ld	c,(hl)
	ld	a,(bc)
	exx

	jp	z,.half

;	------------

	ld	(paula_cache_a_1+1),a
	add	hl,bc
	jr	nc,.no_0
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_0:
	ld	(paula_cache_a_1+25),a
	add	hl,bc
	jr	nc,.no_1
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_1:
	ld	(paula_cache_a_1+49),a
	add	hl,bc
	jr	nc,.no_2
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_2:
	ld	(paula_cache_a_1+73),a
	add	hl,bc
	jr	nc,.no_3
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_3:
	ld	(paula_cache_a_1+97),a
	add	hl,bc
	jr	nc,.no_4
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_4:
	ld	(paula_cache_a_1+121),a
	add	hl,bc
	jr	nc,.no_5
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_5:
	ld	(paula_cache_a_1+145),a
	add	hl,bc
	jr	nc,.no_6
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_6:
	ld	(paula_cache_a_1+169),a
	add	hl,bc
	jr	nc,.no_7
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_7:
	ld	(paula_cache_a_1+193),a
	add	hl,bc
	jr	nc,.no_8
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_8:
	ld	(paula_cache_a_1+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_9:	jr	.next

;	------------
;	------------
;	------------

.half:	ld	(paula_cache_b_1+1),a
	add	hl,bc
	jr	nc,.no_10
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_10:
	ld	(paula_cache_b_1+25),a
	add	hl,bc
	jr	nc,.no_11
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_11:
	ld	(paula_cache_b_1+49),a
	add	hl,bc
	jr	nc,.no_12
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_12:
	ld	(paula_cache_b_1+73),a
	add	hl,bc
	jr	nc,.no_13
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_13:
	ld	(paula_cache_b_1+97),a
	add	hl,bc
	jr	nc,.no_14
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_14:
	ld	(paula_cache_b_1+121),a
	add	hl,bc
	jr	nc,.no_15
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_15:
	ld	(paula_cache_b_1+145),a
	add	hl,bc
	jr	nc,.no_16
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_16:
	ld	(paula_cache_b_1+169),a
	add	hl,bc
	jr	nc,.no_17
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_17:
	ld	(paula_cache_b_1+193),a
	add	hl,bc
	jr	nc,.no_18
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_18:
	ld	(paula_cache_b_1+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_19:
;	------------

.next:	ld	(AUD1CNT),hl

	exx

paula_next_1:	pop	de
	xor	a
	sbc	hl,de
	ex	de,hl

	ld	hl,(AUD1LCL)
	add	hl,de
	ld	(AUD1LCL),hl
	ld	a,(AUD1LCH)
	adc	a,0
	ld	(AUD1LCH),a

	ld	hl,(AUD1LEN)
	xor	a
	sbc	hl,de
	jr	c,.loop
	jr	nz,.no_loop

.loop:	ld	a,h
	cpl
	ld	b,a
	ld	a,l
	cpl
	ld	c,a
	inc	bc
	ex	de,hl

	ld	hl,(AUD1LPL)
	add	hl,bc
	ld	(AUD1LCL),hl
	ld	a,(AUD1LPH)
	adc	a,0
	ld	(AUD1LCH),a

	ld	hl,(AUD1LOP)
	add	hl,de

.no_loop:	ld	(AUD1LEN),hl
	exx

;	------------
;	------------
;	------------
;	------------
;	------------
;	------------
;	------------

paula_off_1:	ld	a,(DMACON)
	test	AUD2EN
	jr	nz,paula_dma_2

	ld	hl,paula_cache_a_2+1
	ld	de,paula_cache_b_2+1
	call	paula_reset_dac

;	ld	hl,(AUD2LPL)	; Reset loop **WIP**
;	ld	(AUD2LCL),hl
;	ld	a,(AUD2LPH)
;	ld	(AUD2LCH),a
;	ld	hl,(AUD2LOP)
;	ld	(AUD2LEN),hl

	jp	paula_off_2

;	------------

paula_dma_2:	ld	hl,(AUD2CNT)
	ld	bc,(AUD2RES)
	ld	a,(AUD2VOL)
	test	64
	jp	z,paula_amp_2

paula_64_2:	ld	de,(AUD2LCL+1)
	ld	a,b
	ld	b,5
	bsrl	de,b
	ld	b,a
	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	de,(AUD2LCL)
	ld	a,d
	and	00011111b
	or	01000000b
	ld	d,a	

	push	de

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA
	ld	a,(de)
	jp	z,.half

;	------------

	ld	(paula_cache_a_2+1),a
	add	hl,bc
	jr	nc,.no_0
	inc	de
	ld	a,(de)
.no_0:
	ld	(paula_cache_a_2+25),a
	add	hl,bc
	jr	nc,.no_1
	inc	de
	ld	a,(de)
.no_1:
	ld	(paula_cache_a_2+49),a
	add	hl,bc
	jr	nc,.no_2
	inc	de
	ld	a,(de)
.no_2:
	ld	(paula_cache_a_2+73),a
	add	hl,bc
	jr	nc,.no_3
	inc	de
	ld	a,(de)
.no_3:
	ld	(paula_cache_a_2+97),a
	add	hl,bc
	jr	nc,.no_4
	inc	de
	ld	a,(de)
.no_4:
	ld	(paula_cache_a_2+121),a
	add	hl,bc
	jr	nc,.no_5
	inc	de
	ld	a,(de)
.no_5:
	ld	(paula_cache_a_2+145),a
	add	hl,bc
	jr	nc,.no_6
	inc	de
	ld	a,(de)
.no_6:
	ld	(paula_cache_a_2+169),a
	add	hl,bc
	jr	nc,.no_7
	inc	de
	ld	a,(de)
.no_7:
	ld	(paula_cache_a_2+193),a
	add	hl,bc
	jr	nc,.no_8
	inc	de
	ld	a,(de)
.no_8:
	ld	(paula_cache_a_2+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_9:	jr	.next

;	------------

.half:	ld	(paula_cache_b_2+1),a
	add	hl,bc
	jr	nc,.no_10
	inc	de
	ld	a,(de)
.no_10:
	ld	(paula_cache_b_2+25),a
	add	hl,bc
	jr	nc,.no_11
	inc	de
	ld	a,(de)
.no_11:
	ld	(paula_cache_b_2+49),a
	add	hl,bc
	jr	nc,.no_12
	inc	de
	ld	a,(de)
.no_12:
	ld	(paula_cache_b_2+73),a
	add	hl,bc
	jr	nc,.no_13
	inc	de
	ld	a,(de)
.no_13:
	ld	(paula_cache_b_2+97),a
	add	hl,bc
	jr	nc,.no_14
	inc	de
	ld	a,(de)
.no_14:
	ld	(paula_cache_b_2+121),a
	add	hl,bc
	jr	nc,.no_15
	inc	de
	ld	a,(de)
.no_15:
	ld	(paula_cache_b_2+145),a
	add	hl,bc
	jr	nc,.no_16
	inc	de
	ld	a,(de)
.no_16:
	ld	(paula_cache_b_2+169),a
	add	hl,bc
	jr	nc,.no_17
	inc	de
	ld	a,(de)
.no_17:
	ld	(paula_cache_b_2+193),a
	add	hl,bc
	jr	nc,.no_18
	inc	de
	ld	a,(de)
.no_18:
	ld	(paula_cache_b_2+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_19:
;	------------

.next:	ld	(AUD2CNT),hl

	push	de
	exx
	pop	hl

	jp	paula_next_2

;	------------
;	------------
;	------------

paula_amp_2:	exx
	ld	de,(AUD2LCL+1)
	ld	b,5
	bsrl	de,b

	ld	b,a
	and	00100000b
	rlca
	rlca
	rlca
	add	a,BANK8K_VOLUME
	nextreg	MM4,a
	res	5,b
	set	7,b

	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	hl,(AUD2LCL)
	ld	a,h
	and	00011111b
	or	01000000b
	ld	h,a	

	push	hl

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA

	ld	c,(hl)
	ld	a,(bc)
	exx

	jp	z,.half

;	------------

	ld	(paula_cache_a_2+1),a
	add	hl,bc
	jr	nc,.no_0
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_0:
	ld	(paula_cache_a_2+25),a
	add	hl,bc
	jr	nc,.no_1
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_1:
	ld	(paula_cache_a_2+49),a
	add	hl,bc
	jr	nc,.no_2
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_2:
	ld	(paula_cache_a_2+73),a
	add	hl,bc
	jr	nc,.no_3
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_3:
	ld	(paula_cache_a_2+97),a
	add	hl,bc
	jr	nc,.no_4
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_4:
	ld	(paula_cache_a_2+121),a
	add	hl,bc
	jr	nc,.no_5
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_5:
	ld	(paula_cache_a_2+145),a
	add	hl,bc
	jr	nc,.no_6
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_6:
	ld	(paula_cache_a_2+169),a
	add	hl,bc
	jr	nc,.no_7
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_7:
	ld	(paula_cache_a_2+193),a
	add	hl,bc
	jr	nc,.no_8
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_8:
	ld	(paula_cache_a_2+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_9:	jr	.next

;	------------
;	------------
;	------------

.half:	ld	(paula_cache_b_2+1),a
	add	hl,bc
	jr	nc,.no_10
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_10:
	ld	(paula_cache_b_2+25),a
	add	hl,bc
	jr	nc,.no_11
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_11:
	ld	(paula_cache_b_2+49),a
	add	hl,bc
	jr	nc,.no_12
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_12:
	ld	(paula_cache_b_2+73),a
	add	hl,bc
	jr	nc,.no_13
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_13:
	ld	(paula_cache_b_2+97),a
	add	hl,bc
	jr	nc,.no_14
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_14:
	ld	(paula_cache_b_2+121),a
	add	hl,bc
	jr	nc,.no_15
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_15:
	ld	(paula_cache_b_2+145),a
	add	hl,bc
	jr	nc,.no_16
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_16:
	ld	(paula_cache_b_2+169),a
	add	hl,bc
	jr	nc,.no_17
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_17:
	ld	(paula_cache_b_2+193),a
	add	hl,bc
	jr	nc,.no_18
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_18:
	ld	(paula_cache_b_2+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_19:
;	------------

.next:	ld	(AUD2CNT),hl

	exx

paula_next_2:	pop	de
	xor	a
	sbc	hl,de
	ex	de,hl

	ld	hl,(AUD2LCL)
	add	hl,de
	ld	(AUD2LCL),hl
	ld	a,(AUD2LCH)
	adc	a,0
	ld	(AUD2LCH),a

	ld	hl,(AUD2LEN)
	xor	a
	sbc	hl,de
	jr	c,.loop
	jr	nz,.no_loop

.loop:	ld	a,h
	cpl
	ld	b,a
	ld	a,l
	cpl
	ld	c,a
	inc	bc
	ex	de,hl

	ld	hl,(AUD2LPL)
	add	hl,bc
	ld	(AUD2LCL),hl
	ld	a,(AUD2LPH)
	adc	a,0
	ld	(AUD2LCH),a

	ld	hl,(AUD2LOP)
	add	hl,de

.no_loop:	ld	(AUD2LEN),hl
	exx

;	------------
;	------------
;	------------
;	------------
;	------------
;	------------
;	------------

paula_off_2:	ld	a,(DMACON)
	test	AUD3EN
	jr	nz,paula_dma_3

	ld	hl,paula_cache_a_3+1
	ld	de,paula_cache_b_3+1
	call	paula_reset_dac

;	ld	hl,(AUD3LPL)	; Reset loop **WIP**
;	ld	(AUD3LCL),hl
;	ld	a,(AUD3LPH)
;	ld	(AUD3LCH),a
;	ld	hl,(AUD3LOP)
;	ld	(AUD3LEN),hl

	jp	paula_off_3

;	------------

paula_dma_3:	ld	hl,(AUD3CNT)
	ld	bc,(AUD3RES)
	ld	a,(AUD3VOL)
	test	64
	jp	z,paula_amp_3

paula_64_3:	ld	de,(AUD3LCL+1)
	ld	a,b
	ld	b,5
	bsrl	de,b
	ld	b,a
	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	de,(AUD3LCL)
	ld	a,d
	and	00011111b
	or	01000000b
	ld	d,a	

	push	de

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA
	ld	a,(de)
	jp	z,.half

;	------------

	ld	(paula_cache_a_3+1),a
	add	hl,bc
	jr	nc,.no_0
	inc	de
	ld	a,(de)
.no_0:
	ld	(paula_cache_a_3+25),a
	add	hl,bc
	jr	nc,.no_1
	inc	de
	ld	a,(de)
.no_1:
	ld	(paula_cache_a_3+49),a
	add	hl,bc
	jr	nc,.no_2
	inc	de
	ld	a,(de)
.no_2:
	ld	(paula_cache_a_3+73),a
	add	hl,bc
	jr	nc,.no_3
	inc	de
	ld	a,(de)
.no_3:
	ld	(paula_cache_a_3+97),a
	add	hl,bc
	jr	nc,.no_4
	inc	de
	ld	a,(de)
.no_4:
	ld	(paula_cache_a_3+121),a
	add	hl,bc
	jr	nc,.no_5
	inc	de
	ld	a,(de)
.no_5:
	ld	(paula_cache_a_3+145),a
	add	hl,bc
	jr	nc,.no_6
	inc	de
	ld	a,(de)
.no_6:
	ld	(paula_cache_a_3+169),a
	add	hl,bc
	jr	nc,.no_7
	inc	de
	ld	a,(de)
.no_7:
	ld	(paula_cache_a_3+193),a
	add	hl,bc
	jr	nc,.no_8
	inc	de
	ld	a,(de)
.no_8:
	ld	(paula_cache_a_3+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_9:	jr	.next

;	------------

.half:	ld	(paula_cache_b_3+1),a
	add	hl,bc
	jr	nc,.no_10
	inc	de
	ld	a,(de)
.no_10:
	ld	(paula_cache_b_3+25),a
	add	hl,bc
	jr	nc,.no_11
	inc	de
	ld	a,(de)
.no_11:
	ld	(paula_cache_b_3+49),a
	add	hl,bc
	jr	nc,.no_12
	inc	de
	ld	a,(de)
.no_12:
	ld	(paula_cache_b_3+73),a
	add	hl,bc
	jr	nc,.no_13
	inc	de
	ld	a,(de)
.no_13:
	ld	(paula_cache_b_3+97),a
	add	hl,bc
	jr	nc,.no_14
	inc	de
	ld	a,(de)
.no_14:
	ld	(paula_cache_b_3+121),a
	add	hl,bc
	jr	nc,.no_15
	inc	de
	ld	a,(de)
.no_15:
	ld	(paula_cache_b_3+145),a
	add	hl,bc
	jr	nc,.no_16
	inc	de
	ld	a,(de)
.no_16:
	ld	(paula_cache_b_3+169),a
	add	hl,bc
	jr	nc,.no_17
	inc	de
	ld	a,(de)
.no_17:
	ld	(paula_cache_b_3+193),a
	add	hl,bc
	jr	nc,.no_18
	inc	de
	ld	a,(de)
.no_18:
	ld	(paula_cache_b_3+217),a
	add	hl,bc
	jr	nc,.next
	inc	de
.no_19:
;	------------

.next:	ld	(AUD3CNT),hl

	push	de
	exx
	pop	hl

	jp	paula_next_3

;	------------
;	------------
;	------------

paula_amp_3:	exx
	ld	de,(AUD3LCL+1)
	ld	b,5
	bsrl	de,b

	ld	b,a
	and	00100000b
	rlca
	rlca
	rlca
	add	a,BANK8K_VOLUME
	nextreg	MM4,a
	res	5,b
	set	7,b

	ld	a,e
	nextreg	MM2,a
	inc	a
	nextreg	MM3,a

	ld	hl,(AUD3LCL)
	ld	a,h
	and	00011111b
	or	01000000b
	ld	h,a	

	push	hl

	db	$FD,$7C		; LD A,IYH
	cp	PAGE_DACA

	ld	c,(hl)
	ld	a,(bc)
	exx

	jp	z,.half

;	------------

	ld	(paula_cache_a_3+1),a
	add	hl,bc
	jr	nc,.no_0
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_0:
	ld	(paula_cache_a_3+25),a
	add	hl,bc
	jr	nc,.no_1
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_1:
	ld	(paula_cache_a_3+49),a
	add	hl,bc
	jr	nc,.no_2
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_2:
	ld	(paula_cache_a_3+73),a
	add	hl,bc
	jr	nc,.no_3
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_3:
	ld	(paula_cache_a_3+97),a
	add	hl,bc
	jr	nc,.no_4
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_4:
	ld	(paula_cache_a_3+121),a
	add	hl,bc
	jr	nc,.no_5
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_5:
	ld	(paula_cache_a_3+145),a
	add	hl,bc
	jr	nc,.no_6
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_6:
	ld	(paula_cache_a_3+169),a
	add	hl,bc
	jr	nc,.no_7
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_7:
	ld	(paula_cache_a_3+193),a
	add	hl,bc
	jr	nc,.no_8
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_8:
	ld	(paula_cache_a_3+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_9:	jr	.next

;	------------
;	------------
;	------------

.half:	ld	(paula_cache_b_3+1),a
	add	hl,bc
	jr	nc,.no_10
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_10:
	ld	(paula_cache_b_3+25),a
	add	hl,bc
	jr	nc,.no_11
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_11:
	ld	(paula_cache_b_3+49),a
	add	hl,bc
	jr	nc,.no_12
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_12:
	ld	(paula_cache_b_3+73),a
	add	hl,bc
	jr	nc,.no_13
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_13:
	ld	(paula_cache_b_3+97),a
	add	hl,bc
	jr	nc,.no_14
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_14:
	ld	(paula_cache_b_3+121),a
	add	hl,bc
	jr	nc,.no_15
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_15:
	ld	(paula_cache_b_3+145),a
	add	hl,bc
	jr	nc,.no_16
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_16:
	ld	(paula_cache_b_3+169),a
	add	hl,bc
	jr	nc,.no_17
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_17:
	ld	(paula_cache_b_3+193),a
	add	hl,bc
	jr	nc,.no_18
	exx
	inc	hl
	ld	c,(hl)
	ld	a,(bc)
	exx
.no_18:
	ld	(paula_cache_b_3+217),a
	add	hl,bc
	jr	nc,.next
	exx
	inc	hl
	exx
.no_19:
;	------------

.next:	ld	(AUD3CNT),hl

	exx

paula_next_3:	pop	de
	xor	a
	sbc	hl,de
	ex	de,hl

	ld	hl,(AUD3LCL)
	add	hl,de
	ld	(AUD3LCL),hl
	ld	a,(AUD3LCH)
	adc	a,0
	ld	(AUD3LCH),a

	ld	hl,(AUD3LEN)
	xor	a
	sbc	hl,de
	jr	c,.loop
	jr	nz,.no_loop

.loop:	ld	a,h
	cpl
	ld	b,a
	ld	a,l
	cpl
	ld	c,a
	inc	bc
	ex	de,hl

	ld	hl,(AUD3LPL)
	add	hl,bc
	ld	(AUD3LCL),hl
	ld	a,(AUD3LPH)
	adc	a,0
	ld	(AUD3LCH),a

	ld	hl,(AUD3LOP)
	add	hl,de

.no_loop:	ld	(AUD3LEN),hl
	exx

;	------------
;	------------
;	------------
;	------------
;	------------
;	------------
;	------------

paula_off_3:	pop	hl
	pop	bc
	exx
	pop	hl
	pop	de
	pop	bc
	pop	af
	reti


; --------------------------------------------------------------------------


; Reset all DAC buffers.


paula_flush_dacs:	ld	hl,paula_cache_a_0+1
	ld	de,paula_cache_b_0+1
	call	paula_reset_dac

	ld	hl,paula_cache_a_1+1
	ld	de,paula_cache_b_1+1
	call	paula_reset_dac

	ld	hl,paula_cache_a_2+1
	ld	de,paula_cache_b_2+1
	call	paula_reset_dac

	ld	hl,paula_cache_a_3+1
	ld	de,paula_cache_b_3+1


; --------------------------------------------------------------------------


; Clear DAC buffers for channel.


; > HL = DAC cache A
; > DE = DAC cache B


paula_reset_dac:	ld	a,24		; Code module length

	ld	bc,$0A80	; B = 10 / C = 128

.a:	ld	(hl),c
	add	hl,a
	djnz	.a

	ex	de,hl		; Swap cache buffer A/B

	ld	b,10

.b:	ld	(hl),c
	add	hl,a
	djnz	.b
	ret


; --------------------------------------------------------------------------


; Paula sample output enable (emulated Amiga register).


DMACON	db	0	; Audio DMA enable (see AUD0EN)
	db	0	; Audio CTC enable (see DMAEN)


; --------------------------------------------------------------------------

