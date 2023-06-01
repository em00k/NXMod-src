
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        TEST.ASM                                            *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Sound engine test.                                  *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Memory Map.


irq_vector	equ	65022	;     2 BYTES Interrupt vector
stack	equ	65021	;   252 BYTES System stack
vector_table	equ	64512	;   257 BYTES Interrupt vector table


; --------------------------------------------------------------------------


; NextZXOS API.


f_open	equ	9Ah	; Opens a file
f_close	equ	9Bh	; Closes a file
f_read	equ	9Dh	; Read bytes from file
f_seek	equ	9Fh	; Set file position


; --------------------------------------------------------------------------


; Entry point. Setup some Next registers and an IM2 vector.


; MM0 255 ROM 0
; MM1 255 ROM 8192
; MM2  10 ULA 16384
; MM3  11 ULA 24576
; MM4   4 RAM 32768
; MM5   5 RAM 40960
; MM6   0 RAM 49152
; MM7   1 RAM 57344


startup:	di			; Set stack and interrupts
	ld	sp,stack	; System STACK

	nextreg	TURBO,00000011b	; 28Mhz / 27Mhz

	ld	hl,vector_table	; 252 (FCh)
	ld	a,h
	ld	i,a
	im	2

	inc	a		; 253 (FDh)
	ld	b,l		; Build 257 BYTE INT table

.irq:	ld	(hl),a
	inc	hl
	djnz	.irq		; B = 0
	ld	(hl),a

	ld	a,0FBh		; EI
	ld	hl,04DEDh	; RETI
	ld	[irq_vector-1],a
	ld	[irq_vector],hl


	nextreg	INTMSB,00000100b; ULA off / LINE interrupt off
	nextreg	INTLSB,255	; IRQ on line 192 (not used)

	ld	a,128		; Can cause initial click
	out	(DAC_AD),a
	out	(DAC_BC),a

	xor	a

	ld	hl,16384	; Clear ULA screen
	ld	de,16384+1
	ld	bc,6144-1
	ld	(hl),a
	ldir

	ld	sp,22528+768	; Set ULA attributes
	ld	hl,0707h	; PAPER 0:INK 7
	ld	b,192
.attr:	push	hl		; 4 BYTES
	push	hl
	djnz	.attr

	ld	bc,LAYER2
	out	(c),a		; LAYER 2 control OFF
	out	(254),a		; BLACK

	ld	bc,SELECT	; Setup hardware registers

	nextreg	TRANSP,a	; LAYER 2 transparent colour

	ld	a,CONFIG3
	out	(c),a
	inc	b
	in	a,(c)
	set	6,a		; Contention OFF
	set	3,a		; DAC ON
	set	1,a		; Turbosound ON
	out	(c),a

	ld	bc,0xFFFD	; Turbosound PSG #1
	ld	a,11111111b
	out	(c),a

	ld	sp,stack	; System STACK
	ei


; --------------------------------------------------------------------------


; Move tables to upper bank8k (See BANK8K_FINETUNE)


	nextreg	MM4,BANK8K_FINETUNE
	nextreg	MM5,5		; See MAIN.ASM (FINETUNE.INC)
	ld	hl,40960
	ld	de,32768	; MMU scratch
	ld	bc,4096+1536+512
	ldir			; Copy to bank8k


; --------------------------------------------------------------------------


; Init the sound engine, setup the variables and the timers.


; --------------------------------------------------------------------------


	call	create_volume_tables

	ld	de,-1		; LINE (-1 = use Paula)
	ld	bc,192		; Vsync line
	call	ctc_init	; CTC set to dummy EI:RETI

	ld	ix,ntsc_filename; Load NTSC period tab
	add	a,"0"		; Patch video timing file
	ld	(ix+11),a

	ld	a,BANK8K_PERIOD
	call	load_period_tab


; --------------------------------------------------------------------------


; Amiga to period string example.


;;;	ld	hl,214		; This will return "C-3"
;;;	call	period_to_string


; --------------------------------------------------------------------------


; Load MOD.


restart:	ld	ix,mod_filename
	call	load_test_mod


; --------------------------------------------------------------------------


; Examples to set the channel waveform and glissando modes.


;	ld	a,WAVEFORM_SINE	; Already set in mod_init
;	ld	(mod_audchan1temp+n_vibratocontrol),a
;	ld	(mod_audchan2temp+n_vibratocontrol),a
;	ld	(mod_audchan3temp+n_vibratocontrol),a
;	ld	(mod_audchan4temp+n_vibratocontrol),a
;	ld	(mod_audchan1temp+n_tremolocontrol),a
;	ld	(mod_audchan2temp+n_tremolocontrol),a
;	ld	(mod_audchan3temp+n_tremolocontrol),a
;	ld	(mod_audchan4temp+n_tremolocontrol),a

;	ld	a,GLISSANDO_OFF	; Already set in mod_init
;	ld	(mod_audchan1temp+n_glissfunk),a
;	ld	(mod_audchan2temp+n_glissfunk),a
;	ld	(mod_audchan3temp+n_glissfunk),a
;	ld	(mod_audchan4temp+n_glissfunk),a


; --------------------------------------------------------------------------


; Test loop.


; ENTER = Toggle PLAY ON/OFF

;     0 = Toggle CTC ON/OFF

;     1 = Toggle channel 0 ON/OFF
;     2 = Toggle channel 1 ON/OFF
;     3 = Toggle channel 2 ON/OFF
;     4 = Toggle channel 3 ON/OFF
;     5 = Set all channels ON

;     Q = Trigger sample 1
;     W = Trigger sample 2
;     E = Trigger sample 3

;     L = Load MOD

;     Z = Default PAN
;     X = DA<->AD PAN
;     C = BC<->CB PAN

;     R = Restart MOD


mainloop:	call	paula_vsync

	nextreg	FALLBACK,128

	if	0

	nextreg	FALLBACK,16

;;;	ld	bc,4000		;  6Mhz Z80N @ 50Hz
	ld	bc,3333		;  6Mhz Z80N @ 60Hz

.delay:	dec	bc		; 30Ts
	ld	a,c
	or	b
	jp	nz,.delay

	nextreg	FALLBACK,0

	endif

;	------------

	ld	hl,debounce_q
	ld	b,(hl)

	ld	a,251		; Q
	in	a,(254)
	and	1
	ld	(hl),a
	jr	nz,.no_q

	ld	a,b		; Trigger instrument #1 ?
	and	1
	jr	z,.no_q
	ld	hl,AUD0RES	; Paula register bank
	ld	de,214		; C-3 (NTSC)
	ld	a,1
	call	mod_trigger_sample
	ld	(AUD0VOL),a
.no_q:
;	------------

	ld	hl,debounce_w
	ld	b,(hl)

	ld	a,251		; W
	in	a,(254)
	and	2
	ld	(hl),a
	jr	nz,.no_w

	ld	a,b		; Trigger instrument #2 ?
	and	2
	jr	z,.no_w
	ld	hl,AUD0RES	; Paula register bank
	ld	de,214		; C-3 (NTSC)
	ld	a,2
	call	mod_trigger_sample
	ld	(AUD0VOL),a
.no_w:
;	------------

	ld	hl,debounce_e
	ld	b,(hl)

	ld	a,251		; E
	in	a,(254)
	and	4
	ld	(hl),a
	jr	nz,.no_e

	ld	a,b		; Trigger instrument #3 ?
	and	4
	jr	z,.no_e
	ld	hl,AUD0RES	; Paula register bank
	ld	de,214		; C-3 (NTSC)
	ld	a,3
	call	mod_trigger_sample
	ld	(AUD0VOL),a
.no_e:
;	------------

	ld	a,(DMACON)	; Channel DMA toggle ON/OFF
	ld	d,a

	ld	hl,debounce_1
	ld	b,(hl)
	ld	a,247		; 1
	in	a,(254)
	and	1
	ld	(hl),a
	jr	nz,.no_1
	ld	a,b
	and	1
	jr	z,.no_1
	ld	a,d
	xor	AUD0EN
	ld	d,a
.no_1:
	ld	hl,debounce_2
	ld	b,(hl)
	ld	a,247		; 2
	in	a,(254)
	and	2
	ld	(hl),a
	jr	nz,.no_2
	ld	a,b
	and	2
	jr	z,.no_2
	ld	a,d
	xor	AUD1EN
	ld	d,a
.no_2:
	ld	hl,debounce_3
	ld	b,(hl)
	ld	a,247		; 3
	in	a,(254)
	and	4
	ld	(hl),a
	jr	nz,.no_3
	ld	a,b
	and	4
	jr	z,.no_3
	ld	a,d
	xor	AUD2EN
	ld	d,a
.no_3:
	ld	hl,debounce_4
	ld	b,(hl)
	ld	a,247		; 4
	in	a,(254)
	and	8
	ld	(hl),a
	jr	nz,.no_4
	ld	a,b
	and	8
	jr	z,.no_4
	ld	a,d
	xor	AUD3EN
	ld	d,a
.no_4:
	ld	a,247		; 5
	in	a,(254)
	and	16
	jr	nz,.no_5
	ld	d,AUD0EN+AUD1EN+AUD2EN+AUD3EN
.no_5:
	ld	a,d
	ld	(DMACON),a

;	------------

	ld	hl,debounce_0	; CTC toggle ON/OFF
	ld	b,(hl)
	ld	a,239		; 0
	in	a,(254)
	and	1
	ld	(hl),a
	jr	nz,.no_0
	ld	a,b
	and	1
	jr	z,.no_0
	ld	a,(DMACON+1)
	xor	DMAEN
	call	paula_enable
.no_0:
;	------------

	ld	hl,debounce_enter ; PLAY toggle ON/OFF
	ld	b,(hl)
	ld	a,191		; 0
	in	a,(254)
	and	1
	ld	(hl),a
	jr	nz,.no_enter
	ld	a,b
	and	1
	jr	z,.no_enter
	ld	a,(mod_enable)
	xor	1
	ld	(mod_enable),a
	jr	nz,.no_enter
	ld	(AUD0VOL),a	; Set volume to zero
	ld	(AUD1VOL),a	; if stopped
	ld	(AUD2VOL),a
	ld	(AUD3VOL),a
.no_enter:
;	------------

	ld	hl,debounce_r	; Restart MOD
	ld	b,(hl)
	ld	a,251		; R
	in	a,(254)
	and	8
	ld	(hl),a
	jr	nz,.no_r
	ld	a,b
	and	8
	jr	z,.no_r

	xor	a
	ld	(mod_enable),a	; **STOP PLAYBACK**
	ld	(AUD0VOL),a	; Set volume to zero
	ld	(AUD1VOL),a
	ld	(AUD2VOL),a
	ld	(AUD3VOL),a
	call	mod_init
	ld	a,1
	ld	(mod_enable),a
.no_r:
;	------------
	
	ld	a,254		; Z (normal off)
	in	a,(254)
	and	2
	call	z,set_stereo_off

	ld	a,254		; X (DA <-> AD)
	in	a,(254)
	and	4
	call	z,set_stereo_daad

	ld	a,254		; C (BC <-> CB)
	in	a,(254)
	and	8
	call	z,set_stereo_bccb

;	------------

	ld	a,191		; L ?
	in	a,(254)
	and	2
	jp	z,restart

;	------------

	nextreg	FALLBACK,0

	ld	a,127		; SPACE ?
	in	a,(254)
	and	1
	jp	nz,mainloop

	jp	mainloop


; --------------------------------------------------------------------------


	if	0

; Tidy up and exit.


quit:	di

	nextreg	MM0,255
	nextreg	MM1,255
	nextreg	MM2,10
	nextreg	MM3,11
	nextreg	MM4,4
	nextreg	MM5,5
	nextreg	MM6,0

	ld	a,128
	out	(DAC_AD),a
	out	(DAC_BC),a

	nextreg	FALLBACK,0	; BLACK
	jp	nx232

	endif


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; **WIP EXAMPLE**


; Shutdown engine, clean up, load MOD, start playback.


; > IX = Filename


load_test_mod:	xor	a		; STOP mode (zero)
	ld	(mod_enable),a

	ld	(AUD0VOL),a	; Set volume to zero
	ld	(AUD1VOL),a
	ld	(AUD2VOL),a
	ld	(AUD3VOL),a

	call	paula_enable	; Set CTC to dummy EI:RETI

	ld	a,128		; Reset DACS (optional)
	out	(DAC_AD),a
	out	(DAC_BC),a

	call	paula_flush_dacs

;	------------

	call	mod_load
	cp	1		; A = load status
	jp	nz,file_err

	call	mod_init

	ld	hl,4095
	ld	(AUD0PER),hl	; Idle at low period
	ld	(AUD1PER),hl	; as code path fetches
	ld	(AUD2PER),hl	; less samples to create
	ld	(AUD3PER),hl	; the output buffer

	ld	a,64
	ld	(AUD0VOL),a	; Set volume to max to
	ld	(AUD1VOL),a	; avoid volume scaler
	ld	(AUD2VOL),a
	ld	(AUD3VOL),a
	
	ld	hl,AUD0PER	; Loop sample 0 to init
	xor	a		; the sound engine
	call	mod_trigger_period	; AUD0 L

	ld	hl,AUD1PER
	xor	a
	call	mod_trigger_period	; AUD1 R

	ld	hl,AUD2PER
	xor	a
	call	mod_trigger_period	; AUD2 R

	ld	hl,AUD3PER
	xor	a
	call	mod_trigger_period	; AUD3 L

;	------------

	ld	a,AUD0EN+AUD1EN+AUD2EN+AUD3EN
	ld	(DMACON),a	; Enable all channels

	ld	a,1		; PLAY mode (any non-zero)
	ld	(mod_enable),a

	ld	a,DMAEN
	jp	paula_enable	; Set CTC to Paula vectors


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Modifiy DAC write code to create fake stereo panning.


set_stereo_off:	ld	a,DAC_A
	ld	b,DAC_B
	ld	c,DAC_C
	ld	d,DAC_D

	ld	hl,paula_dac_a1+1
	call	.a
	ld	hl,paula_dac_b1+1
.a:	ld	e,5

.b:	ld	(hl),a
	add	hl,4
	ld	(hl),d
	add	hl,4
	ld	(hl),c
	add	hl,4
	ld	(hl),b
	add	hl,12

	ld	(hl),a
	add	hl,4
	ld	(hl),d
	add	hl,4
	ld	(hl),c
	add	hl,4
	ld	(hl),b
	add	hl,12
	dec	e
	jr	nz,.b
	ret

;	------------

set_stereo_daad:	ld	a,DAC_A
	ld	b,DAC_B
	ld	c,DAC_C
	ld	d,DAC_D

	ld	hl,paula_dac_a1+1
	call	.a
	ld	hl,paula_dac_b1+1
.a:	ld	e,5

.b:	ld	(hl),d
	add	hl,4
	ld	(hl),a
	add	hl,4
	ld	(hl),c
	add	hl,4
	ld	(hl),b
	add	hl,12

	ld	(hl),a
	add	hl,4
	ld	(hl),d
	add	hl,4
	ld	(hl),c
	add	hl,4
	ld	(hl),b
	add	hl,12
	dec	e
	jr	nz,.b
	ret

;	------------

set_stereo_bccb:	ld	a,DAC_A
	ld	b,DAC_B
	ld	c,DAC_C
	ld	d,DAC_D

	ld	hl,paula_dac_a1+1
	call	.a
	ld	hl,paula_dac_b1+1
.a:	ld	e,5

.b:	ld	(hl),a
	add	hl,4
	ld	(hl),d
	add	hl,4
	ld	(hl),b
	add	hl,4
	ld	(hl),c
	add	hl,12

	ld	(hl),a
	add	hl,4
	ld	(hl),d
	add	hl,4
	ld	(hl),c
	add	hl,4
	ld	(hl),b
	add	hl,12
	dec	e
	jr	nz,.b
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


file_err:	inc	a		; File error handler
	out	(254),a
	jp	file_err


; --------------------------------------------------------------------------


; Test filename.


mod_filename	db	"JAGTITLE.MOD",0

;mod_filename	db	"SKANK.MOD",0

;mod_filename	db	"ELYSIUM.MOD",0

;mod_filename	db	"CHIPLOOP.MOD",0

;mod_filename	db	"FINETUNE.MOD",0

;mod_filename	db	"LOOPS.MOD",0
;mod_filename	db	"TEST.MOD",0
;mod_filename	db	"JARRE.MOD",0
;mod_filename	db	"FEEL.MOD",0
;mod_filename	db	"15.MOD",0
;mod_filename	db	"31.MOD",0
;mod_filename	db	"AXELF.MOD",0
;mod_filename	db	"ACID.MOD",0

;mod_filename	db	"FIREFOX/all_those_years.MOD",0
;mod_filename	db	"FIREFOX/all_those_years_demo.MOD",0
;mod_filename	db	"FIREFOX/always_on_my_mind.MOD",0
;mod_filename	db	"FIREFOX/apocalypse_1.MOD",0
;mod_filename	db	"FIREFOX/a_final_hyperbase.MOD",0
;mod_filename	db	"FIREFOX/blaster.MOD",0
;mod_filename	db	"FIREFOX/Blues.MOD",0
;mod_filename	db	"FIREFOX/check_your_level_v5.MOD",0
;mod_filename	db	"FIREFOX/chinese_dream.MOD",0
;mod_filename	db	"FIREFOX/crack_force_5_ii.MOD",0
;mod_filename	db	"FIREFOX/Curse_of_Pacman.MOD",0
;mod_filename	db	"FIREFOX/demo_tune_i.MOD",0
;mod_filename	db	"FIREFOX/digital_chock_ii.MOD",0
;mod_filename	db	"FIREFOX/disaster_is_obvious.MOD",0
;mod_filename	db	"FIREFOX/exstasia.MOD",0
;mod_filename	db	"FIREFOX/F14_tomcat.MOD",0
;mod_filename	db	"FIREFOX/fftune1.MOD",0
;mod_filename	db	"FIREFOX/Firefoxspecialv2.MOD",0
;mod_filename	db	"FIREFOX/forgotten_minds.MOD",0
;mod_filename	db	"FIREFOX/foundation.MOD",0
;mod_filename	db	"FIREFOX/fructail_intro.MOD",0
;mod_filename	db	"FIREFOX/Full_Contact_menu.MOD",0
;mod_filename	db	"FIREFOX/galaxy.MOD",0
;mod_filename	db	"FIREFOX/galaxy_.MOD",0
;mod_filename	db	"FIREFOX/galaxy_ii.MOD",0
;mod_filename	db	"FIREFOX/generation_compoed.MOD",0
;mod_filename	db	"FIREFOX/get_with_it_mama.MOD",0
;mod_filename	db	"FIREFOX/ghostmusic.MOD",0
;mod_filename	db	"FIREFOX/heavy_n_funky.MOD",0
;mod_filename	db	"FIREFOX/hip_for_the_hop.MOD",0
;mod_filename	db	"FIREFOX/hip_for_the_hop_remix.MOD",0
;mod_filename	db	"FIREFOX/hiscore.MOD",0
;mod_filename	db	"FIREFOX/interspace_intro.MOD",0
;mod_filename	db	"FIREFOX/its_no_secret.MOD",0
;mod_filename	db	"FIREFOX/i_m_all_you_need.MOD",0
;mod_filename	db	"FIREFOX/i_was_lucky.MOD",0
;mod_filename	db	"FIREFOX/just_spank_it.MOD",0
;mod_filename	db	"FIREFOX/Just_Spank_it_.MOD",0
;mod_filename	db	"FIREFOX/load_tune_iii.MOD",0
;mod_filename	db	"FIREFOX/low_altitude.MOD",0
;mod_filename	db	"FIREFOX/macrocosm_sht.MOD",0
;mod_filename	db	"FIREFOX/macrocosm.MOD",0
;mod_filename	db	"FIREFOX/magic_fantasy.MOD",0
;mod_filename	db	"FIREFOX/mega_end.MOD",0
;mod_filename	db	"FIREFOX/Miami_Chase_ingame.MOD",0
;mod_filename	db	"FIREFOX/Miami_Chase_menu.MOD",0
;mod_filename	db	"FIREFOX/mon.MOD",0
;mod_filename	db	"FIREFOX/musicline2.MOD",0
;mod_filename	db	"FIREFOX/music_loader_ii.MOD",0
;mod_filename	db	"FIREFOX/musiklinjen.MOD",0
;mod_filename	db	"FIREFOX/nice_and_funky_ii.MOD",0
;mod_filename	db	"FIREFOX/night_flight.MOD",0
;mod_filename	db	"FIREFOX/on_the_rocks.MOD",0
;mod_filename	db	"FIREFOX/our_just_spank_it.MOD",0
;mod_filename	db	"FIREFOX/rasta_man_firefox.MOD",0
;mod_filename	db	"FIREFOX/slibbig_house.MOD",0
;mod_filename	db	"FIREFOX/static_byte_short.MOD",0
;mod_filename	db	"FIREFOX/static_byte.MOD",0
;mod_filename	db	"FIREFOX/strange_loader.MOD",0
;mod_filename	db	"FIREFOX/the_end.MOD",0
;mod_filename	db	"FIREFOX/the_seventh_sea.MOD",0
;mod_filename	db	"FIREFOX/the_way_i_feel_v2.MOD",0
;mod_filename	db	"FIREFOX/Utterly_Weird.MOD",0
;mod_filename	db	"FIREFOX/v42_intro_tune.MOD",0
;mod_filename	db	"FIREFOX/Vaxjo_by_Night.MOD",0
;mod_filename	db	"FIREFOX/vector.MOD",0
;mod_filename	db	"FIREFOX/vector_long.MOD",0
;mod_filename	db	"FIREFOX/vortex_42.MOD",0
;mod_filename	db	"FIREFOX/weird_technology.MOD",0
;mod_filename	db	"FIREFOX/yeaah_just_spank_it.MOD",0


; --------------------------------------------------------------------------


; Test variables.


debounce_enter	db	0

debounce_0	db	0
debounce_1	db	0
debounce_2	db	0
debounce_3	db	0
debounce_4	db	0

debounce_r	db	0

debounce_q	db	0
debounce_w	db	0
debounce_e	db	0


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Convert Amiga 12-bit period to 0 terminated string.


; > HL = Amiga period (0..4095)

; < HL = Pointer to note string


period_to_string	nextreg	MM2,BANK8K_FINETUNE ; $4000
		
	set	6,h		; Period + 16384 (MM2)
	ld	a,(hl)
	ld	hl,note_tab
	add	a,a		; Pre-multiplied by 2
	add	hl,a
	ret


; --------------------------------------------------------------------------
; --------------------------------------------------------------------------
; --------------------------------------------------------------------------


; Note strings using 4K lookup table (See period_to_note_tab)


;                C   C#  D   D#  E   F   F#  G   G#  A   A#  B
;     Octave 1: 856,808,762,720,678,640,604,570,538,508,480,453
;     Octave 2: 428,404,381,360,339,320,302,285,269,254,240,226
;     Octave 3: 214,202,190,180,170,160,151,143,135,127,120,113


;		NOTE     INDEX  AMIGA HZ
;		----------------------------
note_tab	db	"C-1",0  ; 00 - 04181.71 C-1
	db	"C#1",0  ; 02 - 04430.12 C#1
	db	"D-1",0  ; 04 - 04697.56 D-1
	db	"D#1",0  ; 06 - 04971.59 D#1
	db	"E-1",0  ; 08 - 05279.56 E-1
	db	"F-1",0  ; 10 - 05593.03 F-1
	db	"F#1",0  ; 12 - 05926.39 F#1
	db	"G-1",0  ; 14 - 06279.90 G-1
	db	"G#1",0  ; 16 - 06690.73 G#1
	db	"A-1",0  ; 18 - 07046.34 A-1
	db	"A#1",0  ; 20 - 07457.38 A#1
	db	"B-1",0  ; 22 - 07901.86 B-1
	db	"C-2",0  ; 24 - 08363.42 C-2
	db	"C#2",0  ; 26 - 08860.25 C#2
	db	"D-2",0  ; 28 - 09395.13 D-2
	db	"D#2",0  ; 30 - 09943.18 D#2
	db	"E-2",0  ; 32 - 10559.12 E-2
	db	"F-2",0  ; 34 - 11186.07 F-2
	db	"F#2",0  ; 36 - 11852.79 F#2
	db	"G-2",0  ; 38 - 12559.80 G-2
	db	"G#2",0  ; 40 - 13306.85 G#2
	db	"A-2",0  ; 42 - 14092.69 A-2
	db	"A#2",0  ; 44 - 14914.77 A#2
	db	"B-2",0  ; 46 - 15838.69 B-2
	db	"C-3",0  ; 48 - 16726.84 C-3
	db	"C#3",0  ; 50 - 17720.51 C#3
	db	"D-3",0  ; 52 - 18839.71 D-3
	db	"D#3",0  ; 54 - 19886.36 D#3
	db	"E-3",0  ; 56 - 21056.14 E-3
	db	"F-3",0  ; 58 - 22372.15 F-3
	db	"F#3",0  ; 60 - 23705.59 F#3
	db	"G-3",0  ; 62 - 25031.78 G-3
	db	"G#3",0  ; 64 - 26515.14 G#3
	db	"A-3",0  ; 66 - 28185.39 A-3
	db	"A#3",0  ; 68 - 29829.54 A#3
	db	"B-3",0  ; 70 - 31677.38 B-3
	db	"---",0  ; 72 - -----.-- ---


; --------------------------------------------------------------------------

