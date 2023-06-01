
; --------------------------------------------------------------------------
;
;
;    ********************************************************************
;    *                                                                  *
;    * File:        HARDWARE.INC                                        *
;    * Format:      SjASMPlus Z80                                       *
;    * Tabs:        28,36,44,52,60,68,76,84                             *
;    *                                                                  *
;    * Project:     NXMOD                                               *
;    * Platform:    ZX Spectrum Next                                    *
;    * Programmer:  KevB aka 9bitcolor                                  *
;    *                                                                  *
;    * Modified:    25th September 2022                                 *
;    *                                                                  *
;    * Description: ZX Spectrum Next hardware.                          *
;    *                                                                  *
;    ********************************************************************
;
;
; --------------------------------------------------------------------------


; Hardware registers.


DMA	equ	006Bh	; Datagear DMA

LAYER2	equ	123Bh	; TBBlue layer 2 control

SELECT	equ	243Bh	; TBBlue register select
ACCESS	equ	253Bh	; TBBlue register access

COREVER	equ	01h	; Core major/minor versions
CORESUB	equ	0Eh	; Core sub-version
RESET	equ	02h	; Reset

MACHINE	equ	03h	; Machine type

CONFIG1	equ	05h	; Peripheral 1 setting
CONFIG2	equ	06h	; Peripheral 2 setting

TURBO	equ	07h	; Turbo control

CONFIG3	equ	08h	; Peripheral 3 setting
CONFIG4	equ	09h	; Peripheral 4 setting

TIMING	equ	11h	; Video timing mode (0..7)

LAYERB	equ	12h	; Layer 2 bank
LAYERBS	equ	13h	; Layer 2 bank (shadow)

TRANSP	equ	14h	; Global transparency

LAYERS	equ	15h	; Layer priority

RASMSB	equ	1Eh	; Current line drawn MSB
RASLSB	equ	1Fh	; Current line drawn LSB

INTMSB	equ	22h	; Line interrupt MSB / control
INTLSB	equ	23h	; Line interrupt LSB

ULAX	equ	26h	; ULA X offset (MSB)
ULAY	equ	27h	; ULA Y offset

DAC	equ	2Dh	; DAC A+D mirror (mono)

DACL	equ	2Ch	; DAC B mirror (left)
DACM	equ	2Dh	; DAC A+D mirror (mono)
DACR	equ	2Eh	; DAC C mirror (right)

FALLBACK	equ	4Ah	; Fallback colour
TRANSS	equ	4Bh	; Transparency index for Sprites

MM0	equ	50h	; Memory bank8k
MM1	equ	51h
MM2	equ	52h
MM3	equ	53h
MM4	equ	54h
MM5	equ	55h
MM6	equ	56h
MM7	equ	57h

INTCTL	equ	0C0h	; Interrupt control
NMILSB	equ	0C2h	; NMI Return Address LSB
NMIMSB	equ	0C3h	; NMI Return Address MSB
INTEN0	equ	0C4h	; INT EN 0
INTEN1	equ	0C5h	; INT EN 1
INTEN2	equ	0C6h	; INT EN 2
INTST0	equ	0C8h	; INT status 0
INTST1	equ	0C9h	; INT status 1
INTST2	equ	0CAh	; INT status 2
INTDM0	equ	0CCh	; INT DMA EN 0
INTDM1	equ	0CDh	; INT DMA EN 1
INTDM2	equ	0CEh	; INT DMA EN 2

CTC0	equ	183Bh	; CTC channel 0 port
CTC1	equ	193Bh	; CTC channel 1 port
CTC2	equ	1A3Bh	; CTC channel 2 port
CTC3	equ	1B3Bh	; CTC channel 3 port
CTC4	equ	1C3Bh	; CTC channel 4 port
CTC5	equ	1D3Bh	; CTC channel 5 port
CTC6	equ	1E3Bh	; CTC channel 6 port
CTC7	equ	1F3Bh	; CTC channel 7 port


; --------------------------------------------------------------------------

