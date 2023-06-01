
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        PLAYER.INC                                          *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Player data/Paula registers.                        *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Bank8k allocation.


BANK8K_VOLUME	equ	2	;   16K
BANK8K_FINETUNE	equ	12	;    8K
BANK8K_PERIOD	equ	14	;    8K (see mod_trigger)
BANK8K_PATTERNS	equ	16	;   64K max (128-192K)
BANK8K_SAMPLES	equ	24	; 1600K max (192-1792K)


; --------------------------------------------------------------------------


; Audio DMA enable masks (See DMACON)


AUD3EN	equ	00001000b	; DAC D L
AUD2EN	equ	00000100b	; DAC C R
AUD1EN	equ	00000010b	; DAC B R
AUD0EN	equ	00000001b	; DAC A L

DMAEN	equ	00000010b	; DMA (CTC)


; --------------------------------------------------------------------------


; MOD data structure for M.K. (see mod_header)


MOD_header	equ	0	; 20 BYTES
MOD_samples	equ	20	; 930 BYTES
MOD_songlength	equ	950	; BYTE
MOD_127	equ	951	; BYTE
MOD_sequence	equ	952	; 128 BYTES
MOD_mk	equ	1080	; LONG
MOD_patterns	equ	1084	; 1024 BYTES * N
MOD_listlen	equ	1084


; MOD sample structure.


SAMPLE_name	equ	0	; 22 BYTES
SAMPLE_length	equ	22	; WORD
SAMPLE_finetune	equ	24	; BYTE
SAMPLE_volume	equ	25	; BYTE
SAMPLE_repeatpos	equ	26	; WORD
SAMPLE_repeatlen	equ	28	; WORD
SAMPLE_listlen	equ	30

SAMPLES	equ	31	; M.K.


; ZX Spectrun Next sample structure.


AUDX_tun	equ	0	; BYTE **DONT CHANGE ORDER**
AUDX_vol	equ	1	; BYTE
AUDX_lpl	equ	2	; WORD
AUDX_lph	equ	4	; BYTE
AUDX_lop	equ	5	; WORD
AUDX_lcl	equ	7	; WORD
AUDX_lch	equ	9	; BYTE
AUDX_len	equ	10	; WORD
AUDX_listlen	equ	12


; --------------------------------------------------------------------------


; Channel structure (see mod_audchan1temp) **64 BYTES PER CHANNEL**


; **MODIFIED TO INCLUDE PAULA HARDWARE REGISTERS**

; **EDIT MOD_CLEAR IF ORDER CHANGE**


n_note	equ	0	; WORD (must be first!)
n_cmd	equ	2	; WORD (must be second!)
n_cmdlo	equ	3	; BYTE (offset in n_cmd)

n_AUDXPER	equ	4	; WORD Amiga period 0..4095 (12-bit)
n_AUDXRES	equ	6	; WORD Next period reset (16-bit)
n_AUDXCNT	equ	8	; WORD Next period count (16-bit)
n_AUDXLPL	equ	10	; WORD Loop location 21-bit (2MB)
n_AUDXLPH	equ	12	; BYTE
n_AUDXLOP	equ	13	; WORD Loop length in samples 16-bit
n_AUDXLCL	equ	15	; WORD Location in SRAM 21-bit (2MB)
n_AUDXLCH	equ	17	; BYTE
n_AUDXLEN	equ	18	; WORD Length in samples 16-bit
n_AUDXVOL	equ	20	; BYTE Volume 0..64

n_21	equ	21	; BYTE **RESERVED**
n_22	equ	22	; BYTE **RESERVED**
n_23	equ	23	; BYTE **RESERVED**

n_peroffset	equ	24	; WORD
n_period	equ	26	; WORD AUDxPER

n_wantedperiod	equ	28	; WORD
n_finetune	equ	30	; BYTE
n_volume	equ	31	; BYTE AUDxVOL
n_toneportdirec	equ	32	; BYTE
n_toneportspeed	equ	33	; BYTE
n_vibratocmd	equ	34	; BYTE
n_vibratopos	equ	35	; BYTE
n_tremolocmd	equ	36	; BYTE
n_tremolopos	equ	37	; BYTE
n_vibratocontrol	equ	38	; BYTE Moved from n_wavecontrol
n_tremolocontrol	equ	39	; BYTE Moved from n_wavecontrol
n_sampleoffset	equ	40	; BYTE
n_pattpos	equ	41	; BYTE
n_loopcount	equ	42	; BYTE
n_glissfunk	equ	43	; BYTE Changed to be 0/1 (OFF/ON)

n_loopstart	equ	44	; 3 BYTES AUXxLPL/AUXxLPH (21-bit)
n_replen	equ	47	; WORD    AUXxLOP
n_start	equ	49	; 3 BYTES AUXxLCL/AUXxLCH (21-bit)
n_length	equ	52	; WORD    AUDxLEN

n_54	equ	54	; BYTE **RESERVED**
n_55	equ	55	; BYTE **RESERVED**
n_56	equ	56	; BYTE **RESERVED**

n_dmabit	equ	57	; BYTE DMACON

n_retrigger	equ	58	; BYTE Index for n_loopstart
n_offset	equ	59	; BYTE Index for n_start

n_paula_per	equ	60	; BYTE Index for channel AUDxPER
n_paula_lpl	equ	61	; BYTE Index for channel AUDxLPL
n_paula_lcl	equ	62	; BYTE Index for channel AUDxLCL
n_paula_vol	equ	63	; BYTE Index for channel AUDxVOL


; --------------------------------------------------------------------------


; Vibrato and tremolo control.


WAVEFORM_SINE	equ	0
WAVEFORM_RAMP	equ	1
WAVEFORM_SQUARE	equ	2
WAVEFORM_RANDOM	equ	3	; **NOT SUPPORTED**

WAVEFORM_RESET	equ	4


; --------------------------------------------------------------------------


; Glissando control.


GLISSANDO_OFF	equ	0
GLISSANDO_ON	equ	1


; --------------------------------------------------------------------------


; Page aligned code and data.


PAGE_PAULA	equ	$F9	; 63744
PAGE_DACA	equ	$FA	; 64000
PAGE_DACB	equ	$FB	; 64256


; --------------------------------------------------------------------------


	org	PAGE_PAULA*256


; --------------------------------------------------------------------------


; Channel structures (shadows) (see n_note) (64 BYTES) + emulated registers.

; Includes Paula sound chip registers using 'official' naming convention.

; Also includes extended registers for ZX Spectrum Next.

; Register order matches mod_instrument structure for mem copy sample trigger.


; **PAGE ALIGNED**

; **DO NOT CHANGE ORDER**


mod_audchan1temp	ds	4	; See n_note
AUD0PER	dw	0	; Amiga period 0..4095 (12-bit)
AUD0RES	dw	0	; Next period reset (16-bit)
AUD0CNT	dw	0	; Next period count (16-bit)
AUD0LPL	dw	0	; Loop location 21-bit (2MB)
AUD0LPH	db	0
AUD0LOP	dw	0	; Loop length in samples 16-bit
AUD0LCL	dw	0	; Location in SRAM 21-bit (2MB)
AUD0LCH	db	0
AUD0LEN	dw	0	; Length in samples 16-bit
AUD0VOL	db	0	; Volume 0..64
	ds	36
	db	AUD0EN
	db	n_loopstart+(64*0) ;
	db	n_start+1+(64*0)   ;
	db	n_AUDXPER+(64*0)   ; Quick LSB indexes for
	db	n_AUDXLPL+(64*0)   ; for IX channel struct
	db	n_AUDXLCL+(64*0)   ;
	db	n_AUDXVOL+(64*0)   ;

mod_audchan2temp	ds	4
AUD1PER	dw	0	
AUD1RES	dw	0
AUD1CNT	dw	0
AUD1LPL	dw	0
AUD1LPH	db	0
AUD1LOP	dw	0
AUD1LCL	dw	0
AUD1LCH	db	0
AUD1LEN	dw	0
AUD1VOL	db	0
	ds	36
	db	AUD1EN
	db	n_loopstart+(64*1)
	db	n_start+1+(64*1)
	db	n_AUDXPER+(64*1)
	db	n_AUDXLPL+(64*1)
	db	n_AUDXLCL+(64*1)
	db	n_AUDXVOL+(64*1)

mod_audchan3temp	ds	4
AUD2PER	dw	0
AUD2RES	dw	0
AUD2CNT	dw	0
AUD2LPL	dw	0
AUD2LPH	db	0
AUD2LOP	dw	0
AUD2LCL	dw	0
AUD2LCH	db	0
AUD2LEN	dw	0
AUD2VOL	db	0
	ds	36
	db	AUD2EN
	db	n_loopstart+(64*2)
	db	n_start+1+(64*2)
	db	n_AUDXPER+(64*2)
	db	n_AUDXLPL+(64*2)
	db	n_AUDXLCL+(64*2)
	db	n_AUDXVOL+(64*2)

mod_audchan4temp	ds	4
AUD3PER	dw	0
AUD3RES	dw	0
AUD3CNT	dw	0
AUD3LPL	dw	0
AUD3LPH	db	0
AUD3LOP	dw	0
AUD3LCL	dw	0
AUD3LCH	db	0
AUD3LEN	dw	0
AUD3VOL	db	0
	ds	36
	db	AUD3EN
	db	n_loopstart+(64*3)
	db	n_start+1+(64*3)
	db	n_AUDXPER+(64*3)
	db	n_AUDXLPL+(64*3)
	db	n_AUDXLCL+(64*3)
	db	n_AUDXVOL+(64*3)


; --------------------------------------------------------------------------

