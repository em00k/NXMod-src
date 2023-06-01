
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        DAC.ASM                                             *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: DAC code modules.                                   *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------

; Mono DAC ports.


DAC_A	equ	$3F	;  L (AUD0)
DAC_D	equ	$5F	;  R (AUD1)
DAC_C	equ	$4F	;  R (AUD2)
DAC_B	equ	$0F	;  L (AUD3)


; Stereo DAC ports.


DAC_AD	equ	$DF	; L+R (N/A)
DAC_BC	equ	$B3	; L+R (N/A)


; 0001 1111 0x1f DAC A
; 0011 1111 0x3f DAC A
; 0000 1111 0x0f DAC B
; 1101 1111 0xdf DAC A,D
; 1011 0011 0xb3 DAC B,C
; 0100 1111 0x4f DAC C
; 0101 1111 0x5f DAC D


; --------------------------------------------------------------------------


	org	PAGE_DACA*256


; --------------------------------------------------------------------------


; 31250Hz CTC0 DAC 'cache' write modules (10+10 samples for each channel).


	ex	af,af'		; Cache buffer A
paula_cache_a_0:	ld	a,128
paula_dac_a1:	out	(DAC_A),a	; L
paula_cache_a_1:	ld	a,128
paula_dac_a2:	out	(DAC_D),a	; R
paula_cache_a_2:	ld	a,128
paula_dac_a3:	out	(DAC_C),a	; R
paula_cache_a_3:	ld	a,128
paula_dac_a4:	out	(DAC_B),a	; L
	db	$FD,$2E,24
	ex	af,af'
	ei
	reti			; Each module is 24 BYTES

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,48
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,72
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,96
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,120
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,144
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,168
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,192
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,216
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	ld	iy,PAGE_DACB*256; Buffer swap to B
	ex	af,af'
	ei
	reti			; 241 BYTES


; --------------------------------------------------------------------------


	org	PAGE_DACB*256


; --------------------------------------------------------------------------B


	ex	af,af'		; Cache buffer B
paula_cache_b_0:	ld	a,128
paula_dac_b1:	out	(DAC_A),a	; L
paula_cache_b_1:	ld	a,128
paula_dac_b2:	out	(DAC_D),a	; R
paula_cache_b_2:	ld	a,128
paula_dac_b3:	out	(DAC_C),a	; R
paula_cache_b_3:	ld	a,128
paula_dac_b4:	out	(DAC_B),a	; L
	db	$FD,$2E,24
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,48
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,72
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,96
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,120
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,144
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,168
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,192
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	db	$FD,$2E,216
	ex	af,af'
	ei
	reti

	ex	af,af'
	ld	a,128
	out	(DAC_A),a
	ld	a,128
	out	(DAC_D),a
	ld	a,128
	out	(DAC_C),a
	ld	a,128
	out	(DAC_B),a
	ld	iy,PAGE_DACA*256; Buffer swap to A
	ex	af,af'
	ei
	reti			; 241 BYTES


; --------------------------------------------------------------------------

