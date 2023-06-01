
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        MAIN.ASM                                            *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: Main file.                                          *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; NXMOD Memory Map.


;       0 - MM0   X - Paula CTC1 MMU **LOCKED**
;    8192 - MM1   X - Paula CTC1 MMU **LOCKED**
;   16384 - MM2  10 - ULA
;   24576 - MM3  11 - ULA
;   32768 - MM4   X - Protracker/Paula CTC1/CTC2 MMU **LOCKED**
;   40960 - MM5   5 - N/A
;   49152 - MM6   0 - Protracker CTC init/loader/test app
;   57344 - MM7   1 - Protracker/Paula/interrupts/stack **LOCKED**


; --------------------------------------------------------------------------


; Bank8k allocation.


; 000 Protracker CTC init/loader/test app (?)
; 001 Protracker player/paula/interrupts/stack/nx232 (8K)
; 002 Volume table (16K)
; 003 Volume table
; 004 N/A
; 005 N/A
; 006 N/A
; 007 N/A
; 008 N/A
; 009 N/A
; 010 Default (ULA/TILEMAP)
; 011 Default (ULA/TILEMAP)
; 012 Note, fine tune and tables (4096+1536+512 BYTES)
; 013 N/A
; 014 Amiga NTSC period translation (8K)
; 015 SHADOW ULA
; 016 PATTERNS
; 017 PATTERNS
; 018 PATTERNS
; 019 PATTERNS
; 020 PATTERNS
; 021 PATTERNS
; 022 PATTERNS
; 023 PATTERNS
; 024 SAMPLES
; 025 SAMPLES
; 026 SAMPLES
; 027 SAMPLES
; 028 SAMPLES
; 029 SAMPLES
; 030 SAMPLES
; 031 SAMPLES
; 032 SAMPLES
; 033 SAMPLES
; 034 SAMPLES
; 035 SAMPLES
; 036 SAMPLES
; 037 SAMPLES
; 038 SAMPLES
; 039 SAMPLES
; 040 SAMPLES
; 041 SAMPLES
; 042 SAMPLES
; 043 SAMPLES
; 044 SAMPLES
; 045 SAMPLES
; 046 SAMPLES
; 047 SAMPLES
; 048 SAMPLES
; 049 SAMPLES
; 050 SAMPLES
; 051 SAMPLES
; 052 SAMPLES
; 053 SAMPLES
; 054 SAMPLES
; 055 SAMPLES
; 056 SAMPLES
; 057 SAMPLES
; 058 SAMPLES
; 059 SAMPLES
; 060 SAMPLES
; 061 SAMPLES
; 062 SAMPLES
; 063 SAMPLES
; 064 SAMPLES
; 065 SAMPLES
; 066 SAMPLES
; 067 SAMPLES
; 068 SAMPLES
; 069 SAMPLES
; 070 SAMPLES
; 071 SAMPLES
; 072 SAMPLES
; 073 SAMPLES
; 074 SAMPLES
; 075 SAMPLES
; 076 SAMPLES
; 077 SAMPLES
; 078 SAMPLES
; 079 SAMPLES
; 080 SAMPLES
; 081 SAMPLES
; 082 SAMPLES
; 083 SAMPLES
; 084 SAMPLES
; 085 SAMPLES
; 086 SAMPLES
; 087 SAMPLES
; 088 SAMPLES
; 089 SAMPLES
; 090 SAMPLES
; 091 SAMPLES
; 092 SAMPLES
; 093 SAMPLES
; 094 SAMPLES
; 095 SAMPLES


; --------------------------------------------------------------------------


	device zxspectrum48


; --------------------------------------------------------------------------


	include "INC/EQUATES.INC"	; Program equates
	include "INC/HARDWARE.INC"	; ZX Spectrum Next


; --------------------------------------------------------------------------


	org	32768			; MM4 bank8k


; --------------------------------------------------------------------------


	org	40960			; MM5 bank8k


; --------------------------------------------------------------------------


	include "INC/FINETUNE.INC"	; **RELOCATED**


; --------------------------------------------------------------------------


	org	49152			; MM6 bank8k


; --------------------------------------------------------------------------


	include "ASM/TEST.ASM"		; Player test


; --------------------------------------------------------------------------


	include "ASM/CTC.ASM"		; CTC init
	include "ASM/VOLUME.ASM"	; VOL generation
	include "ASM/LOADER.ASM"	; MOD loader


; --------------------------------------------------------------------------


	org	57344			; MM7 bank8k


; --------------------------------------------------------------------------


	include "ASM/PAULA.ASM"
	include "ASM/PLAYER.ASM"


; --------------------------------------------------------------------------


end_of_code		; Should be below 63744 (current 63407)


; --------------------------------------------------------------------------


; **TEMP PLACED HERE**


file_buf	equ	63488	; **256 BYTE ALIGNED**


; --------------------------------------------------------------------------



	include "INC/PLAYER.INC"	; **FIXED ORG**
	include "ASM/DAC.ASM"		; **FIXED ORG**


; --------------------------------------------------------------------------


	org	64512			; Vector table


; --------------------------------------------------------------------------


	org	65024


; --------------------------------------------------------------------------


	incbin	 "BIN/NX232.BIN"	; RS232 stub


; --------------------------------------------------------------------------


	savesna	"NXMOD.SNX",startup


; --------------------------------------------------------------------------

