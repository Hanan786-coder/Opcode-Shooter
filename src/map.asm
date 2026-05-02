; FILE: map.asm
.MODEL SMALL

EXTRN GameRunning : BYTE
EXTRN VideoSeg    : WORD

; Exporting these so main.asm can find them
PUBLIC InitMap
PUBLIC DrawMap
PUBLIC SelectMap
PUBLIC MapData
PUBLIC MAP_COLS
PUBLIC MAP_ROWS
PUBLIC TILE_W
PUBLIC TILE_H
PUBLIC MAPINDEX
PUBLIC SKYCOLOR
PUBLIC GROUNDCOLOR

.DATA

MAP_COLS EQU 20
MAP_ROWS EQU 12
TILE_W   EQU 16
TILE_H   EQU 16

; Global variables main.asm is looking for
SKYCOLOR    DB 01h      
GROUNDCOLOR DB 02h      
MAPINDEX    DB 1        

; Map Sky Color Palette
COLOR_SKY1   EQU 01h      
COLOR_SKY2   EQU 08h      
COLOR_SKY3   EQU 01h      

MapData LABEL BYTE
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,1,1,1,0,0,0,0,0,0,0,0,1,1,1,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

Map2Data LABEL BYTE
    ; Symmetric three-tier layout + solid floor (mirrored around center)
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 1
    DB 0,0,0,1,1,1,0,0,1,1,1,1,0,0,1,1,1,0,0,0  ; row 2 - top islands
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 3
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 4
    DB 1,1,1,1,1,1,1,0,0,0,0,0,0,1,1,1,1,1,1,1  ; row 5 - middle band with mirrored gaps
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 6
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 7
    DB 0,0,0,0,0,1,1,1,0,0,0,0,1,1,1,0,0,0,0,0  ; row 8 - lower platforms
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 9
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 10
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1  ; row 11 (floor)

Map3Data LABEL BYTE
    ; Symmetric zig-zag layout for Map3 (mirrored halves)
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 0
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 1 - top zig islands
    DB 0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0  ; row 2
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 3 - mid zig band
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 4
    DB 0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1  ; row 5 - lower zig islands
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 6
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 7
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0  ; row 8
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 9 - near-floor accents
    DB 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0  ; row 10
    DB 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1  ; row 11 (floor)

Glyph1 DB 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1
Glyph2 DB 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1
Glyph3 DB 1,1,1, 0,0,1, 0,1,1, 0,0,1, 1,1,1

SCAN_1 EQU 02h
SCAN_2 EQU 03h
SCAN_3 EQU 04h

.CODE

SelectMap PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH ES
    MOV  AX, 0A000h
    MOV  ES, AX
SM_Redraw:
    XOR  DI, DI
    MOV  CX, 32000
    MOV  AX, 0101h
    REP  STOSW
    XOR  DI, DI
    MOV  CX, 3520
    MOV  AX, 0303h
    REP  STOSW
    MOV  DI, 7040
    MOV  CX, 320
    MOV  AL, 07h
    REP  STOSB
    CALL DrawPanel1
    CALL DrawPanel2
    CALL DrawPanel3
    MOV  AL, MAPINDEX
    CMP  AL, 2
    JE   SM_HL2
    CMP  AL, 3
    JE   SM_HL3
    MOV  AX, 19
    MOV  DX, 27
    MOV  CX, 84
    MOV  BX, 72
    CALL DrawYellowBorder
    JMP  SM_HLDone
SM_HL2:
    MOV  AX, 118
    MOV  DX, 27
    MOV  CX, 84
    MOV  BX, 72
    CALL DrawYellowBorder
    JMP  SM_HLDone
SM_HL3:
    MOV  AX, 217
    MOV  DX, 27
    MOV  CX, 84
    MOV  BX, 72
    CALL DrawYellowBorder
SM_HLDone:
    MOV  AX, 55
    MOV  DX, 108
    MOV  BL, 0Fh
    LEA  SI, Glyph1
    CALL DrawBigGlyph
    MOV  AX, 154
    MOV  DX, 108
    MOV  BL, 0Fh
    LEA  SI, Glyph2
    CALL DrawBigGlyph
    MOV  AX, 253
    MOV  DX, 108
    MOV  BL, 0Fh
    LEA  SI, Glyph3
    CALL DrawBigGlyph
    CALL PrintMenuText
    MOV  CX, 6000h
SM_PollLoop:
    IN   AL, 60h
    CMP  AL, SCAN_1
    JE   SM_Pick1
    CMP  AL, SCAN_2
    JE   SM_Pick2
    CMP  AL, SCAN_3
    JE   SM_Pick3
    LOOP SM_PollLoop
    JMP  SM_Redraw          
SM_Pick1: 
    MOV  MAPINDEX, 1 
    JMP  SM_Exit
SM_Pick2: 
    MOV  MAPINDEX, 2 
    JMP  SM_Exit
SM_Pick3: 
    MOV  MAPINDEX, 3
SM_Exit:
SM_WaitRelease:
    IN   AL, 60h
    TEST AL, 80h
    JZ   SM_WaitRelease
    XOR  DI, DI
    MOV  CX, 32000
    XOR  AX, AX
    REP  STOSW
    POP  ES
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
SelectMap ENDP

PrintMenuText PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  AH, 02h 
    MOV  BH, 0 
    MOV  DH, 1 
    MOV  DL, 11 
    INT  10h
    MOV  BH, 0 
    MOV  BL, 0Fh 
    MOV  AH, 0Eh
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AL, 'L'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AL, 'C'
    INT  10h
    MOV  AL, 'T'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, 'Y'
    INT  10h
    MOV  AL, 'O'
    INT  10h
    MOV  AL, 'U'
    INT  10h
    MOV  AL, 'R'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, 'M'
    INT  10h
    MOV  AL, 'A'
    INT  10h
    MOV  AL, 'P'
    INT  10h
    MOV  AH, 02h 
    MOV  BH, 0 
    MOV  DH, 13 
    MOV  DL, 0 
    INT  10h
    MOV  BL, 0Bh 
    MOV  AH, 0Eh
    MOV  AL, 'C'
    INT  10h
    MOV  AL, 'L'
    INT  10h
    MOV  AL, 'A'
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'I'
    INT  10h
    MOV  AL, 'C'
    INT  10h
    MOV  AH, 02h 
    MOV  BH, 0 
    MOV  DH, 13 
    MOV  DL, 14 
    INT  10h
    MOV  BL, 07h 
    MOV  AH, 0Eh
    MOV  AL, 'C'
    INT  10h
    MOV  AL, 'A'
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'T'
    INT  10h
    MOV  AL, 'L'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AH, 02h 
    MOV  BH, 0 
    MOV  DH, 13 
    MOV  DL, 28 
    INT  10h
    MOV  BL, 0Fh 
    MOV  AH, 0Eh
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'K'
    INT  10h
    MOV  AL, 'Y'
    INT  10h
    MOV  AH, 02h 
    MOV  BH, 0 
    MOV  DH, 23 
    MOV  DL, 8 
    INT  10h
    MOV  BL, 0Eh 
    MOV  AH, 0Eh
    MOV  AL, 'P'
    INT  10h
    MOV  AL, 'R'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, '1'
    INT  10h
    MOV  AL, ','
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, '2'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, 'O'
    INT  10h
    MOV  AL, 'R'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, '3'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, 'T'
    INT  10h
    MOV  AL, 'O'
    INT  10h
    MOV  AL, ' '
    INT  10h
    MOV  AL, 'S'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AL, 'L'
    INT  10h
    MOV  AL, 'E'
    INT  10h
    MOV  AL, 'C'
    INT  10h
    MOV  AL, 'T'
    INT  10h
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
PrintMenuText ENDP

DrawBigGlyph PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  CX, 5              
DBG_GRow:
    PUSH CX
    PUSH AX                 
    PUSH DX                 
    MOV  CX, 3              
DBG_GCol:
    MOV  AH, [SI]           
    INC  SI
    CMP  AH, 1
    JNE  DBG_Skip
    PUSH AX
    PUSH CX
    PUSH DX
    MOV  CX, 3
DBG_BlockRow:
    PUSH CX
    PUSH DX
    PUSH AX
    MOV  CX, 320
    XCHG AX, DX             
    MUL  CX                 
    ADD  AX, DX             
    MOV  DI, AX
    MOV  AL, BL
    STOSB
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    POP  AX
    POP  DX
    POP  CX
    INC  DX
    LOOP DBG_BlockRow
    POP  DX
    POP  CX
    POP  AX
DBG_Skip:
    ADD  AX, 3              
    LOOP DBG_GCol
    POP  DX
    POP  AX
    POP  CX
    ADD  DX, 3              
    LOOP DBG_GRow
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawBigGlyph ENDP

FillBlock PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  SI, DI             
FB_Row:
    PUSH CX
    MOV  AX, DX
    MOV  CX, 320
    MUL  CX                 
    ADD  AX, SI             
    MOV  DI, AX
    POP  CX
    MOV  AL, AH             
    PUSH CX
    REP  STOSB
    POP  CX
    INC  DX
    DEC  BX
    JNZ  FB_Row
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
FillBlock ENDP

DrawGrayBorder PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  SI, DI             
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  AL, 07h
    PUSH CX 
    REP  STOSB 
    POP  CX
    MOV  AX, DX
    ADD  AX, BX
    DEC  AX
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  AL, 07h
    PUSH CX 
    REP  STOSB 
    POP  CX
    MOV  BP, BX      
DGB_Row:
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  BYTE PTR ES:[DI], 07h
    ADD  DI, CX
    DEC  DI
    MOV  BYTE PTR ES:[DI], 07h
    INC  DX
    DEC  BP
    JNZ  DGB_Row
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawGrayBorder ENDP

DrawYellowBorder PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  SI, AX             
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  AL, 0Eh
    PUSH CX 
    REP  STOSB 
    POP  CX
    SUB  DI, CX
    ADD  DI, 320
    PUSH CX 
    REP  STOSB 
    POP  CX
    MOV  AX, DX
    ADD  AX, BX
    SUB  AX, 2
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  AL, 0Eh
    PUSH CX 
    REP  STOSB 
    POP  CX
    SUB  DI, CX
    ADD  DI, 320
    PUSH CX 
    REP  STOSB 
    POP  CX
    MOV  BP, BX      
DYB_Row:
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, SI
    MOV  DI, AX
    MOV  AL, 0Eh
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    ADD  DI, CX
    SUB  DI, 2
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    INC  DX
    DEC  BP
    JNZ  DYB_Row
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawYellowBorder ENDP

DrawMapPreview PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    PUSH BP
    MOV  BP, DI             
    XOR  BX, BX             
DMP_Row:
    CMP  BX, MAP_ROWS
    JL   ContDMPR
    JMP  DMPDone
ContDMPR:
    PUSH DX                 
    MOV  AX, BP             
    PUSH BX
    XOR  BX, BX             
DMP_Col:
    CMP  BX, MAP_COLS
    JL   ContDMPC
    JMP  DMPNextR
ContDMPC:
    MOV  CL, [SI]
    INC  SI
    CMP  CL, 1
    JNE  DMPSkipT
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  CX, 4
DMPBRow:
    PUSH CX
    PUSH DX
    PUSH AX
    MOV  CX, 320
    XCHG AX, DX
    MUL  CX
    ADD  AX, DX
    MOV  DI, AX
    MOV  AL, GROUNDCOLOR
    STOSB
    MOV  ES:[DI], AL
    MOV  ES:[DI+1], AL
    MOV  ES:[DI+2], AL
    POP  AX
    POP  DX
    POP  CX
    INC  DX
    LOOP DMPBRow
    POP  DX
    POP  CX
    POP  BX
    POP  AX
DMPSkipT:
    ADD  AX, 4
    INC  BX
    JMP  DMP_Col
DMPNextR:
    POP  BX
    POP  DX
    ADD  DX, 4
    INC  BX
    JMP  DMP_Row
DMPDone:
    POP  BP
    POP  SI
    POP  DI
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET
DrawMapPreview ENDP

DrawPanel1 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  DI, 20 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    MOV  AH, COLOR_SKY1
    CALL FillBlock
    LEA  SI, MapData
    MOV  DI, 21 
    MOV  DX, 32
    CALL DrawMapPreview
    MOV  DI, 20 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    CALL DrawGrayBorder
    POP  SI 
    POP  DI 
    POP  DX 
    POP  CX 
    POP  BX 
    POP  AX
    RET
DrawPanel1 ENDP

DrawPanel2 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  DI, 119 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    MOV  AH, COLOR_SKY2
    CALL FillBlock
    LEA  SI, Map2Data
    MOV  DI, 120 
    MOV  DX, 32
    CALL DrawMapPreview
    MOV  DI, 119 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    CALL DrawGrayBorder
    POP  SI 
    POP  DI 
    POP  DX 
    POP  CX 
    POP  BX 
    POP  AX
    RET
DrawPanel2 ENDP

DrawPanel3 PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH SI
    MOV  DI, 218 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    MOV  AH, COLOR_SKY3
    CALL FillBlock
    LEA  SI, Map3Data
    MOV  DI, 219 
    MOV  DX, 32
    CALL DrawMapPreview
    MOV  DI, 218 
    MOV  DX, 28 
    MOV  CX, 82 
    MOV  BX, 70
    CALL DrawGrayBorder
    POP  SI 
    POP  DI 
    POP  DX 
    POP  CX 
    POP  BX 
    POP  AX
    RET
DrawPanel3 ENDP

InitMap PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES
    CALL GetSkyColor        
    MOV  SKYCOLOR, AL
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  DI, DI
    MOV  CX, 32000
    MOV  AL, SKYCOLOR
    MOV  AH, AL
    REP  STOSW
    ; Copy selected template into runtime MapData buffer so collisions match
    CALL GetMapDataPtr      ; returns SI -> template (offset in DS)
    LEA  DI, MapData        ; DI = offset of MapData (destination)
    MOV  AX, SEG MapData
    MOV  ES, AX             ; ES = data segment for destination
    MOV  CX, 240            ; number of tiles (20 * 12)
    CLD
    REP  MOVSB
    ; restore ES to video segment for drawing
    MOV  AX, VideoSeg
    MOV  ES, AX
    CALL DrawAllTiles
    POP  ES
    POP  DI
    POP  CX
    POP  AX
    RET
InitMap ENDP

DrawMap PROC NEAR
    PUSH AX
    PUSH CX
    PUSH DI
    PUSH ES
    CALL GetSkyColor
    MOV  SKYCOLOR, AL
    MOV  AX, VideoSeg
    MOV  ES, AX
    XOR  DI, DI
    MOV  CX, 32000
    MOV  AL, SKYCOLOR
    MOV  AH, AL
    REP  STOSW
    CALL DrawAllTiles
    POP  ES
    POP  DI
    POP  CX
    POP  AX
    RET
DrawMap ENDP

GetSkyColor PROC NEAR
    MOV  AL, MAPINDEX
    CMP  AL, 2 
    JE   GSC2
    CMP  AL, 3 
    JE   GSC3
    MOV  AL, COLOR_SKY1 
    RET
GSC2: 
    MOV  AL, COLOR_SKY2 
    RET
GSC3: 
    MOV  AL, COLOR_SKY3 
    RET
GetSkyColor ENDP

GetMapDataPtr PROC NEAR
    MOV  AL, MAPINDEX
    CMP  AL, 2 
    JE   GMP2
    CMP  AL, 3 
    JE   GMP3
    LEA  SI, MapData  
    RET
GMP2: 
    LEA  SI, Map2Data 
    RET
GMP3: 
    LEA  SI, Map3Data 
    RET
GetMapDataPtr ENDP

DrawAllTiles PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    CALL GetMapDataPtr
    XOR  DX, DX             
DATRow:
    CMP  DX, MAP_ROWS 
    JL   ContDATR
    JMP  DATDone
ContDATR:
    XOR  BX, BX             
DATCol:
    CMP  BX, MAP_COLS 
    JL   ContDATC
    JMP  DATNextR
ContDATC:
    MOV  AL, [SI]
    CMP  AL, 1
    JNE  DATSkip
    PUSH BX 
    PUSH DX
    MOV  AX, BX
    MOV  CX, TILE_W
    MUL  CX
    MOV  BX, AX             
    POP  AX                 
    PUSH AX
    MOV  CX, TILE_H
    MUL  CX                 
    MOV  DX, AX
    MOV  AX, BX
    CALL DrawOneTile
    POP  DX 
    POP  BX
DATSkip:
    INC  SI 
    INC  BX
    JMP  DATCol
DATNextR:
    INC  DX 
    JMP  DATRow
DATDone:
    POP  SI 
    POP  DX 
    POP  CX 
    POP  BX 
    POP  AX
    RET
DrawAllTiles ENDP

DrawOneTile PROC NEAR
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH DI
    PUSH ES
    MOV  BX, AX
    MOV  AX, VideoSeg
    MOV  ES, AX
    MOV  CX, TILE_H
DOTRow:
    PUSH DX
    MOV  AX, DX
    MOV  DI, 320
    MUL  DI
    ADD  AX, BX
    MOV  DI, AX
    PUSH CX
    MOV  CX, TILE_W
    MOV  AL, GROUNDCOLOR
    REP  STOSB
    POP  CX
    POP  DX
    INC  DX
    LOOP DOTRow
    POP  ES 
    POP  DI 
    POP  DX 
    POP  CX 
    POP  BX 
    POP  AX
    RET
DrawOneTile ENDP

END