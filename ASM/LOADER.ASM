
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        LOADER.ASM                                          *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Protracker MOD loader.                              *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Load MOD header, song sequence, patterns and all samples.

; sram_ptr will point to the end of sample RAM on return.


; **CHANGES MM0/MM1/MM2/MM3**

; **DISABLE PAULA BEFORE CALLING**


; > IX = Pointer to filename

; <  A = Status (0 = fail / 1 = load / -1 = open)


mod_load:	ld	(loader_sp),sp	; Backup stack pointer

	nextreg	MM0,255		; Restore ROM
	nextreg	MM1,255

	ld	b,1		; Read mode; Existing file
	ld	a,"*"		; Use default drive
	rst	08h
	db	f_open		; Open file
	jp	c,mod_open_err
	ld	(file_handle),a	; Store file handle

	ld	ix,mod_header
	ld	bc,MOD_listlen	; Size
	ld	a,(file_handle)
	rst	08h
	db	f_read		; Cache header and song
	jp	c,mod_file_err

	ld	a,b		; 1084 ($43C) loaded ok?
	cp	$04
	jp	nz,mod_file_err
	ld	a,c
	cp	$3C
	jp	nz,mod_file_err

;	------------

	ld	hl,mod_mk	; B = 4
	ld	de,mk_txt
.mk:	ld	a,(de)		; "M.K." signature?
	cp	(hl)
	jr	nz,.not_mk
	inc	de
	inc	hl
	djnz	.mk

	ld	hl,MOD_listlen/2
	jr	.is_mk

;	------------

.not_mk:	ld	ix,2		; Seek mode (subtract)
	ld	bc,0		; Seek size
	ld	de,1084-600	; Seek back to offset 600
	ld	a,(file_handle)
	rst	08h
	db	f_seek		; Seek
	jp	c,mod_file_err

;	------------

	ld	hl,mod_samples+(30*15) ; Convert header 15
	ld	de,mod_songlength
	ld	bc,130*256	; C = 0 to wipe sample data

.relocate:	ld	a,(hl)		; Promote 15 sample to 31
	ld	(hl),c		; Wipe 480 bytes as we go
	inc	hl
	ld	(de),a
	inc	de
	djnz	.relocate

	ld	b,350/2		; 350+130 = 480 (30*16)
.wipe:	ld	(hl),c
	inc	hl
	ld	(hl),c
	inc	hl
	djnz	.wipe

	ld	hl,600/2	; 1084-484 (MOD_listlen)

;	------------
;	------------
;	------------

.is_mk:	ld	(.header_patch+2),hl	; ADD HL,NN

	ld	hl,mod_samples+SAMPLE_length
	ld	b,31

.sixty_four_k:	bit	7,(hl)		; Check for > 64K samples
	jp	nz,mod_file_err
	add	hl,SAMPLE_listlen
	djnz	.sixty_four_k

;	------------

	ld	hl,mod_sequence		;
	xor	a			; Check all 128
	ld	b,128			;

.count:	cp	(hl)		; Count patterns
	jr	nc,.next	; Higher or same
	ld	a,(hl)
.next:	inc	hl
	djnz	.count

	inc	a		; +1 (include 0)

	ld	(mod_patterns),a

	ld	hl,24576	; MM3 ($6000)
	ld	b,a		; Patterns to load
	ld	a,BANK8K_PATTERNS

.pattern:	push	bc
	push	hl

	push	hl
	pop	ix		; IX=HL

	nextreg	MM3,a		; 24K MMU workspace

	ex	af,af

	ld	bc,1024		; Pattern size
	ld	a,(file_handle)
	rst	08h
	db	f_read		; Cache patterns
	jp	c,mod_file_err

	ex	af,af

	pop	hl

	add	hl,1024		; HL = IX+1024
	bit	7,h		; 32K?
	jr	z,.no_wrap
	ld	hl,24576	; MM3 ($6000)
	inc	a		; Next bank8k
.no_wrap:
	pop	bc
	djnz	.pattern

;	------------

	ld	a,(mod_patterns); Calc sample seek position

	ld	b,a
	add	a,a
	ld	h,a		; * 512
	xor	a
	ld	l,a
.header_patch:	add	hl,MOD_listlen/2; **PATCHED**
	add	hl,hl		; Handles 64 patterns (64K)
	ld	(sample_pos+0),hl
	adc	a,0
	ld	(sample_pos+2),a ; 17-bit file seek

;	------------

	call	mod_load_samples

	ld	a,(file_handle)
	rst	08h
	db	f_close		; Close file

	ld	a,1		; Return 1 'load'
	ret

;	------------

mod_file_err:	di
	ld	sp,(loader_sp)	; Restore stack pointer
	ei

	ld	a,(file_handle)
	rst	08h
	db	f_close		; Close file

	xor	a		; Return 0 'fail'
	ret

mod_open_err:	ld	a,-1		; Return -1 'open'
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Load samples into SRAM and pre-render loops for four cases;

; Case #0: No loop, silence added to the end of the existing sample.
; Case #1: Small loop 4,6,8, repeated six times at end of existing sample.
; Case #2: Large loop, appended with overflow at end of existing sample.
; Case #3: Loop to end, overflow appended to end of existing sample.


mod_load_samples:	ld	hl,(sram_init+0)   ; Init SRAM sample ptr
	ld	a, (sram_init+2)
	ld	(sram_ptr+0),hl
	ld	(sram_ptr+2),a

	ld	iy,mod_instruments

	xor	a		 ; **CREATE SAMPLE ZERO**
	ld	(iy+AUDX_tun),a
	ld	(iy+AUDX_vol),64 ; Faster to NOT vol scale

	ld	(iy+AUDX_len+0),240 ; 24 packet play len
	ld	(iy+AUDX_len+1),a

	ld	(iy+AUDX_lop+0),240 ; 24 packet loop len
	ld	(iy+AUDX_lop+1),a

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	ld	(iy+AUDX_lcl+0),l ; Set sample play ptr
	ld	(iy+AUDX_lcl+1),h
	ld	(iy+AUDX_lch+0),d

	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),d

	call	mod_mmu_sram

	ld	bc,128		; B = 0 (256) / C = 128

.zero:	ld	(hl),c		; 256 samples of silence to
	inc	hl		; clear SRAM and build 10
	djnz	.zero		; sample loop with overflow
	ld	c,b
	inc	b		; BC = 256

	ld	hl,(sram_ptr+0)
	ld	a, (sram_ptr+2)
	add	hl,bc		; 21-bit (2MB)
	adc	a,0
	ld	(sram_ptr+0),hl
	ld	(sram_ptr+2),a

	ld	iy,mod_instruments+AUDX_listlen

;	------------

	ld	ix,mod_samples
	ld	a,31

.sample:	push	af
	push	ix
	push	iy

	ld	hl,(sample_pos+0)	; Set file ptr
	ld	a, (sample_pos+2)
	ld	(file_ptr+0),hl
	ld	(file_ptr+2),a

	ld	h,(ix+SAMPLE_length+0)	; **ENDIAN**
	ld	l,(ix+SAMPLE_length+1)
	add	hl,hl			; WORDS to BYTES
	ld	(sample_len),hl		; MOD sample len

	ld	a,l
	or	h
	jr	nz,.valid		; A = 0 (EMPTY) ? 

;	------------

	ld	(iy+AUDX_tun),a	; **CREATE EMPTY SAMPLE**

	ld	(iy+AUDX_vol),64 ; Faster to NOT vol scale

	ld	(iy+AUDX_len+0),240 ; 24 packet play len
	ld	(iy+AUDX_len+1),a

	ld	(iy+AUDX_lop+0),240 ; 24 packet loop len
	ld	(iy+AUDX_lop+1),a

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	ld	(iy+AUDX_lcl+0),l ; Set sample play ptr
	ld	(iy+AUDX_lcl+1),h
	ld	(iy+AUDX_lch+0),d

	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),d

	call	mod_mmu_sram

	ld	bc,128		; B = 0 (256)

.silence:	ld	(hl),c		; 256 samples of silence to
	inc	hl		; clear SRAM and build 10
	djnz	.silence	; sample loop with overflow

	ld	bc,256
	jp	.align_256

;	------------
;	------------
;	------------

.valid:	ld	(file_len),hl	; Store sample length

	ld	(iy+AUDX_len+0),l ; Set sample play len
	ld	(iy+AUDX_len+1),h

	ld	a,(ix+SAMPLE_volume)
	ld	(iy+AUDX_vol),a		; Set volume
	ld	a,(ix+SAMPLE_finetune)
	and	00001111b
	ld	(iy+AUDX_tun),a		; Set fine tune

	ld	hl,(sram_ptr+0)
	ld	a,(sram_ptr+2)

	ld	(iy+AUDX_lcl+0),l ; Set sample play ptr
	ld	(iy+AUDX_lcl+1),h
	ld	(iy+AUDX_lch+0),a

	call	mod_read_samples; Read file_len SRAM

	ld	h,(ix+SAMPLE_repeatpos+0) ; **ENDIAN**
	ld	l,(ix+SAMPLE_repeatpos+1)

	add	hl,hl		; WORDS to BYTES
	ex	de,hl		; DE = loop pos

	ld	hl,(file_ptr+0)	; Set to repeat position
	ld	a, (file_ptr+2)
	add	hl,de		; 21-bit (2MB)
	adc	a,0
	ld	(file_ptr+0),hl
	ld	(file_ptr+2),a

	ld	h,(ix+SAMPLE_repeatlen+0) ; **ENDIAN**
	ld	l,(ix+SAMPLE_repeatlen+1)

	add	hl,hl		; WORDS to BYTES
	ld	b,h
	ld	c,l		; BC = len
	add	hl,de		; HL = len+pos

	inc	b
	dec	b
	jr	nz,.large	; > 255 ? (16-bit length)

	ld	a,c		; Compare 8-bit length

	cp	2+1		; No loop?
	jp	c,.case0
	cp	10
	jp	c,.case1	; Small loop?	

.large:	ld	a,(file_len+0)
	cp	l
	jp	nz,.case2	; Generic loop?
	ld	a,(file_len+1)
	cp	h
	jp	nz,.case2	; Generic loop?
	
	ld	l,(iy+AUDX_lcl+0)
	ld	h,(iy+AUDX_lcl+1)
	ld	a,(iy+AUDX_lch+0)
	add	hl,de		; Add loop pos (21-bit)
	adc	a,0
	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),a
	ld	(iy+AUDX_lop+0),c ; Set sample loop len
	ld	(iy+AUDX_lop+1),b

	jp	.case3		; Always plays to end

;	------------
;	------------
;	------------

.align_256:	ld	hl,(sram_ptr+0)	; BC = over-run length
	ld	a, (sram_ptr+2)
	add	hl,bc		; 21-bit (2MB)
	adc	a,0

	ld	bc,255		; 256 BYTE align PTR
	add	hl,bc		; 21-bit (2MB)
	adc	a,0
	ld	l,0		; AND A:HL,-256
	ld	(sram_ptr+0),hl
	ld	(sram_ptr+2),a

;	------------

	ld	bc,(sample_len) ; Advance MOD sample ptr

	ld	hl,(sample_pos+0)
	ld	a, (sample_pos+2)
	add	hl,bc		; 21-bit (2MB)
	adc	a,0
	ld	(sample_pos+0),hl
	ld	(sample_pos+2),a

	pop	iy
	pop	ix
	pop	af

	ld	bc,SAMPLE_listlen	; Next sample
	add	ix,bc
	ld	c,AUDX_listlen
	add	iy,bc
	dec	a
	jp	nz,.sample

	ret


; --------------------------------------------------------------------------


; No loop, silence added at end of existing sample.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; > BC = Repeat length


.case0:	ld	(iy+AUDX_lop+0),10 ; 10 sample loop len
	ld	(iy+AUDX_lop+1),0

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),d

	call	mod_mmu_sram

	ld	bc,$1480	; B = 20 / C = 128

.twenty:	ld	(hl),c		; 20 samples of silence
	inc	hl		; to handle loop overflow
	djnz	.twenty

	ld	bc,20
	jr	.align_256


; --------------------------------------------------------------------------


; Small loop expanded six times, repeated at end of existing sample.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; > BC = Repeat length


.case1:	push	bc

	ld	a,c
	call	mod_cache_samples

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),d

	call	mod_mmu_sram

	pop	bc		; C = repeat length

	ex	de,hl		; Swap for LDIR
	ld	a,6

.six:	ld	hl,file_buf	; Duplicate six times
	push	bc		; to make sure length
	ldir			; is always >= 20
	pop	bc		; 4 = 24
	dec	a		; 6 = 36
	jr	nz,.six		; 8 = 48

	ld	a,c		; B = 0
	add	a,a
	add	a,c
	add	a,a
	ld	c,a		; C = length * 6

	ld	(iy+AUDX_lop+0),c ; Set sample loop len
	ld	(iy+AUDX_lop+1),b
	jp	.align_256


; --------------------------------------------------------------------------


; Large loop, appended with overflow to end of existing sample.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; > BC = Repeat length


.case2:	ld	hl,(sram_ptr+0)	; SRAM_PTR (end of sample)
	ld	de,(sram_ptr+1)

	ld	(iy+AUDX_lpl+0),l ; Set sample loop ptr
	ld	(iy+AUDX_lpl+1),h
	ld	(iy+AUDX_lph+0),d
	ld	(iy+AUDX_lop+0),c ; Set sample loop len
	ld	(iy+AUDX_lop+1),b

	ld	(file_len),bc	; Loop length
	call	mod_read_samples; Loop copy


; --------------------------------------------------------------------------


; Large loop, overflow appended to end of existing sample.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; > BC = Repeat length


.case3:	ld	a,10
	call	mod_cache_samples

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	call	mod_mmu_sram

	ld	de,file_buf
	ld	bc,$0A0A	; B = 10 / C = 10

.ten:	ld	a,(de)
	inc	e
	ld	(hl),a		; 10 samples from file_ptr
	inc	hl		; to handle loop overflow
	djnz	.ten

	jp	.align_256	; BC = 10


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Read samples from MOD in 256 byte chunks and change sign to Next format.

; Destination can be any location in SRAM (2MB) with a size limit of 64K.


; **READS FILE_LEN SAMPLES**

; **UPDATES 21-BIT SRAM_PTR**


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure

; < IX = As entry
; < IY = As entry


mod_read_samples:	push	ix
	push	iy

	ld	ix,0		; Seek mode (start)
	ld	de,(file_ptr+0)	; Seek size BC:DE
	ld	a, (file_ptr+2)
	ld	c,a
	ld	b,0
	ld	a,(file_handle)
	rst	08h
	db	f_seek		; Seek
	jp	c,mod_file_err

;	------------

	ld	a,(file_len+1)	; MSB of sample length
	and	a
	jr	z,.low

.high:	push	af

	ld	bc,256
	call	.read_chunk	; Read 256 samples

	pop	af
	dec	a
	jr	nz,.high

;	------------

.low:	ld	a,(file_len+0)	; LSB of sample length
	and	a
	jr	z,.zero
	ld	c,a
	ld	b,0
	call	.read_chunk	; Read 1..255 samples

.zero:	pop	iy
	pop	ix
	ret

;	------------
;	------------
;	------------

.read_chunk:	ld	ix,file_buf
	ld	a,(file_handle)
	rst	08h
	db	f_read		; Read N samples
	jp	c,mod_file_err

	push	bc

;	<------><--H---><--L--->
;	<--D---><--E---><------>
;	000mmmmmmmmooooooooooooo; MMU : OFFSET (21-bit)

	ld	hl,(sram_ptr+0)
	ld	de,(sram_ptr+1)

	call	mod_mmu_sram

	ld	de,file_buf	; 256 BYTE aligned
	ld	b,c
	ld	c,128

.sign:	ld	a,(de)		; Copy samples to SRAM
	add	a,c		; Amiga SIGNED to UNSIGNED
	ld	(hl),a
	inc	e
	inc	hl
	djnz	.sign

	pop	bc		; Samples read

	ld	hl,(sram_ptr+0)
	ld	a, (sram_ptr+2)
	add	hl,bc		; 21-bit (2MB)
	adc	a,0
	ld	(sram_ptr+0),hl
	ld	(sram_ptr+2),a
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Cache small buffer of samples from MOD and change sign to Next format.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; >  A = Samples to read

; < IX = As entry
; < IY = As entry


mod_cache_samples:	push	ix
	push	iy

	ld	(.length+1),a	; LD BC,0

	ld	ix,0		; Seek mode (start)
	ld	de,(file_ptr+0)	; Seek size BC:DE
	ld	a, (file_ptr+2)
	ld	c,a
	ld	b,0
	ld	a,(file_handle)
	rst	08h
	db	f_seek		; Seek
	jp	c,mod_file_err

;	------------

	ld	ix,file_buf
.length:	ld	bc,0
	ld	a,(file_handle)
	rst	08h
	db	f_read		; Read N samples
	jp	c,mod_file_err	; BC = bytes read

;	------------

	ld	de,file_buf
	ld	b,c
	ld	c,128

.sign:	ld	a,(de)
	add	a,c
	ld	(de),a
	inc	e
	djnz	.sign

	pop	iy
	pop	ix
	ret


; --------------------------------------------------------------------------


; Set 21-bit MMU and return 16K offset in HL.


; > IX = Pointer to sample structure
; > IY = Pointer to instrument structure
; > HL = SRAM LSW
; > DE = SRAM MSW

; < IX = As entry
; < IY = As entry
; < HL = Pointer to MM2/MM3


mod_mmu_sram:	ld	b,5
	bsrl	de,b		; 21-bit address to bank8k
	ld	a,e
	nextreg	MM2,a		; Use address 16384..24575
	inc	a
	nextreg	MM3,a		; Handle bank8k overflow

	ld	a,h
	and	00011111b	; Bank8k offset (0..8191)
	add	a,64		; MM2 (16384) ($4000)
	ld	h,a	
	ret


; --------------------------------------------------------------------------


; Data and variables for loader.


loader_sp	dw	0	; SP to reset stack on error

sample_pos	ds	3	; Sample start seek offset in MOD
sample_len	dw	0	; Sample length in MOD

file_ptr	ds	3	; 21-bit file pointer
file_handle	db	0	; MOD file handle
file_len	dw	0	; Used by mod_read_samples

sram_ptr	ds	3	; 21-bit SRAM pointer
sram_init	dd	BANK8K_SAMPLES*8192

mk_txt	db	"M.K."	; 31 sample signature


; --------------------------------------------------------------------------

