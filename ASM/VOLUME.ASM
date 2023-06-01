
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        VOLUME.ASM                                          *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Paula volume table generation.                      *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; **ONLY NEED TO DO THIS AT STARTUP**


create_volume_tables:	ld	a,BANK8K_VOLUME; Volume tab (64*256 BYTES)
	nextreg	MM0,a
	inc	a
	nextreg	MM1,a

	exx
	ld	hl,volume_64_table
	exx

	ld	hl,0		; Build table 0..63
	ld	a,64

.vol:	ex	af,af'
	exx
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	hl
	push	bc
	exx
	pop	bc
	call	create_volume_tab
	
	ex	af,af'
	dec	a
	jr	nz,.vol
	ret


; --------------------------------------------------------------------------


; Create unsigned 8-bit volume scale table using 8.8 fixed point.


; **SOFT CLIP WHEN BOOSTING VOLUME**


;	ld	bc,512		; 512 = 200%
;	ld	bc,384		; 384 = 150%
;	ld	bc,256		; 256 = 100%
;	ld	bc,192		; 192 =  75%
;	ld	bc,128		; 128 =  50%
;	ld	bc,64		;  64 =  25%
;	ld	bc,0		;   0 =   0%


; > HL = Pointer to 256 BYTE aligned table
; > BC = 8.8 fixed point scale (See examples above)

; < HL = +256
; < BC = As entry


create_volume_tab:	push	hl
	ld	de,128*256	; 0db (128)
	ld	l,d		; Middle of table

.neg:	ld	(hl),d		; Store scaled 8-bit PCM

	ex	de,hl		; Decrease 128 towards 0
	xor	a
	sbc	hl,bc
	ex	de,hl

	jr	nc,.no_0
	ld	de,256*0	; Clamp at 0
.no_0:
	dec	l		; Work backwards
	jp	p,.neg

;	------------

	ld	de,128*256	; 0db (128)
	ld	l,d		; Middle of table

.pos:	ld	(hl),d		; Store scaled 8-bit PCM

	ex	de,hl		; Increase 128 towards 255
	add	hl,bc
	ex	de,hl

	jr	nc,.no_255
	ld	de,256*255	; Clamp at 255
.no_255:
	inc	l		; Work forwards
	jp	nz,.pos

	pop	hl
	inc	h		; +256
	ret


; --------------------------------------------------------------------------


; Linear volume 0..63 (0 to 0.984375%), volume scale is bypassed for 64 (100%)


volume_64_table	dw	000,004,008,012,016,020,024,028
	dw	032,036,040,044,048,052,056,060
	dw	064,068,072,076,080,084,088,092
	dw	096,100,104,108,112,116,120,124
	dw	128,132,136,140,144,148,152,156
	dw	160,164,168,172,176,180,184,188
	dw	192,196,200,204,208,212,216,220
	dw	224,228,232,236,240,244,248,252


; --------------------------------------------------------------------------

